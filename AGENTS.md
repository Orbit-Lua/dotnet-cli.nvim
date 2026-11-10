# AGENTS Instructions

## Ownership

This plugin runs local SDK-style .NET workflows in Neovim. Keep .NET behavior here and reusable palette behavior in comet.nvim.

| Change | Owner |
| --- | --- |
| `setup()`, public exports | `lua/dotnet-cli/init.lua` |
| `Dotnet*` user commands | `lua/dotnet-cli/commands/register.lua` |
| Manager actions | `lua/dotnet-cli/commands/` |
| Option defaults, shape and validation | `lua/dotnet-cli/config.lua` |
| Process execution, stdin, cancellation, sync queries | `lua/dotnet-cli/job.lua` |
| `.csproj`, `.sln`, `.slnx` discovery and selectors | `lua/dotnet-cli/project.lua` |
| Selected root, project, solution, configuration, framework, profile | `lua/dotnet-cli/workspace.lua`, saved by `lua/dotnet-cli/state.lua` |
| Startup project resolution for a launch | `lua/dotnet-cli/startup.lua` |
| Evaluated output metadata, launch profiles | `lua/dotnet-cli/msbuild.lua`, `lua/dotnet-cli/launch.lua` |
| nvim-dap registration, adapter, launch configuration, launch notification | `lua/dotnet-cli/dap/` |
| Manager command line: parsing, completion, execution | `lua/dotnet-cli/command_line/` |
| CLI output parsing, SDK queries, `global.json` pin | `lua/dotnet-cli/parsers.lua`, `lua/dotnet-cli/sdk.lua` |
| Health checks | `lua/dotnet-cli/health.lua` |

## Change contracts

- Run processes through `job.lua` or `commands/common.lua`.
- Pass each command as an argument array. Never pass a command string through `'shell'`.
- Keep manager actions as focused command specs. Do not duplicate Neovim job handling in action modules.
- Use the asynchronous discovery functions of `project.lua` for pickers.
  - Show a scanning state at once, then update the active page.
  - Skip generated directories.
  - Do not let a late result overwrite another view.
- Store project selection through `workspace.lua`.
- Query launch targets with `msbuild.lua`. Do not guess `bin` paths or parse project XML for evaluated output.
- Read launch profiles through `launch.lua`.
- Put CLI output interpretation in pure `parsers.lua` functions.
- Keep VSTest and Microsoft.Testing.Platform command options distinct.
- Register the job and the Comet terminal of each interactive task, so that input and cancellation work.
- Never print user-secret values into task output or persistent buffers.
- Report each DAP launch message through `dap/status.lua`. Do not call `vim.notify` for launch phases elsewhere.
- Give each new option a default and a shape entry in `config.lua`. `setup()` rejects keys that the shape does not list.
- Keep `require("dotnet-cli")` exports and `Dotnet*` commands unless the task changes the public API.
- Update `README.md` when commands, options, dependencies, manager behavior, health checks or publish-profile behavior change.
- Edit `lua/dotnet-cli/template/dotnet.csproj` only for a publish-profile task.
- Follow `.stylua.toml` for Lua files.
- Write modules as a local `M = {}` with `return M`.
- Give public functions LuaDoc types. Declare a class for each known table shape.

## Git

- Write commits in [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) format.
- Start the type, the scope and the description in lowercase. Keep the case of code identifiers and proper nouns.
- For a non-trivial change, write a commit body that explains why.
- Mark a breaking change with `!` and a `BREAKING CHANGE:` footer.
- Author commits as the user alone. Add no agent trailers or links, such as `Co-Authored-By` or a session URL.
- Commit as the plan progresses.
- Before you push, squash related commits into one commit to keep the history clean.
- Push only after the user approves that push.

## Releases

- Version releases with [Semantic Versioning 2.0.0](https://semver.org/).
- Name each release tag with the bare version, such as `1.2.3`. If the repo already uses a tag prefix, such as `v`, keep it.
- When you create a changelog, use [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) format. Keep the format of an existing changelog.
- Release in this order:
  1. Update the version files and the changelog in one commit, such as `chore(release): prepare 1.2.3`.
  2. Push the commit to the default branch.
  3. Wait until the branch pipeline of that commit passes.
  4. Tag that commit with an annotated tag: `git tag -a 1.2.3 -m "Release 1.2.3" <commit>`. Tag a release candidate as `1.2.3-rc.1`.
  5. Push the tag alone: `git push origin 1.2.3`. The tag pipeline publishes the package and creates the release.
- Push the commit and the tag in separate pushes. Do not use `git push --follow-tags`. One push starts two overlapping pipelines, and a single runner queues the tag pipeline.

## Tests

- Add a test to the repo only when it guards behavior that no existing test covers.
- The test must fail when that behavior breaks. Weigh this before you add each test.
- Run throwaway tests freely to check your work.
- Keep throwaway tests out of the repo unless they meet the bar above.
- Run the checks from the repository root:

  ```sh
  just all
  just test-integration
  just test-debug
  ```

- `just all` checks formatting, runs Luacheck and runs the specs in `tests/dotnet-cli/`.
- `just test-integration` runs the specs that start real processes.
- `just test-debug` builds a .NET 10 fixture and debugs it with netcoredbg.
- Run one spec with `just test-spec tests/dotnet-cli/<name>_spec.lua`.
- `make all` rewrites formatting before it runs the same checks.
- `tests/run.lua` runs each spec in its own Neovim process and reports through telemetry.lua.
- Each spec child checks its own result. A failed or skipped test, a spec with no tests, or an editor error fails it.
- Load test dependencies from `$DOTNET_TEST_PLUGINS`, or else from the lazy.nvim data directory.
  - The dependencies are plenary.nvim, comet.nvim, nvim-dap and telemetry.lua.
  - `DOTNET_TEST_COMET` and `DOTNET_TEST_TELEMETRY` select local checkouts.
  - `DOTNET_TEST_ADAPTER` selects the netcoredbg executable of `just test-debug`.
- A missing dependency fails the run. Report each check that you could not run.
- Use temporary project directories for discovery tests. Restore the working directory before the test ends.
- In a spec that replaces `vim.notify`, ignore INFO messages. They are launch progress.

## CI

- Keep a CI check only when it catches a concrete failure that no existing check covers.
- Identify that failure before you add or keep the check.
- Apply the test rules to CI checks too.
- Run the repo's entry points against real inputs or isolated fixtures.
- Reject duplicate checks, source-text assertions, copied inventories and checks that only prove that a command or file exists.
- Name each workflow, job and step by its target and its action.
- Propagate command failures.
- Count a missing prerequisite or skipped required coverage as a failure.
- Run the checks in branch pipelines only. A tag pipeline builds, smoke-tests and publishes the package, and then creates the release.
- Start each release job with a check that the tagged commit is on the default branch.
- Match release jobs to the tag format of the version, such as `/^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$/`.
- Protect the release tags. Only protected refs can read the release credentials.
- A tag pipeline uses the CI config of the tagged commit. Merge a CI change to the default branch before you tag.
- After you change these rules, audit the repo against them.
- Validate changes locally. Then verify the required CI on the pushed commit.
- Report each uncovered contract and each unavailable check.
- Run the checks in a workflow on `pull_request` and on `push` to branches.
- Run the release in a separate workflow on `push` of tags that match `[0-9]+.[0-9]+.[0-9]+`. GitHub tag filters are globs, such as `[0-9]+.[0-9]+.[0-9]+` and `[0-9]+.[0-9]+.[0-9]+-*`.
- Check out release jobs with `fetch-depth: 0`, so that the ancestry check sees the default branch.
- Keep release secrets in an environment that allows only the release tags. Protect the tags with a tag ruleset.
- CI runs on Linux only. Run `just all`, `just test-integration` and `just test-debug` on Windows before each push.
- Pin each CI test plugin to the commit in the OrbitVim lock file.

## Docs

- Keep each doc concise and plain. Each sentence must carry information.
- Write only standing rules in `AGENTS.md`. A standing rule changes how an agent does later, unrelated tasks.
- Record a fact about one place or one failure at its source: a code comment, a test, a commit body, an ADR or an issue.
- Write English docs in US English, to the [ASD-STE100](https://www.asd-ste100.org/) writing rules:
  - Give one instruction in each sentence.
  - Write instructions in the imperative and in the active voice.
  - Use one word for one meaning, and one meaning for one word.
  - An instruction has 20 words or fewer. A description has 25 words or fewer.
- Review each sentence over these limits. Split it if it holds more than one instruction or fact.
- Use a numbered list for three or more instructions in a fixed order, also across sentences.
- Write a set of full-sentence items, or of more than five items, as a bullet list. Otherwise, the set can stay in one sentence, even when the sentence is over the limits.
- Write a non-English doc in two passes:
  1. Write an English draft to these rules.
  2. Translate the draft:
     1. Keep its sentence boundaries and one term for each concept.
     2. Keep commands, paths and code unchanged.
     3. Use the natural word order of the target language.
- Read `docs/capabilities.md` before you change a provider, a support limit or the validated platforms.
