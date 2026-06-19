# Dotnet-cli.md

Guidance for agents working on `dotnet-cli.nvim`.

## Project

This repository is a Neovim plugin that wraps common `dotnet` CLI workflows.
It uses Lua 5.1 in the Neovim runtime and depends on
[comet.nvim](https://github.com/gin31259461/comet.nvim) for the manager UI.

Runtime requirements:

- Neovim 0.10 or newer.
- `dotnet` on `PATH`.
- `comet.nvim`.
- Optional `nvim-web-devicons`.

## Layout

```text
lua/dotnet-cli/init.lua          setup(), commands, public API
lua/dotnet-cli/config.lua        defaults and user option merging
lua/dotnet-cli/ui.lua            comet.nvim shim
lua/dotnet-cli/job.lua           async and sync command runners
lua/dotnet-cli/project.lua       project and solution discovery
lua/dotnet-cli/parsers.lua       dotnet output parsers
lua/dotnet-cli/sdk.lua           SDK detection and cache
lua/dotnet-cli/health.lua        checkhealth integration
lua/dotnet-cli/commands/         manager command specs
lua/dotnet-cli/template/         publish profile template
plugin/dotnet-cli.lua            plugin entry point
tests/dotnet-cli/                plenary specs
```

## Core Concepts

- `CometCommand` is the command spec consumed by `comet.open()`.
- `CometCtx` is the output context passed to command actions.
- Important context methods are `clear`, `append`, `write`, `done`, `error`,
  `select`, and `start_async_task`.

## Command Guidelines

When adding a manager command:

1. Add `lua/dotnet-cli/commands/<name>.lua`.
2. Export a `.spec` table, or clearly named specs for grouped commands.
3. Register the spec in `lua/dotnet-cli/commands/init.lua`.
4. Keep command construction in a helper when tests or direct commands need it.

Use `job.run(cmd, ctx, on_complete)` for streamed output. Use `job.run_sync()`
only for small lookups needed before the next UI selection.

Read configuration at call time with:

```lua
local cfg = require("dotnet-cli.config").get()
```

Avoid expensive work at module load time. In particular, do not run shell
commands, read workspace files, or require `comet` outside a function body.

## Testing

Run the full local check before handing off changes:

```bash
make ready
```

Targets:

- `make fmt`: format Lua with StyLua.
- `make lint`: run luacheck.
- `make test`: run plenary specs.

Tests use `tests/minimal_init.lua`, which expects plenary at the user's
lazy.nvim package path.

## Do Not

- Change comet.nvim's API surface from this repository.
- Add non-Lua runtime dependencies.
- Modify `tests/minimal_init.lua` unless the plenary bootstrap path changes.
- Add decorative icons or emoji to Lua source, logs, or error messages.
- Reformat unrelated files while making a focused change.
