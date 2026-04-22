-- dotnet-cli.nvim commands: Solution Management
local job = require("dotnet-cli.job")
local parsers = require("dotnet-cli.parsers")
local project = require("dotnet-cli.project")

local M = {}

---@type CometCommand
M.spec = {
  name = "Solution",
  icon = "󰘐 ",
  icon_hl = "DiagnosticHint",
  desc = "dotnet sln management",
  action = function(ctx)
    ctx:select({
      { _raw = "list", icon = "󰈚 ", icon_hl = "Comment", name = "List Projects" },
      { _raw = "add", icon = "󰐕 ", icon_hl = "DiagnosticOk", name = "Add Project" },
      { _raw = "remove", icon = "󰍴 ", icon_hl = "DiagnosticError", name = "Remove Project" },
      { _raw = "new", icon = "󰝒 ", icon_hl = "DiagnosticInfo", name = "New Solution" },
    }, {
      title = "Solution Action",
      on_select = function(item, c)
        local action = item._raw

        if action == "new" then
          vim.cmd("stopinsert")
          vim.ui.input({ prompt = "Solution name: " }, function(name)
            if not name or name == "" then
              return
            end
            vim.schedule(function()
              job.run({ "dotnet", "new", "sln", "-n", name }, c)
            end)
          end)
          return
        end

        if action == "list" then
          project.select_sln(c, function(sln, c2)
            job.run({ "dotnet", "sln", sln, "list" }, c2)
          end)
          return
        end

        if action == "add" then
          project.select_sln(c, function(sln, c2)
            local files = project.get_csproj_files()
            if #files == 0 then
              c2:clear()
              c2:append("No .csproj files found in: " .. vim.fn.getcwd())
              return
            end
            if #files == 1 then
              job.run({ "dotnet", "sln", sln, "add", files[1] }, c2)
              return
            end

            local proj_items = {}
            for _, f in ipairs(files) do
              table.insert(proj_items, {
                _raw = f,
                icon = project.get_file_icon(f),
                icon_hl = "DevIconCs",
                name = f,
              })
            end

            c2:select(proj_items, {
              title = "Add Project",
              multi_select = true,
              on_select = function(selected, c3)
                local cmd = { "dotnet", "sln", sln, "add" }
                for _, proj_item in ipairs(selected) do
                  table.insert(cmd, proj_item._raw)
                end
                job.run(cmd, c3)
              end,
            })
          end)
          return
        end

        if action == "remove" then
          project.select_sln(c, function(sln, c2)
            c2:clear()
            local raw, ok = job.run_sync({ "dotnet", "sln", sln, "list" })
            if not ok then
              c2:append("Failed to list projects in " .. sln)
              return
            end

            local projects = parsers.sln_projects(raw)
            if #projects == 0 then
              c2:append("No projects found in " .. sln)
              return
            end

            local proj_items = {}
            for _, p in ipairs(projects) do
              table.insert(proj_items, {
                _raw = p,
                icon = "󰈚 ",
                icon_hl = "Special",
                name = p,
              })
            end

            c2:select(proj_items, {
              title = "Remove Project",
              multi_select = true,
              on_select = function(selected, c3)
                local cmd = { "dotnet", "sln", sln, "remove" }
                for _, proj_item in ipairs(selected) do
                  table.insert(cmd, proj_item._raw)
                end
                job.run(cmd, c3)
              end,
            })
          end)
          return
        end
      end,
    })
  end,
}

return M
