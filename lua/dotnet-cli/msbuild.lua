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

local function command(project, configuration, tfm, root)
  assert(type(project) == "string" and project ~= "", "project is required")
  local cmd = {
    "dotnet",
    "msbuild",
    project,
    "-nologo",
    "-getProperty:TargetPath,OutputType,TargetFramework,TargetFrameworks,IsTestProject",
  }
  if configuration then
    table.insert(cmd, "-property:Configuration=" .. configuration)
  end
  if tfm then
    table.insert(cmd, "-property:TargetFramework=" .. tfm)
  end
  local output = require("dotnet-cli.build").output(configuration, root)
  if output then
    table.insert(cmd, "-property:OutDir=" .. output .. "/")
  end
  return cmd
end

local function metadata(project, lines)
  local data, err = parse_json(lines)
  if not data then
    return nil, err
  end
  local properties = data.Properties or data
  if
    (not properties.TargetPath or properties.TargetPath == "")
    and (not properties.TargetFrameworks or properties.TargetFrameworks == "")
  then
    return nil, "MSBuild returned no TargetPath for " .. project
  end
  local target_path = properties.TargetPath or ""
  local is_absolute = target_path:match("^[/\\]")
    or target_path:match("^%a:[/\\]")
  if target_path ~= "" and not is_absolute then
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
    IsTestProject = tostring(properties.IsTestProject):lower() == "true",
  }
end

function M.get(project, configuration, tfm, root)
  local lines, ok = job.run_sync(command(project, configuration, tfm, root), {
    cwd = root or vim.fs.dirname(vim.fn.fnamemodify(project, ":p")),
  })
  if not ok then
    return nil,
      "dotnet msbuild metadata query failed: " .. table.concat(lines, "\n")
  end
  return metadata(project, lines)
end

function M.get_async(project, configuration, tfm, root, callback)
  local output = {}
  local function collect(_, lines)
    vim.list_extend(output, lines)
  end
  local id = job.start({
    stdout_buffered = true,
    stderr_buffered = true,
    argv = command(project, configuration, tfm, root),
    cwd = root,
    on_stdout = collect,
    on_stderr = collect,
    on_exit = function(code)
      vim.schedule(function()
        if code ~= 0 then
          callback(
            nil,
            "dotnet msbuild metadata query failed: "
              .. table.concat(output, "\n")
          )
        else
          callback(metadata(project, output))
        end
      end)
    end,
  })
  if not id or id <= 0 then
    vim.schedule(function()
      callback(nil, "Could not start dotnet msbuild")
    end)
  end
  return id
end

return M
