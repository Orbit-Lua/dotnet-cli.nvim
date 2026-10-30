local config = require("dotnet-cli.config")
local M = {}

function M.output(configuration, root)
  local template = config.get().output_dir_template
  if not template then
    return nil
  end
  local path = template:gsub(
    "{config}",
    configuration or config.get().default_build_config
  )
  if not (path:match("^[/\\]") or path:match("^%a:[/\\]")) then
    path = vim.fs.joinpath(root or vim.fn.getcwd(), path)
  end
  return vim.fs.normalize(path)
end

function M.argv(project, configuration, tfm, root)
  configuration = configuration or config.get().default_build_config
  local argv = { "dotnet", "build" }
  if project and project ~= "" then
    argv[#argv + 1] = project
  end
  vim.list_extend(argv, { "-c", configuration })
  if tfm then
    vim.list_extend(argv, { "-f", tfm })
  end
  local output = M.output(configuration, root)
  if output then
    vim.list_extend(argv, { "-o", output })
  end
  return argv
end

return M
