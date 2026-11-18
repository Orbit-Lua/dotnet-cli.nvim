local job = require("dotnet-cli.job")

---Start a job with a stubbed process and deliver one stdout chunk.
---@param interactive boolean
---@param chunk string[]
---@return string[][] written lines that the context received
---@return string[][] received lines that the stdout callback received
local function deliver(interactive, chunk)
  local jobstart = vim.fn.jobstart
  local options
  vim.fn.jobstart = function(_, opts)
    options = opts
    return 7
  end
  local written, received = {}, {}
  local ok, err = pcall(job.start, {
    argv = { "dotnet", "run" },
    interactive = interactive,
    on_stdout = function(_, data)
      received[#received + 1] = data
    end,
  }, {
    write = function(_, lines)
      written[#written + 1] = lines
    end,
  })
  vim.fn.jobstart = jobstart
  assert(ok, err)
  options.on_stdout(7, chunk, "stdout")
  return written, received
end

describe("job output", function()
  it("removes control sequences from interactive output", function()
    local written, received =
      deliver(true, { "\27[?25l\27[2J\27[H中文測試\r", "\27[?25h\r", "" })
    assert.are.same({ { "中文測試", "" } }, written)
    assert.are.same({ { "中文測試", "" } }, received)
  end)

  it("keeps the bytes of piped output", function()
    local written = deliver(false, { "\27[31mred\27[0m\r", "" })
    assert.are.same({ { "\27[31mred\27[0m", "" } }, written)
  end)
end)
