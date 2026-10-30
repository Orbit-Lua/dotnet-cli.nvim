if arg[1] == "failure" then
  vim.cmd("cquit 1")
end
if arg[1] == "json-chunks" or arg[1] == "completion-chunks" then
  local json = arg[1] == "json-chunks"
  io.stdout:write(json and '{"Properties":{"TargetPath":"' or "bu")
  io.stdout:flush()
  vim.wait(150, function()
    return false
  end)
  io.stdout:write(
    json and 'App.dll","OutputType":"Exe","TargetFramework":"net10.0"}}\n'
      or "ild\n"
  )
  io.stdout:flush()
  return
end
io.stdout:write(arg[1] == "cwd" and vim.fn.getcwd() or "hello")
io.stdout:write("\n")
