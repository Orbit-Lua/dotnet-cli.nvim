-- dotnet-cli.nvim – .NET CLI integration for Neovim
-- Provides DotnetManager UI, build/publish/test commands, and SDK management.

local M = {}

M.title = "Dotnet"

---Open the Dotnet Manager UI.
M.open = function()
  local commands = require("dotnet-cli.commands").get_all()
  require("dotnet-cli.ui").open(commands, { title = "Dotnet Manager" })
end

-- Re-export submodules for external use
M.project = require("dotnet-cli.project")
M.sdk = require("dotnet-cli.sdk")
M.parsers = require("dotnet-cli.parsers")
M.job = require("dotnet-cli.job")

---@param opts? DotnetCliConfig
M.setup = function(opts)
  local config = require("dotnet-cli.config")
  config.setup(opts)

  local cfg = config.get()
  local build_cmd = require("dotnet-cli.commands.build")
  local publish_cmd = require("dotnet-cli.commands.publish")

  -- ── individual user commands (work without the UI) ─────────────────────────

  local function notify_job(cmd, msg_start, msg_ok, msg_fail)
    vim.notify(msg_start, vim.log.levels.INFO, { title = M.title })
    vim.fn.jobstart(cmd, {
      on_exit = function(_, code)
        local ok = code == 0
        vim.notify(ok and msg_ok or msg_fail, ok and vim.log.levels.INFO or vim.log.levels.ERROR, { title = M.title })
      end,
    })
  end

  vim.api.nvim_create_user_command("DotnetBuild", function()
    vim.ui.select(M.project.get_csproj_files(), { prompt = "Choose project to build" }, function(f)
      if f then
        notify_job(build_cmd.get_cmd(f), "Building…", "Build succeeded", "Build failed")
      end
    end)
  end, { desc = "Dotnet Build" })

  vim.api.nvim_create_user_command("DotnetPublish", function()
    vim.ui.select(M.project.get_csproj_files(), { prompt = "Choose project to publish" }, function(f)
      if f then
        notify_job(publish_cmd.get_cmd(f), "Publishing…", "Publish succeeded", "Publish failed")
      end
    end)
  end, { desc = "Dotnet Publish" })

  vim.api.nvim_create_user_command("DotnetGlobalJson", function()
    local existing_version
    if vim.fn.filereadable("global.json") == 1 then
      local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile("global.json"), "\n"))
      if ok and data and data.sdk and data.sdk.version then
        existing_version = data.sdk.version
      end
    end

    local sdk_lines = vim.fn.systemlist("dotnet --list-sdks")
    if vim.v.shell_error ~= 0 or #sdk_lines == 0 then
      vim.notify("Failed to retrieve SDK list.", vim.log.levels.ERROR, { title = M.title })
      return
    end
    local choices = {}
    for i = #sdk_lines, 1, -1 do
      table.insert(choices, (sdk_lines[i]:gsub("[\r\n]", "")))
    end
    vim.ui.select(choices, {
      prompt = existing_version and ("Current: " .. existing_version .. " — Select new SDK version:")
        or "Select .NET SDK version:",
    }, function(choice)
      if not choice then
        return
      end
      local version = choice:match("^(%S+)")
      if not version then
        return
      end

      if existing_version then
        local raw = table.concat(vim.fn.readfile("global.json"), "\n")
        local ok, data = pcall(vim.json.decode, raw)
        if ok and data then
          data.sdk = data.sdk or {}
          data.sdk.version = version
          vim.fn.writefile({ vim.json.encode(data) }, "global.json")
          vim.notify(
            "Updated global.json (SDK " .. existing_version .. " → " .. version .. ")",
            vim.log.levels.INFO,
            { title = M.title }
          )
        else
          vim.notify("Failed to parse existing global.json", vim.log.levels.ERROR, { title = M.title })
        end
      else
        local out = vim.fn.system("dotnet new globaljson --sdk-version " .. version)
        local ok = vim.v.shell_error == 0
        vim.notify(
          ok and "Created global.json (SDK " .. version .. ")" or "Error: " .. out,
          ok and vim.log.levels.INFO or vim.log.levels.ERROR,
          { title = M.title }
        )
      end
    end)
  end, { desc = "Dotnet global.json – pin SDK version" })

  vim.api.nvim_create_user_command("DotnetManager", function()
    M.open()
  end, { desc = "Open Dotnet Manager UI" })

  -- ── Roslyn auto-insert ────────────────────────────────────────────────────

  if cfg.roslyn_auto_insert then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("DotnetCliRoslyn", { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local bufnr = args.buf

        if client and (client.name == "roslyn" or client.name == "roslyn_ls") then
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
