local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

M.command = function(action, project, startup, name)
  local cmd = { "dotnet", "ef" }
  vim.list_extend(cmd, action)
  if name then
    table.insert(cmd, name)
  end
  vim.list_extend(cmd, { "--project", project, "--startup-project", startup })
  return cmd
end

local actions = {
  { name = "List DbContexts", parts = { "dbcontext", "list" } },
  { name = "List Migrations", parts = { "migrations", "list" } },
  { name = "Add Migration", parts = { "migrations", "add" }, input = true },
  { name = "Remove Last Migration", parts = { "migrations", "remove" } },
  { name = "Generate SQL Script", parts = { "migrations", "script" } },
  { name = "Update Local Database", parts = { "database", "update" } },
}

M.spec = {
  name = "EF Core",
  icon = "󰆼 ",
  desc = "contexts and migrations using dotnet-ef",
  action = function(ctx)
    ctx:select(actions, {
      title = "EF Core Action",
      on_select = function(item, c)
        common.project(c, function(project, child)
          local startup = workspace.current().project or project
          local function run(name)
            common.run(child, M.command(item.parts, project, startup, name), {
              cwd = workspace.current().root,
            })
          end
          if item.input then
            common.input("Migration name: ", run)
          else
            run()
          end
        end)
      end,
    })
  end,
}

return M
