# AGENTS.md — Loci

Guidance for humans and Cloud agents working on this repository.

## What Loci is

**Loci** is an Apple-only (macOS + iOS), Capacities-inspired personal knowledge base. Every object is a markdown file (plus YAML frontmatter) inside a user-owned vault directory on iCloud Drive, with a mandatory **local Documents fallback** when iCloud is unavailable. Search, backlinks, and “created today” come from a **local SQLite index** under Application Support — the index is disposable, rebuildable, and **must never live inside the vault**.

The product vision, vault format, package boundaries, and stacked PR plan live in [`docs/PLAN.md`](docs/PLAN.md). Architecture research: [`docs/architecture-best-practices.md`](docs/architecture-best-practices.md). Feature hard rules: [`.cursor/skills/loci-feature-architecture/SKILL.md`](.cursor/skills/loci-feature-architecture/SKILL.md). Playwright feature tests: [`.cursor/skills/loci-playwright-feature-tests/SKILL.md`](.cursor/skills/loci-playwright-feature-tests/SKILL.md).

## Architecture pointers

| Piece | Role |
|---|---|
| `LociCore` | Models, IDs, errors, protocols (no SwiftUI, no I/O) |
| `LociVault` | File coordination, ubiquity/local roots (PR04) |
| `LociMarkdown` | Loci MD ↔ BlockAST (PR06) |
| `LociIndex` | SQLite projection in Application Support (PR07) |
| `LociDesignSystem` | Tokens + primitives (PR02) |
| `App/` | Composition root + `Features/<Domain>/` folders |
| `DevHarness/` | Browser UI shell for visual testing on Linux |

Dependency direction: Features → Core/DesignSystem (+ protocols). App wires concretes. Features do not import features.

## Swift toolchain (Linux Cloud agents)

Documented install used by PR01:

- **Swift 6.2 (swift-6.2-RELEASE)** for **Ubuntu 24.04** (`x86_64`)
- Installed under `/opt/swift` (symlink to `/opt/swift-6.2-RELEASE-ubuntu24.04`)
- Official tarball: `https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz`

```bash
export PATH=/opt/swift/usr/bin:$PATH
swift --version   # expect: Swift version 6.2 (swift-6.2-RELEASE)
```

Reinstall sketch:

```bash
curl -L -o /tmp/swift.tar.gz \
  "https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz"
sudo tar -xzf /tmp/swift.tar.gz -C /opt
sudo ln -sfn /opt/swift-6.2-RELEASE-ubuntu24.04 /opt/swift
export PATH=/opt/swift/usr/bin:$PATH
# LociIndex (GRDB) needs SQLite headers on Linux:
sudo apt-get install -y libsqlite3-dev
```

On **macOS**, use Xcode’s Swift toolchain. Do not expect the `App/` SwiftUI target to build on Linux — only SPM packages in `Package.swift` are Linux-tested.

## How to test

### Linux (Cloud agents) — required every PR

```bash
./scripts/lint.sh
./scripts/test.sh
./scripts/e2e.sh            # Playwright feature tests vs DevHarness
./scripts/run-harness.sh    # leave running; open http://127.0.0.1:5173
```

Playwright specs live in `DevHarness/e2e/`. Load [`.cursor/skills/loci-playwright-feature-tests/SKILL.md`](.cursor/skills/loci-playwright-feature-tests/SKILL.md) before adding tests. They cover the Linux harness surface only — not SwiftUI.

Sync UX (PR21) extras:

```bash
./scripts/demo-sync.sh
# harness: http://127.0.0.1:5173/?panel=settings
```

Linux CI reports **local-only** sync status; simulated chip states live in the demo fixture. On Apple, ubiquity preferred when signed in; ensure-downloaded runs before open (media refs too). Index rebuild is Settings-only and never writes into the vault.

Collections (PR22) extras:

```bash
./scripts/demo-collections.sh
# harness: http://127.0.0.1:5173/?panel=types
```

Membership is vault JSON under `.loci/collections/<type>.<slug>.json` (not index-only).

Queries (PR23) extras:

```bash
./scripts/demo-queries.sh
# harness: http://127.0.0.1:5173/?panel=types  (pinned queries)
#          http://127.0.0.1:5173/?panel=editor ( /query embed)
```

Saved definitions live under `.loci/queries/<slug>.json`; results are derived from the index.

Graph (PR24) extras:

```bash
./scripts/demo-graph.sh
# harness: http://127.0.0.1:5173/?panel=graph
```

Graph topology comes from the index `links` table (`IndexQuerying.graph`); type filter + node/edge caps apply.

Calendar (PR25) extras:

```bash
./scripts/demo-calendar.sh
# harness: http://127.0.0.1:5173/?panel=calendar
```

Calendar dots come from `IndexQuerying.calendarMarkers` (daily presence / FTS content / creations). Day select opens `daily/YYYY-MM-DD.md` via `DailyNoteServing.ensure` — never rewrite vault for chrome.

Capture (PR26) extras:

```bash
./scripts/demo-capture.sh
# harness: http://127.0.0.1:5173/?panel=capture
```

Extensions write staging JSON under `.loci/inbox/`; main app drains on foreground into today’s daily or a typed object. Index updates via ObjectServing — never from the extension process.

Import (PR27) extras:

```bash
./scripts/demo-import.sh
# harness: http://127.0.0.1:5173/?panel=import
```

Dry-run summary then apply: generic markdown folder, Obsidian vault (wiki-links best-effort), Capacities-style export. Writes real vault files; preserves ObjectID / `daily/YYYY-MM-DD.md` when detectable.

Type conversion (PR28) extras:

```bash
./scripts/demo-type-convert.sh
# harness: http://127.0.0.1:5173/?panel=type-convert
```

Change object type with property mapping; move file under `objects/<type>/`; ObjectID stays stable; index via ObjectServing / IndexUpdating. Daily notes cannot convert.

Richer editor (PR29) extras:

```bash
./scripts/demo-editor.sh
# harness: http://127.0.0.1:5173/?panel=editor
```

Tables / toggles / callouts / mermaid fences round-trip in LociMarkdown; slash menu + “Turn into…” uses ObjectServing.create + wiki-link. Syntax highlight is harness/CSS on Linux.

AI assist (PR30) extras:

```bash
./scripts/demo-ai.sh
# harness: http://127.0.0.1:5173/?panel=ai
```

Side-panel summarize / rewrite / translate / property autofill. On-device heuristics by default; BYOK never uploads without opt-in. Credentials in Application Support — never the vault. Apply via ObjectServing / EditorSession only.

Apple Calendar / Reminders (PR31) extras:

```bash
./scripts/demo-apple.sh
# harness: http://127.0.0.1:5173/?panel=apple
```

Event list on daily is UI chrome (daily .md unchanged). Create Meeting → `objects/meeting/` via ObjectServing. Optional Reminders sync is explicit + settings outside vault.

Safari web clipper (PR32) extras:

```bash
./scripts/demo-safari.sh
# harness: http://127.0.0.1:5173/?panel=safari
```

Safari App Extension enqueues `.loci/inbox/*.json` (same Capture inbox); main app drains → today’s daily (`· safari`) or a Weblink object with `url` property. Index never from the extension. **Wave D (PR30–PR32) complete.**

Pins (PR34) extras:

```bash
./scripts/demo-pins.sh
# harness: http://127.0.0.1:5173  (sidebar Pinned section)
```

Pinned object ids live in `.loci/space.json` (`pins`) so they sync with the vault. The index only resolves title/type for display. Cap 24; pin is idempotent; unpin missing is a no-op. Daily notes may be pinned.

Media pickers (PR35) extras:

```bash
./scripts/demo-media.sh
./scripts/demo-media-pickers.sh
# harness: http://127.0.0.1:5173/?panel=media
```

iOS `PhotosPicker` and macOS `.onDrop` copy bytes via `MediaServing` into vault `media/`, then insert `![alt](relative)`. Linux uses `attach(fileURL:)`. Never persist absolute disk paths or store blobs in SQLite. Proof flags `photosPickerWired` / `dragDropWired` mean “code present”.

EventKit (PR36) extras:

```bash
./scripts/demo-apple.sh
# harness: http://127.0.0.1:5173/?panel=apple
```

On Apple, Calendar/Reminders use EventKit (`requestFullAccessToEvents` / reminders). Linux and tests inject `FakeAppleCalendarStore` / `FakeAppleRemindersStore`. EventKit types stay out of LociCore. Listing events never writes daily.md. Proof flags `eventKitWired` / `linuxUsesFakes` / `dailyUnchanged`.

Share extension + Widget (PR37) extras:

```bash
./scripts/demo-capture.sh
./scripts/demo-share-widget.sh
# harness: http://127.0.0.1:5173/?panel=capture
```

Share sheet extracts `public.plain-text` / `public.url` via UIKit, then `ShareInboxFactory` (LociCore, no UIKit) → `CaptureInboxWriter` → `.loci/inbox/*.json`. Widget “Open today” is `loci://daily/today`; Quick add enqueues a line or deep-links `loci://capture`. Extension process never opens SQLite. Proof flags `shareExtractsText` / `widgetOpenToday` / `inboxNotIndex` / `indexInsideVault: false`.

Menu bar + Safari clipper (PR38) extras:

```bash
./scripts/demo-safari.sh
./scripts/demo-menubar.sh
# harness: http://127.0.0.1:5173/?panel=safari
```

macOS menu bar `install()` from app launch: Quick capture → `CaptureServing.appendToToday` or inbox enqueue if vault-only; Open today → `Navigating` / `loci://daily/today`. Safari `messageReceived` reads JS payload keys `url` / `title` / `selection` via `SafariClipFactory` → `CaptureInboxWriter` (same `.loci/inbox/`). Missing vault is a no-op. No EventKit/SafariServices types in LociCore. Proof flags `menuBarWired` / `safariExtractsPage` / `inboxNotIndex` / `indexInsideVault: false`.

macOS CI + shortcuts + VoiceOver (PR39) extras:

```bash
./scripts/demo-macos-ci.sh
# harness: http://127.0.0.1:5173/?panel=settings
```

GitHub Actions `macos-xcode` job (`runs-on: macos-14`) generates the Xcode project and builds iOS Simulator + macOS unsigned Debug. Linux cannot run `xcodebuild` — YAML is the Mac deliverable. macOS `.commands`: New Page ⌘N, Search ⌘K, Go to Today ⌘T, Quick Capture ⌘⇧N. VoiceOver identifiers on Daily / Editor / Search / Settings; typography uses `Font.custom(_:size:relativeTo:)`. Proof flags `macosCIWorkflowPresent` / `shortcutsCatalogued` / `voiceOverLabelsPresent` / `dynamicTypeScales` / `indexInsideVault: false`.

Type dashboard filter / sort / group (PR41) extras:

```bash
./scripts/demo-dashboard.sh
# harness: http://127.0.0.1:5173/?panel=types
```

The type dashboard list uses `IndexQuerying.execute(QueryDefinition)` for type + property equals + sort. Group-by is derived UI (`DashboardGrouping`) — never written into object markdown. Collection tabs stay a post-filter on vault `memberIDs`. User defaults persist only to `.loci/types/<slug>.json` (`TypeDashboardConfig`). Proof flags `filterApplied` / `sortApplied` / `groupApplied` / `resultsNotWrittenToMarkdown` / `indexInsideVault: false`.

Kanban by label (PR42) extras:

```bash
./scripts/demo-kanban.sh
# harness: http://127.0.0.1:5173/?panel=types
```

Board view lives in `App/Features/ObjectTypes/UI/TypeDashboardBoard.swift` (not a new feature module). Columns come from `DashboardGrouping` / `KanbanMove.columns` (select option order, or observed tags + Untagged). Moving a card updates YAML via `KanbanMove` + `ObjectServing.open`/`save` — body unchanged; layout is never written into markdown. `TypeDashboardConfig.defaultView` is `"list"` | `"board"` (decode default `"list"`). Proof flags `boardColumnsFromGroup` / `moveUpdatesVaultYAML` / `layoutNotWrittenToMarkdown` / `indexInsideVault: false`.

Weblink preview metadata cache (PR43) extras:

```bash
./scripts/demo-weblink-preview.sh
# harness: http://127.0.0.1:5173/?panel=safari
```

OG title/description/image are parsed from HTML (`OpenGraphHTMLParser`) and cached as JSON next to the index (Application Support) — **never** inside the vault and not written to weblink YAML. Fetch on weblink open / Refresh preview / after create; **never** on editor typing. Linux uses `FakeLinkPreviewFetcher` (fixture HTML, no live network). Proof flags `parsesOpenGraph` / `cacheOutsideVault` / `noFetchOnType` / `indexInsideVault: false`.

Unlinked mentions (PR44) extras:

```bash
./scripts/demo-unlinked-mentions.sh
# harness: http://127.0.0.1:5173/?panel=links
```

Other notes whose **plain body text** contains this object’s **title** but do not already wiki-link to it. Scanner is pure (`UnlinkedMentionScanner`); `IndexQuerying.unlinkedMentions` is bounded (50) and **never** runs on the typing path. Derived UI only — do not auto-rewrite markdown. Optional **Link** tap replaces the first occurrence with `[[id|title]]` via `ObjectServing.save`. Proof flags `detectsPlainTitle` / `ignoresExistingWikiLink` / `doesNotRewriteBody` / `indexInsideVault: false`. **Wave F (PR40–PR45) complete.**

Graph polish (PR45) extras:

```bash
./scripts/demo-graph.sh
# harness: http://127.0.0.1:5173/?panel=graph
```

Hide high-degree nodes (`GraphBuildOptions.hideDegreeAtOrAbove`) runs **before** caps, then drops their edges. `focusObjectID` isolates to the node + 1-hop neighbors. Hide/focus persist in memory (`AppServices`) — **not** vault markdown. Layout coordinates are never written into notes. Proof flags `hidesHighDegree` / `focusNeighbors` / `layoutNotWrittenToVault` / `indexInsideVault: false`. **Next is Wave G PR46** (daily date mentions / due tasks) — do not implement here.

Object-select picker (PR40) extras:

```bash
./scripts/demo-object-select.sh
# harness: http://127.0.0.1:5173/?panel=types
```

Inspector picker queries `IndexQuerying.linkCandidates` (Properties must not import `Features/Links`). Values are ObjectID UUID strings in YAML (`PropertyValue.objectSelect`); indexing merges them into the `links` table so backlinks/outgoing work. Do **not** rewrite the markdown body with `[[id]]`. Proof flags `pickerUsesIndexCandidates` / `storesObjectIDs` / `createsRealLinks` / `doesNotRewriteBody` / `indexInsideVault: false`.

Save proof under `evidence/prNN/`:

| Artifact | Example |
|---|---|
| Test log | `evidence/prNN/test.log` |
| Lint log | `evidence/prNN/lint.log` |
| Harness log | `evidence/prNN/harness.log` |
| Harness HTML / screenshot | `evidence/prNN/harness.html` or `harness.png` |

**Rule:** Agents must not finish a PR without evidence that lint + tests passed and the harness serves a page. No regressions vs prior green baseline.

### macOS (Xcode)

- Build/run the `Loci` app target (iOS Simulator + Mac).
- Still run `./scripts/test.sh` for package unit tests.
- Use DevHarness when validating shell chrome without a full Simulator loop.

## Branch / PR naming

```text
cursor/prNN-<short-name>-d2c1
```

Examples: `cursor/pr01-scaffold-d2c1`, `cursor/pr02-design-system-d2c1`.

PR title: `PRNN: <short feature name>`.

## After each PR

1. Update [`_agent/PREVIOUS_CONTEXT.md`](_agent/PREVIOUS_CONTEXT.md) with handoff notes (what landed, how to test, pitfalls).
2. Commit on the feature branch; push if `origin` exists.
3. Leave evidence under `evidence/prNN/`.

## Do not

- Put SQLite / index files inside the iCloud vault
- Import one feature folder from another
- Skip local vault fallback in designs
- Mark a PR done without green `lint` + `test` + harness proof
