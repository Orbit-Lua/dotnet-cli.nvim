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
  local build_cmd = require("dotnet-cli.commands.build")
  local publish_cmd = require("dotnet-cli.commands.publish")

  -- ── individual user commands (work without the UI) ─────────────────────────

  local function notify_job(cmd, msg_start, msg_ok, msg_fail)
    vim.notify(msg_start, vim.log.levels.INFO, { title = M.title })
    M.job.run(cmd, nil, nil, {
      on_exit = function(code)
        vim.schedule(function()
          local ok = code == 0
          vim.notify(
            ok and msg_ok or msg_fail,
            ok and vim.log.levels.INFO or vim.log.levels.ERROR,
            { title = M.title }
          )
        end)
      end,
    })
  end

  vim.api.nvim_create_user_command("DotnetBuild", function()
    local root = vim.fn.getcwd()
    vim.notify(
      "Scanning .NET projects…",
      vim.log.levels.INFO,
      { title = M.title }
    )
    M.project.get_csproj_files_async(root, function(files)
      if #files == 0 then
        vim.notify(
          "No .csproj files found",
          vim.log.levels.WARN,
          { title = M.title }
        )
        return
      end
      vim.ui.select(files, { prompt = "Choose project to build" }, function(f)
        if f then
          local path = vim.fs.joinpath(root, f)
          M.workspace.select_project(path)
          notify_job(
            build_cmd.get_cmd(path),
            "Building…",
            "Build succeeded",
            "Build failed"
          )
        end
      end)
    end)
  end, { desc = "Dotnet Build" })

  vim.api.nvim_create_user_command("DotnetPublish", function()
    local root = vim.fn.getcwd()
    vim.notify(
      "Scanning .NET projects…",
      vim.log.levels.INFO,
      { title = M.title }
    )
    M.project.get_csproj_files_async(root, function(files)
      if #files == 0 then
        vim.notify(
          "No .csproj files found",
          vim.log.levels.WARN,
          { title = M.title }
        )
        return
      end
      vim.ui.select(files, { prompt = "Choose project to publish" }, function(f)
        if f then
          local path = vim.fs.joinpath(root, f)
          M.workspace.select_project(path)
          notify_job(
            publish_cmd.get_cmd(path),
            "Publishing…",
            "Publish succeeded",
            "Publish failed"
          )
        end
      end)
    end)
  end, { desc = "Dotnet Publish" })

  vim.api.nvim_create_user_command("DotnetGlobalJson", function()
    local existing_version
    if vim.fn.filereadable("global.json") == 1 then
      local ok, data = pcall(
        vim.json.decode,
        table.concat(vim.fn.readfile("global.json"), "\n")
      )
      if ok and data and data.sdk and data.sdk.version then
        existing_version = data.sdk.version
      end
    end

    local sdk_lines, sdk_ok = M.job.run_sync({ "dotnet", "--list-sdks" })
    if not sdk_ok or #sdk_lines == 0 then
      vim.notify(
        "Failed to retrieve SDK list.",
        vim.log.levels.ERROR,
        { title = M.title }
      )
      return
    end
    local choices = {}
    for i = #sdk_lines, 1, -1 do
      table.insert(choices, (sdk_lines[i]:gsub("[\r\n]", "")))
    end
    vim.ui.select(choices, {
      prompt = existing_version
          and ("Current: " .. existing_version .. " — Select new SDK version:")
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
            "Updated global.json (SDK "
              .. existing_version
              .. " → "
              .. version
              .. ")",
            vim.log.levels.INFO,
            { title = M.title }
          )
        else
          vim.notify(
            "Failed to parse existing global.json",
            vim.log.levels.ERROR,
            { title = M.title }
          )
        end
      else
        local output, ok = M.job.run_sync({
          "dotnet",
          "new",
          "globaljson",
          "--sdk-version",
          version,
        })
        vim.notify(
          ok and "Created global.json (SDK " .. version .. ")"
            or "Error: " .. table.concat(output, "\n"),
          ok and vim.log.levels.INFO or vim.log.levels.ERROR,
          { title = M.title }
        )
      end
    end)
  end, { desc = "Dotnet global.json – pin SDK version" })

  vim.api.nvim_create_user_command("DotnetManager", function()
    M.open()
  end, { desc = "Open Dotnet Manager UI" })

  vim.api.nvim_create_user_command("DotnetDebug", function()
    M.workspace.activate(vim.fn.getcwd())
    local function run(project)
      if not project then
        return
      end
      M.workspace.select_project(project)
      local ok, err = require("dotnet-cli.dap").launch()
      if not ok then
        vim.notify(err, vim.log.levels.ERROR, { title = M.title })
      end
    end
    local selected = M.workspace.current().project
    if selected then
      run(selected)
    else
      local root = vim.fn.getcwd()
      vim.notify(
        "Scanning .NET projects…",
        vim.log.levels.INFO,
        { title = M.title }
      )
      M.project.get_csproj_files_async(root, function(files)
        if #files == 0 then
          vim.notify(
            "No .csproj files found",
            vim.log.levels.WARN,
            { title = M.title }
          )
          return
        end
        vim.ui.select(files, { prompt = "Choose project to debug" }, function(f)
          run(f and vim.fs.joinpath(root, f))
        end)
      end)
    end
  end, { desc = "Debug selected .NET project" })

  vim.api.nvim_create_user_command("DotnetAttach", function()
    local ok, err = require("dotnet-cli.dap").attach()
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = M.title })
    end
  end, { desc = "Attach .NET debugger to a local process" })

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
