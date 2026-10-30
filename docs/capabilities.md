# .NET capability guide

This plugin targets local SDK-style C# projects. It delegates language intelligence to Neovim LSP/Roslyn and debugging to nvim-dap plus netcoredbg. Features that depend on an SDK tool, extension, or package report that dependency at use time.

| Workflow | Support | Provider or limit |
| --- | --- | --- |
| Console, library, ASP.NET Core project creation/build/run | Native manager actions | Installed .NET SDK; libraries are built but cannot be launched directly. |
| `.csproj`, `.sln`, `.slnx` discovery | Native | Project selection is per workspace root. |
| Startup selection and restart persistence | Native | Reuse valid selections or choose one runnable non-test project. Ambiguity prompts; missing selections stop launch. |
| Command input and completion | Native manager page | SDK suggestions, project paths, quoted arguments, and explicit execution without a shell. |
| Build configuration, target framework, Project launch profile | Native | Output path comes from MSBuild evaluation. IIS Express profiles are omitted. |
| C# completion, rename, code actions, navigation | Editor integration | Configure Roslyn LSP in Neovim. |
| Local CoreCLR launch and attach | Optional | nvim-dap and netcoredbg; breakpoints/stack/step/watch use nvim-dap and its UI. |
| VSTest and Microsoft.Testing.Platform | Native commands | MTP needs a compatible SDK and extension options advertised by `dotnet test --help`. |
| Coverage | Optional | VSTest needs XPlat Code Coverage collector; MTP needs its coverage extension. |
| NuGet packages, central versions, lockfiles | Native commands and file editing | `Directory.Packages.props` is opened for editing; NuGet manages package mutations and restore. |
| EF Core migrations and local database update | Optional | `dotnet-ef` global or local tool and project EF packages. |
| User secrets and HTTPS development certificate | Native CLI actions | Secret values are entered through a secret prompt. |
| Counters, trace, dump | Optional | Matching global or local dotnet diagnostic tools. Artifacts are local. |
| Pack and local publish | Native | Profile, runtime ID, self-contained, single-file, and output options are available. |
| Legacy .NET Framework, VS designers, cloud/remote services | Outside scope | No claim of Visual Studio feature parity for these workflows. |

## Platform validation

Run `just all` for hermetic behavior checks.
Run `just test-integration` for native SDK, process, and restart checks.
Run `just test-debug` for build, launch, breakpoint, attach, pause, and disconnect checks.
These entry points run on Windows and Linux with isolated state and generated fixtures.
The Linux integration fixture was built with .NET SDK 10.0.112.
The debug fixture requires the .NET 10 SDK and netcoredbg 3.2.0-1092 or newer.
Run `:checkhealth dotnet-cli` to inspect optional tools.
