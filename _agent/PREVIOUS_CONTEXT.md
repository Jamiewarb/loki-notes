# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR20 — Media

**Branch:** `cursor/pr20-media-d2c1`  
**Based on:** `cursor/pr19-tasks-d2c1` @ `00bfae6`

### What landed

- **`Features/Media/`:** `MediaFeature`, `MediaInserter`, `ImageObjectFactory`, `MediaAttachControls` (Photos/drop stubs)
- **Core:** `MediaServing`, `MediaKind` / `MediaAttachment` / `MediaPath`, `MediaInserter`, `ObjectType.builtInImage`, `VaultServing.putMedia`
- **Vault:** `MediaService`, `MediaStore`, `ImageObjectFactory` — coordinated copy into `media/images|files`
- **Markdown:** `/image` slash kind → placeholder image block
- **Editor:** attach controls on `ObjectEditorView`; insert markdown image via bridge
- **Demo:** `loci-media-demo` / `scripts/demo-media.sh` → `DevHarness/public/demo-media/`
- **Harness:** Media panel (`?panel=media`)
- **Tests:** **175** package tests (was 163)
- Evidence: `evidence/pr20/`
- Version: Index / Markdown → `*-pr20`; Vault → `0.20.0-pr20`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-media.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=media
```

### Pitfalls for PR21 (Sync UX)

- Media blobs are vault-only; Sync UX must never suggest putting binaries in the index
- iCloud download-on-demand: opening a note with `![](../media/…)` may need ensure-downloaded for the media file (PR21 surface)
- Conflicted media copies: surface in Sync conflict list like markdown conflicts
- Photos picker / macOS drag-drop are stubs — wire real pickers when polishing Apple UI
- Features must not import each other (Media ↔ Sync via protocols only)

### Next: PR21 — Sync UX and resilience

- Branch: `cursor/pr21-sync-ux-d2c1`
- Sync status chip; ensure downloaded; conflict list; rebuild index; reveal vault path
- Depends on: PR04, PR08
- Milestone: **MVP complete**

---

## PR19 — Tasks

**Branch:** `cursor/pr19-tasks-d2c1`

Today/Open tasks aggregation. See `evidence/pr19/`.

### Still relevant

- Task rows key off `blockIndex|itemIndex`
- Index never inside the vault

---

## Wave A (PR01–PR08) complete · Wave B: PR09–PR20 done · next PR21 (MVP)
