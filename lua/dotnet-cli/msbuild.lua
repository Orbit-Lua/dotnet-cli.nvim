-- Query evaluated project metadata through the installed .NET SDK.

local job = require("dotnet-cli.job")
local M = {}

local function parse_json(lines)
  local text = table.concat(lines, "\n")
  local start = text:find("{")
  if not start then
    return nil, "dotnet msbuild did not return JSON"
  end
  local ok, data = pcall(vim.json.decode, text:sub(start))
  if not ok then
    return nil, "could not parse dotnet msbuild JSON: " .. tostring(data)
  end
  return data
end

function M.get(project, configuration, tfm)
  assert(type(project) == "string" and project ~= "", "project is required")
  local cmd = {
    "dotnet",
    "msbuild",
    project,
    "-nologo",
    "-getProperty:TargetPath,OutputType,TargetFramework,TargetFrameworks",
  }
  if configuration then
    table.insert(cmd, "-property:Configuration=" .. configuration)
  end
  if tfm then
    table.insert(cmd, "-property:TargetFramework=" .. tfm)
  end
  local lines, ok = job.run_sync(cmd)
  if not ok then
    return nil,
      "dotnet msbuild metadata query failed: " .. table.concat(lines, "\n")
  end
  local data, err = parse_json(lines)
  if not data then
    return nil, err
  end
  local properties = data.Properties or data
  if not properties.TargetPath or properties.TargetPath == "" then
    return nil, "MSBuild returned no TargetPath for " .. project
  end
  local target_path = properties.TargetPath
  local is_absolute = target_path:match("^[/\\]")
    or target_path:match("^%a:[/\\]")
  if not is_absolute then
    local project_path = vim.fn.fnamemodify(project, ":p")
    target_path = vim.fs.normalize(
      vim.fs.joinpath(vim.fs.dirname(project_path), target_path)
    )
  end
  return {
    TargetPath = target_path,
    OutputType = properties.OutputType,
    TargetFramework = properties.TargetFramework,
    TargetFrameworks = properties.TargetFrameworks,
  }
end

return M
