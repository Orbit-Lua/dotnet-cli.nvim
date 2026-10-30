local job = require("dotnet-cli.job")
local fixture = vim.fs.joinpath(vim.fn.getcwd(), "tests/fixtures/process.lua")
local function command(mode)
  return {
    vim.v.progpath,
    "--headless",
    "--clean",
    "-i",
    "NONE",
    "-l",
    fixture,
    mode,
  }
end

describe("native process adapter", function()
  it(
    "returns output and unsuccessful status from actual child processes",
    function()
      local lines, ok = job.run_sync(command("success"))
      assert.is_true(ok)
      assert.same({ "hello" }, lines)
      local _, failed = job.run_sync(command("failure"))
      assert.is_false(failed)
    end
  )

  it("preserves the legacy string entry point without CR suffixes", function()
    -- Neovim derives 'shell' from the caller's SHELL, so Git Bash would pair
    -- bash with the cmd.exe flags. Pin the platform shell for this case.
    local names = {
      "shell",
      "shellcmdflag",
      "shellquote",
      "shellxquote",
    }
    local saved = {}
    for _, name in ipairs(names) do
      saved[name] = vim.o[name]
    end
    if vim.fn.has("win32") == 1 then
      vim.o.shell = "cmd.exe"
      vim.o.shellcmdflag = "/s /c"
      vim.o.shellquote = ""
      vim.o.shellxquote = '"'
    else
      vim.o.shell = "sh"
      vim.o.shellcmdflag = "-c"
      vim.o.shellquote = ""
      vim.o.shellxquote = ""
    end
    local cmd = '"'
      .. vim.v.progpath
      .. '" --headless --clean -i NONE -l "'
      .. fixture
      .. '" success'
    local ok, lines, success = pcall(job.run_sync, cmd)
    for _, name in ipairs(names) do
      vim.o[name] = saved[name]
    end
    assert(ok, lines)
    assert.is_true(success)
    assert.same({ "hello" }, lines)
  end)

  it(
    "runs in the captured working directory and observes completion",
    function()
      local root = vim.fs.normalize(vim.g.dotnet_test_root .. "/process cwd")
      vim.fn.mkdir(root, "p")
      local output, status = {}, nil
      local id = job.start({
        argv = command("cwd"),
        cwd = root,
        on_stdout = function(_, lines)
          vim.list_extend(output, lines)
        end,
        on_exit = function(code)
          status = code
        end,
      })
      assert.is_true(id > 0)
      assert.is_true(vim.wait(5000, function()
        return status ~= nil
      end))
      assert.equals(0, status)
      assert.equals(root, vim.fs.normalize(output[1]))
    end
  )
end)
