# Contributing

## Goal

The contributor workflow for this repository should be:

```text
clone host repo
clone this repo into the host repo
run bootstrap
open VS Code
run validation
start contributing
```

## First-Time Setup

Finish the Quick Start in [README.md](./README.md) before using the development workflow here.

Prerequisites:

- `git`
- `python`
- `luajit`

## Tooling Rules

This repository standardizes on:

- Runtime: `LuaJIT`
- Formatter: `StyLua`
- Linter: `Luacheck`
- Editor / language server: `Lua Language Server`
- Test runners: project-owned Python wrappers plus Lua test helpers

Rules:

- `StyLua` is the only formatter for Lua code.
- `Luacheck` is the linter of record.
- LuaLS formatting stays disabled to avoid formatter conflicts.
- Repo-owned config files under the root and `.vscode/` are part of the project contract.

## Validation Commands

Format:

```powershell
.\scripts\fmt.ps1
.\scripts\fmt.ps1 -Check
```

Lint:

```powershell
.\scripts\lint.ps1
```

Stable validation:

```powershell
.\scripts\test.ps1
python .\tests\run_transport_smoke.py
```

Extended validation when compatibility-only helpers are affected:

```powershell
.\scripts\test.ps1 -Experimental
```

## Pull Request Expectations

Before opening a pull request:

1. Run formatting.
2. Run lint.
3. Run the stable validation flow.
4. Run the experimental suite if your change touches experimental behavior.
5. Verify the change inside a compatible PoB host layout.

There is no active GitHub Actions workflow at the moment. Local validation is the source of truth.

## Architecture Rules

Architecture and module boundaries are defined in [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

Contributor rule:

- follow the current `api.lua` / `orchestrator.lua` / `pob.lua` / `helpers/` feature pattern
- keep direct PoB object access inside `pob.lua` adapters or shared runtime adapters
- do not re-introduce `repo.lua`, `service.lua`, or `pob_adapter.lua` inside `src/api/<feature>/`

## Stable API Change Checklist

If you change stable API behavior, follow [VERSIONING.md](./VERSIONING.md) and update:

1. `contracts/stable_api_v1.json`
2. transport coverage
3. release notes in `CHANGELOG.md`
4. `README.md` if the public summary, compatibility note, or document map changed
5. `VERSIONING.md` if the release classification or compatibility policy changed

## Troubleshooting

### `bootstrap.ps1` cannot find `luajit`

Install LuaJIT first and make sure `luajit` is in `PATH`.

### `Lua Language Server` was installed but the shell still cannot find it

Re-open the terminal or VS Code window. `winget` updates the user path, but the current shell may not see it immediately.

### Tests fail with missing `Launch.lua` or missing runtime modules

Your checkout layout is wrong. Move this repository so that it sits inside a compatible PoB host repository.

### Luacheck or StyLua is missing

Run `.\scripts\bootstrap.ps1` again. The local tools live under `.tools/` and are intentionally not committed.

### Persistent worker clients still show old Lua behavior

Restart the app or worker process after Lua runtime changes.

## Notes for Maintainers

If the validated host repository or release changes:

1. update [README.md](./README.md)
2. rerun the full validation flow

If architecture rules change:

1. update [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)
2. update this file only if the contributor workflow changes
