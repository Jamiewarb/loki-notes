# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR04 — VaultIO + iCloud Documents (current)

**Branch:** `cursor/pr04-vault-io-d2c1`  
**Based on:** `cursor/pr03-app-shell-d2c1` @ `c1e34a8`

### What landed

- **`LociVault` (real, not stub):**
  - `VaultRoot` — local Documents always; ubiquity behind `#if canImport(Darwin)`
  - `VaultService` — `VaultServing` impl: skeleton, coordinated R/W, trash+tombstone
  - `FileCoordinatorClient` — `NSFileCoordinator` on Apple; plain `FileManager` on Linux
  - `MetadataQueryMonitor` — `NSMetadataQuery` structure on ubiquity paths; poll/`noteLocalWrite` on Linux
  - `ConflictedCopyDetector` — `(conflicted copy` / numbered `Name 2.md` patterns
  - `TombstoneStore` — `.tombstone` JSON under `.loci/trash/`
  - `VaultLayout` — canonical paths (`.loci/`, `daily/`, `objects/`, `media/…`)
- **Core:** extended `VaultServing` (`rootKind`, `ensureSkeleton`, `trashFile`, `TombstoneRecord`, `VaultFileEvent`); `LociError` path/coordination cases
- **App:** `AppServices` owns `VaultService` + `SyncStatusProviding`; `VaultSettingsView` Create vault; iCloud entitlements + `NSUbiquitousContainers`
- **CLI:** `loci-vault-demo` + `scripts/demo-vault.sh`
- **DevHarness:** Settings vault status panel (`?panel=settings`)
- **Tests:** **30** package tests (was 19) — vault round-trip / skeleton / trash / conflicts / monitor green on Linux
- Evidence: `evidence/pr04/` (lint, test, demo-vault, harness settings png/dom)

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-vault.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=settings
```

### API surface (VaultServing)

```text
vaultRootURL / rootKind
ensureSkeleton(spaceName:)
readFile / writeFile / deleteFile / fileExists / absoluteURL
trashFile → TombstoneRecord
```

### Pitfalls for PR05

- Do **not** put SQLite inside the vault — SchemaStore uses VaultServing only for `.loci/types/*.json` + `space.json`.
- `space.json` already written by `ensureSkeleton`; SchemaStore should load/merge, not blindly overwrite pins later.
- Prefer per-type files under `.loci/types/` (merge-friendly) — seed built-in **Page**.
- Identity = ObjectID / type id strings — never persist absolute ubiquity URLs as sole identity.
- Linux has no iCloud; tests must keep using `preferredLocalDirectory` / `forceLocal`.

### Next: PR05 — Domain models + schema store

- `Space`, `ObjectType`, `PropertyDef`, `LociObject` metadata in LociCore
- SchemaStore load/save via VaultServing; bootstrap `page.json`
- Settings type list (read-only)
- Branch: `cursor/pr05-schema-domain-d2c1`

---

## PR03 — App shell navigation

**Branch:** `cursor/pr03-app-shell-d2c1`  
**Based on:** `cursor/pr02-design-system-d2c1` @ `0c17eda`

### What landed

- **`LociCore.Route`:** primary destinations Daily / Search / Types / Settings + `designGallery` + `object(ObjectID)`
- **`AppServices`:** `Navigating`; owns `selectedRoute`
- AppShell (macOS split / iOS tabs) + DevHarness sectioned sidebar
- Tests: 19 package tests after PR03

---

## PR02 — Design system

**Branch:** `cursor/pr02-design-system-d2c1`

Design direction **editorial-sage** (ink `#1A2421`, paper `#E8EFE8`, accent `#0F6B5C`, Fraunces + Source Sans 3).

---

## PR01 — Scaffold

SPM monorepo, protocols, scripts, CI. Swift **6.2** at `/opt/swift`.
