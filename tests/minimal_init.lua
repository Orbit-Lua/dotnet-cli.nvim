local plugins = vim.env.DOTNET_TEST_PLUGINS
  or (vim.fn.stdpath("data") .. "/lazy")
vim.g.dotnet_test_plugins = plugins
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.g.dotnet_test_root = root
for _, name in ipairs({ "CONFIG", "DATA", "STATE", "CACHE" }) do
  vim.env["XDG_" .. name .. "_HOME"] = root .. "/" .. name:lower()
end
vim.env.NVIM_LOG_FILE = root .. "/nvim.log"
vim.o.shadafile = "NONE"
vim.o.swapfile = false
vim.opt.runtimepath = { vim.fn.getcwd(), vim.env.VIMRUNTIME }
vim.opt.packpath = {}
for _, path in ipairs({
  plugins .. "/plenary.nvim",
  vim.env.DOTNET_TEST_COMET or (plugins .. "/comet.nvim"),
  plugins .. "/nvim-dap",
}) do
  assert(vim.fn.isdirectory(path) == 1, "Missing test dependency: " .. path)
  vim.opt.runtimepath:append(path)
end
package.path = vim.fn.getcwd() .. "/?.lua;" .. package.path
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    vim.fn.delete(root, "rf")
  end,
})
vim.cmd("runtime plugin/plenary.vim")
