-- dotnet-cli.nvim job runner
-- Async job execution with streaming output to the UI context.

local parsers = require("dotnet-cli.parsers")

local M = {}

---@class JobOpts
---@field ctx_clear boolean? whether to clear the context before running the job (default: true)

---Run a shell command, streaming stdout/stderr into the UI output panel.
---@param cmd string[]
---@param ctx CometCtx
---@param on_complete? fun(ctx: CometCtx) called on exit-code 0
---@param opts? JobOpts
---@return number job_id
M.run = function(cmd, ctx, on_complete, opts)
  opts = vim.tbl_deep_extend("force", {
    ctx_clear = true,
  }, opts or {})

  if opts.ctx_clear then
    ctx.clear()
  end

  ctx.append("$ " .. table.concat(cmd, " "))
  ctx.append("")

  return vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      ctx.write(data)
    end,
    on_stderr = function(_, data)
      ctx.write(data)
    end,
    on_exit = function(_, code)
      ctx.append("")
      if code == 0 then
        ctx.append("✓  Completed successfully")
        if on_complete then
          vim.schedule(function()
            on_complete(ctx)
          end)
        end
        vim.schedule(function()
          ctx.done()
        end)
      else
        ctx.append("✗  Failed  (exit code " .. code .. ")")
      end
    end,
  })
end

---Run a command synchronously and return stdout lines.
---@param cmd string[]|string
---@return string[] lines
---@return boolean ok
M.run_sync = function(cmd)
  local lines = vim.fn.systemlist(cmd)
  return lines, vim.v.shell_error == 0
end

---@param proj string
---@return integer?
M.get_netcore_pid = function(proj)
  local cmd = {}

  if vim.uv.os_uname().sysname:find("Windows") then
    cmd = {
      "powershell",
      "-NoProfile",
      "-Command",
      string.format(
        "(Get-Process dotnet | Where-Object {$_.CommandLine -match '%s'} | Select-Object -First 1).Id",
        proj
      ),
    }
  else
    -- pgrep -f: finds processes matching the full command lines
    -- -n: returns only the newest (most recently started) matching process, which is crucial for dotnet watch that spawns new processes on changes

    cmd = {
      "pgrep",
      "-f",
      proj,
      "-n",
    }
  end

  local pid = parsers.first_pid(vim.fn.system(cmd))
  return pid
end

return M
