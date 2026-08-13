# Architecture Best Practices — Local-First Object PKM (Loci)

Research summary **separate from the product plan**. Sources: Ink & Switch local-first ideals, Apple iCloud Documents guidance, Obsidian vault/index split, SwiftUI modular packaging practice (2025–2026), and local-first markdown apps (NoteGen, outl).

---

## 1. Local-first ideals (Ink & Switch)

Apply these as product/architecture tests:

1. **No spinners** — reads/writes hit local storage; sync is background.
2. **Not trapped on one device** — iCloud Documents moves bytes between Mac/iPhone.
3. **Network optional** — full capture/edit/search against local replica + local index.
4. **Collaboration** — *out of scope* for v1 (personal app); still design so one user on two devices does not corrupt data.
5. **The Long Now** — human-readable markdown + schema on disk survives the vendor.
6. **Privacy by default** — no Loci server; vault stays in the user’s iCloud account.
7. **Ultimate ownership** — Finder/Files-visible directory; export is the vault itself.

**Implication:** Prefer plain files users can open in other tools over opaque CRDT blobs *for note bodies*, accepting weaker merge semantics than Yjs/Automerge unless we later add an op-log.

---

## 2. Source-of-truth layering (Obsidian / outl lessons)

| Layer | Role | Must not |
|---|---|---|
| **Vault files** (`.md`, media, schema) | Authoritative durable state | Be bypassed by writing “only to SQLite” |
| **Open editor session** | Working copy for the active doc | Fight disk on every keystroke without debounce |
| **Index (SQLite)** | Derived projection for search/graph/queries/created-today | Live inside the iCloud vault or be treated as truth |
| **UI projections** | Backlinks, created-today, query embeds | Be persisted as fake user edits unless intentionally exported |

**Rules:**

- Files are truth; index is disposable and rebuildable.
- Keep the **index outside iCloud** (Application Support). Syncing SQLite via iCloud causes corruption and pointless conflicts.
- Typing must never wait on index or network (outl: “a keystroke should never wait for the disk” for secondary projections).
- Prefer **stale-while-revalidate**: UI reads index immediately; indexer catches up asynchronously.

---

## 3. iCloud Documents realities (Apple)

- Discover files with **`NSMetadataQuery`**, not persisted URLs (files move/rename).
- All I/O through **`NSFileCoordinator`**; treat open docs as **file presenters** (`UIDocument`/`NSDocument` or equivalent).
- On iOS, **metadata can arrive before bytes** — check download status; trigger download before parse; indexer must tolerate “known but not local” files.
- Keep coordinator/presenter callbacks **short** — no heavy parse inside coordination blocks; copy bytes then parse off-queue.
- Disable query updates while iterating results; re-enable after.
- Provide a **local non-iCloud vault** for CI, simulators, and users who disable iCloud.

**Conflict model for file sync (not CRDT):** same-path last-write-wins or conflicted copies. Design to **narrow write surfaces** and **deterministic paths** so two devices usually write the same file, not twins.

---

## 4. Sync and conflict strategy (practical, non-CRDT)

For a personal markdown vault on iCloud Drive:

1. **One working copy per open object** — editor owns in-memory state; debounced save is the only writer for that file while focused.
2. **External change while open** → reload prompt or conflict UI; never silently clobber cursor state.
3. **Debounce + coalesce** saves (idle + max interval) to reduce sync chatter (NoteGen pattern).
4. **Deterministic identity for dailies** — path `daily/YYYY-MM-DD.md` and id derived from date so two devices create the same note, not two.
5. **Do not write derived UI into markdown** (e.g. auto “created today” lists) — that causes cross-device thrash.
6. **Schema writes are rare and mergeable** — prefer per-type schema files over one monolithic `schema.json` choke point.
7. **Tombstones / trash folder** for deletes so the other device does not “resurrect” from stale cache.
8. Treat **network failure** vs **version conflict** as different UX states.

When true multi-caret sync is needed later, introduce CRDTs *behind* markdown export (outl/memrynote model)—do not pretend LWW file sync is CRDT-grade.

---

## 5. Hub-and-spoke app core (Obsidian-shaped)

Central composition object (e.g. `LociServices`) exposes subsystems; features depend on protocols, not on each other:

- **Vault** — file CRUD, events (`create`/`modify`/`delete`/`rename`)
- **MetadataIndex** — frontmatter, links, tags, FTS (Obsidian `MetadataCache`)
- **ObjectService** — high-level object ops that update files *and* keep links consistent (Obsidian `FileManager`)
- **SchemaStore** — types, properties, templates
- **Workspace / Navigator** — navigation and open editors
- **SyncStatus** — iCloud/local state for chrome

Features never reach into another feature’s folders; they call services.

---

## 6. SwiftUI modularity (2026 practice)

- **Do not** create one SPM package per feature early — package walls are expensive.
- Prefer a **star graph**:
  - `LociCore` — pure models, IDs, errors, protocols (no SwiftUI)
  - `LociVault` — file coordination, metadata query, document sessions
  - `LociIndex` — SQLite/GRDB, depends on Core (+ parses via Core markdown types)
  - `LociDesignSystem` — tokens/components
  - **App / feature folders** — SwiftUI features composed in the app target (or one `LociFeatures` target)
- **App target = composition root** — only place that wires concrete types.
- Features import **Core + DesignSystem + protocols**; they do not import sibling features.
- Navigation via typed routes / `Navigator` protocol, not cross-feature view imports.

---

## 7. Code organization: co-locate by domain

Prefer:

```text
Features/DailyNotes/
  DailyNote.swift
  DailyNoteStore.swift
  DailyNoteView.swift
  CreatedTodayPanel.swift
```

Over type-layered dumps (`Views/`, `ViewModels/`, `Models/` globally).

**File size:** aim for one primary type per file; split when a file exceeds ~200–300 lines or mixes unrelated concerns. Keep parsers, UI, and persistence in separate files even inside the same domain folder.

---

## 8. Editor architecture

- Block AST in memory; serialize to Loci Markdown on save.
- **Editor is source of truth while dirty**; disk wins only after acknowledged reload.
- Do not use index APIs on the hot typing path.
- Slash menu / link picker query the index asynchronously.
- MarkdownKit must be pure and heavily tested — it is the interchange contract with the Long Now.

---

## 9. Feature architecture checklist

When adding a feature:

1. Name the **domain folder** and the **service protocol** it needs.
2. State whether it **reads files, writes files, or only reads the index**.
3. Declare **events it publishes** and **events it consumes** (vault/index/nav).
4. Keep UI ignorant of iCloud — only Vault/SyncStatus know ubiquity.
5. Ensure behavior works with **local fallback vault**.
6. Add fixture-based tests for any disk format change.
7. Avoid writing derived data back into the vault unless the user edited it.

---

## 10. Anti-patterns

- SQLite (or any cache) inside the iCloud container as “the database”
- Giant `schema.json` rewritten on every property edit without merge strategy
- Auto-appending generated sections into daily notes every sync
- Features importing other features’ view models
- Persisting absolute file URLs
- Parsing markdown inside `NSFileCoordinator` callbacks
- Blocking the main thread on full-vault reindex
- Dual writers (editor autosave + background “formatter” rewrite) without a single session owner
