# Contributing

## Goal

The contributor experience for this repository should be:

```text
clone host repo
clone this repo into the host repo
run bootstrap
open VS Code
start contributing
```

This document explains the exact workflow and the constraints behind it.

## Development Baseline

This repository standardizes on the following toolchain:

- Runtime: `LuaJIT`
- Formatter: `StyLua`
- Linter: `Luacheck`
- Editor / language server: `Lua Language Server`
- Test runners: project-owned Python wrappers plus Lua test helpers

Why this baseline exists:

- the runtime code expects LuaJIT behavior and FFI support
- formatter, linter, and language server responsibilities are separated cleanly
- repo-owned configuration avoids per-user editor drift
- repo-local tools reduce Windows setup friction for first-time contributors

## Required Repository Layout

This repository expects a compatible Path of Building host repository as its parent directory.

Expected layout:

```text
PathOfBuilding-Headless/
├─ src/
├─ runtime/
└─ pob-headless-runtime/
```

This requirement is not optional for runtime tests. The code resolves `../src/Launch.lua` and `../runtime/lua` through the host repository.

If you only clone `pob-headless-runtime` by itself, editor features can still work, but smoke tests and runtime entry points will not.

## First-Time Setup

### 1. Install prerequisites

Make sure these commands are available:

- `git`
- `python`
- `luajit`

### 2. Run bootstrap

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1
```

What bootstrap does:

- creates a repo-local `.tools/` directory
- installs a repo-local LuaRocks environment
- installs `Luacheck` into that repo-local environment
- downloads a pinned `StyLua` binary into `.tools/`
- installs `Lua Language Server` through `winget` when available
- installs recommended VS Code extensions when possible
- verifies tool versions at the end

### 3. Open VS Code

The repository includes:

- `.vscode/settings.json`
- `.vscode/extensions.json`
- `.luarc.json`
- `.stylua.toml`
- `.luacheckrc`
- `.editorconfig`

These files are part of the contract. Do not replace them with undocumented local-only conventions.

## Editor Rules

Formatting:

- `StyLua` is the only formatter for Lua code.
- format-on-save is enabled for Lua files in VS Code.
- LuaLS formatting is disabled on purpose.

Linting:

- `Luacheck` is the linter of record.
- if `Luacheck` reports a real issue, fix the code or adjust the repo config intentionally
- do not bypass lint failures with editor-only settings

Language Server:

- `Lua Language Server` is used for diagnostics, hover, jump-to-definition, and workspace indexing
- the workspace config points at both this repository and the compatible parent PoB layout

## Daily Commands

Format:

```powershell
.\scripts\fmt.ps1
```

Check formatting without editing files:

```powershell
.\scripts\fmt.ps1 -Check
```

Run lint:

```powershell
.\scripts\lint.ps1
```

Run the default test suite:

```powershell
.\scripts\test.ps1
```

Run the extended test suite:

```powershell
.\scripts\test.ps1 -Experimental
```

## Pull Request Expectations

Before opening a pull request:

1. Run formatting.
2. Run lint.
3. Run tests.
4. Make sure your change still works inside a compatible PoB host layout.

CI validates the same baseline. If CI fails because the compatible host repository changed, update the workflow or the documented host pin deliberately. Do not hand-wave that mismatch away.

## What Is Feasible and What Is Not

### Feasible

- repo-owned formatter, linter, LSP, and PowerShell scripts
- novice-friendly setup for Windows contributors
- CI enforcement of style and tests
- a predictable "fork and start working" path for contributors using AI tools

### Not Feasible Without Extra Context

- standalone runtime execution without a compatible PoB host repository
- stable smoke tests against arbitrary upstream PoB branches
- assuming global Windows package managers will install every Lua tool reliably without fallbacks

## Troubleshooting

### `bootstrap.ps1` cannot find `luajit`

Install LuaJIT first and make sure `luajit` is in `PATH`.

### `Lua Language Server` was installed but the shell still cannot find it

Re-open the terminal or VS Code window. `winget` updates the user path, but the current shell may not see it immediately.

### Tests fail with missing `Launch.lua` or missing runtime modules

Your checkout layout is wrong. Move this repository so that it sits inside a compatible PoB host repository.

### Luacheck or StyLua is missing

Run `.\scripts\bootstrap.ps1` again. The local tools live under `.tools/` and are intentionally not committed.

## Notes for Maintainers

If you change the compatible host repository or branch:

1. update the CI workflow
2. update `README.md`
3. update this file
4. verify the full test suite again
