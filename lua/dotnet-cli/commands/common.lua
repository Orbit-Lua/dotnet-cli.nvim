local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

M.run = function(ctx, argv, opts)
  local id = job.run(argv, ctx, nil, opts)
  if id and id > 0 and opts and opts.interactive and ctx.terminal then
    ctx:terminal(id)
  end
  return id
end

M.project = function(ctx, callback)
  local workspace = require("dotnet-cli.workspace")
  local active = workspace.current().project
  if active and vim.fn.filereadable(active) == 1 then
    callback(active, ctx)
  else
    project.select_csproj(ctx, function(selected, child)
      workspace.select_project(selected)
      callback(selected, child)
    end)
  end
end

M.input = function(prompt, callback)
  vim.cmd("stopinsert")
  vim.ui.input({ prompt = prompt }, function(value)
    if value and vim.trim(value) ~= "" then
      vim.schedule(function()
        callback(vim.trim(value))
      end)
    end
  end)
end

return M
