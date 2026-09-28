-- dotnet-cli.nvim job runner
-- Async job execution with streaming output to the UI context.

local parsers = require("dotnet-cli.parsers")

local M = {}

---@class JobOpts
---@field ctx_clear boolean? whether to clear the context before running the job (default: true)
---@field cwd string? working directory
---@field env table<string, string>? environment overrides
---@field clear_env boolean? start without inherited environment
---@field interactive boolean? allocate a PTY for stdin/stdout interaction
---@field on_exit fun(code: integer, event: string, ctx: CometCtx?, job_id: integer)?

local function emit(ctx, method, ...)
  if ctx and type(ctx[method]) == "function" then
    ctx[method](ctx, ...)
  end
end

---Start a structured process specification.
---@param spec table { argv: string[], cwd?, env?, interactive?, on_exit? }
---@param ctx? CometCtx
---@return integer job_id
M.start = function(spec, ctx)
  assert(
    type(spec) == "table" and type(spec.argv) == "table",
    "spec.argv is required"
  )
  local options = {
    stdout_buffered = false,
    stderr_buffered = false,
    cwd = spec.cwd,
    env = spec.env,
    clear_env = spec.clear_env,
    pty = spec.interactive or false,
    on_stdout = function(id, data, event)
      emit(ctx, "write", data)
      if spec.on_stdout then
        spec.on_stdout(id, data, event)
      end
    end,
    on_stderr = function(id, data, event)
      emit(ctx, "write", data)
      if spec.on_stderr then
        spec.on_stderr(id, data, event)
      end
    end,
    on_exit = function(id, code, event)
      if spec.on_exit then
        spec.on_exit(code, event, ctx, id)
      end
    end,
  }
  local id = vim.fn.jobstart(spec.argv, options)
  if id > 0 and spec.stdin then
    vim.fn.chansend(id, spec.stdin)
  end
  return id
end

---Run a shell command, streaming stdout/stderr into the UI output panel.
---@param cmd string[]
---@param ctx CometCtx
---@param on_complete? fun(ctx: CometCtx) called on exit-code 0
---@param opts? JobOpts
---@return number job_id
M.run = function(cmd, ctx, on_complete, opts)
  -- Also accept run(cmd, opts) for callers that do not use the Comet UI.
  if ctx and type(ctx) == "table" and not ctx.append and on_complete == nil then
    opts = ctx
    ctx = nil
  end
  opts = vim.tbl_deep_extend("force", {
    ctx_clear = true,
  }, opts or {})

  if opts.ctx_clear then
    emit(ctx, "clear")
  end

  emit(ctx, "append", "$ " .. table.concat(cmd, " "))
  emit(ctx, "append", "")

  local id = M.start({
    argv = cmd,
    cwd = opts.cwd,
    env = opts.env,
    clear_env = opts.clear_env,
    interactive = opts.interactive,
    stdin = opts.stdin,
    on_stdout = opts.on_stdout,
    on_stderr = opts.on_stderr,
    on_exit = function(code, event, job_ctx, id)
      emit(job_ctx, "append", "")
      if code == 0 then
        emit(job_ctx, "append", "✓  Completed successfully")
        if on_complete then
          vim.schedule(function()
            on_complete(job_ctx)
          end)
        end
      else
        emit(job_ctx, "append", "✗  Failed  (exit code " .. code .. ")")
        emit(job_ctx, "error", id)
      end
      if opts.on_exit then
        opts.on_exit(code, event, job_ctx, id)
      end
      if code == 0 then
        vim.schedule(function()
          emit(job_ctx, "done", id)
        end)
      end
    end,
  }, ctx)
  if id > 0 then
    emit(ctx, "start_async_task", id)
  else
    emit(
      ctx,
      "append",
      "Could not start process (jobstart returned " .. id .. ")"
    )
    emit(ctx, "set_status", "error")
    emit(ctx, "error")
  end
  return id
end

---@param job_id integer
---@param text string
---@return integer
M.send = function(job_id, text)
  return vim.fn.chansend(job_id, text)
end

---@param job_id integer
---@return integer
M.cancel = function(job_id)
  return vim.fn.jobstop(job_id)
end

M.stop = M.cancel

---Run a command synchronously and return stdout lines.
---@param cmd string[]|string
---@return string[] lines
---@return boolean ok
M.run_sync = function(cmd, opts)
  opts = opts or {}
  if type(cmd) == "string" then
    local lines = vim.fn.systemlist(cmd)
    return lines, vim.v.shell_error == 0
  end
  if vim.system then
    local result = vim
      .system(cmd, {
        cwd = opts.cwd,
        env = opts.env,
        clear_env = opts.clear_env,
        text = true,
      })
      :wait()
    local output = result.stdout or ""
    local lines = vim.split(output, "\n", { plain = true })
    if lines[#lines] == "" then
      table.remove(lines)
    end
    return lines, result.code == 0
  end
  local lines = vim.fn.systemlist(cmd)
  return lines, vim.v.shell_error == 0
end

---@param proj string
---@return integer?
M.get_netcore_pid = function(proj)
  local cmd

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
    -- -n: returns only the newest match, which matters for dotnet watch
    -- because it spawns new processes on changes.

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
