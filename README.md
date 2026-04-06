# Path of Building Headless

`Path of Building Headless` is a headless automation and integration layer for Path of Building. It exposes PoB runtime capabilities through a scriptable API so external tools can load builds, inspect stats, simulate changes, compare results, and run repeatable workflows without a GUI.

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

- Load builds from file, XML, PoB share code, or raw payloads
- Save builds back to XML, share code, or disk
- Query summaries and selected stats
- Inspect and switch skills
- Update supported configuration fields
- Parse, test, compare, simulate, and equip items
- Snapshot and restore passive trees
- Simulate passive tree deltas and mastery changes
- Update imported builds from local payloads or remote character data
- Inspect runtime state and stub capabilities in headless mode

## Quick Start

If you want to run the sample bridge locally, use the helper script:

```powershell
python .\run_headless.py
```

If you want to integrate the bridge into another tool, launch `headless_bridge.lua` directly from the PoB environment and pass your own script through the `POB_HEADLESS_SCRIPT` environment variable.

## Public API Overview

The exported API is centered around a session object created at startup. Common operations include:

- `load_build_file`
- `load_build_xml`
- `load_build_code`
- `save_build_xml`
- `save_build_code`
- `get_summary`
- `get_tree`
- `search_tree_nodes`
- `parse_item`
- `test_item`
- `compare_item_stats`
- `simulate_node_delta`
- `update_imported_build`

If a service is unavailable, the API returns a clear error instead of silently degrading.

## Typical Use Cases

### Build analysis

Load a build, inspect summary stats, and compare before/after changes.

### Item evaluation

Parse an item, test it against the current build, and review the resulting stat delta before equipping it.

### Passive tree simulation

Snapshot the current tree, simulate node changes, and restore the previous state after inspection.

### Import automation

Update a build from offline payloads or remote character data while preserving skill selection and runtime consistency.

## Testing Strategy

The project uses both smoke tests and unit tests to protect the API surface and runtime behavior.

Smoke tests focus on end-to-end workflows such as:

- API contract coverage
- item comparison and tooltip rendering
- passive tree simulation
- config comparison
- importer updates
- skill selection restore behavior

Unit tests focus on:

- API exposure
- repo/service boundaries
- runtime session behavior
- import orchestration
- tree delta modeling
- simulation restore behavior

## Repository Layout

- `headless_bridge.lua` - runtime bootstrap and session startup
- `run_headless.py` - convenience launcher for local smoke runs
- `src` - implementation code
- `tests` - smoke tests and unit tests
- `markdown` - documentation and design notes

## Status

This repository is oriented around experimentation, automation, and refactoring of PoB headless workflows. The safest way to understand behavior is to inspect the tests and the service layer together.

## License

Add the project license here if it is not already defined at the repository root.
