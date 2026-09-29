# AGENTS Instructions

## Scope and ownership

This Lua plugin runs local SDK-style .NET workflows in Neovim.
`lua/dotnet-cli/init.lua` owns `setup()`, the public exports, and `Dotnet*` user
commands; `lua/dotnet-cli/commands/` owns manager actions.
`lua/dotnet-cli/ui.lua` delegates the manager UI to sibling `comet.nvim`. Keep
.NET behavior here and reusable palette behavior in Comet.

| Change | Owner |
| --- | --- |
| Option defaults and merging | `lua/dotnet-cli/config.lua` |
| Structured process execution, stdin, cancellation, sync queries | `lua/dotnet-cli/job.lua` |
| `.csproj`, `.sln`, `.slnx` discovery and selectors | `lua/dotnet-cli/project.lua` |
| Selected root, project, solution, configuration, framework, profile | `lua/dotnet-cli/workspace.lua` |
| Evaluated output metadata and Project launch profiles | `lua/dotnet-cli/msbuild.lua`, `lua/dotnet-cli/launch.lua` |
| Optional nvim-dap/netcoredbg registration | `lua/dotnet-cli/dap.lua` |
| CLI output parsing and SDK cache | `lua/dotnet-cli/parsers.lua`, `lua/dotnet-cli/sdk.lua` |
| Health checks | `lua/dotnet-cli/health.lua` |

`plugin/dotnet-cli.lua` is the loader. `tests/dotnet-cli/` contains Plenary
specs; `tests/minimal_init.lua` bootstraps their runtime path. The bundled
template at `lua/dotnet-cli/template/dotnet.csproj` is for publish-profile
behavior: edit it only for a publish-profile task.

## Change contracts

- Keep manager actions as focused command specs. Use `commands/common.lua` and
  `job.lua` to run commands; pass structured argument arrays and do not
  duplicate Neovim job handling in action modules.
- Use the asynchronous discovery functions in `project.lua` for UI pickers. Show
  an immediate scanning state, then update the active page; skip generated
  directories and do not let a late result overwrite another view.
- Store project selection through `workspace.lua`. Query launch targets with
  `msbuild.lua`; do not guess `bin` paths or parse project XML for evaluated
  output. Launch profiles come from `launch.lua`.
- Put CLI output interpretation in pure `parsers.lua` functions. Keep VSTest and
  Microsoft.Testing.Platform command options distinct.
- Interactive tasks must register their job and Comet terminal so input and
  cancellation work. Never print user-secret values into task output or
  persistent buffers.
- Preserve existing `require("dotnet-cli")` exports and `Dotnet*` commands
  unless the task explicitly changes the public API. Update README when
  commands, setup options, dependencies, manager behavior, health checks, or
  publish-profile behavior change.

Lua files follow `.stylua.toml` (two spaces, 80 columns, Unix endings). Modules
use local `M = {}` and `return M`. Prefer short comments that explain a choice
rather than repeat code.

## Validation

From this repository root:

```sh
make all
```

`make all` runs `make fmt` (rewrites Lua files), `make lint`
(`luacheck lua --globals vim`), then `make test` (Plenary specs). Use
`make lint` and `make test` separately while iterating;
`stylua --check lua/ --config-path=.stylua.toml` checks formatting without
rewriting.

Add focused specs when changing parsers, config defaults, command arrays,
project discovery, workspace state, SDK caching, MSBuild/launch behavior, DAP
registration, test-runner options, or job behavior. Use temporary project
directories for discovery tests and restore the working directory before the
test ends. For documentation-only edits, validate links and `git diff --check`;
running the full Lua suite is useful when examples or commands change.

`stylua`, `luacheck`, and `plenary.nvim` are development dependencies.
`tests/minimal_init.lua` searches Neovim's lazy.nvim data directory and
`~/.local/share/nvim/lazy/plenary.nvim` for Plenary. Report any check skipped
because a local tool is missing, and preserve unrelated working-tree changes.
