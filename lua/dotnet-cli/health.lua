-- dotnet-cli.nvim health check
-- :checkhealth dotnet-cli

local M = {}

local function check_sdks()
  local sdk_lines = vim.fn.systemlist("dotnet --list-sdks")
  if vim.v.shell_error == 0 and #sdk_lines > 0 then
    vim.health.ok(#sdk_lines .. " SDK(s) installed")
    for _, line in ipairs(sdk_lines) do
      vim.health.info("  " .. line)
    end
  else
    vim.health.warn("No .NET SDKs found")
  end

  local rt_lines = vim.fn.systemlist("dotnet --list-runtimes")
  if vim.v.shell_error == 0 and #rt_lines > 0 then
    vim.health.ok(#rt_lines .. " runtime(s) installed")
  else
    vim.health.warn("No .NET runtimes found")
  end
end

local function check_global_json()
  if vim.fn.filereadable("global.json") ~= 1 then
    vim.health.info("No global.json in current directory")
    return
  end
  local version = require("dotnet-cli.sdk").global_json_version()
  if version then
    vim.health.ok("global.json pins SDK " .. version)
  else
    vim.health.info("global.json exists but no SDK version pinned")
  end
end

local function check_plugins()
  if pcall(require, "nvim-web-devicons") then
    vim.health.ok("nvim-web-devicons available (file icons)")
  else
    vim.health.info("nvim-web-devicons not found (icons will use fallback)")
  end
  if pcall(require, "comet") then
    vim.health.ok("comet.nvim available (manager UI)")
  else
    vim.health.warn("comet.nvim not found; install it for DotnetManager")
  end
  if pcall(require, "dap") then
    vim.health.ok("nvim-dap available")
  else
    vim.health.info("nvim-dap not found; .NET debugging is unavailable")
  end
  if vim.fn.executable("netcoredbg") == 1 then
    vim.health.ok("netcoredbg available")
  else
    vim.health.info("netcoredbg not found; set adapter_path for .NET debugging")
  end
end

local function check_tools()
  for _, tool in ipairs({
    "dotnet-ef",
    "dotnet-counters",
    "dotnet-trace",
    "dotnet-dump",
  }) do
    if vim.fn.executable(tool) == 1 then
      vim.health.ok(tool .. " available")
    else
      vim.health.info(
        tool .. " not on PATH; a local tool manifest may provide it"
      )
    end
  end
end

---Run `:checkhealth dotnet-cli`.
M.check = function()
  vim.health.start("dotnet-cli.nvim")
  if vim.fn.executable("dotnet") ~= 1 then
    vim.health.error(
      "dotnet CLI not found",
      { "Install .NET SDK: https://dot.net/download" }
    )
    return
  end
  local version = vim.fn.system("dotnet --version")
  vim.health.ok("dotnet CLI found: " .. vim.trim(version))
  check_sdks()
  check_global_json()
  check_plugins()
  check_tools()
end

return M
