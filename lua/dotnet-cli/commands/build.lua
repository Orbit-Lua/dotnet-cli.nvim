-- dotnet-cli.nvim commands: Build
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

---@param proj? string
---@param config? string
---@return string[]
M.get_cmd = function(proj, config)
  config = config or "Debug"
  local out_dir = vim.fs.joinpath(vim.fn.getcwd(), "bin", config)
  local cmd = { "dotnet", "build" }
  if proj and proj ~= "" then
    table.insert(cmd, proj)
  end
  vim.list_extend(cmd, { "-c", config, "-o", out_dir })
  return cmd
end

---@type CometCommand
M.spec = {
  name = "Build",
  icon = "󰒓 ",
  icon_hl = "DiagnosticOk",
  desc = "dotnet build",
  action = function(ctx)
    ctx.select({
      { _raw = "Debug", icon = "󰃤 ", icon_hl = "DiagnosticWarn", name = "Debug" },
      { _raw = "Release", icon = "󰑊 ", icon_hl = "DiagnosticOk", name = "Release" },
    }, {
      title = "Build Configuration",
      on_select = function(item, c)
        local config = item._raw
        project.select_csproj(c, function(f, c2)
          local job_id = job.run(M.get_cmd(f, config), c2)
          ctx.start_async_task(job_id)
        end)
      end,
    })
  end,
}

return M
