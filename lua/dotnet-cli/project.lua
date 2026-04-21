-- dotnet-cli.nvim project helpers
-- Discover and select .csproj / .sln files in the workspace.

local M = {}

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

---@return string[]
M.get_csproj_files = function()
  return vim.fn.glob("*.csproj", false, true)
end

---@return string[]
M.get_sln_files = function()
  local sln = vim.fn.glob("*.sln", false, true)
  local slnx = vim.fn.glob("*.slnx", false, true)
  vim.list_extend(sln, slnx)
  return sln
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
  local files = M.get_csproj_files()
  if #files == 0 then
    ctx.clear()
    ctx.append("No .csproj files found in: " .. vim.fn.getcwd())
    return
  end
  if #files == 1 then
    callback(files[1], ctx)
    return
  end

  local items = {}
  for _, f in ipairs(files) do
    table.insert(items, {
      _raw = f,
      icon = M.get_file_icon(f),
      icon_hl = "DevIconCs",
      name = f,
    })
  end

  ctx.select(items, {
    title = "Select Project",
    on_select = function(item, c)
      callback(item._raw, c)
    end,
  })
end

---Push a sln-file selector onto the UI left panel.
---If only one .sln exists it is selected automatically.
---@param ctx CometCtx
---@param callback fun(file: string, ctx: CometCtx)
M.select_sln = function(ctx, callback)
  local files = M.get_sln_files()
  if #files == 0 then
    ctx.clear()
    ctx.append("No .sln/.slnx files found in: " .. vim.fn.getcwd())
    return
  end
  if #files == 1 then
    callback(files[1], ctx)
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

  ctx.select(items, {
    title = "Select Solution",
    on_select = function(item, c)
      callback(item._raw, c)
    end,
  })
end

return M
