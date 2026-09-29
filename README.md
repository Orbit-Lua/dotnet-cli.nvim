# dotnet-cli.nvim

[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10%2B-57A143?style=flat-square&logo=neovim&logoColor=white)](https://neovim.io/)
[![Lua plugin](https://img.shields.io/badge/Lua-plugin-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://www.lua.org/)
[![GPL-3.0 license](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square)](LICENSE)

`dotnet-cli.nvim` runs local SDK-style C# development workflows from Neovim. Its
[Comet manager](https://github.com/Orbit-Lua/comet.nvim) lets you select a
workspace project, build, run, test, manage packages, and create local artifacts
without leaving the editor. Optional
[nvim-dap](https://github.com/mfussenegger/nvim-dap) integration supplies .NET
launch and attach configurations; your Neovim config can keep its own breakpoint
keys and debug UI.

The scope is local console, class library, and ASP.NET Core development. Legacy
.NET Framework projects, Visual Studio designers, cloud deployment, and remote
debugging are outside this plugin's scope. See the [capability
guide](docs/capabilities.md) for provider requirements and support limits.

## Requirements

- Neovim **0.10 or newer** with Lua support.
- A [.NET SDK](https://dotnet.microsoft.com/download) available as `dotnet` on
  `PATH`.
- [comet.nvim](https://github.com/Orbit-Lua/comet.nvim) for `:DotnetManager`.
- Optional: [nvim-dap](https://github.com/mfussenegger/nvim-dap) and
  `netcoredbg` for `:DotnetDebug` and `:DotnetAttach`.
- Optional: `dotnet-ef`, `dotnet-counters`, `dotnet-trace`, and `dotnet-dump`
  for their matching actions. Global installations and local tool manifests are
  supported.
- Optional: `nvim-web-devicons` for project file icons. The manager has fallback
  icons without it.

## Quick start

Install with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Orbit-Lua/dotnet-cli.nvim",
  dependencies = { "Orbit-Lua/comet.nvim" },
  cmd = {
    "DotnetManager",
    "DotnetBuild",
    "DotnetPublish",
    "DotnetGlobalJson",
    "DotnetDebug",
    "DotnetAttach",
  },
  config = function()
    require("dotnet-cli").setup()
  end,
}
```

For a first run, open an existing SDK-style C# project, or create a small one:

```sh
dotnet new console -n Demo
cd Demo
nvim .
```

Run `:DotnetManager`, choose **Workspace → Startup Project**, and select
`Demo.csproj`. Then choose **Build** and **Debug**. The right panel shows the
`dotnet build` output and a completion status. Project and solution lists show a
scanning row immediately and update when discovery finishes; generated `bin` and
`obj` directories are skipped.

## Everyday workflows

| Manager area | What you can do |
| --- | --- |
| Workspace | Select a startup project, solution, build configuration, target framework, and supported `launchSettings.json` Project profile. Choices are kept per workspace root. |
| Build and run | Build, run, watch run/test, restore, clean, and format. Interactive run and watch jobs accept line input from Comet's output panel. |
| Test Explorer | Discover tests, run all or a named test, rerun the last failed named test, collect coverage, and send reported source locations to quickfix. VSTest and `global.json` selected Microsoft.Testing.Platform use different CLI options. Coverage requires the corresponding collector or extension. |
| Packages and solutions | List direct, transitive, outdated, and vulnerable packages; add, update, or remove packages; edit central versions; create or use a lockfile; manage NuGet sources, projects, and solutions. |
| Local tooling | List or restore local tools and workloads; run EF Core context and migration actions; manage user secrets and the HTTPS development certificate. Secret values are entered through a secret prompt and are not written to manager output. |
| Diagnostics and delivery | Collect counters, traces, or dumps from a local process; pack a NuGet package; publish to a local output path with profile, runtime ID, self-contained, and single-file options; create an item from a template. |

Comet stores output by workspace session. Focus the output panel and press `i`
or `a` to send a line to an interactive job; press `<C-c>` to stop the current
job. Diagnostic artifacts go under `artifacts/diagnostics` in the selected
workspace. The separate **Publish** action retains the bundled `FolderProfile`
behavior; **Pack & Publish** provides configurable local publishing.

### Direct commands

| Command | Purpose |
| --- | --- |
| `:DotnetManager` | Open the manager. |
| `:DotnetBuild` | Choose and build a project. |
| `:DotnetPublish` | Publish with the existing `FolderProfile` action. |
| `:DotnetGlobalJson` | Create or update an SDK pin in `global.json`. |
| `:DotnetDebug` | Build and debug the selected startup project. |
| `:DotnetAttach` | Attach to a local process through nvim-dap. |
| `:checkhealth dotnet-cli` | Inspect the SDK and optional providers. |

## Debugging and configuration

Install nvim-dap and `netcoredbg`, then register the .NET adapter after nvim-dap
loads:

```lua
local dotnet = require("dotnet-cli")
local ok, err = dotnet.setup_dap()
if not ok then
  vim.notify(err, vim.log.levels.WARN)
end
```

If `netcoredbg` is outside `PATH`, call
`setup_dap({ adapter_path = "/absolute/path/to/netcoredbg" })`.
Select the startup project in the manager
before `:DotnetDebug`, or set it from Lua with
`dotnet.workspace.select_project("/absolute/path/to/App.csproj")`. Debug launch
uses the target path evaluated by MSBuild. A class library can be built but
cannot be launched directly.

`setup()` accepts these options:

| Option | Default | Effect |
| --- | --- | --- |
| `roslyn_auto_insert` | `true` | Enable the Roslyn `/` auto-insert integration when Roslyn LSP attaches. |
| `build_configurations` | `{ "Debug", "Release" }` | Choices shown for build configuration. |
| `default_build_config` | `"Debug"` | Configuration for direct builds. |
| `output_dir_template` | unset | Optional build output directory; `{config}` is replaced by the configuration. Leave unset for the SDK output layout used by MSBuild and the debugger. |
| `nuget.allow_insecure_connections` | `false` | Allow insecure connections when adding a NuGet source. |

The public `workspace`, `msbuild`, `launch`, `job`, `project`, `sdk`, and
`parsers` modules are available through `require("dotnet-cli")` for other Neovim
integrations.

## Development

From the repository root, install `stylua`, `luacheck`, and
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim), then run:

```sh
make all
```

`make all` formats Lua source, lints it, and runs Plenary specs under
`tests/dotnet-cli/`. Use `make fmt`, `make lint`, or `make test` for an
individual stage. Repository editing and test rules are in
[AGENTS.md](AGENTS.md).

This project is licensed under [GPL-3.0](LICENSE).
