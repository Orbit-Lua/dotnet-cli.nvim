-- dotnet-cli.nvim parsers
-- Pure-function parsers for dotnet CLI output.

local M = {}

---Parse the tabular output of `dotnet new list` into template records.
---@param lines string[]
---@return {name: string, short_name: string}[]
M.templates = function(lines)
  local templates = {}
  local in_data = false
  for _, line in ipairs(lines) do
    if line:match("^%-%-%-%-") then
      in_data = true
    elseif in_data and line:match("%S") then
      local parts = vim.split(vim.trim(line), "%s%s+")
      if #parts >= 2 then
        table.insert(templates, {
          name = vim.trim(parts[1]),
          short_name = vim.trim(parts[2]),
        })
      end
    end
  end
  return templates
end

---Parse the output of `dotnet sln <sln> list` into project paths.
---@param lines string[]
---@return string[]
M.sln_projects = function(lines)
  local projects = {}
  local in_data = false
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if not in_data and trimmed:match("^%-+$") then
      in_data = true
    elseif in_data and trimmed ~= "" then
      table.insert(projects, trimmed)
    end
  end
  return projects
end

local NUGET_DISABLED = { Disabled = true, ["已停用"] = true, ["已禁用"] = true }

---Parse the output of `dotnet nuget list source` into source records.
---Output format:
---   Registered Sources:
---     1.  nuget.org [Enabled]
---         https://api.nuget.org/v3/index.json
---@param lines string[]
---@return {name: string, url: string, enabled: boolean}[]
M.nuget_sources = function(lines)
  local sources = {}
  local i = 1
  while i <= #lines do
    local name, status = lines[i]:match("^%s*%d+%.%s+(.-)%s+%[([^%]]+)%]")
    if name then
      local url = (lines[i + 1] or ""):match("^%s+(%S+)")
      table.insert(sources, { name = name, url = url or "", enabled = not NUGET_DISABLED[status] })
      i = i + 2
    else
      i = i + 1
    end
  end
  return sources
end

---Parse `dotnet --list-sdks` output into version strings.
---Each line: "8.0.100 [/usr/share/dotnet/sdk]"
---@param lines string[]
---@return string[]
M.sdk_versions = function(lines)
  local versions = {}
  for _, line in ipairs(lines) do
    local ver = line:match("^(%S+)")
    if ver then
      table.insert(versions, ver)
    end
  end
  return versions
end

return M
