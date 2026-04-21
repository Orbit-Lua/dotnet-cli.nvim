# dotnet-cli.nvim

A full-featured .NET CLI integration for Neovim. Manage projects, solutions,
NuGet packages, and SDK versions through a beautiful two-panel UI or individual
commands.

![dotnet-cli.nvim manager](docs/images/manager-overview.png)

## ✨ Features

- **Interactive Manager UI** — Two-panel Telescope-style picker with fuzzy
  filtering, multi-select, and streaming output
- **Build / Run / Test / Watch** — All common `dotnet` workflows at your
  fingertips
- **Solution Management** — Create, list, add/remove projects from solutions
- **NuGet Source Management** — List, add, remove, enable/disable package
  sources
- **SDK Version Pinning** — Create and update `global.json` with installed SDK
  versions
- **New Project Scaffolding** — Browse and create from all installed templates
- **Publish Profiles** — Auto-generate `FolderProfile.pubxml` from bundled
  template
- **Add Package** — Quickly add NuGet packages to any project
- **Code Formatting** — Run `dotnet format` on projects or solutions
- **Hot Reload** — `dotnet watch` integration with streaming output
- **Roslyn Auto-Insert** — Automatic `/` trigger for XML doc comments in C#
- **Health Check** — `:checkhealth dotnet-cli` validates your environment

## 📦 Requirements

- **Neovim** ≥ 0.10
- **.NET SDK** ≥ 6.0 (any version supported, 7+ recommended)
- **[comet.nvim](https://github.com/gin31259461/comet.nvim)** — UI library
  (two-panel picker used by the Dotnet Manager)
- **Optional:**
  [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file
  icons

## 📥 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Orbit-Lua/dotnet-cli.nvim",
  dependencies = { "Orbit-Lua/comet.nvim" },
  cmd = { "DotnetManager", "DotnetBuild", "DotnetPublish", "DotnetGlobalJson" },
  ft = "cs",
  opts = {},
}
```

## ⚙️ Configuration

```lua
require("dotnet-cli").setup({
  -- Enable Roslyn '/' auto-insert for XML doc comments (default: true)
  roslyn_auto_insert = true,

  -- Available build configurations shown in the UI
  build_configurations = { "Debug", "Release" },

  -- Default build configuration
  default_build_config = "Debug",

  -- Output directory template ({config} is replaced with the build config)
  output_dir_template = "bin/{config}",
})
```

All options are optional — calling `setup({})` or using `opts = {}` with
lazy.nvim uses sensible defaults.

## 🚀 Usage

### Commands

| Command             | Description                           |
| ------------------- | ------------------------------------- |
| `:DotnetManager`    | Open the interactive Manager UI       |
| `:DotnetBuild`      | Build a project (with notification)   |
| `:DotnetPublish`    | Publish a project (with notification) |
| `:DotnetGlobalJson` | Pin SDK version via global.json       |

### Keymaps (suggested)

```lua
vim.keymap.set("n", "<leader>dp", "<cmd>DotnetManager<CR>", { desc = "Dotnet Manager" })
vim.keymap.set("n", "<leader>db", "<cmd>DotnetBuild<CR>", { desc = "Dotnet Build" })
```

## Manager UI

The Manager UI is a two-panel floating window:

| Panel | Description                                       |
| ----- | ------------------------------------------------- |
| Left  | Search input (top) + scrollable command/item list |
| Right | Output panel with syntax-highlighted build output |

![dotnet-cli.nvim panels](docs/images/manager-panels.png)

### UI Keybindings

| Key       | Mode | Action                          |
| --------- | ---- | ------------------------------- |
| `<CR>`    | n/i  | Execute selected command/item   |
| `<C-j>`   | n/i  | Move selection down             |
| `<C-k>`   | n/i  | Move selection up               |
| `j` / `k` | n    | Move selection down/up          |
| `<Tab>`   | n/i  | Toggle multi-select mark        |
| `<C-l>`   | n/i  | Focus output panel              |
| `<C-h>`   | n/i  | Return focus to input           |
| `<Esc>`   | n/i  | Cancel sub-selection / close UI |
| `q`       | n    | Same as `<Esc>`                 |
| Type text | i    | Filter commands/items           |

### Multi-Select

When a command supports multi-select (e.g., Add/Remove projects from solution):

1. Use `<Tab>` to mark items (✓ appears)
2. Title shows count: `"Remove Project (2 selected)"`
3. Press `<CR>` to confirm — all marked items are processed

![dotnet-cli.nvim multi-select](docs/images/multi-select.png)

## Manager Commands

| Command           | Description                               |
| ----------------- | ----------------------------------------- |
| **Build**         | Build with Debug/Release configuration    |
| **Run**           | Run a project                             |
| **Test**          | Run tests with minimal verbosity          |
| **Watch**         | Hot-reload with `dotnet watch run/test`   |
| **Restore**       | Restore NuGet packages                    |
| **Clean**         | Clean build artifacts                     |
| **Publish**       | Publish for deployment                    |
| **Format**        | Run `dotnet format`                       |
| **New Project**   | Scaffold from installed templates         |
| **Solution**      | List/Add/Remove projects, Create solution |
| **NuGet Sources** | List/Add/Remove/Enable/Disable sources    |
| **Add Package**   | Add a NuGet package to a project          |
| **Global JSON**   | Pin SDK version                           |
| **List SDKs**     | Show installed SDK versions               |
| **List Runtimes** | Show installed runtimes                   |

## Health Check

Run `:checkhealth dotnet-cli` to verify your environment:

```
dotnet-cli.nvim
- OK dotnet CLI found: 9.0.100
- OK 3 SDK(s) installed
-   6.0.400 [/usr/share/dotnet/sdk]
-   8.0.100 [/usr/share/dotnet/sdk]
-   9.0.100 [/usr/share/dotnet/sdk]
- OK 5 runtime(s) installed
- OK global.json pins SDK 9.0.100
- OK nvim-web-devicons available (file icons)
```

## Architecture

```
lua/dotnet-cli/
├── init.lua            -- Public API & setup()
├── config.lua          -- Default config & user options
├── ui.lua              -- Two-panel picker UI
├── job.lua             -- Async job runner
├── project.lua         -- Project/solution file discovery
├── parsers.lua         -- Output parsers (templates, sources, etc.)
├── sdk.lua             -- SDK detection & caching
├── health.lua          -- :checkhealth integration
├── commands/
│   ├── init.lua        -- Command registry
│   ├── build.lua       -- Build command
│   ├── run.lua         -- Run command
│   ├── test.lua        -- Test command
│   ├── watch.lua       -- Watch (hot reload)
│   ├── restore.lua     -- Restore packages
│   ├── clean.lua       -- Clean artifacts
│   ├── publish.lua     -- Publish & profile template
│   ├── format.lua      -- Code formatting
│   ├── new.lua         -- New project scaffolding
│   ├── solution.lua    -- Solution management
│   ├── nuget.lua       -- NuGet source management
│   ├── add_package.lua -- Add NuGet package
│   └── sdk.lua         -- SDK listing & global.json
└── template/
    └── dotnet.csproj   -- Publish profile template
```

## Testing

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim):

```bash
# Run all tests
make test

# Lua syntax check
make lint

# Format with StyLua
make format

# Check formatting
make check
```

## Output Highlighting

The output panel automatically highlights lines matching common patterns:

| Pattern           | Highlight        |
| ----------------- | ---------------- |
| `$ command`       | Comment (dimmed) |
| `✓` (success)     | DiagnosticOk     |
| `✗` (failure)     | DiagnosticError  |
| `Build succeeded` | DiagnosticOk     |
| `Build FAILED`    | DiagnosticError  |
| `Warning`         | DiagnosticWarn   |
| `Error`           | DiagnosticError  |
| `Restored`        | DiagnosticOk     |
| `Passed!`         | DiagnosticOk     |
| `Failed!`         | DiagnosticError  |

## API

The plugin exposes submodules for programmatic use:

```lua
local dotnet = require("dotnet-cli")

-- Open the manager UI
dotnet.open()

-- Access submodules
dotnet.project.get_csproj_files()  -- string[]
dotnet.project.get_sln_files()     -- string[]
dotnet.sdk.get_major()             -- number?
dotnet.sdk.get_version()           -- string?
dotnet.sdk.is_available()          -- boolean
dotnet.parsers.templates(lines)    -- {name, short_name}[]
dotnet.parsers.sln_projects(lines) -- string[]
dotnet.parsers.nuget_sources(lines)-- {name, url, enabled}[]
dotnet.job.run(cmd, ctx, on_complete?)  -- run async with UI ctx
dotnet.job.run_sync(cmd)                -- string[], boolean
```

## License

MIT

## Notice

This plugin primarily wraps the dotnet CLI, allowing lazy developers like myself
to avoid manually typing commands. However, its functionality is not yet
complete. While it's sufficient for my daily dotnet development, this plugin is
suitable for those familiar with the dotnet CLI.

## Acknowledgments

- Built for use with [NvChad](https://github.com/NvChad/NvChad)
- Inspired by
  [omnisharp-extended-lsp.nvim](https://github.com/Hoffs/omnisharp-extended-lsp.nvim)
  and [roslyn.nvim](https://github.com/seblj/roslyn.nvim)
