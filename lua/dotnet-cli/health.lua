-- dotnet-cli.nvim health check
-- :checkhealth dotnet-cli

local M = {}

M.check = function()
  vim.health.start("dotnet-cli.nvim")

  -- Check dotnet CLI
  if vim.fn.executable("dotnet") == 1 then
    local version = vim.fn.system("dotnet --version")
    vim.health.ok("dotnet CLI found: " .. vim.trim(version))
  else
    vim.health.error(
      "dotnet CLI not found",
      { "Install .NET SDK: https://dot.net/download" }
    )
    return
  end

  -- Check SDKs installed
  local sdk_lines = vim.fn.systemlist("dotnet --list-sdks")
  if vim.v.shell_error == 0 and #sdk_lines > 0 then
    vim.health.ok(#sdk_lines .. " SDK(s) installed")
    for _, line in ipairs(sdk_lines) do
      vim.health.info("  " .. line)
    end
  else
    vim.health.warn("No .NET SDKs found")
  end

  -- Check runtimes
  local rt_lines = vim.fn.systemlist("dotnet --list-runtimes")
  if vim.v.shell_error == 0 and #rt_lines > 0 then
    vim.health.ok(#rt_lines .. " runtime(s) installed")
  else
    vim.health.warn("No .NET runtimes found")
  end

  -- Check global.json
  if vim.fn.filereadable("global.json") == 1 then
    local ok, data =
      pcall(vim.json.decode, table.concat(vim.fn.readfile("global.json"), "\n"))
    if ok and data and data.sdk and data.sdk.version then
      vim.health.ok("global.json pins SDK " .. data.sdk.version)
    else
      vim.health.info("global.json exists but no SDK version pinned")
    end
  else
    vim.health.info("No global.json in current directory")
  end

  -- Check optional dependencies
  local has_devicons = pcall(require, "nvim-web-devicons")
  if has_devicons then
    vim.health.ok("nvim-web-devicons available (file icons)")
  else
    vim.health.info("nvim-web-devicons not found (icons will use fallback)")
  end

  local has_comet = pcall(require, "comet")
  if has_comet then
    vim.health.ok("comet.nvim available (manager UI)")
  else
    vim.health.warn("comet.nvim not found; install it for DotnetManager")
  end

  local has_dap = pcall(require, "dap")
  if has_dap then
    vim.health.ok("nvim-dap available")
  else
    vim.health.info("nvim-dap not found; .NET debugging is unavailable")
  end
  if vim.fn.executable("netcoredbg") == 1 then
    vim.health.ok("netcoredbg available")
  else
    vim.health.info("netcoredbg not found; set adapter_path for .NET debugging")
  end

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

return M
