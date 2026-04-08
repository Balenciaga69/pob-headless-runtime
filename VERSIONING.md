# Versioning Policy

This project follows a simplified Semantic Versioning strategy.

## Version Format

```
MAJOR.MINOR.PATCH
```

Example:

- `0.1.0`
- `0.1.1`
- `0.2.0`

---

## Current Stage

The project is currently in `0.x` stage.

This means:

- The project is usable as a dependency
- The API is **not fully stable**
- Only the **stable API surface** is covered by compatibility expectations

---

## Stability Scope

### Stable API (Guaranteed)

Defined in:

```
contracts/stable_api_v1.json
```

Includes:

- build load/save
- summary / stats
- equipment operations
- config read/write
- runtime + health

Rules:

- Backward compatibility is expected
- Breaking changes require MAJOR bump (after 1.0.0)

---

### Experimental API (Not Guaranteed)

- No compatibility guarantee
- Can change or break at any time
- Not part of versioning contract

---

## Version Bump Rules

### PATCH (`0.1.0 → 0.1.1`)

- Bug fixes
- Internal refactor
- No change to stable API behavior

---

### MINOR (`0.1.1 → 0.2.0`)

- Add new stable API capability
- Behavioral changes that downstream should notice
- Structural improvements affecting usage

---

### MAJOR (`1.0.0 → 2.0.0`)

- Breaking changes to stable API

Note:

- Before `1.0.0`, breaking changes may still occur
- Prefer using MINOR bump for safety

---

## Release Checklist

Before each release:

```powershell
.\scripts\fmt.ps1 -Check
.\scripts\lint.ps1
.\scripts\test.ps1
```

If experimental code is affected:

```powershell
.\scripts\test.ps1 -Experimental
```

---

## Changelog Requirement

Each release must include:

```md
## X.Y.Z - YYYY-MM-DD

### Added

### Changed

### Fixed

### Known limitations
```

---

## Git Tagging

Each release must be tagged:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

---

## Downstream Usage Recommendation

During `0.x` stage:

- Use exact version pinning:

  ```
  v0.1.0
  ```

- Avoid version ranges

---

## Path to 1.0.0

Upgrade to `1.0.0` when:

- Stable API is finalized
- Contract is trusted long-term
- Downstream usage is verified
- Test coverage is reliable
