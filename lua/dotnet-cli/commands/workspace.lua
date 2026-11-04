local launch = require("dotnet-cli.launch")
local msbuild = require("dotnet-cli.msbuild")
local project = require("dotnet-cli.project")
local workspace = require("dotnet-cli.workspace")

local M = {}

local function path_items(paths, icon, root)
  local items = {}
  for _, path in ipairs(paths) do
    table.insert(items, {
      name = path,
      _raw = root and vim.fs.joinpath(root, path) or path,
      icon = icon or "󰈚 ",
      icon_hl = "DiagnosticInfo",
    })
  end
  return items
end

local function select_paths(ctx, paths, title, callback, icon)
  local captured = workspace.current()
  if #paths == 0 then
    ctx:clear()
    ctx:append("No files found in " .. vim.fn.getcwd())
    return
  end
  ctx:select(path_items(paths, icon), {
    title = title,
    on_select = function(item, child)
      if not workspace.matches(captured) then
        child:append("Workspace changed; reopen the selection")
        return
      end
      callback(item._raw, child)
      captured = workspace.current()
    end,
  })
end

local function select_paths_async(ctx, finder, title, callback, icon)
  local captured = workspace.current()
  local root = captured.root
  ctx:select({ { name = "Scanning…", icon = "󰈚 " } }, {
    title = title,
    on_select = function(item, child)
      if item._raw then
        if not workspace.matches(captured) then
          child:append("Workspace changed; reopen the selection")
          return
        end
        callback(item._raw, child, captured)
        captured = workspace.current()
      end
    end,
  })
  finder(root, function(paths, err)
    if not workspace.matches(captured) then
      return
    end
    if err then
      ctx:append("Discovery failed: " .. err)
    end
    if #paths == 0 then
      ctx:update({ { name = "No files found", icon = "󰈚 " } })
    else
      ctx:update(path_items(paths, icon, root))
    end
  end)
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
  end, "󰅩 ")
end

local function select_startup_project(child)
  select_paths_async(
    child,
    project.get_csproj_files_async,
    "Startup Project",
    function(path, c, captured)
      local chosen = workspace.select_project(path, { root = captured.root })
      c:clear()
      c:append("Startup project: " .. chosen.project)
    end,
    project.get_file_icon("App.csproj")
  )
end

local function select_solution(child)
  select_paths_async(
    child,
    project.get_sln_files_async,
    "Solution",
    function(path, c)
      workspace.set({ solution = path })
      c:clear()
      c:append("Solution: " .. workspace.current().solution)
    end,
    "󰨞 "
  )
end

local function select_configuration(child)
  local configs = require("dotnet-cli.config").get().build_configurations
  select_paths(child, configs, "Configuration", function(name, c)
    workspace.set({ configuration = name })
    c:clear()
    c:append("Configuration: " .. name)
  end, "󰒓 ")
end

local function select_profile(child)
  local selected = workspace.current().project
  if not selected then
    child:append("Select a startup project first")
    return
  end
  local names = {}
  for _, profile in ipairs(launch.profiles(selected)) do
    names[#names + 1] = profile.name
  end
  select_paths(child, names, "Launch Profile", function(name, c)
    workspace.set({ profile = name })
    c:clear()
    c:append("Launch profile: " .. name)
  end, " ")
end

local handlers = {
  project = select_startup_project,
  solution = select_solution,
  configuration = select_configuration,
  framework = choose_framework,
  profile = select_profile,
}

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
      { name = "Startup Project", _raw = "project", icon = "󰈚 " },
      { name = "Solution", _raw = "solution", icon = "󰨞 " },
      { name = "Configuration", _raw = "configuration", icon = "󰒓 " },
      { name = "Target Framework", _raw = "framework", icon = "󰅩 " },
      { name = "Launch Profile", _raw = "profile", icon = " " },
    }, {
      title = "Workspace Action",
      on_select = function(item, child)
        local state = require("dotnet-cli.state")
        if
          state.identity(workspace.current().root)
          ~= state.identity(current.root)
        then
          child:append("Workspace changed; reopen Dotnet Manager")
          return
        end
        local handler = handlers[item._raw]
        if handler then
          handler(child)
        end
      end,
    })
  end,
}

return M
