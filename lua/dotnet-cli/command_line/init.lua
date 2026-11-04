-- The manager's dotnet command line: SDK completion and guarded execution.
local job = require("dotnet-cli.job")
local workspace = require("dotnet-cli.workspace")
local config = require("dotnet-cli.config")
local parse = require("dotnet-cli.command_line.parse")
local M = {}

M.parse = parse.parse

-- Commands that take a project argument.
local project_commands = {
  build = true,
  clean = true,
  restore = true,
  test = true,
  publish = true,
  pack = true,
}

-- Commands that take the selected configuration and framework.
local build_commands = vim.tbl_extend("force", project_commands, {
  run = true,
  restore = false,
})

-- Options whose next argument is a value, not the project.
local value_options = {
  ["--configuration"] = true,
  ["-c"] = true,
  ["--framework"] = true,
  ["-f"] = true,
  ["--output"] = true,
  ["-o"] = true,
  ["--runtime"] = true,
  ["-r"] = true,
  ["--verbosity"] = true,
  ["-v"] = true,
  ["--arch"] = true,
  ["-a"] = true,
  ["--os"] = true,
  ["--project"] = true,
  ["-p"] = true,
}

local function executable()
  return vim.fn.has("win32") == 1 and "dotnet.exe" or "dotnet"
end

---@class DotnetCliCompletionRequest
---@field text string
---@field cursor integer

---@class DotnetCliCompletionItem
---@field label string
---@field text string
---@field start integer
---@field finish integer

---Collect unique candidates for the token that spans `first` to `last`.
---@param first integer
---@param last integer
---@return DotnetCliCompletionItem[] items
---@return fun(value: string) add
local function candidates(first, last)
  local items, seen = {}, {}
  local function add(value)
    value = value:gsub("\r$", "")
    if value == "" or value:find("[\r\n]") or seen[value] then
      return
    end
    -- The subcommand position offers only allowed subcommands.
    if first <= 7 and not parse.allowed[value] then
      return
    end
    seen[value] = true
    items[#items + 1] = {
      label = value,
      text = parse.quote_candidate(value),
      start = first,
      finish = last,
    }
  end
  return items, add
end

---Add the selected configurations or framework after their option.
---@param context DotnetCliWorkspaceContext
---@param before string text before the completed token
---@param add fun(value: string)
local function add_option_values(context, before, add)
  if before:match("%-%-configuration%s+$") or before:match("%-c%s+$") then
    for _, value in ipairs(config.get().build_configurations) do
      add(value)
    end
  elseif
    context.tfm
    and (before:match("%-%-framework%s+$") or before:match("%-f%s+$"))
  then
    add(context.tfm)
  end
end

---@param request DotnetCliCompletionRequest
---@param tokens DotnetCliToken[]
---@return integer first
---@return integer last
local function cursor_token(request, tokens)
  local first, last = request.cursor, request.cursor
  for _, token in ipairs(tokens) do
    if token.start <= request.cursor and token.finish >= request.cursor then
      first, last = token.start, token.finish
    end
  end
  return first, last
end

---@class DotnetCliCompletion
---@field context DotnetCliWorkspaceContext
---@field request DotnetCliCompletionRequest
---@field argv string[]
---@field first integer
---@field last integer
---@field reply fun(items: DotnetCliCompletionItem[], err?: string)
---@field canceled fun(): boolean

---Turn the SDK candidates into completion items, plus option values and
---project files where the command takes them.
---@param state DotnetCliCompletion
---@param lines string[]
local function answer(state, lines)
  local items, add = candidates(state.first, state.last)
  for _, line in ipairs(lines) do
    add(line)
  end
  add_option_values(state.context, state.request.text:sub(1, state.first), add)
  local argv = state.argv
  if
    not project_commands[argv[2]]
    or #argv > 3
    or state.first <= 7
    or (argv[3] or ""):match("^%-")
  then
    state.reply(items)
    return
  end
  local prefix = (argv[3] or ""):lower()
  require("dotnet-cli.project").get_csproj_files_async(
    state.context.root,
    function(files, scan_err)
      if state.canceled() or not workspace.matches(state.context) then
        return
      end
      for _, file in ipairs(scan_err and {} or files) do
        if file:sub(1, #prefix):lower() == prefix then
          add(file)
        end
      end
      state.reply(items)
    end
  )
end

---Ask the SDK for candidates at the cursor.
---@param context DotnetCliWorkspaceContext
---@param request DotnetCliCompletionRequest
---@param reply fun(items: DotnetCliCompletionItem[], err?: string)
---@return fun()? cancel
function M.complete(context, request, reply)
  local argv, tokens = parse.parse(request.text, true)
  if
    not workspace.matches(context)
    or not argv
    or not parse.permitted(argv, true)
  then
    reply({})
    return
  end
  ---@cast tokens DotnetCliToken[]
  local first, last = cursor_token(request, tokens)
  local canceled = false
  local state = {
    context = context,
    request = request,
    argv = argv,
    first = first,
    last = last,
    reply = reply,
    canceled = function()
      return canceled
    end,
  }
  local lines = {}
  local id = job.start({
    stdout_buffered = true,
    argv = {
      executable(),
      "complete",
      "--position",
      tostring(parse.utf16_position(request.text:sub(1, request.cursor))),
      request.text,
    },
    cwd = context.root,
    on_stdout = function(_, data)
      vim.list_extend(lines, data)
    end,
    on_exit = function(code)
      vim.schedule(function()
        if canceled or not workspace.matches(context) then
          return
        end
        if code ~= 0 then
          reply({}, ".NET completion is unavailable")
          return
        end
        answer(state, lines)
      end)
    end,
  })
  if not id or id <= 0 then
    reply({}, "Could not start .NET completion")
    return
  end
  return function()
    canceled = true
    pcall(job.cancel, id)
  end
end

---Find an option value in `argv` after the subcommand.
---@param argv string[]
---@param long string
---@param short? string
---@return string? value
---@return boolean? present
local function option(argv, long, short)
  for i = 3, #argv do
    if argv[i] == long or argv[i] == short then
      return argv[i + 1], true
    end
    if argv[i]:sub(1, #long + 1) == long .. "=" then
      return argv[i]:sub(#long + 2), true
    end
  end
end

---Move the arguments after `--` out of `argv`.
---@param argv string[]
---@return string[] application arguments for the program
local function split_application(argv)
  local separator = #argv + 1
  for i = 3, #argv do
    if argv[i] == "--" then
      separator = i
      break
    end
  end
  local application = {}
  while #argv >= separator do
    application[#application + 1] = table.remove(argv, separator)
  end
  return application
end

---@param argv string[]
---@return boolean
local function names_project(argv)
  local index = 3
  while index <= #argv do
    if value_options[argv[index]] then
      index = index + 2
    elseif argv[index]:sub(1, 1) == "-" then
      index = index + 1
    else
      return true
    end
  end
  return false
end

---Add the selected project, configuration, framework and build output where
---the user did not type them.
---@param argv string[]
---@param context DotnetCliWorkspaceContext
local function add_selection(argv, context)
  local command = argv[2]
  if context.project and project_commands[command] then
    if not names_project(argv) then
      table.insert(argv, 3, context.project)
    end
  elseif
    context.project
    and command == "run"
    and not select(2, option(argv, "--project", "-p"))
  then
    vim.list_extend(argv, { "--project", context.project })
  end
  if not build_commands[command] then
    return
  end
  local chosen, has_configuration = option(argv, "--configuration", "-c")
  if not has_configuration then
    vim.list_extend(argv, { "--configuration", context.configuration })
  end
  if context.tfm and not select(2, option(argv, "--framework", "-f")) then
    vim.list_extend(argv, { "--framework", context.tfm })
  end
  if command == "build" and not select(2, option(argv, "--output", "-o")) then
    local output = require("dotnet-cli.build").output(
      chosen or context.configuration,
      context.root
    )
    if output then
      vim.list_extend(argv, { "--output", output })
    end
  end
end

---@param ctx table Comet context
---@param message string
local function reject(ctx, message)
  ctx:append(message)
  ctx:set_status("error")
end

---Run a typed command in the selected workspace.
---@param context DotnetCliWorkspaceContext
---@param text string
---@param ctx table Comet context
function M.submit(context, text, ctx)
  local argv, err = parse.parse(text)
  if not argv then
    reject(ctx, err --[[@as string]])
    return
  end
  if not parse.permitted(argv, false) then
    reject(
      ctx,
      "Use a supported SDK command. Run EF, NuGet, and secrets workflows through their manager actions."
    )
    return
  end
  if not workspace.matches(context) then
    reject(ctx, "Workspace selection changed; reopen Command Line")
    return
  end
  argv[1] = executable()
  local application = split_application(argv)
  add_selection(argv, context)
  local interactive = argv[2] == "run" or argv[2] == "test"
  vim.list_extend(argv, application)
  require("dotnet-cli.commands.common").run(
    ctx,
    argv,
    { cwd = context.root, echo = false, interactive = interactive }
  )
end

M.spec = {
  name = "Command Line",
  desc = "type a dotnet command with SDK suggestions",
  icon = "󰘳 ",
  action = function(ctx)
    local context = workspace.current()
    ctx:command({
      title = "Dotnet Command Line",
      initial = "dotnet ",
      complete = function(request, reply)
        return M.complete(context, request, reply)
      end,
      submit = function(text, output)
        M.submit(context, text, output)
      end,
    })
  end,
}

return M
