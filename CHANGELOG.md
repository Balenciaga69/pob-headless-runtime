# Changelog

## 0.2.1 - 2026-04-10

### Added

- Added stable `list_items` to return every item currently stored in `itemsTab.items`.
- Added stable `list_skills`, `select_skill`, and `get_selected_skill` at the top-level API while keeping the experimental skill aliases for compatibility.
- Added stable `preview_item_display_stats` to preview a temporary item replacement and return GUI-like detailed stats without leaving the item equipped.
- Added contract, transport, unit-test, and smoke coverage for the new stable skill and item methods.

### Changed

- Updated the public API surface, contract manifest, and README to document the new stable skill and item methods.

## 0.2.0 - 2026-04-09

### Added

- Added stable `get_display_stats` to expose GUI-like detailed stat entries from PoB's display stat catalog.
- Added stable summary metadata for calcs skill context so downstream UIs can identify the active socket group, skill, and skill part behind current DPS.
- Added contract examples for display-stats requests and responses under `contracts/examples/`.
- Added transport smoke coverage for `get_display_stats`.

### Changed

- Updated summary and stats metadata to prefer the actual passive tree version from the loaded spec.
- Updated contributor guidance so stable API changes must also update machine-readable contracts, release notes, and transport coverage.

### Fixed

- Fixed build load validation so default empty builds are no longer reported as successful loads.
- Fixed persistent-worker load behavior by waiting for mode switch, calcs readiness, output readiness, and populated XML sections before returning success.
- Fixed summary and main-skill reporting to use calcs skill selection context instead of only the main-page skill selector.
- Fixed detailed stat formatting for overcap values and skill-part metadata in stable responses.
- Fixed unit coverage around build-code loading to match the current validated load flow.
