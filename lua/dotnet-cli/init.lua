-- dotnet-cli.nvim – .NET CLI integration for Neovim
-- Provides DotnetManager UI, build/publish/test commands, and SDK management.

local M = {}

M.title = "Dotnet"

---Open the Dotnet Manager UI.
M.open = function()
  local workspace = require("dotnet-cli.workspace")
  workspace.activate(vim.fn.getcwd())
  local commands = require("dotnet-cli.commands").get_all()
  require("dotnet-cli.ui").open(commands, {
    session_id = "dotnet_manager:" .. workspace.current().root,
    root_title = "Dotnet Manager",
    default_icon = "󰈚 ",
  })
end

-- Re-export submodules for external use
M.project = require("dotnet-cli.project")
M.sdk = require("dotnet-cli.sdk")
M.parsers = require("dotnet-cli.parsers")
M.job = require("dotnet-cli.job")
M.workspace = require("dotnet-cli.workspace")
M.msbuild = require("dotnet-cli.msbuild")
M.launch = require("dotnet-cli.launch")

M.setup_dap = function(opts)
  return require("dotnet-cli.dap").setup(opts)
end

---@param opts? DotnetCliConfig
M.setup = function(opts)
  local config = require("dotnet-cli.config")
  config.setup(opts)

  local cfg = config.get()
  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("DotnetCliWorkspace", { clear = true }),
    callback = function()
      M.workspace.activate(vim.fn.getcwd())
    end,
  })
  require("dotnet-cli.commands.register").setup(M.title)

  -- ── Roslyn auto-insert ────────────────────────────────────────────────────

  if cfg.roslyn_auto_insert then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("DotnetCliRoslyn", { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local bufnr = args.buf

        if
          client and (client.name == "roslyn" or client.name == "roslyn_ls")
        then
          vim.api.nvim_create_autocmd("InsertCharPre", {
            desc = "Roslyn: Trigger an auto insert on '/'.",
            buffer = bufnr,
            callback = function()
              local char = vim.v.char
              if char ~= "/" then
                return
              end

              local row, col = unpack(vim.api.nvim_win_get_cursor(0))
              row, col = row - 1, col + 1
              local uri = vim.uri_from_bufnr(bufnr)

              local params = {
                _vs_textDocument = { uri = uri },
                _vs_position = { line = row, character = col },
                _vs_ch = char,
                _vs_options = {
                  tabSize = vim.bo[bufnr].tabstop,
                  insertSpaces = vim.bo[bufnr].expandtab,
                },
              }

              vim.defer_fn(function()
                client:request(
                  ---@diagnostic disable-next-line: param-type-mismatch
                  "textDocument/_vs_onAutoInsert",
                  params,
                  function(err, result, _)
                    if err or not result then
                      return
                    end
                    vim.snippet.expand(result._vs_textEdit.newText)
                  end,
                  bufnr
                )
              end, 1)
            end,
          })
        end
      end,
    })
  end
end

return M
