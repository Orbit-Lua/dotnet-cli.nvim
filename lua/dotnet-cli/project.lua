-- dotnet-cli.nvim project helpers
-- Discover and select .csproj / .sln files in the workspace.

local M = {}

local ignored_dirs = {
  [".git"] = true,
  [".vs"] = true,
  ["bin"] = true,
  ["obj"] = true,
  ["node_modules"] = true,
}

M._current_running_project = nil

---@return string?
M.get_current_running_project = function()
  return M._current_running_project
end

---@return string?
M.get_current_running_project_name = function()
  local proj = M.get_current_running_project()
  if not proj then
    return nil
  end
  return vim.fn.fnamemodify(proj, ":t:r")
end

---@param extension string
---@return string[]
local function find_files(extension, root)
  local pattern = root and (vim.fs.normalize(root) .. "/**/*." .. extension)
    or ("**/*." .. extension)
  local files = vim.fn.glob(pattern, false, true)
  if root then
    for i, file in ipairs(files) do
      files[i] = vim.fs.relpath(root, file) or file
    end
  end
  table.sort(files)
  return files
end

---@return string[]
M.get_csproj_files = function(root)
  return find_files("csproj", root)
end

---@return string[]
M.get_sln_files = function(root)
  local sln = find_files("sln", root)
  local slnx = find_files("slnx", root)
  vim.list_extend(sln, slnx)
  table.sort(sln)
  return sln
end

local function find_files_async(root, extensions, callback)
  root = vim.fs.normalize(vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p"))
  local pending = 1
  local files = {}
  local root_error

  local function completed()
    pending = pending - 1
    if pending == 0 then
      table.sort(files)
      vim.schedule(function()
        callback(files, root_error)
      end)
    end
  end

  local scan
  scan = function(dir, is_root)
    vim.uv.fs_scandir(dir, function(err, request)
      vim.schedule(function()
        if err or not request then
          if is_root then
            root_error = err or "could not scan " .. dir
          end
          completed()
          return
        end

        local function read_batch()
          for _ = 1, 128 do
            local name, kind = vim.uv.fs_scandir_next(request)
            if not name then
              completed()
              return
            end
            local path = vim.fs.joinpath(dir, name)
            if kind == "directory" and not ignored_dirs[name] then
              pending = pending + 1
              scan(path, false)
            elseif kind == "file" then
              local extension = name:match("%.([^%.]+)$")
              if extension and extensions[extension] then
                table.insert(files, vim.fs.relpath(root, path) or path)
              end
            end
          end
          vim.schedule(read_batch)
        end
        read_batch()
      end)
    end)
  end

  scan(root, true)
end

M.get_csproj_files_async = function(root, callback)
  find_files_async(root, { csproj = true }, callback)
end

M.get_sln_files_async = function(root, callback)
  find_files_async(root, { sln = true, slnx = true }, callback)
end

---Get a Nerd Font icon for a file path (requires nvim-web-devicons).
---@param path string
---@return string
M.get_file_icon = function(path)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return "󰈚 "
  end
  local filename = vim.fn.fnamemodify(path, ":t")
  local icon = devicons.get_icon(filename, filename:match("%.([^%.]+)$"))
  return (icon or "󰈚") .. " "
end

---Push a csproj-file selector onto the UI left panel.
---If only one .csproj exists it is selected automatically.
---@param ctx CometCtx
---@param callback fun(file: string, ctx: CometCtx)
M.select_csproj = function(ctx, callback)
  local root = vim.fn.getcwd()
  ctx:select({ { name = "Scanning projects…", icon = "󰈚 " } }, {
    title = "Select Project",
    on_select = function(item, c)
      if not item._raw then
        return
      end
      require("dotnet-cli.workspace").select_project(item._raw)
      callback(item._raw, c)
    end,
  })
  M.get_csproj_files_async(root, function(files, err)
    if err then
      ctx:append("Project scan failed: " .. err)
    end
    if #files == 0 then
      ctx:update({ { name = "No .csproj files found", icon = "󰈚 " } })
      return
    end
    local icon = M.get_file_icon(files[1])
    local items = {}
    for _, f in ipairs(files) do
      table.insert(items, {
        _raw = f,
        icon = icon,
        icon_hl = "DevIconCs",
        name = f,
      })
    end
    local active = ctx:update(items)
    if #files == 1 and active then
      require("dotnet-cli.workspace").select_project(files[1])
      callback(files[1], ctx)
    end
  end)
end

---Push a sln-file selector onto the UI left panel.
---If only one .sln exists it is selected automatically.
---@param ctx CometCtx
---@param callback fun(file: string, ctx: CometCtx)
M.select_sln = function(ctx, callback)
  local root = vim.fn.getcwd()
  ctx:select({ { name = "Scanning solutions…", icon = "󰈚 " } }, {
    title = "Select Solution",
    on_select = function(item, c)
      if item._raw then
        callback(item._raw, c)
      end
    end,
  })
  M.get_sln_files_async(root, function(files, err)
    if err then
      ctx:append("Solution scan failed: " .. err)
    end
    if #files == 0 then
      ctx:update({ { name = "No .sln/.slnx files found", icon = "󰈚 " } })
      return
    end
    local items = {}
    for _, f in ipairs(files) do
      table.insert(items, {
        _raw = f,
        icon = M.get_file_icon(f),
        icon_hl = "Special",
        name = f,
      })
    end
    local active = ctx:update(items)
    if #files == 1 and active then
      callback(files[1], ctx)
    end
  end)
end

return M
