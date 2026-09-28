local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

M.pack_cmd = function(project, options)
  options = options or {}
  local cmd = { "dotnet", "pack", project }
  if options.configuration then
    vim.list_extend(cmd, { "-c", options.configuration })
  end
  if options.output then
    vim.list_extend(cmd, { "-o", options.output })
  end
  return cmd
end

M.publish_cmd = function(project, options)
  options = options or {}
  local cmd = { "dotnet", "publish", project }
  if options.configuration then
    vim.list_extend(cmd, { "-c", options.configuration })
  end
  if options.profile then
    vim.list_extend(cmd, { "-p:PublishProfile=" .. options.profile })
  end
  if options.runtime then
    vim.list_extend(cmd, { "-r", options.runtime })
  end
  if options.self_contained ~= nil then
    table.insert(cmd, "--self-contained")
    table.insert(cmd, options.self_contained and "true" or "false")
  end
  if options.single_file then
    table.insert(cmd, "-p:PublishSingleFile=true")
  end
  if options.output then
    vim.list_extend(cmd, { "-o", options.output })
  end
  return cmd
end

M.item_cmd = function(template, name, output)
  return { "dotnet", "new", template, "--name", name, "--output", output }
end

local function ask_options(ctx, project, publish)
  local choices = { "Run with defaults", "Configure options" }
  vim.ui.select(choices, {
    prompt = publish and "Publish (configure prompts for each option):"
      or "Pack (configure prompts for each option):",
    format_item = function(item)
      return item
    end,
  }, function(selected)
    if not selected or selected == "Run with defaults" then
      common.run(
        ctx,
        publish and M.publish_cmd(project) or M.pack_cmd(project),
        {
          cwd = workspace.current().root,
        }
      )
      return
    end
    local options = {}
    local fields = publish
        and {
          { "Configuration", "Configuration (Debug/Release): " },
          { "Publish Profile", "Publish profile name or path: " },
          { "Runtime ID", "Runtime ID (for example linux-x64): " },
          { "Self-contained", "Self-contained? (true/false): " },
          { "Single-file", "Single-file? (true/false): " },
          { "Output directory", "Output directory: " },
        }
      or {
        { "Configuration", "Configuration (Debug/Release): " },
        { "Output directory", "Output directory: " },
      }
    local function prompt(index)
      local field = fields[index]
      if not field then
        common.run(
          ctx,
          publish and M.publish_cmd(project, options)
            or M.pack_cmd(project, options),
          {
            cwd = workspace.current().root,
          }
        )
        return
      end
      vim.ui.input({ prompt = field[2] }, function(value)
        if value and vim.trim(value) ~= "" then
          value = vim.trim(value)
          if field[1] == "Configuration" then
            options.configuration = value
          elseif field[1] == "Publish Profile" then
            options.profile = value
          elseif field[1] == "Runtime ID" then
            options.runtime = value
          elseif field[1] == "Output directory" then
            options.output = value
          elseif field[1] == "Self-contained" then
            options.self_contained = value == "true"
          elseif field[1] == "Single-file" then
            options.single_file = value == "true"
          end
        end
        vim.schedule(function()
          prompt(index + 1)
        end)
      end)
    end
    prompt(1)
  end)
end

M.spec = {
  name = "Pack & Publish",
  icon = "󰆦 ",
  desc = "create NuGet packages and configure local publish output",
  action = function(ctx)
    ctx:select({
      { name = "Pack Project", _raw = "pack" },
      { name = "Publish Options", _raw = "publish" },
      { name = "Create Item Template", _raw = "item" },
    }, {
      title = "Pack & Publish",
      on_select = function(item, child)
        common.project(child, function(project, c)
          if item._raw == "item" then
            local output = vim.fs.dirname(project)
            common.input(
              "Item template short name (for example class): ",
              function(template)
                common.input("Item name: ", function(name)
                  common.run(c, M.item_cmd(template, name, output), {
                    cwd = workspace.current().root,
                  })
                end)
              end
            )
            return
          end
          ask_options(c, project, item._raw == "publish")
        end)
      end,
    })
  end,
}

return M
