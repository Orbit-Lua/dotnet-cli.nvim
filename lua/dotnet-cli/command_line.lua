local job = require("dotnet-cli.job")
local workspace = require("dotnet-cli.workspace")
local config = require("dotnet-cli.config")
local M = {}

-- This is an execution boundary, not a completion grammar. The SDK supplies candidates.
local allowed = {
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

function M.parse(text, partial)
  local values, tokens, value, quote, first, started =
    {}, {}, "", nil, nil, false
  local i = 1
  local function finish(last)
    if started then
      values[#values + 1] = value
      tokens[#tokens + 1] = { start = first, finish = last }
      value, first, started = "", nil, false
    end
  end
  while i <= #text do
    local char = text:sub(i, i)
    if not quote and char:match("%s") then
      finish(i - 1)
    else
      if not started then
        first, started = i - 1, true
      end
      if char == "\\" and quote ~= "'" then
        local j = i
        while text:sub(j, j) == "\\" do
          j = j + 1
        end
        local count, next_char = j - i, text:sub(j, j)
        if next_char == '"' then
          value = value .. string.rep("\\", math.floor(count / 2))
          if count % 2 == 1 then
            value = value .. '"'
          elseif quote == '"' then
            quote = nil
          else
            quote = '"'
          end
          i = j
        elseif count == 1 and not quote and next_char:match("%s") then
          value, i = value .. next_char, j
        else
          value, i = value .. string.rep("\\", count), j - 1
        end
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

local function permitted(argv, partial)
  if argv[1] ~= "dotnet" then
    return false
  end
  for _, value in ipairs(argv) do
    local lower = value:lower()
    if
      lower:match("password%s*[:=]")
      or lower:match("^%-%-password")
      or lower:match("connection[%-_]?string%s*[:=]")
      or lower:match("^%-%-connection[%-_]?string")
      or lower:match("api[%-_]?key%s*[:=]")
      or lower:match("^%-%-api[%-_]?key")
      or lower:match("[%-_]token%s*[:=]")
      or lower:match("^%-%-token")
      or lower:match("pwd%s*=")
      or lower:match("https?://[^/]+:[^/]+@")
      or lower == "-k"
      or lower == "--connection"
      or lower:match("^%-%-connection=")
    then
      return false
    end
  end
  local command = argv[2] or ""
  if allowed[command] then
    return true
  end
  if partial and #argv <= 2 then
    for name in pairs(allowed) do
      if name:sub(1, #command) == command then
        return true
      end
    end
  end
  return false
end

local function executable()
  return vim.fn.has("win32") == 1 and "dotnet.exe" or "dotnet"
end

local function utf16_position(text)
  local count = 0
  for _, point in ipairs(vim.fn.str2list(text, true)) do
    count = count + (point > 65535 and 2 or 1)
  end
  return count
end

local function quote_candidate(value)
  if not value:find("[%s\"']") then
    return value
  end
  return '"' .. value:gsub('(\\*)"', '%1%1\\"'):gsub("(\\+)$", "%1%1") .. '"'
end

function M.complete(context, request, reply)
  local argv = M.parse(request.text, true)
  if
    not workspace.matches(context)
    or not argv
    or not permitted(argv, true)
  then
    reply({})
    return
  end
  local _, tokens = M.parse(request.text, true)
  local first, last = request.cursor, request.cursor
  for _, token in ipairs(tokens) do
    if token.start <= request.cursor and token.finish >= request.cursor then
      first, last = token.start, token.finish
    end
  end
  local lines, canceled = {}, false
  local id = job.start({
    stdout_buffered = true,
    argv = {
      executable(),
      "complete",
      "--position",
      tostring(utf16_position(request.text:sub(1, request.cursor))),
      request.text,
    },
    cwd = context.root,
    on_stdout = function(_, data)
      vim.list_extend(lines, data)
    end,
    on_exit = function(code)
      vim.schedule(function()
        if canceled or not workspace.matches(context) then
          return
        end
        if code ~= 0 then
          reply({}, ".NET completion is unavailable")
          return
        end
        local items, seen = {}, {}
        local function add(value)
          value = value:gsub("\r$", "")
          if value == "" or value:find("[\r\n]") or seen[value] then
            return
          end
          if first <= 7 and not allowed[value] then
            return
          end
          seen[value] = true
          items[#items + 1] = {
            label = value,
            text = quote_candidate(value),
            start = first,
            finish = last,
          }
        end
        for _, line in ipairs(lines) do
          add(line)
        end
        local before = request.text:sub(1, first)
        if before:match("%-%-configuration%s+$") or before:match("%-c%s+$") then
          for _, value in ipairs(config.get().build_configurations) do
            add(value)
          end
        elseif
          context.tfm
          and (before:match("%-%-framework%s+$") or before:match("%-f%s+$"))
        then
          add(context.tfm)
        end
        local project_commands = {
          build = true,
          clean = true,
          restore = true,
          test = true,
          publish = true,
          pack = true,
        }
        if
          project_commands[argv[2]]
          and #argv <= 3
          and first > 7
          and not (argv[3] or ""):match("^%-")
        then
          require("dotnet-cli.project").get_csproj_files_async(
            context.root,
            function(files, scan_err)
              if canceled or not workspace.matches(context) then
                return
              end
              if not scan_err then
                local prefix = argv[3] or ""
                for _, file in ipairs(files) do
                  if file:sub(1, #prefix):lower() == prefix:lower() then
                    add(file)
                  end
                end
              end
              reply(items)
            end
          )
        else
          reply(items)
        end
      end)
    end,
  })
  if not id or id <= 0 then
    reply({}, "Could not start .NET completion")
    return
  end
  return function()
    canceled = true
    pcall(job.cancel, id)
  end
end

function M.submit(context, text, ctx)
  local argv, err = M.parse(text)
  if not argv then
    ctx:append(err)
    ctx:set_status("error")
    return
  end
  if not permitted(argv, false) then
    ctx:append(
      "Use a supported SDK command. Run EF, NuGet, and secrets workflows through their manager actions."
    )
    ctx:set_status("error")
    return
  end
  if not workspace.matches(context) then
    ctx:append("Workspace selection changed; reopen Command Line")
    ctx:set_status("error")
    return
  end
  argv[1] = executable()
  local command = argv[2]
  local separator = #argv + 1
  for i = 3, #argv do
    if argv[i] == "--" then
      separator = i
      break
    end
  end
  local application = {}
  while #argv >= separator do
    application[#application + 1] = table.remove(argv, separator)
  end
  local function option(long, short)
    for i = 3, #argv do
      if argv[i] == long or argv[i] == short then
        return argv[i + 1], true
      end
      if argv[i]:sub(1, #long + 1) == long .. "=" then
        return argv[i]:sub(#long + 2), true
      end
    end
  end
  local explicit_project = false
  local value_options = {
    ["--configuration"] = true,
    ["-c"] = true,
    ["--framework"] = true,
    ["-f"] = true,
    ["--output"] = true,
    ["-o"] = true,
    ["--runtime"] = true,
    ["-r"] = true,
    ["--verbosity"] = true,
    ["-v"] = true,
    ["--arch"] = true,
    ["-a"] = true,
    ["--os"] = true,
    ["--project"] = true,
    ["-p"] = true,
  }
  local index = 3
  while index <= #argv do
    if value_options[argv[index]] then
      index = index + 2
    elseif argv[index]:sub(1, 1) == "-" then
      index = index + 1
    else
      explicit_project = true
      break
    end
  end
  if
    context.project
    and (
      command == "build"
      or command == "clean"
      or command == "restore"
      or command == "test"
      or command == "publish"
      or command == "pack"
    )
  then
    if not explicit_project then
      table.insert(argv, 3, context.project)
    end
  elseif
    context.project
    and command == "run"
    and not select(2, option("--project", "-p"))
  then
    vim.list_extend(argv, { "--project", context.project })
  end
  if
    command == "build"
    or command == "clean"
    or command == "run"
    or command == "test"
    or command == "publish"
    or command == "pack"
  then
    local chosen, has_configuration = option("--configuration", "-c")
    if not has_configuration then
      vim.list_extend(argv, { "--configuration", context.configuration })
    end
    if context.tfm and not select(2, option("--framework", "-f")) then
      vim.list_extend(argv, { "--framework", context.tfm })
    end
    if command == "build" and not select(2, option("--output", "-o")) then
      local output = require("dotnet-cli.build").output(
        chosen or context.configuration,
        context.root
      )
      if output then
        vim.list_extend(argv, { "--output", output })
      end
    end
  end
  local interactive = command == "run" or command == "test"
  vim.list_extend(argv, application)
  require("dotnet-cli.commands.common").run(
    ctx,
    argv,
    { cwd = context.root, echo = false, interactive = interactive }
  )
end

M.spec = {
  name = "Command Line",
  desc = "type a dotnet command with SDK suggestions",
  icon = "󰘳 ",
  action = function(ctx)
    local context = workspace.current()
    ctx:command({
      title = "Dotnet Command Line",
      initial = "dotnet ",
      complete = function(request, reply)
        return M.complete(context, request, reply)
      end,
      submit = function(text, output)
        M.submit(context, text, output)
      end,
    })
  end,
}

return M
