# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR05 — Domain models + schema store (current)

**Branch:** `cursor/pr05-schema-domain-d2c1`  
**Based on:** `cursor/pr04-vault-io-d2c1` @ `944321d`

### What landed

- **LociCore models:** `ObjectType`, `PropertyDef`, `PropertyKind`, `TypeDashboardConfig`; expanded `PropertyValue` (select / multiSelect / objectSelect / url), `SpaceSettings.pins`, `LociObjectMeta.tags` + `properties`
- **`SchemaServing`:** load/save space, knownTypeIDs / loadType / saveType / allTypes / `bootstrapSchema`
- **`SchemaStore` (LociVault):** `.loci/space.json` + per-type `.loci/types/<slug>.json` (not monolithic schema.json); seeds built-in **Page**
- **`VaultService.ensureSkeleton`:** also writes `page.json` when missing (idempotent)
- **App:** `AppServices.schema`; `TypeListView` (read-only); Settings create vault → `bootstrapSchema`
- **CLI / harness:** `scripts/demo-schema.sh` → `DevHarness/public/demo-schema/`; Types panel `?panel=types`
- **Tests:** **48** package tests (was 30) — domain Codable + SchemaStore bootstrap / custom type reload
- Evidence: `evidence/pr05/`

### Schema file shapes

**`.loci/space.json`**
```json
{ "name": "Loci", "schemaVersion": 1, "pins": [] }
```

**`.loci/types/page.json`**
```json
{
  "id": "page",
  "name": "Page",
  "icon": "doc.text",
  "color": "#0F6B5C",
  "properties": [],
  "templateIDs": [],
  "dashboard": { "cardPreviewPropertyIDs": [] },
  "isBuiltIn": true,
  "isDaily": false
}
```

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-schema.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=types
```

### Pitfalls for PR06 (MarkdownKit)

- Frontmatter fields should align with `LociObjectMeta` (`id`, `type`/`typeID`, `title`, `created`, `updated`, `tags`, `properties`)
- Property values in YAML may be bare primitives — `PropertyValue` already accepts bare JSON text/number/bool/array; MD frontmatter parser should map into the same union
- Do **not** put SQLite in the vault; SchemaStore remains VaultServing-only
- Daily type is modeled (`ObjectType.builtInDaily` / `isDaily`) but **not** auto-seeded yet — PR10 can seed `daily.json`
- Identity remains ObjectID strings — never absolute ubiquity URLs

### Next: PR06 — MarkdownKit

- Loci MD ↔ BlockAST + YAML frontmatter encode/decode
- Round-trip unit tests + fixtures
- Branch: `cursor/pr06-markdown-kit-d2c1` (or plan name)

---

## PR04 — VaultIO + iCloud Documents

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
