-- dotnet-cli.nvim configuration: defaults, validation and merging.

local M = {}

---@class DotnetCliConfig
---@field roslyn_auto_insert? boolean Enable Roslyn '/' auto-insert (default true)
---@field build_configurations? string[] Available build configurations (default `{ "Debug", "Release" }`)
---@field default_build_config? string Default build configuration (default `"Debug"`)
---@field output_dir_template? string Build output directory; `{config}` is replaced by the configuration
---@field nuget? DotnetCliNugetConfig NuGet-related configuration
---@field dap? DotnetCliDapConfig Debug adapter configuration

---@class DotnetCliNugetConfig
---@field allow_insecure_connections? boolean Allow insecure connections for NuGet sources (default false)

---@class DotnetCliDapConfig
---@field integrated_console? boolean Route debuggee output to nvim-dap instead of a console window (default true)

---@class DotnetCliValues
---@field roslyn_auto_insert boolean
---@field build_configurations string[]
---@field default_build_config string
---@field output_dir_template? string
---@field nuget { allow_insecure_connections: boolean }
---@field dap { integrated_console: boolean }

---@type DotnetCliValues
M.defaults = {
  roslyn_auto_insert = true,
  build_configurations = { "Debug", "Release" },
  default_build_config = "Debug",
  nuget = {
    allow_insecure_connections = false,
  },
  dap = {
    integrated_console = true,
  },
}

-- The accepted type of each option. A table value describes a nested option
-- table; "string[]" is a list of strings that replaces the default list.
---@alias DotnetCliOptionType "boolean"|"string"|"string[]"|table<string, DotnetCliOptionType>
---@type table<string, DotnetCliOptionType>
local shape = {
  roslyn_auto_insert = "boolean",
  build_configurations = "string[]",
  default_build_config = "string",
  output_dir_template = "string",
  nuget = { allow_insecure_connections = "boolean" },
  dap = { integrated_console = "boolean" },
}

---@type DotnetCliValues
M.values = vim.deepcopy(M.defaults)

---@param value any
---@return boolean
local function is_string_list(value)
  if type(value) ~= "table" or not vim.islist(value) then
    return false
  end
  for _, item in ipairs(value) do
    if type(item) ~= "string" then
      return false
    end
  end
  return true
end

---@param path string
---@param expected DotnetCliOptionType
---@param value any
local function check_value(path, expected, value)
  local ok
  if expected == "string[]" then
    ok = is_string_list(value)
  else
    ok = type(value) == expected
  end
  if not ok then
    error(("%s: expected %s, got %s"):format(path, expected, type(value)), 0)
  end
end

---@param prefix string
---@param spec table<string, DotnetCliOptionType>
---@param opts table
local function check_table(prefix, spec, opts)
  for key, value in pairs(opts) do
    local path = prefix .. tostring(key)
    local expected = spec[key]
    if expected == nil then
      error(path .. ": unknown option", 0)
    end
    if type(expected) == "table" then
      if type(value) ~= "table" then
        error(("%s: expected table, got %s"):format(path, type(value)), 0)
      end
      check_table(path .. ".", expected, value)
    else
      check_value(path, expected, value)
    end
  end
end

---Raise an error that names the option path when `opts` has an unknown key
---or a value of the wrong type.
---@param opts? DotnetCliConfig
function M.validate(opts)
  if opts == nil then
    return
  end
  if type(opts) ~= "table" then
    error("dotnet-cli options: expected table, got " .. type(opts), 0)
  end
  check_table("", shape, opts)
end

---Validate user options, then apply them on top of the defaults. Lists
---replace the default list. On an error the previous values stay.
---@param opts? DotnetCliConfig
M.setup = function(opts)
  M.validate(opts)
  local values = vim.deepcopy(M.defaults)
  for key, value in pairs(opts or {}) do
    if type(shape[key]) == "table" then
      values[key] = vim.tbl_extend("force", values[key], value)
    else
      values[key] = vim.deepcopy(value)
    end
  end
  M.values = values
end

---Get the current resolved config.
---@return DotnetCliValues
M.get = function()
  return M.values
end

return M
