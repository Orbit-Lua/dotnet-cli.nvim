# .NET capability guide

This plugin targets local SDK-style C# projects. It delegates language intelligence to Neovim LSP/Roslyn and debugging to nvim-dap plus netcoredbg. Features that depend on an SDK tool, extension, or package report that dependency at use time.

| Workflow | Support | Provider or limit |
| --- | --- | --- |
| Console, library, ASP.NET Core project creation/build/run | Native manager actions | Installed .NET SDK; libraries are built but cannot be launched directly. |
| `.csproj`, `.sln`, `.slnx` discovery | Native | Project selection is per workspace root. |
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

The automated suite exercises command generation, workspace isolation, MSBuild metadata parsing, launch profiles, task handling, DAP registration, and Comet state. The local integration fixture was built on Linux using .NET SDK 10.0.112. Other operating systems and SDK versions require their own validation. Optional tools are checked with `:checkhealth dotnet-cli`.
