# pob_headless_refactor tests

This folder collects test-related scripts for the headless PoB bridge.

Planned layout:

- `helpers/` for reusable helper scripts used by smoke or integration runs
- `smoke/` for executable smoke tests against known fixtures
- `unit/` for future isolated unit tests
- `fixtures/` for XML or other test data
- `run_smoke.py` for batch-running all smoke scripts
- `run_unit.py` for batch-running isolated unit scripts

The current smoke entry points were moved here from `custom/pob_headless_refactor/` so
test code lives in one place instead of being mixed with runtime bridge code.

Run smoke tests with:

```powershell
python custom\pob_headless_refactor\tests\run_smoke.py
```

Run unit tests with:

```powershell
python custom\pob_headless_refactor\tests\run_unit.py
```
