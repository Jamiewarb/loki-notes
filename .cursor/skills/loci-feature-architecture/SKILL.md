---
name: loci-feature-architecture
description: Architect and implement Loci (Capacities-style local-first PKM) features using vault-as-truth, derived local index, domain co-location, and protocol boundaries. Use when planning, scaffolding, or reviewing any Loci feature, PR wave, data model, editor, sync, or SwiftUI module structure.
---
# Loci Feature Architecture

Use this skill for every Loci feature design or PR. Canonical research summary: [docs/architecture-best-practices.md](../../../docs/architecture-best-practices.md).

## Hard rules

1. **Vault files are source of truth.** Markdown + schema + media in the vault directory. SQLite index is a **local disposable projection** (Application Support), never synced via iCloud.
2. **No cross-feature imports.** Features talk through `LociCore` protocols; the app composition root wires concretes.
3. **Co-locate by domain**, not by type. `Features/DailyNotes/{Model,Store,View}.swift` — not global `Views/` + `Models/`.
4. **One primary type per file.** Split before ~250 lines or when mixing UI + I/O + parsing.
5. **Typing never waits on index or network.** Debounced save; async index; stale-while-revalidate UI.
6. **Do not persist derived UI into markdown** (created-today, backlink lists, query results) unless the user explicitly inserts an embed.
7. **iCloud I/O only inside Vault layer** (`NSFileCoordinator`, metadata query, download-on-demand). Features call `VaultServing` / `ObjectServing`.
8. **Local vault fallback must work** for every feature (CI/simulator/no iCloud).
9. **Deterministic paths/ids** for singleton-per-day objects (`daily/YYYY-MM-DD.md`).
10. **Schema is merge-friendly** — prefer per-type definition files; avoid monolithic rewrite churn.

## Package / target shape

```text
LociCore          — models, IDs, errors, protocols (no SwiftUI, no I/O)
LociVault         — ubiquity/local roots, coordination, document sessions, events
LociMarkdown      — parse/serialize Loci MD ↔ BlockAST + frontmatter
LociIndex         — GRDB/SQLite projection, FTS, link/tag graphs
LociDesignSystem  — tokens + primitives
Loci (app)        — composition root, Features/*, platform shells
```

Dependency direction: `Features → Core/DesignSystem` (+ use protocols for Vault/Index/Markdown). `LociIndex` → `LociCore` + `LociMarkdown`. `LociVault` → `LociCore`. App imports all and injects.

## Feature design template

Copy and fill before coding:

```markdown
### Feature: <name>
- Domain folder: `Loci/Features/<Domain>/`
- Writes vault? yes/no — which paths?
- Reads index? yes/no — which queries?
- Protocols needed: (e.g. ObjectServing, SchemaServing, IndexQuerying, Navigating)
- Events consumed: (vault modify, index updated, calendar day change)
- Events published: (none | navigation requests | user notifications)
- New files (aim small):
  - `...`
- Touch points / boundaries:
  - Provides: …
  - Requires from composition: …
- Tests: fixtures under `LociMarkdownTests` / `LociIndexTests` / feature tests
- Sync hazards: (schema? concurrent daily create? open editor external change?)
```

## Standard feature folder layout

```text
Features/<Domain>/
  <Domain>Feature.swift          # public entry: factory or root View
  Model/                         # domain structs/enums (or use LociCore if shared)
  Services/                      # feature-local use of protocols (thin)
  UI/                            # SwiftUI views only
  Resources/                     # optional
```

If a type is shared by ≥2 features, move it to `LociCore` (model/protocol) or a small shared domain folder owned by Core — do not create a bidirectional feature dependency.

## Service protocols (composition surface)

Define/extend in `LociCore` as needed:

| Protocol | Responsibility |
|---|---|
| `VaultServing` | resolve URLs, coordinated read/write, trash, media put, file events |
| `SchemaServing` | object types, properties, templates; merge-safe updates |
| `ObjectServing` | create/open/save/delete/convert objects; path allocation |
| `IndexQuerying` | search, created(on:), links, tags, tasks, filter/sort |
| `IndexUpdating` | apply vault events; rebuild (Vault/Index pipeline, not features) |
| `Navigating` | open object, present sheet, search, settings |
| `SyncStatusProviding` | iCloud/local/offline/conflict chips |

Features depend on these protocols only.

## Data flow (mandatory)

```text
User edit → EditorSession (memory)
         → debounced ObjectServing.save
         → VaultServing.write (coordinated)
         → Vault event
         → IndexUpdating.apply (async, local DB)
         → Index publishers → UI panels (backlinks, created-today, search)
```

External vault change → Vault event → if file open: EditorSession.proposeReload → IndexUpdating.apply.

## iCloud-specific implementation notes

- Discover with `NSMetadataQuery`; never persist absolute ubiquity URLs as sole identity.
- Object identity = frontmatter `id` (UUID). Path/slug are locators.
- Before parse on iOS: ensure downloaded (`NSURLUbiquitousItemDownloadingStatusKey`) or show placeholder.
- Keep work inside coordinator blocks minimal (Data in/out only).
- Conflicted copies: surface in Sync UI; index both; let user choose.

## PR / wave mapping

When implementing a stacked PR from the build plan:

1. Read this skill + best-practices doc.
2. Fill the feature design template into the PR description.
3. Create only files listed; no drive-by folder renames.
4. Add/adjust protocols in Core before feature UI if the boundary is new.
5. Verify local-vault path in tests.

## Review checklist

- [ ] Index DB path is under Application Support, not the vault
- [ ] No feature imports another feature module
- [ ] No derived lists written into daily markdown automatically
- [ ] Save path debounced; editor owns dirty state
- [ ] New disk format has round-trip tests
- [ ] Works with local fallback vault
- [ ] Files stay small and domain-colocated
