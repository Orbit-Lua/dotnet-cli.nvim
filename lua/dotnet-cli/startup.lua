-- Resolve the .NET startup project, framework and metadata for a launch.
local workspace = require("dotnet-cli.workspace")
local project = require("dotnet-cli.project")
local msbuild = require("dotnet-cli.msbuild")
local M = {}
local generation = 0

local obsolete =
  ".NET startup selection became obsolete; retry in the active workspace"

---Receives the context and metadata, or nil and the error.
---@alias DotnetCliStartupCallback
---| fun(context?: DotnetCliWorkspaceContext, metadata?: DotnetCliMsbuildMetadata, err?: string)

---One resolve call. A newer call or a workspace change makes it obsolete.
---@class DotnetCliStartupRequest
---@field id integer
---@field buffer integer
---@field selected DotnetCliWorkspaceContext
---@field callback DotnetCliStartupCallback
---@field finished boolean
local Request = {}
Request.__index = Request

---@param metadata DotnetCliMsbuildMetadata
---@return boolean
local function runnable(metadata)
  return (metadata.OutputType == "Exe" or metadata.OutputType == "WinExe")
    and not metadata.IsTestProject
end

---@return boolean
function Request:current()
  return self.id == generation and workspace.matches(self.selected, self.buffer)
end

---Deliver the result once, on a later event loop turn. A context that no
---longer matches the active workspace becomes the obsolete error.
---@param context? DotnetCliWorkspaceContext
---@param metadata? DotnetCliMsbuildMetadata
---@param err? string
function Request:finish(context, metadata, err)
  if self.finished then
    return
  end
  self.finished = true
  vim.schedule(function()
    local stale = context
      and (self.id ~= generation or not workspace.matches(context, self.buffer))
    if stale then
      self.callback(nil, nil, obsolete)
      return
    end
    self.callback(context, metadata, err)
  end)
end

---Finish with the obsolete error when the request is no longer current.
---@return boolean current
function Request:guarded()
  if not self:current() then
    self:finish(nil, nil, obsolete)
    return false
  end
  return true
end

---Query project metadata; the callback runs only while the request is current.
---@param path string
---@param tfm? string
---@param done fun(data?: DotnetCliMsbuildMetadata, err?: string)
function Request:query(path, tfm, done)
  local selected = self.selected
  msbuild.get_async(
    path,
    selected.configuration,
    tfm,
    selected.root,
    function(data, err)
      if self:guarded() then
        done(data, err)
      end
    end
  )
end

---Query the chosen framework and select the project in the workspace.
---@param request DotnetCliStartupRequest
---@param path string
---@param tfm? string
local function accept_framework(request, path, tfm)
  if not request:guarded() then
    return
  end
  if not tfm then
    request:finish(nil, nil, "Startup selection canceled")
    return
  end
  request:query(path, tfm, function(target, err)
    if not target then
      request:finish(nil, nil, err)
      return
    end
    if not runnable(target) then
      request:finish(
        nil,
        nil,
        "The selected project is not a runnable non-test application"
      )
      return
    end
    local selected = request.selected
    local context = workspace.select_project(path, {
      root = selected.root,
      configuration = selected.configuration,
      tfm = tfm,
      profile = selected.project == path and selected.profile or nil,
    })
    request:finish(context, target)
  end)
end

---Use the selected framework, the only one, or ask for one.
---@param request DotnetCliStartupRequest
---@param path string
---@param data DotnetCliMsbuildMetadata
local function choose_framework(request, path, data)
  local frameworks =
    vim.split(data.TargetFrameworks or "", ";", { trimempty = true })
  if
    data.TargetPath ~= ""
    and data.TargetFramework
    and data.TargetFramework ~= ""
  then
    frameworks = { data.TargetFramework }
  end
  local function accept(tfm)
    accept_framework(request, path, tfm)
  end
  if request.selected.tfm then
    accept(request.selected.tfm)
  elseif #frameworks == 1 then
    accept(frameworks[1])
  elseif #frameworks > 1 then
    vim.ui.select(frameworks, { prompt = "Target framework" }, accept)
  else
    request:finish(nil, nil, "The project has no runnable target framework")
  end
end

---@param request DotnetCliStartupRequest
---@param path? string
---@param data? DotnetCliMsbuildMetadata
local function candidate(request, path, data)
  if not request:guarded() then
    return
  end
  if not path or not data then
    request:finish(nil, nil, "Startup selection canceled")
    return
  end
  choose_framework(request, path, data)
end

---@class DotnetCliStartupCandidate
---@field path string
---@field metadata DotnetCliMsbuildMetadata

---Use the only runnable project, or ask for one.
---@param request DotnetCliStartupRequest
---@param candidates DotnetCliStartupCandidate[]
local function pick_candidate(request, candidates)
  if #candidates == 0 then
    request:finish(nil, nil, "No runnable non-test .NET project found")
    return
  end
  if #candidates == 1 then
    candidate(request, candidates[1].path, candidates[1].metadata)
    return
  end
  local root = request.selected.root
  vim.ui.select(candidates, {
    prompt = "Choose startup project",
    format_item = function(item)
      return vim.fs.relpath(root, item.path) or item.path
    end,
  }, function(item)
    candidate(request, item and item.path, item and item.metadata)
  end)
end

---Query each project file in turn and keep the runnable ones.
---@param request DotnetCliStartupRequest
---@param files string[] paths relative to the workspace root
local function collect_candidates(request, files)
  local candidates, index = {}, 0
  local function next_project()
    if not request:guarded() then
      return
    end
    index = index + 1
    local file = files[index]
    if not file then
      pick_candidate(request, candidates)
      return
    end
    local path = vim.fs.joinpath(request.selected.root, file)
    request:query(path, nil, function(data, err)
      if not data then
        request:finish(nil, nil, err)
        return
      end
      if runnable(data) then
        candidates[#candidates + 1] = { path = path, metadata = data }
      end
      next_project()
    end)
  end
  next_project()
end

---@param request DotnetCliStartupRequest
---@param path string selected startup project
local function resolve_selected(request, path)
  if vim.fn.filereadable(path) ~= 1 then
    request:finish(
      nil,
      nil,
      "The selected .NET startup project is missing; select a replacement in Dotnet Manager"
    )
    return
  end
  request:query(path, request.selected.tfm, function(data, err)
    if data then
      candidate(request, path, data)
    else
      request:finish(nil, nil, err)
    end
  end)
end

---Resolve the startup project of the buffer's workspace. The selected
---project wins; otherwise the only runnable project, or the user's pick.
---The callback runs once, on a later event loop turn.
---@param callback DotnetCliStartupCallback
---@param opts? { buffer?: integer, context?: DotnetCliWorkspaceContext }
function M.resolve(callback, opts)
  opts = opts or {}
  local buffer = opts.buffer or vim.api.nvim_get_current_buf()
  local source = vim.api.nvim_buf_get_name(buffer)
  generation = generation + 1
  local request = setmetatable({
    id = generation,
    buffer = buffer,
    selected = opts.context
      or workspace.activate(source ~= "" and source or vim.fn.getcwd()),
    callback = callback,
    finished = false,
  }, Request)

  local selected = request.selected
  if selected.selection_error then
    request:finish(nil, nil, selected.selection_error)
  elseif selected.project then
    resolve_selected(request, selected.project)
  else
    project.get_csproj_files_async(selected.root, function(files, scan_err)
      if not request:guarded() then
        return
      end
      if scan_err then
        request:finish(nil, nil, scan_err)
        return
      end
      collect_candidates(request, files)
    end)
  end
end

return M
