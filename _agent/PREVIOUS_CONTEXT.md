# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave B MVP complete (PR09–PR21)

**Milestone:** Capacities-core daily loop + types + templates + links + search + tasks + media + sync UX usable on Mac/iPhone via iCloud directory (local Documents fallback always).

Next stack: **Wave C** starting at **PR22 Collections**.

---

## PR21 — Sync UX and resilience

**Branch:** `cursor/pr21-sync-ux-d2c1`  
**Based on:** `cursor/pr20-media-d2c1` @ `6d513cc`

### What landed

- **`Features/SyncStatus/`:** `SyncStatusFeature`, `SyncChip`, `ConflictList`, `SyncSettingsSection`
- **Core:** expanded `SyncStatusProviding` (path, conflicts, ensureDownloaded, rebuildIndex, reveal); `SyncStatusDerivation`; `SyncConflictItem`
- **Vault:** `SyncStatusService`, `DownloadOnDemand` (Apple stub / Linux no-op), `ConflictScanner` (markdown + media), `VaultPathRevealer`
- **`VaultServing.ensureDownloaded` + `listConflictedCopies`**; `ObjectService.open` ensures note + media refs
- **Settings:** rebuild index, reveal vault path, conflict list; sidebar sync chip
- **Demo:** `loci-sync-demo` / `scripts/demo-sync.sh` → `DevHarness/public/demo-sync/`
- **Harness:** Settings sync status panel (`?panel=settings`)
- **Tests:** status derivation + conflict listing (Core + Vault)
- Evidence: `evidence/pr21/`
- Version: Index / Markdown → `*-pr21`; Vault → `0.21.0-pr21`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-sync.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=settings
```

### Pitfalls for PR22 (Collections)

- Collections membership must be vault files (not index-only); pick a merge-friendly format
- Do not import SyncStatus / Media / Types features into Collections — protocols only
- Type dashboard tabs: wire through SchemaServing / ObjectServing / IndexQuerying
- Pinned sidebar stub may later surface collections — keep AppShell chrome thin

### Next: PR22 — Collections

- Branch: `cursor/pr22-collections-d2c1`
- Manual collections per type; membership file; collection tabs on type dashboard; add/remove
- Depends on: PR12
- Wave C depth begins

---

## PR20 — Media

**Branch:** `cursor/pr20-media-d2c1`

Media attach into `media/` + Image type. See `evidence/pr20/`.

### Still relevant

- Media blobs vault-only; Sync conflict list includes media conflicted copies
- Photos picker / drag-drop remain Apple stubs

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · next Wave C PR22
