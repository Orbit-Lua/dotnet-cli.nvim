-- dotnet-cli.nvim commands: New Project
local job = require("dotnet-cli.job")
local parsers = require("dotnet-cli.parsers")
local publish = require("dotnet-cli.commands.publish")
local sdk = require("dotnet-cli.sdk")

local M = {}

---@type CometCommand
M.spec = {
  name = "New Project",
  icon = "󰝒 ",
  icon_hl = "DiagnosticInfo",
  desc = "dotnet new",
  action = function(ctx)
    ctx:clear()

    local major = sdk.get_major()
    local list_cmd = (major and major >= 7) and "dotnet new list" or "dotnet new --list"

    ctx:append("$ " .. list_cmd)
    ctx:append("")

    local raw, ok = job.run_sync(list_cmd)
    if not ok then
      ctx:append("Failed to list templates. Is dotnet installed?")
      return
    end

    local templates = parsers.templates(raw)
    if #templates == 0 then
      ctx:append("No templates found.")
      return
    end

    local items = {}
    for _, t in ipairs(templates) do
      table.insert(items, {
        _raw = t,
        icon = "󰈚 ",
        icon_hl = "Special",
        name = t.name .. "  (" .. t.short_name .. ")",
      })
    end

    ctx:select(items, {
      title = "Select Template",
      on_select = function(item, c)
        local tpl = item._raw
        vim.cmd("stopinsert")
        vim.ui.input({ prompt = "Project name: " }, function(name)
          if not name or name == "" then
            return
          end
          vim.schedule(function()
            job.run({ "dotnet", "new", tpl.short_name, "-n", name, "-o", name }, c, function(ctx2)
              vim.schedule(function()
                vim.ui.select({ "Yes", "No" }, {
                  prompt = "Configure publish profile (.pubxml) from custom template?",
                }, function(choice)
                  if choice == "Yes" then
                    vim.schedule(function()
                      publish.configure_profile(name, ctx2)
                    end)
                  end
                end)
              end)
            end)
          end)
        end)
      end,
    })
  end,
}

return M
