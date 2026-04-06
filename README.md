# pob-head-less-runtime

`pob-head-less-runtime` is a headless automation and integration layer for Path of Building. It exposes PoB runtime capabilities through a scriptable API so external tools can load builds, inspect stats, simulate changes, compare results, and run repeatable workflows without a GUI.

## Requirements

This project is designed to run inside a PoB-compatible Lua runtime and depends on the upstream Path of Building codebase.

Required environment:

- `Path of Building` source/runtime available in the expected repository layout
- `LuaJIT` runtime
- `LuaJIT FFI` support
- Python 3 if you want to run the test runners

Practical notes:

- PoB share-code compression/decompression uses `LuaJIT FFI`
- GUI-only features are stubbed or reported as unavailable in headless mode
- The bridge expects to be launched from within the PoB project layout, not as a standalone pure-Lua package

## Entry Points

The main entry point is:

- [`headless_bridge.lua`](headless_bridge.lua)
- [`json_worker.lua`](json_worker.lua)

`headless_bridge.lua` bootstraps the Lua search path, prepares the runtime, launches PoB in headless mode, and publishes the session API for legacy script-driven workflows.

`json_worker.lua` is the formal machine-facing entry point for stable automation. It accepts one JSON request on `stdin`, writes one JSON response on `stdout`, and exits.

## What This Project Is

This is not a rewrite of the PoB calculator. It is an integration layer that keeps upstream PoB behavior intact while making it callable from scripts and automation.

The architecture follows a three-layer model:

- `repo` for direct access to PoB runtime objects
- `service` for business logic and orchestration
- `api` for the public surface exposed to callers

## Key Features

- Load builds from XML text or PoB share code
- Query summaries and selected stats
- Compare candidate items against the current build
- Simulate passive tree deltas and mastery changes
- Inspect runtime state in headless mode

## Quick Start

If you want to integrate the bridge into another tool, use `json_worker.lua`.

`headless_bridge.lua` remains available for legacy script-driven workflows through `POB_HEADLESS_SCRIPT`, but it is no longer the preferred external integration path.

If you want a formal machine-facing transport, launch `json_worker.lua` and send one JSON request through `stdin`. The worker returns one JSON response through `stdout` and then exits.

## Public API Overview

The exported API is centered around a session object created at startup.

### Stable API v1

- `load_build_xml`
- `load_build_code`
- `get_summary`
- `get_stats(fields)`
- `compare_item_stats`
- `simulate_node_delta`
- `get_runtime_status`
- `health`

`Stable API v1` is the only contract intended for external automation and future transports.

### JSON Transport

The minimal formal transport is `JSON over stdin/stdout`:

- one request
- one response
- process exit

Request shape:

```json
{"id":"1","method":"health","params":{}}
```

Response shape:

```json
{"id":"1","ok":true,"result":{"mainReady":true}}
```

For stateless use, non-load methods may accept preload fields inside `params`:

- `build_xml`
- `build_code`
- `build_name`

Example:

```json
{"id":"2","method":"get_summary","params":{"build_xml":"<PathOfBuilding>...</PathOfBuilding>"}}
```

### Experimental API

The implementation still exposes additional methods for refactoring and local automation, but they are not part of the stable contract and may change without compatibility guarantees. This includes:

- file save/load helpers
- importer update helpers
- skill selection APIs
- config mutation APIs
- tooltip/equip/simulate-mod item helpers
- `get_tree`
- snapshot/restore/search helpers

If a service is unavailable, the API returns a clear error instead of silently degrading. Callers can inspect the declared API tiers through `get_api_surface()`.

## Typical Use Cases

### Build analysis

Load a build, inspect summary stats, and compare before/after changes.

### Stable item evaluation

Parse an item, test it against the current build, and review the resulting stat delta before equipping it.

### Stable passive tree simulation

Snapshot the current tree, simulate node changes, and restore the previous state after inspection.

## Testing Strategy

The project uses both smoke tests and unit tests to protect the API surface and runtime behavior.

Smoke tests are split into two suites:

- `stable` for the supported contract surface
- `experimental` for opt-in behavior that depends more heavily on PoB internals

Unit tests focus on:

- API exposure
- repo/service boundaries
- runtime session behavior
- import orchestration
- tree delta modeling
- simulation restore behavior

## Repository Layout

- `headless_bridge.lua` - runtime bootstrap and session startup
- `json_worker.lua` - formal JSON stdin/stdout worker entry point
- `src` - implementation code
- `tests` - smoke tests and unit tests
- `tips` - notes and design drafts

## Status

This repository is oriented around experimentation, automation, and refactoring of PoB headless workflows. The safest way to understand behavior is to inspect the tests and the service layer together.

## License

Add the project license here if it is not already defined at the repository root.
