# AGENTS.md — dotnet-cli.nvim

Guidelines for AI agents (Claude, Copilot, etc.) working in this repository.

## Project overview

A Neovim plugin that wraps the `dotnet` CLI. It provides a two-panel floating
UI (via [comet.nvim](https://github.com/gin31259461/comet.nvim)) plus individual
Vim commands for build, publish, test, watch, solution management, NuGet, and
SDK pinning.

- **Language:** Lua 5.1 (LuaJIT, Neovim runtime)
- **Min Neovim:** 0.10
- **Required runtime dep:** comet.nvim
- **Optional dep:** nvim-web-devicons

## Repository layout

```
lua/dotnet-cli/
├── init.lua            -- setup(), user commands, Roslyn auto-insert
├── config.lua          -- DotnetCliConfig defaults + merge
├── ui.lua              -- thin shim: re-exports require("comet")
├── job.lua             -- M.run (async+streaming), M.run_sync, M.get_netcore_pid
├── project.lua         -- csproj/sln file discovery
├── parsers.lua         -- output parsers: templates, sln projects, NuGet sources
├── sdk.lua             -- SDK detection + version caching
├── health.lua          -- :checkhealth dotnet-cli
├── commands/
│   ├── init.lua        -- get_all(): ordered CometCommand[] registry
│   ├── build.lua
│   ├── run.lua
│   ├── test.lua
│   ├── watch.lua
│   ├── restore.lua
│   ├── clean.lua
│   ├── publish.lua
│   ├── format.lua
│   ├── new.lua
│   ├── solution.lua
│   ├── nuget.lua
│   ├── add_package.lua
│   └── sdk.lua         -- global.json, list sdks, list runtimes
└── template/
    └── dotnet.csproj   -- publish profile template
plugin/dotnet-cli.lua   -- entry point (calls setup with no args if not lazy-loaded)
tests/
├── minimal_init.lua    -- headless test bootstrap (uses plenary from lazy path)
└── dotnet-cli/
    ├── config_spec.lua
    ├── job_spec.lua
    ├── parsers_spec.lua
    ├── project_spec.lua
    └── sdk_spec.lua
```

## Core types

These types come from comet.nvim — understand them before touching command files.

- **`CometCtx`** — output-panel context passed into every command handler.
  Key methods: `ctx:clear()`, `ctx:append(line)`, `ctx:write(lines)`,
  `ctx:done()`, `ctx:error()`.
- **`CometCommand`** — a command spec table consumed by `comet.open()`.
  Each command module exposes a `.spec` (or multiple specs for sdk.lua).

## Conventions

### Adding a new command

1. Create `lua/dotnet-cli/commands/<name>.lua` with a `.spec` table.
2. Register it in `lua/dotnet-cli/commands/init.lua` inside `get_all()`.
3. Keep dotnet CLI invocations in a `get_cmd()` helper so tests and the UI
   can both call it without running a real process.

### job.run vs job.run_sync

- Use `job.run(cmd, ctx, on_complete?)` for anything that streams output to the
  UI panel (build, test, watch, etc.).
- Use `job.run_sync(cmd)` only for lightweight lookups that happen before the UI
  opens (e.g. listing SDKs, discovering templates).

### Config access

Always call `require("dotnet-cli.config").get()` at call-time, not at module
load-time. Modules are loaded before `setup()` runs.

### No global state at load time

Do not execute side-effects (file I/O, `vim.fn` calls, `require("comet")`) at
the top level of a module. Defer to function bodies so lazy-loading works
correctly.

## Testing

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) busted runner.
plenary is resolved from the user's lazy.nvim installation at
`~/.local/share/nvim/lazy/plenary.nvim`.

```bash
make test    # run all specs (headless nvim)
make lint    # luac -p syntax check
make format  # stylua in-place
make check   # stylua --check (CI)
```

All spec files live under `tests/dotnet-cli/` and follow the
`*_spec.lua` naming convention.

## What agents should NOT do

- Do not change the comet.nvim API surface — `ui.lua` is intentionally a
  one-line shim; comet is an external dependency.
- Do not add `require(...)` calls at module top-level (breaks lazy-loading).
- Do not introduce non-Lua dependencies or shell helpers beyond what `dotnet`
  already provides.
- Do not modify `tests/minimal_init.lua` unless the plenary bootstrap path
  changes.
- Do not add emojis or decorative icons to Lua source files or error messages.
