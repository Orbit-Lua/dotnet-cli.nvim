local launch = require("dotnet-cli.launch")
local msbuild = require("dotnet-cli.msbuild")
local project = require("dotnet-cli.project")
local workspace = require("dotnet-cli.workspace")

local M = {}

local function select_paths(ctx, paths, title, callback)
  if #paths == 0 then
    ctx:clear()
    ctx:append("No files found in " .. vim.fn.getcwd())
    return
  end
  local items = {}
  for _, path in ipairs(paths) do
    table.insert(items, { name = path, _raw = path })
  end
  ctx:select(items, {
    title = title,
    on_select = function(item, child)
      callback(item._raw, child)
    end,
  })
end

local function choose_framework(ctx)
  local current = workspace.current()
  if not current.project then
    ctx:append("Select a startup project first")
    return
  end
  local metadata, err = msbuild.get(current.project, current.configuration)
  if not metadata then
    ctx:append(err)
    return
  end
  local frameworks = {}
  local value = metadata.TargetFrameworks or metadata.TargetFramework or ""
  for tfm in value:gmatch("[^;]+") do
    table.insert(frameworks, tfm)
  end
  if #frameworks == 0 then
    ctx:append("The project has no target framework")
    return
  end
  select_paths(ctx, frameworks, "Target Framework", function(tfm, child)
    workspace.set({ tfm = tfm })
    child:clear()
    child:append("Target framework: " .. tfm)
  end)
end

M.spec = {
  name = "Workspace",
  icon = "󰈚 ",
  desc = "startup project, solution, configuration and launch profile",
  action = function(ctx)
    local current = workspace.current()
    ctx:append("Root: " .. current.root)
    ctx:append("Project: " .. (current.project or "none"))
    ctx:append("Solution: " .. (current.solution or "none"))
    ctx:append("Configuration: " .. current.configuration)
    ctx:append("Framework: " .. (current.tfm or "project default"))
    ctx:select({
      { name = "Startup Project", _raw = "project" },
      { name = "Solution", _raw = "solution" },
      { name = "Configuration", _raw = "configuration" },
      { name = "Target Framework", _raw = "framework" },
      { name = "Launch Profile", _raw = "profile" },
    }, {
      title = "Workspace Action",
      on_select = function(item, child)
        local action = item._raw
        if action == "project" then
          select_paths(
            child,
            project.get_csproj_files(),
            "Startup Project",
            function(path, c)
              local chosen = workspace.select_project(path)
              c:clear()
              c:append("Startup project: " .. chosen.project)
            end
          )
        elseif action == "solution" then
          select_paths(
            child,
            project.get_sln_files(),
            "Solution",
            function(path, c)
              workspace.set({ solution = path })
              c:clear()
              c:append("Solution: " .. workspace.current().solution)
            end
          )
        elseif action == "configuration" then
          local configs =
            require("dotnet-cli.config").get().build_configurations
          select_paths(child, configs, "Configuration", function(name, c)
            workspace.set({ configuration = name })
            c:clear()
            c:append("Configuration: " .. name)
          end)
        elseif action == "framework" then
          choose_framework(child)
        elseif action == "profile" then
          local selected = workspace.current().project
          if not selected then
            child:append("Select a startup project first")
            return
          end
          local profiles = launch.profiles(selected)
          local names = {}
          for _, profile in ipairs(profiles) do
            table.insert(names, profile.name)
          end
          select_paths(child, names, "Launch Profile", function(name, c)
            workspace.set({ profile = name })
            c:clear()
            c:append("Launch profile: " .. name)
          end)
        end
      end,
    })
  end,
}

return M
