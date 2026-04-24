# pob-headless-runtime

`pob-headless-runtime` is a headless automation layer for Path of Building. It provides a small maintained API so tools can load builds, save builds, read stats, inspect equipment, and apply config changes without the GUI.

This repository is not a standalone PoB fork. It is intended to live inside a compatible Path of Building repository checkout.

## Compatibility

Validated baseline:

- Windows
- `LuaJIT` with FFI support
- Path of Building Community `2.63.0`

Expected host layout:

```text
PathOfBuilding/
├─ src/
├─ runtime/
└─ pob-headless-runtime/
```

If you use a different PoB fork or branch, editor support may still work, but runtime behavior and tests are not guaranteed.

## Quick Start

1. Clone the compatible host repository.
2. Clone this repository into the host repository as `pob-headless-runtime`.
3. Run `powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1`.
4. Use [CONTRIBUTING.md](./CONTRIBUTING.md) for the full development and validation flow.

## Project Documents

- [CONTRIBUTING.md](./CONTRIBUTING.md): contributor setup, tooling rules, validation commands, PR expectations, troubleshooting
- [VERSIONING.md](./VERSIONING.md): compatibility policy, version bump rules, release requirements
- [CHANGELOG.md](./CHANGELOG.md): release history
- [contracts/stable_api_v1.json](./contracts/stable_api_v1.json): machine-readable stable API contract
- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md): current runtime and module boundaries

## Public Contract

The stable API contract is defined by:

- `contracts/stable_api_v1.json`

The stable contract currently covers:

- build load and save
- summary, raw stats, and display stats
- equipment listing, direct item equip, and non-persistent item preview display stats
- config read and write
- runtime health and status

Compatibility rules for stable versus experimental APIs live in [VERSIONING.md](./VERSIONING.md).
