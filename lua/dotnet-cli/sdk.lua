-- dotnet-cli.nvim SDK helpers
-- Detect the active .NET SDK version.

local M = {}

---@type number?
local _sdk_major

---Get the major version number of the active .NET SDK (cached per session).
---@return number?
M.get_major = function()
  if _sdk_major then
    return _sdk_major
  end
  local out = vim.fn.system("dotnet --version")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local major = vim.trim(out):match("^(%d+)")
  _sdk_major = major and tonumber(major)
  return _sdk_major
end

---Get the full SDK version string.
---@return string?
M.get_version = function()
  local out = vim.fn.system("dotnet --version")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(out)
end

---Check whether the dotnet CLI is available.
---@return boolean
M.is_available = function()
  return vim.fn.executable("dotnet") == 1
end

---Reset the cached SDK version (useful for testing).
M._reset_cache = function()
  _sdk_major = nil
end

return M
