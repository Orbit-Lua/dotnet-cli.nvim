# AGENTS.md

## Project Overview

This repository is a Neovim plugin for common `.NET` CLI workflows. It is
implemented in Lua, uses `comet.nvim` as a thin manager UI layer, and uses
`plenary.nvim` for tests.

The plugin exposes `require("dotnet-cli").setup()` plus user commands for
opening the manager, building, publishing, and managing `global.json`. Manager
actions are small command specs that run `dotnet` commands through shared job
helpers and project discovery helpers.

## Project Layout

```text
lua/dotnet-cli/init.lua          setup(), user commands, public API
lua/dotnet-cli/config.lua        default options and user option merging
lua/dotnet-cli/ui.lua            thin comet.nvim adapter
lua/dotnet-cli/job.lua           async and sync command runners
lua/dotnet-cli/project.lua       .csproj, .sln, and .slnx discovery
lua/dotnet-cli/parsers.lua       pure parsers for dotnet CLI output
lua/dotnet-cli/sdk.lua           SDK detection and cache
lua/dotnet-cli/health.lua        :checkhealth integration
lua/dotnet-cli/commands/         manager command specs
lua/dotnet-cli/template/         publish profile template
plugin/dotnet-cli.lua            plugin entry point
tests/dotnet-cli/                plenary specs
tests/minimal_init.lua           test runtimepath bootstrap
docs/images/                     README screenshots
```

## Dependencies

Runtime:

- Neovim with Lua support.
- `dotnet` available on `PATH`.
- `comet.nvim` for the manager UI.
- Optional `nvim-web-devicons` for file icons.

Development:

- `stylua` for formatting.
- `luacheck` for linting.
- `plenary.nvim` for tests. `tests/minimal_init.lua` looks under the normal
  lazy.nvim package path and `~/.local/share/nvim/lazy/plenary.nvim`.

## Setup And Validation

Run all checks from the repository root:

```bash
make all
```

Useful narrower commands:

```bash
make fmt
make lint
make test
```

`make all` runs `make fmt`, `make lint`, and `make test` in that order.
`make lint` invokes `luacheck lua --globals vim`. `make test` runs:

```bash
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/dotnet-cli { minimal_init = 'tests/minimal_init.lua' }"
```

Mention any check that cannot be run because a local tool is missing.

## Development Workflow

- Keep manager actions in `lua/dotnet-cli/commands/` as small command specs.
- Use `lua/dotnet-cli/job.lua` for command execution. Do not duplicate Neovim
  job handling inside command modules.
- Use `lua/dotnet-cli/project.lua` for `.csproj`, `.sln`, and `.slnx`
  discovery.
- Keep output parsing in `lua/dotnet-cli/parsers.lua`; parser functions should
  remain pure and covered by focused specs.
- Keep `lua/dotnet-cli/ui.lua` as a thin `comet.nvim` shim unless the UI
  integration itself changes.
- Do not edit `lua/dotnet-cli/template/dotnet.csproj` unless the task involves
  publish-profile behavior.

## Testing Instructions

Add or update tests when changing:

- parser behavior in `lua/dotnet-cli/parsers.lua`;
- config defaults or merge behavior in `lua/dotnet-cli/config.lua`;
- command generation, especially build/publish command arrays;
- project or solution discovery;
- SDK helper behavior and caching;
- job runner behavior.

Prefer focused specs under `tests/dotnet-cli/` that exercise the changed module
directly. Use temporary directories for project discovery tests and restore the
original working directory before assertions finish.

## Code Style

- Lua files use Stylua settings from `.stylua.toml`: 2-space indentation,
  Unix line endings, 80-column width, and automatic preferred double quotes.
- Keep modules table-based with local `M = {}` and `return M`, matching the
  existing code.
- Prefer structured command arrays such as `{ "dotnet", "build", project }`
  over shell-joined strings unless the called API requires a string.
- Keep comments short and useful. Avoid comments that restate obvious code.
- Preserve existing public module exports from `lua/dotnet-cli/init.lua` unless
  a task explicitly changes the public API.

## User-Facing Documentation

Update `README.md` when user-facing behavior changes, including:

- new or renamed commands;
- setup options or changed defaults;
- changed manager actions;
- dependency changes;
- health check behavior;
- publish-profile behavior.

The README intentionally does not duplicate license, changelog, or contribution
policy content.

## Handoff Notes

- Preserve unrelated user changes in the working tree.
- Report checks run and checks skipped.
- Include exact failure output or missing tool names when validation cannot
  complete.
- If behavior changes but tests were not added, explain the remaining risk.
