-- dotnet-cli.nvim commands: NuGet Sources
local job = require("dotnet-cli.job")
local parsers = require("dotnet-cli.parsers")

local M = {}

---@type CometCommand
M.spec = {
  name = "NuGet Sources",
  icon = "󰏗 ",
  icon_hl = "DiagnosticHint",
  desc = "manage NuGet package sources",
  action = function(ctx)
    ctx:select({
      { _raw = "list", icon = "󰈚 ", icon_hl = "Comment", name = "List Sources" },
      { _raw = "add", icon = "󰐕 ", icon_hl = "DiagnosticOk", name = "Add Source" },
      { _raw = "remove", icon = "󰍴 ", icon_hl = "DiagnosticError", name = "Remove Source" },
      { _raw = "enable", icon = "󰔡 ", icon_hl = "DiagnosticOk", name = "Enable Source" },
      { _raw = "disable", icon = "󰨙 ", icon_hl = "DiagnosticWarn", name = "Disable Source" },
    }, {
      title = "NuGet Sources",
      on_select = function(item, c)
        local action = item._raw

        if action == "list" then
          job.run({ "dotnet", "nuget", "list", "source" }, c)
          return
        end

        if action == "add" then
          vim.cmd("stopinsert")
          vim.ui.input({ prompt = "Source name: " }, function(name)
            if not name or name == "" then
              return
            end
            vim.ui.input({ prompt = "Source URL: " }, function(url)
              if not url or url == "" then
                return
              end
              vim.schedule(function()
                job.run({ "dotnet", "nuget", "add", "source", url, "-n", name }, c)
              end)
            end)
          end)
          return
        end

        -- remove / enable / disable: pick source(s), run action
        c:clear()
        local raw, ok = job.run_sync({ "dotnet", "nuget", "list", "source" })
        if not ok then
          c:append("Failed to list NuGet sources.")
          return
        end

        local sources = parsers.nuget_sources(raw)
        if #sources == 0 then
          c:append("No NuGet sources found.")
          return
        end

        local src_items = {}
        for _, s in ipairs(sources) do
          local state = s.enabled and "Enabled" or "Disabled"
          table.insert(src_items, {
            _raw = s.name,
            icon = s.enabled and "󰔡 " or "󰨙 ",
            icon_hl = s.enabled and "DiagnosticOk" or "DiagnosticWarn",
            name = s.name .. "  (" .. state .. ")  " .. s.url,
          })
        end

        c:select(src_items, {
          title = action:sub(1, 1):upper() .. action:sub(2) .. " Source",
          multi_select = true,
          on_select = function(selected, c2)
            local failed = 0
            c2:clear()
            for idx, src_item in ipairs(selected) do
              local cmd = { "dotnet", "nuget", action, "source", src_item._raw }
              c2:append("$ " .. table.concat(cmd, " "))
              local out, cmd_ok = job.run_sync(cmd)
              if not cmd_ok then
                failed = failed + 1
                c2:append("✗  Failed: " .. src_item._raw)
              else
                c2:write(out)
                c2:append("✓  " .. action .. ": " .. src_item._raw)
              end
              if idx < #selected then
                c2:append("")
              end
            end
            c2:append("")
            if failed == 0 then
              c2:append("✓  All " .. #selected .. " source(s) processed successfully")
            else
              c2:append("✗  " .. failed .. " of " .. #selected .. " source(s) failed")
            end
          end,
        })
      end,
    })
  end,
}

return M
