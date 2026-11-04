-- Read Project profiles from launchSettings.json.

local M = {}

---@class DotnetCliLaunchProfile
---@field name string Profile name in launchSettings.json.
---@field commandName string Always `Project`.
---@field workingDirectory string Absolute working directory.
---@field commandLineArgs? string
---@field environmentVariables? table<string, string>
---@field applicationUrl? string

local function project_dir(project)
  return vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(project, ":p")))
end

---@param project string
---@return DotnetCliLaunchProfile[]
function M.profiles(project)
  local path =
    vim.fs.joinpath(project_dir(project), "Properties", "launchSettings.json")
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end
  local lines = vim.fn.readfile(path)
  if #lines == 0 then
    return {}
  end
  local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(data) ~= "table" or type(data.profiles) ~= "table" then
    return {}
  end
  local profiles = {}
  for name, profile in pairs(data.profiles) do
    if type(profile) == "table" and profile.commandName == "Project" then
      local item = vim.deepcopy(profile)
      item.name = name
      item.workingDirectory = item.workingDirectory
          and vim.fs.normalize(
            vim.fs.joinpath(project_dir(project), item.workingDirectory)
          )
        or project_dir(project)
      table.insert(profiles, item)
    end
  end
  table.sort(profiles, function(a, b)
    return a.name < b.name
  end)
  return profiles
end

M.get_project_profiles = M.profiles

return M
