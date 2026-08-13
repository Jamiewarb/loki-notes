# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C (PR22–)

**Milestone:** Wave B MVP complete (PR09–PR21). Wave C depth: Collections → Queries → Graph → Calendar → Capture → Import…

Next stack: **PR27 Import**.

---

## PR26 — Capture surfaces

**Branch:** `cursor/pr26-share-widget-d2c1`  
**Based on:** `cursor/pr25-calendar-d2c1`  
**Tip:** `e5ab551b4667ad502c5ab1e3e9ddfb499fcd70c8`

### What landed

- **Core:** `CaptureKind` / `CaptureInboxItem` / `CaptureResult` / `CaptureInbox` / `CaptureLineFormatter` / `CaptureInboxCodec`; `CaptureServing`; `Route.capture`
- **Vault:** `CaptureService` + `CaptureInboxWriter`; `.loci/inbox/` in `VaultLayout`; module `0.26.0-pr26`
- **Pipeline:** Extensions enqueue `.loci/inbox/<id>.json` → main app `drainInbox` → append today’s `daily/YYYY-MM-DD.md` **or** create typed object via ObjectServing
- **Features/Capture/:** Quick add UI + store; AppServices wires capture + drains on `openVaultPipeline`
- **Platform stubs:** iOS Share extension + Widget (Info.plist + sources); macOS menu bar quick capture controller
- **Demo:** `loci-capture-demo` / `scripts/demo-capture.sh` → `DevHarness/public/demo-capture/`
- **Harness:** Studio **Capture** panel at `?panel=capture`
- **Tests:** CaptureModels (+8) + CaptureSystem (+5) + Route.capture
- Evidence: `evidence/pr26/`
- Version: Index / Markdown → `*-pr26`; Vault → `0.26.0-pr26`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-capture.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=capture
```

### Pitfalls for PR27 (Import)

- Importers write **real vault files** then index — never invent a parallel store
- Prefer dry-run summary before applying; map Capacities/Obsidian frontmatter carefully
- Wiki-links best-effort; do not break existing ObjectID / daily path schemes
- No feature→feature imports; Import talks ObjectServing / VaultServing / SchemaServing
- Keep Linux-testable parsers in packages; Apple-only UI can stay stubs

### Next: PR27 — Import

- Branch: `cursor/pr27-import-d2c1` (or `cursor/pr27-import-…` per agent suffix)
- Importers: generic markdown folder, Obsidian vault, Capacities export; dry-run summary
- Depends on: PR08, PR06, PR12

---

## PR25 — Calendar UI

**Branch:** `cursor/pr25-calendar-d2c1`

Calendar from index markers; day jump via DailyNoteServing. See `evidence/pr25/`.

### Still relevant

- Capture drains into daily — calendar dots will pick up content after index apply
- Do not confuse calendar chrome (index-only) with capture writes (vault mutations)

---

## PR24 — Graph view

Graph from links table; type filter + caps. See `evidence/pr24/`.

---

## PR23 — Saved queries + embeds

QueryEngine DSL; `.loci/queries/`; `/query` embeds. See `evidence/pr23/`.

---

## PR22 — Collections

Manual collections per type; membership vault JSON. See `evidence/pr22/`.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR26 done · next PR27
