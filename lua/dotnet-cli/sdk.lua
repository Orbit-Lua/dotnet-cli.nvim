-- dotnet-cli.nvim SDK helpers
-- Detect the active .NET SDK version.

local M = {}

---@type table<string, string>
local _versions = {}

local function cache_key(root)
  return vim.fs.normalize(vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p"))
end

---Get the major version number of the active .NET SDK (cached per session).
---@return number?
M.get_major = function(root)
  local version = M.get_version(root)
  if not version then
    return nil
  end
  local major = version:match("^(%d+)")
  return major and tonumber(major)
end

---Get the full SDK version string.
---@return string?
M.get_version = function(root)
  local key = cache_key(root)
  if _versions[key] then
    return _versions[key]
  end
  local lines, ok = require("dotnet-cli.job").run_sync(
    { "dotnet", "--version" },
    {
      cwd = key,
    }
  )
  if not ok or not lines[1] then
    return nil
  end
  _versions[key] = vim.trim(lines[1])
  return _versions[key]
end

---Check whether the dotnet CLI is available.
---@return boolean
M.is_available = function()
  return vim.fn.executable("dotnet") == 1
end

---Reset the cached SDK version (useful for testing).
M._reset_cache = function()
  _versions = {}
end

return M
