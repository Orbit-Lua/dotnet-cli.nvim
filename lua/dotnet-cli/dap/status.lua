-- One updating notification for each .NET launch session. Each phase replaces
-- the previous message through the `replace` option of nvim-notify and the
-- `id` option of snacks.nvim and Noice. A notifier that ignores both shows one
-- message per phase.
local M = {}

M.title = "Dotnet"

local listener = "dotnet-cli"

---@alias DotnetCliDapPhase "resolve"|"build"|"start"|"running"|"exit"|"failed"

-- Phases that wait on work keep their message until the next phase. Resolve
-- is not sticky: another `on_config` listener can abort the run before the
-- adapter starts, and no later phase would replace the message.
---@type table<DotnetCliDapPhase, boolean>
local sticky = { build = true, start = true }

---@class DotnetCliDapStatus
---@field key string Value of `config.dotnet_status` and the notification `id`.
---@field phase? DotnetCliDapPhase Last reported phase.
---@field name? string Project name shown in messages.
---@field bound boolean Whether an nvim-dap session carries this status.
---@field finished boolean Whether a final phase was reported.
---@field private handle any Return value of the last `vim.notify` call.
local Status = {}
Status.__index = Status

---@type table<string, DotnetCliDapStatus>
local active = {}
local counter = 0

---Create a status and keep it until it finishes.
---@return DotnetCliDapStatus
function M.new()
  counter = counter + 1
  local status = setmetatable({
    key = "dotnet-dap-" .. counter,
    bound = false,
    finished = false,
  }, Status)
  active[status.key] = status
  return status
end

---@param key? string
---@return DotnetCliDapStatus?
function M.get(key)
  return key and active[key] or nil
end

---Report a phase. A finished status ignores the call.
---@param phase DotnetCliDapPhase
---@param message string
---@param level? integer `vim.log.levels` value; default INFO
function Status:report(phase, message, level)
  if self.finished then
    return
  end
  self.phase = phase
  -- FIXME: Noice's snacks backend passes `replace` through without mapping
  -- the Noice handle to the snacks notification, so snacks adds a new message
  -- and a sticky phase stays on screen. Every phase also passes the status key
  -- as `id`: snacks creates or updates the message with that id, and Noice
  -- passes an id that names none of its messages through unchanged. The key
  -- must stay a string, because a number can match a Noice message id.
  -- nvim-notify ignores `id` and keeps using `replace`.
  local opts = { title = M.title, replace = self.handle, id = self.key }
  if sticky[phase] then
    opts.timeout = false
  end
  self.handle = vim.notify(message, level or vim.log.levels.INFO, opts)
end

---Report a final phase and release the status.
---@param phase DotnetCliDapPhase
---@param message string
---@param level? integer
function Status:finish(phase, message, level)
  if self.finished then
    return
  end
  self:report(phase, message, level)
  self.finished = true
  active[self.key] = nil
end

---Report a failure as the final phase.
---@param message string
---@param level? integer default ERROR
function Status:fail(message, level)
  self:finish("failed", message, level or vim.log.levels.ERROR)
end

---Summarize failed build output: the error count and the unique compiler
---error lines, or the last output lines when no compiler error parses.
---@param output string[]
---@return string
function M.build_summary(output)
  local lines, seen = {}, {}
  for _, item in ipairs(require("dotnet-cli.parsers").diagnostics(output)) do
    local line = ("%s(%d,%d): %s"):format(
      -- Either separator: MSBuild output can name a path of another platform.
      item.filename:match("[^/\\]+$") or item.filename,
      item.lnum,
      item.col,
      item.text
    )
    if item.type == "E" and not seen[line] then
      seen[line] = true
      lines[#lines + 1] = line
    end
  end
  if #lines == 0 then
    return ".NET build failed\n"
      .. table.concat(vim.list_slice(output, math.max(1, #output - 19)), "\n")
  end
  local count = #lines
  local header = (".NET build failed: %d error%s"):format(
    count,
    count == 1 and "" or "s"
  )
  return header .. "\n" .. table.concat(vim.list_slice(lines, 1, 10), "\n")
end

---@param session? dap.Session
---@return DotnetCliDapStatus?
local function of_session(session)
  return session and session.config and M.get(session.config.dotnet_status)
end

---Bind a new session to its status, and finish the status of a session that
---closed without an exit event. Called from the `on_session` listener.
---@param old? dap.Session
---@param new? dap.Session
function M.on_session(old, new)
  local bound = of_session(new)
  if bound then
    bound.bound = true
  end
  local closed = old and old.closed and of_session(old)
  if closed then
    closed:finish("exit", "Debug session ended")
  end
end

---@param session dap.Session
---@param err? dap.ErrorResponse
local function on_launch(session, err)
  local status = of_session(session)
  if not status then
    return
  end
  if err then
    status:fail("Debugger launch failed: " .. (err.message or vim.inspect(err)))
    return
  end
  status:report("running", "Debugging " .. (status.name or "the program"))
end

---@param session dap.Session
---@param body { exitCode: integer }
local function on_exited(session, body)
  local status = of_session(session)
  if not status then
    return
  end
  local code = body and body.exitCode or 0
  status:finish(
    "exit",
    ("%s exited with code %d"):format(status.name or "The program", code),
    code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
  )
end

---Register the nvim-dap event listeners that move a status forward.
---@param dap table the nvim-dap module
function M.install(dap)
  dap.listeners.after = dap.listeners.after or {}
  local after = dap.listeners.after
  for _, event in ipairs({ "launch", "event_exited", "event_terminated" }) do
    after[event] = after[event] or {}
  end
  after.launch[listener] = function(session, err)
    on_launch(session, err)
  end
  after.event_exited[listener] = on_exited
  after.event_terminated[listener] = function(session)
    local status = of_session(session)
    if status then
      status:finish("exit", "Debug session ended")
    end
  end
end

return M
