# pob-headless-runtime

`pob-headless-runtime` is a headless automation layer for Path of Building. It exposes PoB runtime behavior through a scriptable API so external tools can load builds, inspect stats, simulate changes, compare results, and run repeatable workflows without the GUI.

This repository is not a standalone PoB fork. It is meant to live inside a compatible Path of Building repository layout.

## What You Need

To work on this project locally you need:

- Windows
- `git`
- `Python 3.11+`
- `LuaJIT`
- a compatible Path of Building host repository checked out as the parent folder

Expected layout:

```text
PathOfBuilding-Headless/
├─ src/
├─ runtime/
└─ pob-headless-runtime/
```

The current compatible host repository used for local smoke and runtime testing is:

- `https://github.com/Balenciaga69/PathOfBuilding-Headless.git`
- branch `Headless0000`

If you use a different PoB fork or branch, editor support may still work, but smoke and runtime tests can fail if the upstream object model differs.

## Quick Start

### 1. Clone the compatible host repository

```powershell
git clone --branch Headless0000 https://github.com/Balenciaga69/PathOfBuilding-Headless.git
cd PathOfBuilding-Headless
```

### 2. Clone this repository into the host repository

```powershell
git clone https://github.com/Balenciaga69/pob-headless-runtime.git
cd pob-headless-runtime
```

### 3. Bootstrap the local development environment

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1
```

The bootstrap script installs:

- repo-local `StyLua`
- repo-local `LuaRocks`
- repo-local `Luacheck`
- `Lua Language Server` through `winget` when available
- recommended VS Code extensions when the `code` CLI is available

## Daily Workflow

Typical contributor flow:

1. Run `scripts/bootstrap.ps1` once after cloning.
2. Open the repository in VS Code.
3. Edit Lua files with format-on-save enabled.
4. Run lint and tests before opening a pull request.
5. Keep the host layout intact so runtime tests can resolve upstream files.

Common commands:

```powershell
.\scripts\fmt.ps1
.\scripts\fmt.ps1 -Check
.\scripts\lint.ps1
.\scripts\test.ps1
.\scripts\test.ps1 -Experimental
```

## Tooling Standard

This repository standardizes on:

- Runtime: `LuaJIT`
- Formatter: `StyLua`
- Linter: `Luacheck`
- IDE / LSP: `Lua Language Server`
- Test runners: the existing Python wrappers plus project-owned Lua test helpers

Important rule:

- `StyLua` owns formatting.
- `Luacheck` owns linting.
- `LuaLS` owns navigation, diagnostics, and editor assistance.
- LuaLS formatting is disabled to avoid formatter conflicts.

## Repository Layout

- `headless_bridge.lua`: legacy bridge entry point
- `json_worker.lua`: machine-facing JSON stdin/stdout entry point
- `contracts/`: machine-readable API contracts and examples
- `docs/`: project documentation
- `scripts/`: local contributor scripts
- `src/`: runtime implementation
- `tests/`: unit, smoke, fixtures, and transport tests

Current `src/api/` layout:

- `build/`, `config/`, `import/`, `items/`, `skills/`, `stats/`, `tree/`: feature modules using `api.lua`, `orchestrator.lua`, `pob.lua`, and optional `helpers/`
- `runtime/`: shared runtime gateway used by feature orchestrators and services
- `shared/`: cross-feature utilities that do not belong to a single feature
- `wiring.lua`: dependency assembly for repos and services/orchestrators

Feature responsibility rules:

- `api.lua`: thin entry layer for the feature
- `orchestrator.lua`: flow control, runtime guarantees, snapshot/restore, and cross-feature coordination
- `pob.lua`: direct PoB object access only
- `helpers/`: pure helpers with no session orchestration

## Testing

The current test setup already exists and is part of the project design:

- `tests/run_unit.py` runs isolated Lua unit specs
- `tests/run_smoke.py --suite stable` runs the supported runtime smoke suite
- `tests/run_transport_smoke.py` validates the JSON worker contract

This is why the repository does not currently require `busted` for normal contributor setup. The project already owns a compatible test flow around `luajit` and Python wrappers.

## Feasibility Notes

The proposed SOP is feasible, but two details matter in practice:

1. This repository is not standalone.
   You must document and automate the required host PoB layout. Without that, bootstrap can install tools but tests still cannot run.

2. Windows tooling needs version pinning and fallbacks.
   A naive "install LuaRocks and run `luarocks install luacheck`" flow is fragile on Windows. This repository now uses a repo-local LuaRocks environment with pinned helper repositories so that first-time contributors are less likely to get blocked.

3. There is no GitHub Actions CI at the moment.
   Validation is meant to run locally through the provided scripts until a lightweight, maintainable workflow is added.

## Public API Overview

Stable API v1 methods:

- `load_build_xml`
- `load_build_code`
- `get_summary`
- `get_stats(fields)`
- `compare_item_stats`
- `simulate_node_delta`
- `get_runtime_status`
- `health`

Stable methods live under:

- `session.api.<method>`

Experimental methods live under:

- `session.api.experimental.<method>`

Legacy compatibility keeps flattened experimental methods only on:

- `PoBHeadless.<method>`

## JSON Worker Example

Request:

```json
{ "id": "1", "method": "health", "params": {} }
```

Successful response:

```json
{
  "id": "1",
  "ok": true,
  "result": { "mainReady": true },
  "meta": {
    "request_id": "1",
    "api_version": "v1",
    "engine_version": "2.63.0",
    "duration_ms": 42
  }
}
```

## Contributor Guide

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full development SOP, troubleshooting notes, and pull request expectations.
