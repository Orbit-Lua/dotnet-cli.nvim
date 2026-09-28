local common = require("dotnet-cli.commands.common")
local job = require("dotnet-cli.job")
local parsers = require("dotnet-cli.parsers")
local sdk = require("dotnet-cli.sdk")
local workspace = require("dotnet-cli.workspace")

local M = {}

local last_failed = {}
local capability_cache = {}

local function absolute(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

local function runner_from_global(path)
  local value = vim.env.DOTNET_TEST_RUNNER
  if value and value ~= "" then
    local normalized = value:lower()
    if normalized == "vstest" then
      return "vstest"
    elseif normalized == "microsoft.testing.platform" then
      return "mtp"
    end
  end

  local dir = is_directory(path) and absolute(path)
    or vim.fs.dirname(absolute(path))
  while dir and dir ~= "" do
    local file = vim.fs.joinpath(dir, "global.json")
    if vim.fn.filereadable(file) == 1 then
      local ok, data =
        pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
      if not ok then
        return nil, "Could not parse " .. file .. ": " .. tostring(data)
      end
      local configured = type(data) == "table"
          and type(data.test) == "table"
          and data.test.runner
        or nil
      if configured == nil or configured == "VSTest" then
        return "vstest"
      elseif
        type(configured) == "string"
        and configured:lower() == "microsoft.testing.platform"
      then
        return "mtp"
      end
      return nil,
        "Unsupported test runner in " .. file .. ": " .. tostring(configured)
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
  return "vstest"
end

---Resolve the active test runner using the nearest global.json setting.
---@param root string
---@return "vstest"|"mtp"|nil runner
---@return string? error
M.runner = function(root)
  return runner_from_global(root or workspace.current().root)
end

local function resolve_runner(opts)
  if opts.runner then
    return opts.runner
  end
  return M.runner(opts.root)
end

---Build a `dotnet test` command for the selected runner and operation.
---@param project string
---@param mode string all|discover|selected|coverage
---@param opts table?
---@return string[] command
M.command = function(project, mode, opts)
  opts = opts or {}
  local root = opts.root or workspace.current().root
  local runner = resolve_runner(opts) or "vstest"
  local major = opts.sdk_major or sdk.get_major(root)
  local mtp_native = runner == "mtp" and major and major >= 10
  local cmd = { "dotnet", "test" }
  if mtp_native then
    vim.list_extend(cmd, { "--project", project })
  else
    table.insert(cmd, project)
  end
  if opts.configuration then
    vim.list_extend(cmd, { "-c", opts.configuration })
  end
  if opts.tfm then
    vim.list_extend(cmd, { "-f", opts.tfm })
  end

  local mtp_args = {}
  if mode == "discover" then
    if runner == "mtp" then
      table.insert(mtp_args, "--list-tests")
    else
      table.insert(cmd, "--list-tests")
    end
  elseif mode == "coverage" then
    if runner == "mtp" then
      table.insert(mtp_args, "--coverage")
    else
      table.insert(cmd, "--collect:XPlat Code Coverage")
    end
  elseif mode == "selected" and opts.filter then
    if runner == "mtp" then
      vim.list_extend(
        mtp_args,
        { "--filter", "FullyQualifiedName~" .. opts.filter }
      )
    else
      vim.list_extend(cmd, { "--filter", "FullyQualifiedName~" .. opts.filter })
    end
  end

  if opts.results_dir then
    vim.list_extend(cmd, { "--results-directory", opts.results_dir })
    if runner == "vstest" and mode ~= "discover" then
      local filename = opts.trx_filename or "dotnet-cli.trx"
      vim.list_extend(cmd, { "--logger", "trx;LogFileName=" .. filename })
    elseif
      runner == "mtp"
      and mode ~= "discover"
      and opts.capabilities
      and opts.capabilities.trx
    then
      table.insert(mtp_args, "--report-trx")
    end
  end
  if #mtp_args > 0 then
    if not mtp_native then
      table.insert(cmd, "--")
    end
    vim.list_extend(cmd, mtp_args)
  end
  return cmd
end

local function help_capabilities(project, root, runner, major)
  local key = table.concat(
    { absolute(root), absolute(project), runner, tostring(major) },
    "\0"
  )
  if capability_cache[key] then
    return vim.deepcopy(capability_cache[key])
  end
  local cmd = { "dotnet", "test" }
  if runner == "mtp" and major and major >= 10 then
    vim.list_extend(cmd, { "--project", project })
  else
    table.insert(cmd, project)
  end
  if runner == "mtp" and (not major or major < 10) then
    table.insert(cmd, "--")
  end
  table.insert(cmd, "--help")
  local lines, ok = job.run_sync(cmd, { cwd = root })
  if not ok then
    return nil,
      "Could not inspect test runner capabilities: " .. table.concat(
        lines,
        "\n"
      )
  end
  local help = table.concat(lines, "\n"):lower()
  local function supports(option)
    local offset = 1
    while true do
      local start = help:find(option, offset, true)
      if not start then
        return false
      end
      local next_char = help:sub(start + #option, start + #option)
      if next_char == "" or next_char:match("[%s=<%[]") then
        return true
      end
      offset = start + #option
    end
  end
  local capabilities = {
    runner = runner,
    discover = supports("--list-tests"),
    filter = supports("--filter"),
    coverage = supports("--coverage"),
    trx = supports("--report-trx"),
  }
  capability_cache[key] = vim.deepcopy(capabilities)
  return capabilities
end

---Return runner features advertised by this project's `dotnet test --help`.
---@param project string
---@param opts table?
---@return table? capabilities
---@return string? error
M.capabilities = function(project, opts)
  opts = opts or {}
  local root = opts.root or workspace.current().root
  local runner, runner_err =
    resolve_runner({ runner = opts.runner, root = root })
  if not runner then
    return nil, runner_err
  end
  local major = opts.sdk_major or sdk.get_major(root)
  if runner == "mtp" then
    if not major then
      return nil, "Could not detect the .NET SDK selected for this workspace"
    end
    if major < 10 then
      return nil, "The global.json MTP runner requires .NET SDK 10 or later"
    end
  end
  if runner == "vstest" then
    return {
      runner = runner,
      discover = true,
      filter = true,
      coverage = true,
      trx = true,
    }
  end
  return help_capabilities(project, root, runner, major)
end

M._reset_capabilities = function()
  capability_cache = {}
end

local function results_dir(project)
  local root = vim.fs.joinpath(vim.fn.stdpath("cache"), "dotnet-cli", "tests")
  local name = vim.fn.fnamemodify(project, ":t:r"):gsub("[^%w_.-]", "_")
  local path = vim.fs.joinpath(root, name .. "-" .. tostring(vim.uv.hrtime()))
  vim.fn.mkdir(path, "p")
  return path
end

local function run_test(ctx, project, mode, filter)
  local selected = workspace.current()
  local capabilities, err = M.capabilities(project, { root = selected.root })
  if not capabilities then
    ctx:append(err)
    return
  end
  local required = mode == "discover" and "discover"
    or mode == "coverage" and "coverage"
    or mode == "selected" and "filter"
  if required and not capabilities[required] then
    local help_name = capabilities.runner == "mtp"
        and "the test project’s MTP extensions"
      or "the selected test runner"
    ctx:append(
      "This project does not advertise "
        .. required
        .. " support in "
        .. help_name
    )
    return
  end

  local out_dir = results_dir(project)
  local output = {}
  local cmd = M.command(project, mode, {
    root = selected.root,
    configuration = selected.configuration,
    tfm = selected.tfm,
    filter = filter,
    results_dir = out_dir,
    trx_filename = "results.trx",
    capabilities = capabilities,
    runner = capabilities.runner,
  })
  common.run(ctx, cmd, {
    cwd = selected.root,
    on_stdout = function(_, lines)
      vim.list_extend(output, lines or {})
    end,
    on_stderr = function(_, lines)
      vim.list_extend(output, lines or {})
    end,
    on_exit = function(code)
      vim.schedule(function()
        local locations = parsers.stack_locations(output)
        if #locations > 0 then
          vim.fn.setqflist({}, "r", {
            title = "Dotnet test failures",
            items = locations,
          })
          ctx:append("Source locations added to quickfix")
        end
        ctx:append("Test artifacts: " .. out_dir)
        if mode == "selected" then
          last_failed[project] = code ~= 0 and filter or nil
        end
      end)
    end,
  })
end

M.spec = {
  name = "Test Explorer",
  icon = " ",
  desc = "discover, run, rerun and collect coverage",
  action = function(ctx)
    ctx:select({
      { name = "Run All", _raw = "all" },
      { name = "Discover Tests", _raw = "discover" },
      { name = "Run Selected Name", _raw = "selected" },
      { name = "Rerun Last Failed Name", _raw = "failed" },
      { name = "Collect Coverage", _raw = "coverage" },
    }, {
      title = "Test Action",
      on_select = function(item, child)
        common.project(child, function(project, c)
          local mode = item._raw
          if mode == "selected" then
            common.input("Fully qualified test name: ", function(name)
              run_test(c, project, "selected", name)
            end)
          elseif mode == "failed" then
            if last_failed[project] then
              run_test(c, project, "selected", last_failed[project])
            else
              c:append("No failed selected test recorded for this project")
            end
          else
            run_test(c, project, mode)
          end
        end)
      end,
    })
  end,
}

return M
