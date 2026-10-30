local workspace = require("dotnet-cli.workspace")
local project = require("dotnet-cli.project")
local job = require("dotnet-cli.job")
local M = {}

function M.setup(title)
  local build_cmd = require("dotnet-cli.commands.build")
  local publish_cmd = require("dotnet-cli.commands.publish")

  -- ── individual user commands (work without the UI) ─────────────────────────

  local function notify_job(cmd, msg_start, msg_ok, msg_fail, root)
    vim.notify(msg_start, vim.log.levels.INFO, { title = title })
    job.run(cmd, nil, nil, {
      cwd = root,
      on_exit = function(code)
        vim.schedule(function()
          local ok = code == 0
          vim.notify(
            ok and msg_ok or msg_fail,
            ok and vim.log.levels.INFO or vim.log.levels.ERROR,
            { title = title }
          )
        end)
      end,
    })
  end

  vim.api.nvim_create_user_command("DotnetBuild", function()
    local root = vim.fs.normalize(vim.fn.getcwd())
    local captured, buffer =
      workspace.activate(root), vim.api.nvim_get_current_buf()
    vim.notify(
      "Scanning .NET projects…",
      vim.log.levels.INFO,
      { title = title }
    )
    project.get_csproj_files_async(root, function(files)
      if not workspace.matches(captured, buffer) then
        return
      end
      if #files == 0 then
        vim.notify(
          "No .csproj files found",
          vim.log.levels.WARN,
          { title = title }
        )
        return
      end
      vim.ui.select(files, { prompt = "Choose project to build" }, function(f)
        if not workspace.matches(captured, buffer) then
          return
        end
        if f then
          local path = vim.fs.joinpath(root, f)
          local chosen =
            workspace.select_project(path, { root = captured.root })
          notify_job(
            build_cmd.get_cmd(
              path,
              chosen.configuration,
              chosen.tfm,
              chosen.root
            ),
            "Building…",
            "Build succeeded",
            "Build failed",
            captured.root
          )
        end
      end)
    end)
  end, { desc = "Dotnet Build" })

  vim.api.nvim_create_user_command("DotnetPublish", function()
    local root = vim.fs.normalize(vim.fn.getcwd())
    local captured, buffer =
      workspace.activate(root), vim.api.nvim_get_current_buf()
    vim.notify(
      "Scanning .NET projects…",
      vim.log.levels.INFO,
      { title = title }
    )
    project.get_csproj_files_async(root, function(files)
      if not workspace.matches(captured, buffer) then
        return
      end
      if #files == 0 then
        vim.notify(
          "No .csproj files found",
          vim.log.levels.WARN,
          { title = title }
        )
        return
      end
      vim.ui.select(files, { prompt = "Choose project to publish" }, function(f)
        if not workspace.matches(captured, buffer) then
          return
        end
        if f then
          local path = vim.fs.joinpath(root, f)
          workspace.select_project(path, { root = captured.root })
          notify_job(
            publish_cmd.get_cmd(path),
            "Publishing…",
            "Publish succeeded",
            "Publish failed",
            captured.root
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

    local sdk_lines, sdk_ok = job.run_sync({ "dotnet", "--list-sdks" })
    if not sdk_ok or #sdk_lines == 0 then
      vim.notify(
        "Failed to retrieve SDK list.",
        vim.log.levels.ERROR,
        { title = title }
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
            { title = title }
          )
        else
          vim.notify(
            "Failed to parse existing global.json",
            vim.log.levels.ERROR,
            { title = title }
          )
        end
      else
        local output, ok = job.run_sync({
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
          { title = title }
        )
      end
    end)
  end, { desc = "Dotnet global.json – pin SDK version" })

  vim.api.nvim_create_user_command("DotnetManager", function()
    require("dotnet-cli").open()
  end, { desc = "Open Dotnet Manager UI" })

  vim.api.nvim_create_user_command("DotnetDebug", function()
    local ok, err = require("dotnet-cli.dap").launch()
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = title })
    end
  end, { desc = "Debug selected .NET project" })

  vim.api.nvim_create_user_command("DotnetAttach", function()
    local ok, err = require("dotnet-cli.dap").attach()
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = title })
    end
  end, { desc = "Attach .NET debugger to a local process" })
end

return M
