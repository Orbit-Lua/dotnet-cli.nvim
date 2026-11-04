-- dotnet-cli.nvim commands: Solution Management
local job = require("dotnet-cli.job")
local parsers = require("dotnet-cli.parsers")
local project = require("dotnet-cli.project")

local M = {}

local function new_solution(c)
  vim.cmd("stopinsert")
  vim.ui.input({ prompt = "Solution name: " }, function(name)
    if not name or name == "" then
      return
    end
    vim.schedule(function()
      job.run({ "dotnet", "new", "sln", "-n", name }, c)
    end)
  end)
end

local function list_projects(c)
  project.select_sln(c, function(sln, c2)
    job.run({ "dotnet", "sln", sln, "list" }, c2)
  end)
end

---Show a scanning row at once, then replace it with the found projects.
---@param c table Comet context
local function show_csproj_files(c)
  project.get_csproj_files_async(vim.fn.getcwd(), function(files)
    local items = {}
    for _, file in ipairs(files) do
      items[#items + 1] = {
        _raw = file,
        icon = project.get_file_icon(file),
        icon_hl = "DevIconCs",
        name = file,
      }
    end
    if #items == 0 then
      items = { { name = "No .csproj files found", icon = "󰈚 " } }
    end
    c:update(items)
  end)
end

local function add_projects(c)
  project.select_sln(c, function(sln, c2)
    c2:select({ { name = "Scanning projects…", icon = "󰈚 " } }, {
      title = "Add Project",
      multi_select = true,
      on_select = function(selected, c3)
        local cmd = { "dotnet", "sln", sln, "add" }
        for _, item in ipairs(selected) do
          if item._raw then
            cmd[#cmd + 1] = item._raw
          end
        end
        if #cmd > 4 then
          job.run(cmd, c3)
        end
      end,
    })
    show_csproj_files(c2)
  end)
end

local function remove_projects(c)
  project.select_sln(c, function(sln, c2)
    c2:clear()
    local raw, ok = job.run_sync({ "dotnet", "sln", sln, "list" })
    if not ok then
      c2:append("Failed to list projects in " .. sln)
      return
    end
    local projects = parsers.sln_projects(raw)
    if #projects == 0 then
      c2:append("No projects found in " .. sln)
      return
    end

    local items = {}
    for _, path in ipairs(projects) do
      items[#items + 1] =
        { _raw = path, icon = "󰈚 ", icon_hl = "Special", name = path }
    end
    c2:select(items, {
      title = "Remove Project",
      multi_select = true,
      on_select = function(selected, c3)
        local cmd = { "dotnet", "sln", sln, "remove" }
        for _, item in ipairs(selected) do
          cmd[#cmd + 1] = item._raw
        end
        job.run(cmd, c3)
      end,
    })
  end)
end

local handlers = {
  list = list_projects,
  add = add_projects,
  remove = remove_projects,
  new = new_solution,
}

local actions = {
  {
    _raw = "list",
    icon = "󰈚 ",
    icon_hl = "Comment",
    name = "List Projects",
  },
  {
    _raw = "add",
    icon = "󰐕 ",
    icon_hl = "DiagnosticOk",
    name = "Add Project",
  },
  {
    _raw = "remove",
    icon = "󰍴 ",
    icon_hl = "DiagnosticError",
    name = "Remove Project",
  },
  {
    _raw = "new",
    icon = "󰝒 ",
    icon_hl = "DiagnosticInfo",
    name = "New Solution",
  },
}

---@type CometCommand
M.spec = {
  name = "Solution",
  icon = "󰘐 ",
  icon_hl = "DiagnosticHint",
  desc = "dotnet sln management",
  action = function(ctx)
    ctx:select(vim.deepcopy(actions), {
      title = "Solution Action",
      on_select = function(item, c)
        handlers[item._raw](c)
      end,
    })
  end,
}

return M
