# dotnet-cli.nvim

Build, run, test and debug SDK-style .NET projects from a Neovim manager.

[![Validate](https://github.com/Orbit-Lua/dotnet-cli.nvim/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/Orbit-Lua/dotnet-cli.nvim/actions/workflows/validate.yml?query=branch%3Amain) [![Neovim](https://img.shields.io/badge/Neovim-0.11%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

The manager lets you select a startup project and run the `dotnet` workflows of local console, library and ASP.NET Core development. Optional [nvim-dap](https://github.com/mfussenegger/nvim-dap) integration builds the project and starts `netcoredbg`.

Legacy .NET Framework projects, Visual Studio designers, cloud deployment and remote debugging are out of scope. The [capability guide](docs/capabilities.md) lists each provider and limit.

## Install

Requirements:

- Neovim 0.11 or later.
- A [.NET SDK](https://dotnet.microsoft.com/download) as `dotnet` on `PATH`.
- [comet.nvim](https://github.com/Orbit-Lua/comet.nvim) for `:DotnetManager`.
- Optional: [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [netcoredbg](https://github.com/Samsung/netcoredbg) 3.2.0-1092 or later, for `:DotnetDebug` and `:DotnetAttach`.
- Optional: `dotnet-ef`, `dotnet-counters`, `dotnet-trace` and `dotnet-dump` for their actions. A global install or a local tool manifest works.
- Optional: [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file icons. The manager has fallback icons.

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

## Usage

Open an SDK-style project, or create one:

```sh
dotnet new console -n Demo
cd Demo
nvim .
```

1. Run `:DotnetManager`.
2. Select **Workspace → Startup Project**, then `Demo.csproj`.
3. Select **Build**.

The right panel shows the `dotnet build` output and its status. Project lists show a scanning row at once and skip `bin` and `obj`.

## Manager

| Area | Actions |
| --- | --- |
| Workspace | Select the startup project, solution, build configuration, target framework and `launchSettings.json` Project profile. Each workspace root keeps its selection. |
| Build and run | Build, run, watch run or test, restore, clean and format. Interactive jobs accept line input in the output panel. |
| Test Explorer | Discover tests, run all or one test, rerun the last failed test, collect coverage, and send source locations to quickfix. VSTest and Microsoft.Testing.Platform use different options. |
| Packages and solutions | List direct, transitive, outdated and vulnerable packages. Add, update or remove packages, edit central versions, use a lockfile, and manage NuGet sources, projects and solutions. |
| Local tooling | List or restore local tools and workloads, run EF Core actions, and manage user secrets and the HTTPS development certificate. Secret values never appear in the output. |
| Diagnostics and delivery | Collect counters, traces or dumps from a local process. Pack a NuGet package, publish to a local path, or create an item from a template. |

Comet keeps output per workspace session. In the output panel, press `i` or `a` to send a line to an interactive job. Press `<C-c>` to stop the current job.

Diagnostic artifacts go to `artifacts/diagnostics` in the workspace. **Publish** uses the bundled `FolderProfile`; **Pack & Publish** can ask for each option.

### Command line

**Command Line** runs a typed `dotnet` command. Suggestions come from `dotnet complete` and project discovery.

- Press Tab to accept a suggestion.
- Press Enter to run the command.
- Press `<C-c>` to stop the running task.

The page runs `build`, `clean`, `restore`, `test`, `run`, `publish`, `pack` and `format`, plus SDK information and help options. Use the manager actions for EF, NuGet, secrets and SDK extensions.

The page rejects arguments that carry credentials, before completion and before execution. No shell runs the command, so expansion, pipes and chaining do not apply.

- Quote a path with spaces in single or double quotes.
- Single quotes keep Windows backslashes.
- In double quotes, a backslash escapes a double quote.

Commands default to the selected project, configuration and framework. An explicit option wins. Arguments after `--` go to the application. Reopen the page after you change the workspace selection.

### Commands

| Command | Purpose |
| --- | --- |
| `:DotnetManager` | Open the manager. |
| `:DotnetBuild` | Choose a project and build it. |
| `:DotnetPublish` | Publish with the bundled `FolderProfile`. |
| `:DotnetGlobalJson` | Create or update the SDK pin in `global.json`. |
| `:DotnetDebug` | Build and debug the startup project. |
| `:DotnetAttach` | Attach the debugger to a local process. |
| `:checkhealth dotnet-cli` | Check the SDK and the optional providers. |

## Debugging

Register the adapter after nvim-dap loads:

```lua
local ok, err = require("dotnet-cli").setup_dap()
if not ok then
  vim.notify(err, vim.log.levels.WARN)
end
```

`setup_dap()` finds `netcoredbg` on `PATH`. On Windows, it also checks the Mason install and uses the native `netcoredbg.exe`, not Mason's batch shim. To use another executable, pass `setup_dap({ adapter_path = "/absolute/path/to/netcoredbg" })`.

`:DotnetDebug` and the `Dotnet: Launch selected project` configuration of `:DapNew` resolve the project in the same way:

1. The workspace selection wins.
2. Without a selection, the only runnable non-test project is used.
3. With more than one application, a picker opens.

Libraries and test projects never launch. The launch uses the output path that MSBuild evaluates with the same options.

A launch shows one notification, titled `Dotnet`, that moves through these phases:

| Phase | Message |
| --- | --- |
| Resolve | `Resolving the startup project` |
| Build | `Building <project>` |
| Start | `Starting netcoredbg` |
| Running | `Debugging <project>` |
| Exit | `<project> exited with code <n>`, or `Debug session ended` |

A failure ends the notification at its phase. A failed build shows the error count and up to ten compiler errors. With [nvim-notify](https://github.com/rcarriga/nvim-notify) or [snacks.nvim](https://github.com/folke/snacks.nvim), each phase replaces the message. Other notifiers show one message per phase.

By default, nvim-dap shows the program output, and the program cannot read input. Set `dap.integrated_console = false` for an external console that accepts input. On Windows, the integrated console switches the console output to UTF-8 during a session.

### Saved selection

Selections persist under `stdpath("state")/dotnet-cli/workspaces/`. Each record keeps the project, solution, configuration, framework and profile, and no environment values. A missing project or an invalid record stops the launch until you select again. A failed write keeps the previous record.

To select a project from Lua, call `require("dotnet-cli").workspace.select_project("/absolute/path/to/App.csproj")`.

## Configuration

`setup()` accepts these options:

| Option | Default | Effect |
| --- | --- | --- |
| `roslyn_auto_insert` | `true` | Ask Roslyn for its `/` auto insert, such as a doc comment. |
| `build_configurations` | `{ "Debug", "Release" }` | Configurations that the build picker shows. A list replaces the default list. |
| `default_build_config` | `"Debug"` | Configuration of a direct build. |
| `output_dir_template` | unset | Build output directory. `{config}` becomes the configuration. Unset keeps the SDK layout. |
| `nuget.allow_insecure_connections` | `false` | Allow insecure connections when you add a NuGet source. |
| `dap.integrated_console` | `true` | Show debuggee output in nvim-dap. `false` opens an external console with input. |

`setup()` raises an error for an unknown key or a wrong type, and names the option path:

```text
dap.integrated_consol: unknown option
```

`require("dotnet-cli")` also exports the `workspace`, `msbuild`, `launch`, `job`, `project`, `sdk` and `parsers` modules.

## Ownership

| Task | Owner |
| --- | --- |
| Manager windows, pickers and output panels | comet.nvim |
| Project discovery, selection, builds and `dotnet` commands | dotnet-cli.nvim |
| Debug sessions, breakpoints and debug UI | nvim-dap and your configuration |
| Debug adapter protocol for CoreCLR | netcoredbg |
| C# completion, navigation and code actions | Your Roslyn LSP configuration |

## Contributing

Read [AGENTS.md](AGENTS.md) for the development workflow and the checks.

This project is licensed under [GPL-3.0](LICENSE).
