local config = require("dotnet-cli.config")
local M = {}

---Resolve `output_dir_template` for a configuration, relative to `root`.
---@param configuration? string default `default_build_config`
---@param root? string default the working directory
---@return string? path nil without a template
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

---Build a `dotnet build` command.
---@param project? string
---@param configuration? string
---@param tfm? string
---@param root? string
---@return string[]
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
