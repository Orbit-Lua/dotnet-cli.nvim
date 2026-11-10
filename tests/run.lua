-- Run each spec in its own Neovim process through telemetry.lua. Each child
-- validates its own results and exits nonzero on a failure; the parent checks
-- only that the child reached its results.
local cwd = vim.fn.getcwd()
local plugins = vim.env.DOTNET_TEST_PLUGINS
  or (vim.fn.stdpath("data") .. "/lazy")
local telemetry_path = vim.env.DOTNET_TEST_TELEMETRY
  or (plugins .. "/telemetry.lua")
if vim.fn.isdirectory(telemetry_path) == 0 then
  io.stderr:write("Missing test dependency: " .. telemetry_path .. "\n")
  vim.cmd("cquit 1")
end
package.path = table.concat({
  cwd .. "/?.lua",
  telemetry_path .. "/lua/?.lua",
  telemetry_path .. "/lua/?/init.lua",
  package.path,
}, ";")
local telemetry = require("telemetry")

---@param pattern string a spec file or a directory of `*_spec.lua` files
---@return string[]
local function discover(pattern)
  local files = pattern:match("%.lua$") and { pattern }
    or vim.fn.glob(pattern .. "/*_spec.lua", false, true)
  assert(#files > 0, "No specs found: " .. pattern)
  return files
end

---@param root string
---@param index integer
---@param file string
---@return Telemetry.Suite
local function suite(root, index, file)
  local completion = root .. "/" .. index .. ".json"
  return {
    name = file,
    argv = {
      vim.v.progpath,
      "--headless",
      "--noplugin",
      "-i",
      "NONE",
      "-u",
      "tests/minimal_init.lua",
      "-l",
      "tests/spec.lua",
      file,
      completion,
    },
    env = { DOTNET_TEST_TELEMETRY = telemetry_path },
    timeout = 60000,
    check = function()
      if vim.fn.filereadable(completion) == 0 then
        return file .. ": missing executed result"
      end
    end,
  }
end

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local ok, result = pcall(function()
  local pattern = arg[1] or "tests/dotnet-cli"
  local suites = {}
  for index, file in ipairs(discover(pattern)) do
    suites[index] = suite(root, index, file)
  end
  return telemetry.run({ title = pattern, suites = suites })
end)
vim.fn.delete(root, "rf")
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  vim.cmd("cquit 1")
end
telemetry.exit(result)
