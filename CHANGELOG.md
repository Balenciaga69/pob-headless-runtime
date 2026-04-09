# Changelog

## 0.2.1 - 2026-04-10

### Added

- Added stable `list_items` to return every item currently stored in `itemsTab.items`.
- Added stable `list_skills`, `select_skill`, and `get_selected_skill` at the top-level API while keeping the experimental skill aliases for compatibility.
- Added contract, transport, unit-test, and smoke coverage for the new stable skill/item methods.

### Changed

- Updated the public API surface, contract manifest, and README to document the stable skill/item methods.

## 0.2.0 - 2026-04-09

### Added

- Added stable `get_display_stats` to expose GUI-like detailed stat entries from PoB's display stat catalog.
- Added stable summary metadata for calcs skill context so downstream UIs can identify the active socket group, skill, and skill part behind current DPS.
- Added contract examples for display-stats requests and responses under [contracts/examples](G:\Coding\PathOfBuilding-Headless\pob-headless-runtime\contracts\examples).
- Added transport smoke coverage for `get_display_stats`.

### Changed

- Updated summary and stats metadata to prefer the actual passive tree version from the loaded spec.
- Updated documentation to treat the stable contract as intentionally maintained during late `0.x`, including release-gate guidance for transport smoke tests.
- Updated contributing guidance so stable API changes must also update machine-readable contracts, docs, and transport coverage.

### Fixed

- Fixed build load validation so default empty builds are no longer reported as successful loads.
- Fixed persistent-worker load behavior by waiting for mode switch, calcs readiness, output readiness, and populated XML sections before returning success.
- Fixed summary/main-skill reporting to use calcs skill selection context instead of only the main-page skill selector.
- Fixed detailed stat formatting for overcap values and skill-part metadata in stable responses.
- Fixed unit coverage around build-code loading to match the current validated load flow.

### Known limitations

- The stable API remains intentionally narrower than full PoB GUI control; experimental methods still have no compatibility guarantee.
- Desktop consumers using a persistent worker must restart their app/server process after Lua runtime changes.
- Some builds can still show DPS differences if downstream tools compare a different skill context than PoB GUI; stable metadata now exposes that context so callers can verify alignment.
