-- Tokenize and screen a typed dotnet command line.
local M = {}

-- This is an execution boundary, not a completion grammar. The SDK supplies
-- candidates.
---@type table<string, boolean>
M.allowed = {
  build = true,
  clean = true,
  restore = true,
  test = true,
  run = true,
  publish = true,
  pack = true,
  format = true,
  ["--info"] = true,
  ["--version"] = true,
  ["--list-sdks"] = true,
  ["--list-runtimes"] = true,
  ["--help"] = true,
  ["-h"] = true,
}

---@class DotnetCliToken
---@field start integer Byte offset before the first character.
---@field finish integer Byte offset of the last character.

---Read a run of backslashes at `i` with Windows argument rules: before a
---quote, pairs become backslashes and an odd one escapes the quote.
---@param text string
---@param i integer index of the first backslash
---@param quote? string open quote character
---@return string value text to append
---@return integer index last consumed index
---@return string? quote open quote after the run
local function backslashes(text, i, quote)
  local j = i
  while text:sub(j, j) == "\\" do
    j = j + 1
  end
  local count, next_char = j - i, text:sub(j, j)
  if next_char == '"' then
    local value = string.rep("\\", math.floor(count / 2))
    if count % 2 == 1 then
      return value .. '"', j, quote
    end
    return value, j, quote ~= '"' and '"' or nil
  end
  if count == 1 and not quote and next_char:match("%s") then
    return next_char, j, quote
  end
  return string.rep("\\", count), j - 1, quote
end

---Split a command line into values and their byte ranges.
---@param text string
---@param partial? boolean accept an open quote while the user types
---@return string[]? values
---@return DotnetCliToken[]|string tokens, or the error without `partial`
function M.parse(text, partial)
  local values, tokens = {}, {}
  local value, quote, first, started = "", nil, nil, false
  local function finish(last)
    if started then
      values[#values + 1] = value
      tokens[#tokens + 1] = { start = first, finish = last }
      value, first, started = "", nil, false
    end
  end
  local i = 1
  while i <= #text do
    local char = text:sub(i, i)
    if not quote and char:match("%s") then
      finish(i - 1)
    else
      if not started then
        first, started = i - 1, true
      end
      if char == "\\" and quote ~= "'" then
        local append
        append, i, quote = backslashes(text, i, quote)
        value = value .. append
      elseif char == quote then
        quote = nil
      elseif not quote and (char == '"' or char == "'") then
        quote = char
      else
        value = value .. char
      end
    end
    i = i + 1
  end
  if quote and not partial then
    return nil, "Close the quoted argument before submitting"
  end
  finish(#text)
  return values, tokens
end

-- Arguments that carry secrets never run through the command line.
local secret_patterns = {
  "password%s*[:=]",
  "^%-%-password",
  "connection[%-_]?string%s*[:=]",
  "^%-%-connection[%-_]?string",
  "api[%-_]?key%s*[:=]",
  "^%-%-api[%-_]?key",
  "[%-_]token%s*[:=]",
  "^%-%-token",
  "pwd%s*=",
  "https?://[^/]+:[^/]+@",
  "^%-%-connection=",
}
local secret_flags = { ["-k"] = true, ["--connection"] = true }

---@param value string
---@return boolean
local function secret(value)
  local lower = value:lower()
  if secret_flags[lower] then
    return true
  end
  for _, pattern in ipairs(secret_patterns) do
    if lower:match(pattern) then
      return true
    end
  end
  return false
end

---Whether a command may run: `dotnet`, an allowed subcommand, and no
---secret-bearing argument. A partial line may still be a subcommand prefix.
---@param argv string[]
---@param partial boolean
---@return boolean
function M.permitted(argv, partial)
  if argv[1] ~= "dotnet" then
    return false
  end
  for _, value in ipairs(argv) do
    if secret(value) then
      return false
    end
  end
  local command = argv[2] or ""
  if M.allowed[command] then
    return true
  end
  if partial and #argv <= 2 then
    for name in pairs(M.allowed) do
      if name:sub(1, #command) == command then
        return true
      end
    end
  end
  return false
end

---Count UTF-16 code units, as `dotnet complete --position` expects.
---@param text string
---@return integer
function M.utf16_position(text)
  local count = 0
  for _, point in ipairs(vim.fn.str2list(text, true)) do
    count = count + (point > 65535 and 2 or 1)
  end
  return count
end

---Quote a completion candidate that contains spaces or quotes.
---@param value string
---@return string
function M.quote_candidate(value)
  if not value:find("[%s\"']") then
    return value
  end
  return '"' .. value:gsub('(*)"', '%1%1\\"'):gsub("(+)$", "%1%1") .. '"'
end

return M
