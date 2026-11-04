-- Workspace selection state shared by commands and debugger integrations.

local storage = require("dotnet-cli.state")
local M = {}

---@class DotnetCliWorkspaceContext
---@field root string Absolute workspace root.
---@field solution? string Absolute solution path.
---@field project? string Absolute startup project path.
---@field configuration string Build configuration, such as `Debug`.
---@field tfm? string Selected target framework.
---@field profile? string Selected launch profile name.
---@field selection_error? string Why the saved selection could not load.

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

local function context(root, solution)
  local key = storage.identity(root)
  if not contexts[key] then
    local restored, err = storage.load(root)
    contexts[key] = vim.tbl_extend("force", {
      root = root,
      solution = solution and absolute(solution),
      configuration = "Debug",
    }, restored or {})
    contexts[key].selection_error = err
  end
  return key
end

local function persist(state)
  local ok, err = storage.save(state)
  if not ok then
    vim.notify(
      "Could not save .NET workspace selection: " .. err,
      vim.log.levels.WARN
    )
  end
end

---@return DotnetCliWorkspaceContext copy of the active selection
function M.current()
  if not active_root then
    local root, solution = discover_root(absolute(vim.fn.getcwd()))
    active_root = context(root, solution)
  end
  return copy(contexts[active_root])
end

---Make the workspace that contains `path` active.
---@param path? string default the working directory
---@return DotnetCliWorkspaceContext
function M.activate(path)
  local root, solution = discover_root(absolute(path or vim.fn.getcwd()))
  active_root = context(root, solution)
  return M.current()
end

---Whether the active selection still equals `expected`.
---@param expected DotnetCliWorkspaceContext
---@param buffer? integer also require this buffer to be valid
---@return boolean
function M.matches(expected, buffer)
  if buffer and not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end
  local active = M.current()
  return storage.identity(active.root) == storage.identity(expected.root)
    and active.project == expected.project
    and active.configuration == expected.configuration
    and active.tfm == expected.tfm
    and active.profile == expected.profile
end

---Change and save selection fields. A new project clears tfm and profile.
---@param patch table<string, string?>
---@return DotnetCliWorkspaceContext
function M.set(patch)
  assert(type(patch) == "table", "workspace.set expects a table")
  local current = M.current()
  local requested_root = patch.root and absolute(patch.root) or current.root
  local _, solution = discover_root(requested_root)
  active_root = context(requested_root, solution)
  local state = contexts[active_root]
  if patch.project and absolute(patch.project) ~= state.project then
    state.tfm, state.profile = nil, nil
    state.selection_error = nil
  end
  for key, value in pairs(patch) do
    if key == "project" or key == "solution" then
      state[key] = value and absolute(value) or nil
    elseif key == "configuration" or key == "tfm" or key == "profile" then
      state[key] = value
    end
  end
  persist(state)
  return M.current()
end

---Select a startup project and its workspace root.
---@param project string
---@param opts? { root?: string, configuration?: string, tfm?: string, profile?: string }
---@return DotnetCliWorkspaceContext
function M.select_project(project, opts)
  opts = opts or {}
  local full_path = absolute(project)
  local root, solution = discover_root(full_path)
  root = absolute(opts.root or root)
  local key = context(root, solution)
  active_root = key
  contexts[key].selection_error = nil
  local patch = { root = root, project = full_path }
  for _, field in ipairs({ "configuration", "tfm", "profile" }) do
    patch[field] = opts[field]
  end
  return M.set(patch)
end

---Drop every in-memory selection (tests only).
---@return DotnetCliWorkspaceContext
function M.reset()
  contexts = {}
  active_root = nil
  return M.current()
end

return M
