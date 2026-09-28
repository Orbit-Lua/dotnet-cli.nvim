local common = require("dotnet-cli.commands.common")
local sdk = require("dotnet-cli.sdk")

local M = {}

M.list_cmd = function(project, kind, major)
  major = major or sdk.get_major() or 0
  local cmd
  if major >= 10 then
    cmd = { "dotnet", "package", "list", "--project", project }
  else
    cmd = { "dotnet", "list", project, "package" }
  end
  if kind == "outdated" or kind == "vulnerable" then
    table.insert(cmd, "--" .. kind)
  end
  if kind == "transitive" then
    table.insert(cmd, "--include-transitive")
  end
  vim.list_extend(cmd, { "--format", "json" })
  return cmd
end

M.add_cmd = function(project, package, version)
  local cmd = { "dotnet", "add", project, "package", package }
  if version and version ~= "" then
    vim.list_extend(cmd, { "--version", version })
  end
  return cmd
end

M.remove_cmd = function(project, package)
  return { "dotnet", "remove", project, "package", package }
end

M.restore_cmd = function(project, mode)
  local cmd = { "dotnet", "restore", project }
  if mode == "locked" then
    table.insert(cmd, "--locked-mode")
  elseif mode == "generate" then
    table.insert(cmd, "-p:RestorePackagesWithLockFile=true")
  end
  return cmd
end

local function find_ancestor(start, filename)
  local dir = vim.fs.dirname(start)
  while dir do
    local path = vim.fs.joinpath(dir, filename)
    if vim.fn.filereadable(path) == 1 then
      return path
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

M.spec = {
  name = "Packages",
  icon = "󰏗 ",
  desc = "list, add, update, and remove NuGet packages",
  action = function(ctx)
    ctx:select({
      { name = "List", _raw = "list" },
      { name = "Outdated", _raw = "outdated" },
      { name = "Vulnerable", _raw = "vulnerable" },
      { name = "Transitive", _raw = "transitive" },
      { name = "Add", _raw = "add" },
      { name = "Update", _raw = "update" },
      { name = "Remove", _raw = "remove" },
      { name = "Restore Locked", _raw = "locked" },
      { name = "Generate Lockfile", _raw = "generate" },
      { name = "Open Central Versions", _raw = "central" },
      { name = "Open Lockfile", _raw = "lockfile" },
    }, {
      title = "Package Action",
      on_select = function(item, c)
        common.project(c, function(path, c2)
          local action = item._raw
          if
            action == "list"
            or action == "outdated"
            or action == "vulnerable"
            or action == "transitive"
          then
            common.run(c2, M.list_cmd(path, action))
          elseif action == "locked" or action == "generate" then
            common.run(c2, M.restore_cmd(path, action))
          elseif action == "central" or action == "lockfile" then
            local filename = action == "central" and "Directory.Packages.props"
              or "packages.lock.json"
            local target = find_ancestor(path, filename)
            if target then
              vim.cmd.edit(vim.fn.fnameescape(target))
            else
              c2:append(filename .. " was not found")
            end
          else
            common.input("Package ID: ", function(package)
              if action == "remove" then
                common.run(c2, M.remove_cmd(path, package))
              else
                common.input("Version (or * for latest): ", function(version)
                  common.run(
                    c2,
                    M.add_cmd(path, package, version == "*" and nil or version)
                  )
                end)
              end
            end)
          end
        end)
      end,
    })
  end,
}

return M
