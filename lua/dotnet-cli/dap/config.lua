-- Launch configurations for the selected .NET startup project.
local launch = require("dotnet-cli.launch")
local msbuild = require("dotnet-cli.msbuild")
local workspace = require("dotnet-cli.workspace")

local M = {}

---@class DotnetCliLaunchConfig: dap.Configuration
---@field program string Evaluated output assembly.
---@field cwd string
---@field args string[]
---@field env table<string, string>
---@field dotnet_project string Absolute project path to build.
---@field dotnet_root string Workspace root for the build.
---@field dotnet_configuration string
---@field dotnet_tfm? string
---@field dotnet_status? string Key of the phase notification.
---@field justMyCode boolean
---@field stopAtEntry boolean

---Split a launch profile command line into arguments. Quotes group words;
---a backslash escapes a quote, a backslash or a space.
---@param value string
---@return string[]
function M.split_arguments(value)
  local result, current, quote = {}, "", nil
  local escapable = { ["\\"] = true, ['"'] = true, ["'"] = true, [" "] = true }
  local i = 1
  while i <= #value do
    local char = value:sub(i, i)
    local next_char = value:sub(i + 1, i + 1)
    if char == "\\" and quote ~= "'" and escapable[next_char] then
      current = current .. next_char
      i = i + 1
    elseif quote and char == quote then
      quote = nil
    elseif not quote and (char == "'" or char == '"') then
      quote = char
    elseif not quote and char:match("%s") then
      if current ~= "" then
        result[#result + 1] = current
        current = ""
      end
    else
      current = current .. char
    end
    i = i + 1
  end
  if current ~= "" then
    result[#result + 1] = current
  end
  return result
end

---@return string? project
---@return string? err
local function selected_project()
  local selected = workspace.current().project
  if not selected or vim.fn.filereadable(selected) ~= 1 then
    return nil, "Select a .NET startup project in Dotnet Manager first"
  end
  return selected
end

---@param project string
---@param selected DotnetCliWorkspaceContext
---@return DotnetCliLaunchProfile?
local function selected_profile(project, selected)
  local name = selected.profile
  if not name then
    return nil
  end
  for _, profile in ipairs(launch.profiles(project)) do
    if profile.name == name then
      return profile
    end
  end
  return nil
end

---@param profile DotnetCliLaunchProfile?
---@return table<string, string>
local function profile_env(profile)
  local env = vim.deepcopy(profile and profile.environmentVariables or {})
  if profile and profile.applicationUrl and not env.ASPNETCORE_URLS then
    env.ASPNETCORE_URLS = profile.applicationUrl
  end
  return env
end

---Build the launch configuration of a project. Without a context, use the
---project selected in the workspace.
---@param context? DotnetCliWorkspaceContext
---@param evaluated? DotnetCliMsbuildMetadata
---@return DotnetCliLaunchConfig? config
---@return string? err
function M.launch(context, evaluated)
  local project, err
  if context then
    project = context.project
  else
    project, err = selected_project()
  end
  if not project then
    return nil, err
  end

  local selected = context or workspace.current()
  local metadata = evaluated
  if not metadata then
    metadata, err =
      msbuild.get(project, selected.configuration, selected.tfm, selected.root)
  end
  if not metadata then
    return nil, err
  end
  if metadata.OutputType == "Library" or metadata.IsTestProject then
    return nil, "A class library cannot be launched directly"
  end

  local profile = selected_profile(project, selected)
  if selected.profile and not profile then
    return nil,
      "The selected launch profile is unavailable; select a profile in Dotnet Manager"
  end
  return {
    type = "coreclr",
    request = "launch",
    name = "Dotnet: Launch " .. vim.fn.fnamemodify(project, ":t:r"),
    program = metadata.TargetPath,
    cwd = profile and profile.workingDirectory or vim.fs.dirname(project),
    args = profile and profile.commandLineArgs and M.split_arguments(
      profile.commandLineArgs
    ) or {},
    env = profile_env(profile),
    dotnet_project = project,
    dotnet_root = selected.root,
    dotnet_configuration = selected.configuration,
    dotnet_tfm = selected.tfm,
    justMyCode = false,
    stopAtEntry = false,
  }
end

return M
