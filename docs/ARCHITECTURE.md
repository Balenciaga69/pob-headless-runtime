# Architecture

## Intent

`pob-headless-runtime` is a thin integration layer around upstream PoB.

- `json_worker.lua` is the formal machine-facing entry point
- `headless_bridge.lua` is the legacy script-driven compatibility entry point
- upstream PoB state remains inside the runtime session

## Rough File Structure

```text
custom/pob-headless-runtime/
|-- json_worker.lua
|-- headless_bridge.lua
|-- contracts/
|   |-- stable_api_v1.json
|   `-- examples/
|-- docs/
|   |-- ARCHITECTURE.md
|   `-- FLOWS.md
|-- src/
|   |-- api/
|   |   |-- init.lua
|   |   |-- runtime.lua
|   |   |-- build.lua / stats.lua / items.lua / config.lua / skills.lua / tree.lua
|   |   |-- repo/
|   |   |   |-- build_runtime.lua
|   |   |   |-- pob_*_adapter.lua
|   |   |   `-- *.lua
|   |   `-- service/
|   |       `-- *.lua
|   |-- entry/
|   |-- runtime/
|   |   `-- session.lua
|   |-- transport/
|   |   |-- json_stdio.lua
|   |   `-- error.lua
|   `-- util/
`-- tests/
    |-- smoke/
    |-- unit/
    `-- helpers/
```

## Layer Responsibilities

### Entry

- `json_worker.lua`
  - bootstraps package path
  - prepares environment
  - creates session
  - executes one request
  - emits one JSON response
- `headless_bridge.lua`
  - bootstraps environment for legacy helper scripts
  - installs global compatibility helpers

### Runtime

- `src/runtime/session.lua`
  - owns the live PoB session
  - runs frame/settle loops
  - exposes repos, services, and session API

### API

- `src/api/init.lua`
  - binds service methods onto the public API
  - top-level exports are stable
  - `api.experimental.*` holds non-stable helpers
- `src/api/runtime.lua`
  - publishes runtime status and API surface metadata

### Service

- orchestrates business behavior
- combines repo calls into stable operations
- should not know raw PoB tab/control names when avoidable

### Repo

- lowest project-owned layer above upstream PoB object graph
- adapter files (`pob_*_adapter.lua`) are the approved place for direct `build.*Tab` access
- non-adapter repo files should delegate internal graph access to adapters

### Transport

- `json_stdio.lua`
  - request decode
  - stable method dispatch
  - response/meta envelope
- `error.lua`
  - transport error code mapping
  - retryability policy
  - structured details for selected failures

## Public Surface Model

### Stable

- lives at `session.api.<method>`
- accepted by `json_worker.lua`

### Experimental

- lives at `session.api.experimental.<method>`
- not accepted by `json_worker.lua`
- flattened onto `PoBHeadless.<method>` for legacy compatibility only

## Design Rules

- stable root surface must stay small
- worker transport may only dispatch stable methods
- adapter layer owns direct PoB tab/control access
- legacy compatibility may stay broad, but should not redefine the stable worker contract
