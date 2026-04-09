# Architecture

## Intent

`pob-headless-runtime` is a thin integration layer around upstream Path of Building. Project-owned code should stay as a boundary around PoB internals, not a fork of PoB itself.

## Entry Points

- `json_worker.lua`: formal machine-facing JSON worker
- `headless_bridge.lua`: legacy script-facing compatibility entry point

## Repository Shape

Top-level directories:

- `contracts/`: machine-readable API contract and examples
- `docs/`: project-owned architecture notes
- `scripts/`: local contributor scripts
- `src/`: runtime implementation
- `tests/`: unit, smoke, fixtures, and transport tests

Current `src/api/` feature layout:

- `build/`
- `config/`
- `import/`
- `items/`
- `skills/`
- `stats/`
- `tree/`
- `runtime/`: shared runtime gateway
- `shared/`: cross-feature helpers
- `wiring.lua`: dependency assembly

## Feature Pattern

Feature modules follow this shape:

- `api.lua`: thin public entry layer
- `orchestrator.lua`: flow control, runtime guarantees, snapshot and restore, cross-feature coordination
- `pob.lua`: direct PoB object access
- `helpers/`: pure helpers without session orchestration

## Runtime Layers

- `src/runtime/session.lua`: owns the live PoB session, frame loop, settle loop, adapters, services, and session API
- `src/api/runtime/repo.lua`: shared runtime-side adapter for build readiness and recalculation helpers
- `src/transport/json_stdio/`: request validation, stable dispatch, response envelopes, and error mapping

## Boundary Rules

- keep direct PoB object access inside `pob.lua` adapters or shared runtime adapters
- keep stable worker dispatch limited to the stable contract
- treat `contracts/stable_api_v1.json` as the machine-readable stable API source of truth
- keep contributor workflow and validation rules in `CONTRIBUTING.md`
- keep compatibility and release rules in `VERSIONING.md`
