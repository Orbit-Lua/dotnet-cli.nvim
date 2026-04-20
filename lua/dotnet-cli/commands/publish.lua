-- dotnet-cli.nvim commands: Publish
local job = require("dotnet-cli.job")
local project = require("dotnet-cli.project")

local M = {}

local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

---@param proj string
---@return string[]
M.get_cmd = function(proj)
  return { "dotnet", "publish", proj, "-p:PublishProfile=FolderProfile", "-c", "Release" }
end

---Configure a publish profile from the bundled template.
---@param project_dir string
---@param ctx CometCtx
M.configure_profile = function(project_dir, ctx)
  local csproj_files = vim.fn.glob(project_dir .. "/*.csproj", false, true)
  if #csproj_files == 0 then
    ctx.append("⚠  No .csproj found in " .. project_dir)
    return
  end

  local csproj_content = table.concat(vim.fn.readfile(csproj_files[1]), "\n")
  local target_fw = csproj_content:match("<TargetFramework>(.+)</TargetFramework>")
  if not target_fw then
    ctx.append("⚠  Could not detect TargetFramework from " .. csproj_files[1])
    return
  end

  local template_path = plugin_dir .. "/template/dotnet.csproj"
  if vim.fn.filereadable(template_path) ~= 1 then
    ctx.append("⚠  Publish-profile template not found: " .. template_path)
    return
  end

  local template_lines = vim.fn.readfile(template_path)
  for i, line in ipairs(template_lines) do
    if line:find("TargetFramework") and line:find("netx%.x") then
      template_lines[i] = "    <TargetFramework>" .. target_fw .. "</TargetFramework>"
    end
  end

  local profile_dir = project_dir .. "/Properties/PublishProfiles"
  vim.fn.mkdir(profile_dir, "p")
  local profile_path = profile_dir .. "/FolderProfile.pubxml"
  vim.fn.writefile(template_lines, profile_path)

  ctx.append("")
  ctx.append("✓  Created publish profile: " .. profile_path)
  ctx.append("   TargetFramework: " .. target_fw)
end

---@type CometCommand
M.spec = {
  name = "Publish",
  icon = "󰆦 ",
  icon_hl = "DiagnosticInfo",
  desc = "dotnet publish",
  action = function(ctx)
    project.select_csproj(ctx, function(f, c)
      job.run(M.get_cmd(f), c)
    end)
  end,
}

return M
