# pob-headless-runtime tests

This folder collects test-related scripts for the headless PoB bridge.

- `helpers/` for reusable helper scripts used by smoke or integration runs
- `smoke/` for executable smoke tests against known fixtures
- `unit/` for future isolated unit tests
- `fixtures/` for XML or other test data
- `run_smoke.py` for batch-running all smoke scripts
- `run_unit.py` for batch-running isolated unit scripts

Smoke suites:

- `stable` for the supported contract surface
- `experimental` for opt-in behavior that may change
- `all` for local full regression runs

Run smoke tests with:

```powershell
python custom\pob-headless-runtime\tests\run_smoke.py --suite stable
```

Run unit tests with:

```powershell
python custom\pob-headless-runtime\tests\run_unit.py
```

Run JSON transport smoke tests with:

```powershell
python custom\pob-headless-runtime\tests\run_transport_smoke.py
```

Implementation notes:

- `src/api/repo/build_guard.lua` now owns repo-facing build readiness checks
- `src/api/repo/pob_code.lua` now owns PoB share-code encoding and decoding helpers
- `src/runtime/runtime_state.lua` now owns runtime stop and prompt lifecycle helpers
