# dotnet-cli.nvim

Develop SDK-style C# console apps, libraries, and ASP.NET Core projects from Neovim with `dotnet-cli.nvim` and [comet.nvim](https://github.com/gin31259461/comet.nvim).

The manager keeps a startup project, solution, configuration, target framework, and launch profile for each workspace. Commands run as structured `dotnet` processes and stream into a persistent Comet session. It handles local development workflows; cloud and remote deployment are outside its scope.

## Requirements

- Neovim 0.10 or newer, [.NET SDK](https://dotnet.microsoft.com/download), and `comet.nvim` for the manager.
- Optional [nvim-dap](https://github.com/mfussenegger/nvim-dap) and `netcoredbg` for debugging.
- Optional `dotnet-ef`, `dotnet-counters`, `dotnet-trace`, and `dotnet-dump` for their respective actions. Local tool manifests are supported.
- Optional `nvim-web-devicons` for file icons.
- Development checks require `stylua`, `luacheck`, and `plenary.nvim`.

## Install

```lua
{
  "Orbit-Lua/dotnet-cli.nvim",
  dependencies = { "gin31259461/comet.nvim" },
  cmd = { "DotnetManager", "DotnetBuild", "DotnetPublish", "DotnetGlobalJson", "DotnetDebug", "DotnetAttach" },
  opts = {},
}
```

Open `:DotnetManager` from a .NET workspace. Choose **Workspace** first to select a startup project, configuration, target framework, and optional ASP.NET Core Project launch profile. The selection is shared by build, run, test, and debugging actions. Comet stores output by workspace session; focus its output panel and press `i` or `a` to send a line to an interactive run, watch, or diagnostics job. Press `<C-c>` to stop the current job.

## Manager actions

| Area | Available work |
| --- | --- |
| Build and run | Build, run with a launch profile, watch run/test, restore, clean, and format. Build uses the SDK's normal output path by default so MSBuild and the debugger agree on `TargetPath`. |
| Test Explorer | Discover, run all, run a named test, rerun the last failed named test, collect coverage, and put reported source locations in quickfix. Supports VSTest and `global.json` configured Microsoft.Testing.Platform. Coverage needs the appropriate collector or extension in the test project. |
| Packages | List direct/transitive/outdated/vulnerable packages, add/update/remove packages, open `Directory.Packages.props`, open a lockfile, and restore with or create a lockfile. SDK 10 package-list syntax is selected automatically. |
| Solution and templates | Create projects and items, add/remove/list solution projects, and inspect installed SDKs and runtimes. |
| Tools and EF Core | List/restore local tools and workloads, list DbContexts and migrations, add/remove migrations, generate SQL, and update a local database. |
| Local development | Initialize user secrets, list keys, set/remove a secret, and check/trust the HTTPS development certificate. Secret values are entered through Neovim's secret prompt and are never written to the Comet output panel. |
| Diagnostics | Collect local process counters, traces, and dumps into `artifacts/diagnostics`. Install the matching `dotnet-*` tool first. |
| Delivery | Pack a NuGet package, publish with configuration/profile/RID/self-contained/single-file/output options, or create an item from a `dotnet new` template. The original FolderProfile publish action remains available. |

The selected project must be an SDK-style `.csproj`. Solution discovery supports `.sln` and `.slnx`. The plugin does not implement Visual Studio proprietary designers, legacy .NET Framework project systems, cloud publishing, or remote debugging.

See the [capability guide](docs/capabilities.md) for provider requirements and support limits.

## Direct commands and Lua API

```vim
:DotnetManager
:DotnetBuild
:DotnetPublish
:DotnetGlobalJson
:DotnetDebug
:DotnetAttach
:checkhealth dotnet-cli
```

`DotnetDebug` builds and launches the selected startup project. `DotnetAttach` lets nvim-dap choose a local process. The plugin owns .NET target discovery and DAP configurations; Neovim config can continue to own breakpoint keys and the DAP UI.

```lua
local dotnet = require("dotnet-cli")
dotnet.setup({
  roslyn_auto_insert = true,
  build_configurations = { "Debug", "Release" },
  default_build_config = "Debug",
  nuget = { allow_insecure_connections = false },
})

-- Call after nvim-dap is loaded. netcoredbg must be on PATH, or supply its path.
dotnet.setup_dap({ adapter_path = "/path/to/netcoredbg" })

-- An embedding config can select a project before starting DAP.
dotnet.workspace.select_project("/path/to/App.csproj")
```

| Option | Default | Meaning |
| --- | --- | --- |
| `roslyn_auto_insert` | `true` | Request Roslyn auto-insert on `/`. |
| `build_configurations` | `{ "Debug", "Release" }` | Build and workspace configuration choices. |
| `default_build_config` | `"Debug"` | Default for direct builds. |
| `output_dir_template` | unset | Optional custom build output directory with `{config}` substitution. Leave unset for evaluated SDK output paths and reliable debugging. |
| `nuget.allow_insecure_connections` | `false` | Allow insecure NuGet sources when adding one. |

The public `workspace`, `msbuild`, `launch`, `job`, `project`, `sdk`, and `parsers` modules are available from `require("dotnet-cli")` for integrations. `msbuild.get(project, configuration, tfm)` returns the evaluated target path and output metadata.

## Development

Run `make all` to format, lint, and execute Plenary specs. `make fmt`, `make lint`, and `make test` run each stage separately. Tests live in `tests/dotnet-cli/`.
