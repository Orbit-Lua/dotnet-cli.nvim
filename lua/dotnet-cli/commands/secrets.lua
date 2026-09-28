local common = require("dotnet-cli.commands.common")
local job = require("dotnet-cli.job")

local M = {}

M.list_keys = function(project)
  local lines, ok =
    job.run_sync({ "dotnet", "user-secrets", "list", "--project", project })
  if not ok then
    return nil
  end
  local keys = {}
  for _, line in ipairs(lines) do
    local key = line:match("^(.-)%s+=%s+")
    if key then
      table.insert(keys, key)
    end
  end
  return keys
end

M.set = function(project, key, value, ctx)
  ctx:clear()
  ctx:append("Setting user secret: " .. key)
  local id = job.start({
    argv = { "dotnet", "user-secrets", "set", "--project", project },
    stdin = vim.json.encode({ [key] = value }),
    on_exit = function(code)
      vim.schedule(function()
        if code == 0 then
          ctx:append("Secret saved")
          ctx:done()
        else
          ctx:append("Could not save secret")
          ctx:error()
        end
      end)
    end,
  })
  if id <= 0 then
    ctx:append("Could not start dotnet user-secrets")
    ctx:error()
    return
  end
  vim.fn.chanclose(id, "stdin")
  ctx:start_async_task(id)
end

M.spec = {
  name = "Local Development",
  icon = "󰌆 ",
  desc = "user secrets and HTTPS development certificate",
  action = function(ctx)
    ctx:select({
      { name = "List Secret Keys", _raw = "keys" },
      { name = "Set Secret", _raw = "set" },
      { name = "Remove Secret", _raw = "remove" },
      { name = "Initialize Secrets", _raw = "init" },
      { name = "Check HTTPS Certificate", _raw = "cert_check" },
      { name = "Trust HTTPS Certificate", _raw = "cert_trust" },
    }, {
      title = "Local Development",
      on_select = function(item, child)
        local action = item._raw
        if action == "cert_check" or action == "cert_trust" then
          common.run(child, {
            "dotnet",
            "dev-certs",
            "https",
            action == "cert_check" and "--check" or "--trust",
          })
          return
        end
        common.project(child, function(project, c)
          if action == "keys" then
            local keys = M.list_keys(project)
            c:clear()
            if not keys then
              c:append("Could not list secret keys")
            else
              c:write(keys)
            end
          elseif action == "init" then
            common.run(
              c,
              { "dotnet", "user-secrets", "init", "--project", project }
            )
          else
            common.input("Secret key: ", function(key)
              if action == "remove" then
                common.run(c, {
                  "dotnet",
                  "user-secrets",
                  "remove",
                  key,
                  "--project",
                  project,
                })
              else
                local value = vim.fn.inputsecret("Secret value: ")
                if value ~= "" then
                  M.set(project, key, value, c)
                end
              end
            end)
          end
        end)
      end,
    })
  end,
}

return M
