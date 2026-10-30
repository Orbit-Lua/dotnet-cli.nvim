-- Persist selection metadata only; command input and launch environments never enter this store.
local M = {}
local fields = { "project", "solution", "configuration", "tfm", "profile" }

function M.identity(root)
  local path = vim.fs.normalize(vim.uv.fs_realpath(root) or root)
  return vim.fn.has("win32") == 1 and path:lower() or path
end

local function location(root)
  return vim.fs.joinpath(
    vim.fn.stdpath("state"),
    "dotnet-cli",
    "workspaces",
    vim.fn.sha256(M.identity(root)) .. ".json"
  )
end

function M.load(root)
  local path = location(root)
  if not vim.uv.fs_stat(path) then
    return {}
  end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  if
    not ok
    or type(data) ~= "table"
    or data.version ~= 1
    or data.root ~= M.identity(root)
    or type(data.selection) ~= "table"
  then
    return nil, "Invalid .NET workspace state; select the startup project again"
  end
  local result = {}
  for _, field in ipairs(fields) do
    local value = data.selection[field]
    if value ~= nil and (type(value) ~= "string" or value == "") then
      return nil,
        "Invalid .NET workspace selection; select the startup project again"
    end
    if value and (field == "project" or field == "solution") then
      if not (value:match("^[/\\]") or value:match("^%a:[/\\]")) then
        value = vim.fs.joinpath(root, value)
      end
      value = vim.fs.normalize(value)
    end
    result[field] = value
  end
  return result
end

function M.save(selection)
  local path = location(selection.root)
  local record = {}
  for _, field in ipairs(fields) do
    local value = selection[field]
    if value and (field == "project" or field == "solution") then
      value = vim.fs.relpath(selection.root, value) or value
    end
    record[field] = value
  end
  local temporary
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    temporary = path
      .. "."
      .. vim.uv.os_getpid()
      .. "."
      .. vim.uv.hrtime()
      .. ".tmp"
    local fd = assert(vim.uv.fs_open(temporary, "wx", 384))
    local encoded = vim.json.encode({
      version = 1,
      root = M.identity(selection.root),
      selection = record,
    })
    local written, write_err = vim.uv.fs_write(fd, encoded, 0)
    local closed, close_err = vim.uv.fs_close(fd)
    assert(written == #encoded, write_err or "incomplete state write")
    assert(closed, close_err)
    assert(vim.uv.fs_rename(temporary, path))
  end)
  if temporary then
    vim.uv.fs_unlink(temporary)
  end
  return ok, ok and nil or tostring(err)
end

return M
