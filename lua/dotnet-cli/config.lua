-- dotnet-cli.nvim configuration
-- Default options and user config merging.

local M = {}

---@class DotnetCliConfig
---@field roslyn_auto_insert boolean Enable Roslyn '/' auto-insert (default true)
---@field build_configurations string[] Available build configurations
---@field default_build_config string Default build configuration
---@field output_dir_template string Template for build output directory

---@type DotnetCliConfig
M.defaults = {
  roslyn_auto_insert = true,
  build_configurations = { "Debug", "Release" },
  default_build_config = "Debug",
  output_dir_template = "bin/{config}",
}

---@type DotnetCliConfig
M.values = vim.deepcopy(M.defaults)

---Apply user options on top of defaults.
---@param opts? table
M.setup = function(opts)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

---Get the current resolved config.
---@return DotnetCliConfig
M.get = function()
  return M.values
end

return M
