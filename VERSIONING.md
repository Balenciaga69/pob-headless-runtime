# Versioning Policy

## Version Format

This project uses:

```text
MAJOR.MINOR.PATCH
```

Examples:

- `0.1.0`
- `0.1.1`
- `0.2.0`

## Current Stage

The project is currently in late `0.x`.

This means:

- the project is usable as a dependency
- the stable contract is maintained intentionally
- `1.0.0` has not been declared yet
- only the stable API surface has compatibility expectations

## Stability Scope

Stable API:

- defined by `contracts/stable_api_v1.json`
- accepted by the machine-facing worker
- covered by compatibility expectations

Experimental API:

- not part of the versioned public contract
- may change or break at any time
- exists for compatibility helpers and local experimentation

## Version Bump Rules

### PATCH

Use a PATCH bump for:

- bug fixes
- internal refactors
- documentation alignment for existing stable behavior
- changes that do not alter stable API behavior

### MINOR

Use a MINOR bump for:

- new stable API capability
- downstream-visible stable behavior changes
- stable response changes that downstream may consume

### MAJOR

Use a MAJOR bump for:

- breaking changes to the stable API after `1.0.0`

Before `1.0.0`, breaking changes may still occur, but prefer a MINOR bump when in doubt.

## Release Requirements

Each release must:

1. update `CHANGELOG.md`
2. run the validation flow from [CONTRIBUTING.md](./CONTRIBUTING.md)
3. update `contracts/stable_api_v1.json` if stable API behavior changed
4. update `README.md` if compatibility, entry points, or public summaries changed
5. be tagged as `vX.Y.Z`

## Downstream Recommendation

During `0.x`:

- use exact version pinning
- avoid version ranges

Upgrade to `1.0.0` when the stable API, release process, and downstream usage expectations are all trusted long-term.
