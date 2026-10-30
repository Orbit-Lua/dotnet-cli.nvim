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
  Use netcoredbg 3.2.0-1092 or newer for the validated .NET 10 workflow.
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

### Command input

Open **Command Line** in the manager to type a `dotnet` command.
Suggestions come from `dotnet complete` and workspace project discovery.
Press Tab to accept a suggestion.
Press Enter to run the command.
Use `<C-c>` to stop the page's running task.

The command page supports build, clean, restore, test, run, publish, pack, and
format commands. SDK information and help options are also supported.
Use the existing manager actions for EF, NuGet, secrets, and SDK extensions.
Credential-bearing arguments are rejected before completion or execution.
Command input is not echoed, saved, or interpreted by a shell.

Quote paths containing spaces with single or double quotes.
Single quotes preserve Windows backslashes literally.
Double quotes use backslash escaping before a double quote.
Empty quoted arguments are preserved.
Shell expansion, pipes, and command chaining are not evaluated.

Build commands default to the captured project, configuration, and framework.
Explicit command options take precedence.
Run options are inserted before `--`, which separates application arguments.
Reopen Command Line after changing the workspace selection.

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
On Windows, the adapter uses a native executable instead of Mason's batch shim.
It checks `PATH` and the Mason installation root.
An explicit `adapter_path` takes precedence and must identify a native executable.
Failed debug builds report their output without starting the adapter.
Both `:DotnetDebug` and the registered `:DapNew` launch configuration resolve
the startup project through the same workflow. An existing selection takes
precedence. Without a selection, one runnable non-test project is selected
automatically. Multiple applications open a picker. Libraries and test projects
are not selected for debug launch.

Select a project explicitly in the manager, or call
`dotnet.workspace.select_project("/absolute/path/to/App.csproj")`.
Selections survive editor restarts under `stdpath('state')/dotnet-cli/workspaces/`.
Each workspace stores project, solution, configuration, framework, and profile
identifiers. It stores no launch environment values. Missing selected projects
stop launch until you select a replacement. Invalid state also requires
reselection. A failed state write preserves the previous record and reports a
warning. Concurrent updates to one workspace use the last successful write.

Debug launch uses the target path evaluated by MSBuild with the same build
options. `OutputPath`, `OutDir`, and `output_dir_template` affect that path.

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

From the repository root, install `just`, `stylua`, `luacheck`, and
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim), then run:

```sh
make all
```

`just all` checks formatting, lints source, and runs hermetic core specs.
`just test-integration` executes native process, SDK completion, and restart tests.
`just test-debug` builds an isolated .NET 10 fixture and validates real debugging.
Set `DOTNET_TEST_ADAPTER` to test a specific native debugger executable.
Set `DOTNET_TEST_COMET` to test a local Comet checkout.
`make all` retains formatting, lint, and complete suite execution.
Repository editing and test rules are in
[AGENTS.md](AGENTS.md).

This project is licensed under [GPL-3.0](LICENSE).
