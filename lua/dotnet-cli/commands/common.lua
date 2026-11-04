local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---Run a command in a Comet context; an interactive run gets a terminal.
---@param ctx CometCtx
---@param argv string[]
---@param opts? JobOpts|{ interactive?: boolean }
---@return integer job_id
M.run = function(ctx, argv, opts)
  local id = job.run(argv, ctx, nil, opts)
  if id and id > 0 and opts and opts.interactive and ctx.terminal then
    ctx:terminal(id)
  end
  return id
end

---Use the selected startup project, or let the user pick a project.
---@param ctx CometCtx
---@param callback fun(project: string, ctx: CometCtx)
M.project = function(ctx, callback)
  local workspace = require("dotnet-cli.workspace")
  local bound_root = ctx.session_id
    and ctx.session_id:match("^dotnet_manager:(.*)$")
  if
    bound_root
    and require("dotnet-cli.state").identity(workspace.current().root)
      ~= require("dotnet-cli.state").identity(bound_root)
  then
    ctx:append("Workspace changed; reopen Dotnet Manager")
    return
  end
  local active = workspace.current().project
  if active and vim.fn.filereadable(active) == 1 then
    callback(active, ctx)
  else
    project.select_csproj(ctx, function(selected, child)
      callback(selected, child)
    end)
  end
end

---Ask for a value; an empty answer cancels.
---@param prompt string
---@param callback fun(value: string)
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
