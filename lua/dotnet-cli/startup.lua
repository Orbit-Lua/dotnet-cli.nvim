local workspace = require("dotnet-cli.workspace")
local project = require("dotnet-cli.project")
local msbuild = require("dotnet-cli.msbuild")
local M = {}
local generation = 0

function M.resolve(callback, opts)
  opts = opts or {}
  local buffer = opts.buffer or vim.api.nvim_get_current_buf()
  local source = vim.api.nvim_buf_get_name(buffer)
  local selected = opts.context
    or workspace.activate(source ~= "" and source or vim.fn.getcwd())
  generation = generation + 1
  local request = generation
  local finished = false
  local function current()
    return request == generation and workspace.matches(selected, buffer)
  end
  local function finish(context, metadata, err)
    if finished then
      return
    end
    finished = true
    vim.schedule(function()
      if context then
        if request ~= generation or not workspace.matches(context, buffer) then
          callback(
            nil,
            nil,
            ".NET startup selection became obsolete; retry in the active workspace"
          )
          return
        end
      end
      callback(context, metadata, err)
    end)
  end
  local function guarded()
    if not current() then
      finish(
        nil,
        nil,
        ".NET startup selection became obsolete; retry in the active workspace"
      )
      return false
    end
    return true
  end
  local function query(path, tfm, done)
    msbuild.get_async(
      path,
      selected.configuration,
      tfm,
      selected.root,
      function(data, err)
        if guarded() then
          done(data, err)
        end
      end
    )
  end
  local function choose_framework(path, data)
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
      if not guarded() then
        return
      end
      if not tfm then
        finish(nil, nil, "Startup selection canceled")
        return
      end
      query(path, tfm, function(target, err)
        if not target then
          finish(nil, nil, err)
          return
        end
        if
          target.OutputType ~= "Exe" and target.OutputType ~= "WinExe"
          or target.IsTestProject
        then
          finish(
            nil,
            nil,
            "The selected project is not a runnable non-test application"
          )
          return
        end
        local context = workspace.select_project(path, {
          root = selected.root,
          configuration = selected.configuration,
          tfm = tfm,
          profile = selected.project == path and selected.profile or nil,
        })
        finish(context, target)
      end)
    end
    if selected.tfm then
      accept(selected.tfm)
    elseif #frameworks == 1 then
      accept(frameworks[1])
    elseif #frameworks > 1 then
      vim.ui.select(frameworks, { prompt = "Target framework" }, accept)
    else
      finish(nil, nil, "The project has no runnable target framework")
    end
  end
  local function candidate(path, data)
    if not guarded() then
      return
    end
    if not path then
      finish(nil, nil, "Startup selection canceled")
      return
    end
    choose_framework(path, data)
  end
  if selected.selection_error then
    finish(nil, nil, selected.selection_error)
    return
  end
  if selected.project then
    if vim.fn.filereadable(selected.project) ~= 1 then
      finish(
        nil,
        nil,
        "The selected .NET startup project is missing; select a replacement in Dotnet Manager"
      )
      return
    end
    query(selected.project, selected.tfm, function(data, err)
      if data then
        candidate(selected.project, data)
      else
        finish(nil, nil, err)
      end
    end)
    return
  end
  project.get_csproj_files_async(selected.root, function(files, scan_err)
    if not guarded() then
      return
    end
    if scan_err then
      finish(nil, nil, scan_err)
      return
    end
    local candidates, index = {}, 0
    local function next_project()
      if not guarded() then
        return
      end
      index = index + 1
      local file = files[index]
      if file then
        local path = vim.fs.joinpath(selected.root, file)
        query(path, nil, function(data, err)
          if not data then
            finish(nil, nil, err)
            return
          end
          if
            (data.OutputType == "Exe" or data.OutputType == "WinExe")
            and not data.IsTestProject
          then
            candidates[#candidates + 1] = { path = path, metadata = data }
          end
          next_project()
        end)
      elseif #candidates == 0 then
        finish(nil, nil, "No runnable non-test .NET project found")
      elseif #candidates == 1 then
        candidate(candidates[1].path, candidates[1].metadata)
      else
        vim.ui.select(candidates, {
          prompt = "Choose startup project",
          format_item = function(item)
            return vim.fs.relpath(selected.root, item.path) or item.path
          end,
        }, function(item)
          candidate(item and item.path, item and item.metadata)
        end)
      end
    end
    next_project()
  end)
end

return M
