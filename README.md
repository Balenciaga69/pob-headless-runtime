# pob-head-less-runtime

`pob-head-less-runtime` is a headless automation and integration layer for Path of Building. It exposes PoB runtime capabilities through a scriptable API so external tools can load builds, inspect stats, simulate changes, compare results, and run repeatable workflows without a GUI.

## Requirements

This project is designed to run inside a PoB-compatible Lua runtime and depends on the upstream Path of Building codebase.

Required environment:

- `Path of Building` source/runtime available in the expected repository layout
- `LuaJIT` runtime
- `LuaJIT FFI` support
- Python 3 if you want to use the helper launcher script

Practical notes:

- PoB share-code compression/decompression uses `LuaJIT FFI`
- GUI-only features are stubbed or reported as unavailable in headless mode
- The bridge expects to be launched from within the PoB project layout, not as a standalone pure-Lua package

## Entry Points

The main entry point is:

- [`headless_bridge.lua`](headless_bridge.lua)

That file bootstraps the Lua search path, prepares the runtime, launches PoB in headless mode, and publishes the session API.

The Python script is only a local convenience launcher:

- [`run_headless_demo.py`](run_headless_demo.py)

It demonstrates how to invoke the bridge against a sample build. It is not the primary project entry point.

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

If you want to run the sample bridge locally, use the helper script:

```powershell
python .\run_headless_demo.py
```

If you want to integrate the bridge into another tool, launch `headless_bridge.lua` directly from the PoB environment and pass your own script through the `POB_HEADLESS_SCRIPT` environment variable.

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
- `run_headless_demo.py` - convenience launcher for local smoke runs
- `src` - implementation code
- `tests` - smoke tests and unit tests
- `tips` - notes and design drafts

## Status

This repository is oriented around experimentation, automation, and refactoring of PoB headless workflows. The safest way to understand behavior is to inspect the tests and the service layer together.

## License

Add the project license here if it is not already defined at the repository root.
