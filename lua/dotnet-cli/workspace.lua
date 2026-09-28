-- Workspace selection state shared by commands and debugger integrations.

local M = {}

local function absolute(path)
  path = path or vim.fn.getcwd()
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function discover_root(path)
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  local nearest_project
  while dir and dir ~= "" do
    local solutions = vim.fn.glob(dir .. "/*.sln", false, true)
    vim.list_extend(solutions, vim.fn.glob(dir .. "/*.slnx", false, true))
    if #solutions > 0 then
      table.sort(solutions)
      return dir, solutions[1]
    end
    if
      not nearest_project
      and #vim.fn.glob(dir .. "/*.csproj", false, true) > 0
    then
      nearest_project = dir
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
  return nearest_project or absolute(vim.fn.getcwd()), nil
end

local contexts = {}
local active_root

local function copy(source)
  return vim.deepcopy(source)
end

function M.current()
  if not active_root then
    local root, solution = discover_root(absolute(vim.fn.getcwd()))
    active_root = root
    contexts[root] = {
      root = root,
      solution = solution,
      project = nil,
      configuration = "Debug",
      tfm = nil,
      profile = nil,
    }
  end
  return copy(contexts[active_root])
end

function M.activate(path)
  local root, solution = discover_root(absolute(path or vim.fn.getcwd()))
  if not contexts[root] then
    contexts[root] = {
      root = root,
      solution = solution,
      project = nil,
      configuration = "Debug",
      tfm = nil,
      profile = nil,
    }
  end
  active_root = root
  return M.current()
end

function M.set(patch)
  assert(type(patch) == "table", "workspace.set expects a table")
  local current = M.current()
  local requested_root = patch.root and absolute(patch.root) or current.root
  if requested_root ~= active_root then
    active_root = requested_root
    if not contexts[active_root] then
      local _, discovered_solution = discover_root(active_root)
      contexts[active_root] = {
        root = active_root,
        solution = discovered_solution,
        project = nil,
        configuration = "Debug",
        tfm = nil,
        profile = nil,
      }
    end
  end
  local state = contexts[active_root]
  for key, value in pairs(patch) do
    if key == "root" then
      state.root = active_root
    elseif key == "project" or key == "solution" then
      state[key] = value and absolute(value) or nil
    elseif key == "configuration" or key == "tfm" or key == "profile" then
      state[key] = value
    end
  end
  return M.current()
end

function M.select_project(project, opts)
  opts = opts or {}
  local full_path = absolute(project)
  local discovered_root, discovered_solution = discover_root(full_path)
  active_root = absolute(opts.root or discovered_root)
  if not contexts[active_root] then
    contexts[active_root] = {
      root = active_root,
      solution = discovered_solution,
      project = nil,
      configuration = "Debug",
      tfm = nil,
      profile = nil,
    }
  end
  local state = contexts[active_root]
  state.root = active_root
  state.project = full_path
  state.solution = opts.solution and absolute(opts.solution)
    or state.solution
    or discovered_solution
  if opts.configuration ~= nil then
    state.configuration = opts.configuration
  end
  if opts.tfm ~= nil then
    state.tfm = opts.tfm
  end
  if opts.profile ~= nil then
    state.profile = opts.profile
  end
  return M.current()
end

function M.reset()
  contexts = {}
  active_root = nil
  return M.current()
end

return M
