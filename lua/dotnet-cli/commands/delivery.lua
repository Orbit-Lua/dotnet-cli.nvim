local common = require("dotnet-cli.commands.common")
local workspace = require("dotnet-cli.workspace")

local M = {}

---@param project string
---@param options? { configuration?: string, output?: string }
---@return string[]
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

---@class DotnetCliPublishOptions
---@field configuration? string
---@field profile? string publish profile name or path
---@field runtime? string runtime identifier
---@field self_contained? boolean
---@field single_file? boolean
---@field output? string

---@param project string
---@param options? DotnetCliPublishOptions
---@return string[]
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

---@param template string item template short name
---@param name string
---@param output string
---@return string[]
M.item_cmd = function(template, name, output)
  return { "dotnet", "new", template, "--name", name, "--output", output }
end

-- Each prompt sets one option; `parse` turns the answer into its value.
local publish_fields = {
  { key = "configuration", prompt = "Configuration (Debug/Release): " },
  { key = "profile", prompt = "Publish profile name or path: " },
  { key = "runtime", prompt = "Runtime ID (for example linux-x64): " },
  {
    key = "self_contained",
    prompt = "Self-contained? (true/false): ",
    parse = function(value)
      return value == "true"
    end,
  },
  {
    key = "single_file",
    prompt = "Single-file? (true/false): ",
    parse = function(value)
      return value == "true"
    end,
  },
  { key = "output", prompt = "Output directory: " },
}

local pack_fields = {
  { key = "configuration", prompt = "Configuration (Debug/Release): " },
  { key = "output", prompt = "Output directory: " },
}

local function run_delivery(ctx, project, publish, options)
  common.run(
    ctx,
    publish and M.publish_cmd(project, options) or M.pack_cmd(project, options),
    { cwd = workspace.current().root }
  )
end

---Ask each option in turn; an empty answer keeps the default.
local function prompt_options(ctx, project, publish)
  local fields = publish and publish_fields or pack_fields
  local options = {}
  local function prompt(index)
    local field = fields[index]
    if not field then
      run_delivery(ctx, project, publish, options)
      return
    end
    vim.ui.input({ prompt = field.prompt }, function(value)
      if value and vim.trim(value) ~= "" then
        value = vim.trim(value)
        if field.parse then
          options[field.key] = field.parse(value)
        else
          options[field.key] = value
        end
      end
      vim.schedule(function()
        prompt(index + 1)
      end)
    end)
  end
  prompt(1)
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
      run_delivery(ctx, project, publish)
      return
    end
    prompt_options(ctx, project, publish)
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
