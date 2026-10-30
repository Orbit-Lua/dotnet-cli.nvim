vim.opt.runtimepath:append(arg[1])
vim.fn.chdir(arg[2])
local workspace = require("dotnet-cli.workspace")
if arg[3] == "write" then
  workspace.select_project(arg[2] .. "/App.csproj")
  workspace.set({
    configuration = arg[4],
    tfm = "net10.0",
    profile = "Development",
  })
elseif arg[3] == "debug" then
  vim.opt.runtimepath:append(arg[4])
  local started, message = 0, nil
  vim.fn.jobstart = function()
    started = started + 1
    error("No process may start for a stale project")
  end
  vim.notify = function(value)
    message = value
  end
  assert(require("dotnet-cli").setup_dap({ adapter_path = vim.v.progpath }))
  require("dotnet-cli.commands.register").setup("Dotnet")
  vim.cmd("DotnetDebug")
  assert(
    vim.wait(1000, function()
      return message ~= nil
    end),
    "missing project did not report a failure"
  )
  io.stdout:write(vim.json.encode({ started = started, message = message }))
  return
end
io.stdout:write(vim.json.encode(workspace.activate(arg[2])))
