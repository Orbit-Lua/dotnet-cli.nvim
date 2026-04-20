-- dotnet-cli.nvim commands registry
-- Aggregates all command specs into a single ordered list.

local M = {}

---@return CometCommand[]
M.get_all = function()
  local build = require("dotnet-cli.commands.build")
  local run = require("dotnet-cli.commands.run")
  local test = require("dotnet-cli.commands.test")
  local watch = require("dotnet-cli.commands.watch")
  local restore = require("dotnet-cli.commands.restore")
  local clean = require("dotnet-cli.commands.clean")
  local publish = require("dotnet-cli.commands.publish")
  local new = require("dotnet-cli.commands.new")
  local solution = require("dotnet-cli.commands.solution")
  local nuget = require("dotnet-cli.commands.nuget")
  local add_package = require("dotnet-cli.commands.add_package")
  local format = require("dotnet-cli.commands.format")
  local sdk_cmd = require("dotnet-cli.commands.sdk")

  return {
    build.spec,
    run.spec,
    test.spec,
    watch.spec,
    restore.spec,
    clean.spec,
    publish.spec,
    format.spec,
    new.spec,
    solution.spec,
    nuget.spec,
    add_package.spec,
    sdk_cmd.spec_global_json,
    sdk_cmd.spec_list_sdks,
    sdk_cmd.spec_list_runtimes,
  }
end

return M
