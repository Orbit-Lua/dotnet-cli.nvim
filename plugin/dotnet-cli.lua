-- dotnet-cli.nvim plugin loader
-- Registers lazy-loadable commands without requiring full setup.
if vim.g.loaded_dotnet_cli then
  return
end
vim.g.loaded_dotnet_cli = true

-- Defer setup to when the plugin is actually loaded via lazy.nvim opts
-- The user calls require("dotnet-cli").setup(opts) from their plugin spec.
