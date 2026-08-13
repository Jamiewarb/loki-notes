# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR41 — type dashboard filter / sort / group

**Branch:** `cursor/pr41-dashboard-d2c1`  
**Based on:** `cursor/pr40-object-select-d2c1`  
**Vault module:** `0.41.0-pr41`  
**Swift tests:** pending evidence  
**Playwright:** pending evidence

### Feature design
- Domain folder: `App/Features/ObjectTypes/` — `TypeDashboardView` + `TypeDashboardStore` / `TypeDashboardControls` / `TypeDashboardList`. **Does not import** `App/Features/Queries` (list uses `IndexQuerying.execute` + Core `QueryDefinition`). Existing Feature facade calls (Properties / Templates / Collections / Queries pinned) stay.
- Writes vault? yes — only `.loci/types/<slug>.json` dashboard fields (`defaultSort` / `defaultGroupBy` / `defaultFilterKey` / `defaultFilterText`). Does **not** rewrite object markdown or daily notes.
- Reads index? yes — `IndexQuerying.execute` (type + tags + PropertyFilter.equals + QuerySort). Archive hide + collection membership are post-filters. Typing in the editor does not wait on dashboard I/O.
- Protocols: `IndexQuerying`, `SchemaServing`. Shared protocol only — no new feature→feature imports.
- Core: `DashboardQuery`, `DashboardSort`, `DashboardGrouping`, `DashboardViewProof`. Property-id sort is in-memory (QuerySort stays title/dates).
- Demo: `scripts/demo-dashboard.sh` → `DevHarness/public/demo-dashboard/dashboard.json`. Harness: `?panel=types` dashboard section (`data-harness=dashboard-groups`).

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-dashboard.sh
./scripts/e2e.sh
./scripts/run-harness.sh   # ?panel=types — filterApplied / sortApplied / groupApplied / resultsNotWrittenToMarkdown
```

### Pitfalls
- Do not write filter/sort/group results into object or daily markdown. Only type schema JSON may change.
- Do not import Features/Queries for the dashboard list. Use `IndexQuerying.execute`.
- Collections are vault JSON — keep membership as a post-filter on `memberIDs`.
- `defaultSort` tokens: `title` / `titleAsc` / `updated` / `created` (and *Desc / *Asc). A property id falls back to title in SQL and sorts in memory.
- Group-by is derived UI. Kanban board is **PR42** — do not build a board.
- Stacked vault version assertions (`contains("pr40")`) must also accept `pr41`.
- Index stays in Application Support. Demo JSON `indexInsideVault: false`.

### Next

Wave F **PR42** kanban, stacked on PR41 (`cursor/pr41-dashboard-d2c1`). Parent opens the GitHub PR.

---

## PR40 — object-select picker (creates real links)

**Branch:** `cursor/pr40-object-select-d2c1`  
**Based on:** `cursor/pr39-macos-ci-d2c1`  
**Vault module:** `0.40.0-pr40`  
**Swift tests:** **366** green (was 353). **Playwright:** **85** green (was 82). Evidence: `evidence/pr40/`

### Feature design
- Domain folder: `App/Features/Properties/` — `ObjectSelectPickerView` + thin `ObjectSelectStore`. **Does not import** `App/Features/Links` (`LinkPickerView` is duplicated locally).
- Writes vault? yes — YAML frontmatter `PropertyValue.objectSelect([ObjectID strings])` via `ObjectServing.save`. Never absolute disk paths. Does **not** insert `[[wiki-links]]` into the body.
- Reads index? yes — `IndexQuerying.linkCandidates` (debounced, async). Typing in the editor body does not wait on picker I/O.
- Protocols: `IndexQuerying`, `ObjectServing`. Shared protocol only — no feature→feature imports.
- Core: `ObjectSelectProof`, `ObjectSelectID`. Markdown: `ObjectSelectLinks.wikiLinks` / `merge` (pure; XCTest needs no GRDB). Index: `ObjectIndexer.extract` merges object-select into `doc.wikiLinks` before `LinkIndexer.replaceLinks`.
- Demo: `scripts/demo-object-select.sh` → `DevHarness/public/demo-object-select/object-select.json`. Harness: `?panel=types` object-select section (`data-harness=object-select-picker`).

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-object-select.sh
./scripts/e2e.sh
./scripts/run-harness.sh   # ?panel=types — pickerUsesIndexCandidates / storesObjectIDs / createsRealLinks / doesNotRewriteBody
```

### Pitfalls
- Properties must not import `LinkPickerView`. Duplicate a small picker; share `IndexQuerying.linkCandidates`.
- Persist ObjectID `frontMatterIDString` (lowercase UUID / daily key), never vault-absolute paths.
- Merge object-select into the `links` table; do not rewrite daily/object markdown with `[[id]]`.
- Broken/missing IDs stay in YAML; outgoing can be broken (same as wiki-links).
- Picker search is async + debounced. Do not block editor typing on index/network.
- Stacked vault version assertions (`contains("pr39")`) must also accept `pr40`.
- Index stays in Application Support. Demo JSON `indexInsideVault: false`.

### Next

Wave F **PR41** dashboard filter/sort/group, stacked on PR40 (`cursor/pr40-object-select-d2c1`). Parent opens the GitHub PR.

---

## PR39 — macOS CI + keyboard shortcuts + VoiceOver / Dynamic Type

**Branch:** `cursor/pr39-macos-ci-d2c1`  
**Based on:** `cursor/pr38-menubar-safari-d2c1`  
**Vault module:** `0.39.0-pr39`  
**Swift tests:** **353** green (was 346). **Playwright:** **82** green (was 80). Evidence: `evidence/pr39/`

### Feature design
- Domain folder: `App/` shell (`.commands` + a11y on Daily / Editor / Search / Settings). No feature→feature imports.
- Writes vault? **no** for shortcuts/a11y/CI. New Page ⌘N uses existing `createPage()`. Go to Today uses `handleOpenURL(LociDeepLink.dailyTodayURL)` (ensure today + drain inbox). Capture ⌘⇧N opens `.capture`.
- Reads index? Search ⌘K already did. Typing still does not wait on index/network.
- Protocols: existing `Navigating` / `ObjectServing` / `DailyNoteServing`. Catalogs live in LociCore so Linux XCTest never imports SwiftUI.
- Core: `KeyboardShortcutCatalog`, `LociAccessibilityCatalog`, `LociDynamicTypeCatalog`, `MacOSCIProof`.
- CI: `.github/workflows/ci.yml` job `macos-xcode` on `macos-14` — xcodegen + unsigned Debug iOS Simulator (`iPhone 15`) + macOS. Linux jobs unchanged.
- Dynamic Type: `LociTypography.font` uses `Font.custom(_:size:relativeTo:)`. Numeric token Doubles unchanged.

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-macos-ci.sh
./scripts/e2e.sh
./scripts/run-harness.sh   # ?panel=settings — macosCIWorkflowPresent / shortcutsCatalogued / voiceOverLabelsPresent / dynamicTypeScales
```

### Pitfalls
- Linux **cannot** run `xcodebuild`. Do not fake a passing macos-14 log. YAML + catalogs are the proof.
- iPhone 15 destination is typical on macos-14 / Xcode 15.4. If a later runner drops the name, use `generic/platform=iOS Simulator`.
- Unsigned Debug flags belong on the workflow `xcodebuild` invocation first; extensions stay in `project.yml`.
- Do not invent a second capture inbox. ⌘⇧N opens the existing Capture route.
- Do not rewrite daily.md for VoiceOver chrome. Identifiers/labels are SwiftUI only.
- Index stays in Application Support. Demo JSON `indexInsideVault: false`.
- Stacked vault version assertions (`contains("pr38")`) must also accept `pr39`.

### Next

Wave F **PR40** object-select picker, stacked on PR39 (`cursor/pr39-macos-ci-d2c1`). Parent opens the GitHub PR.

---

## PR38 — Menu bar + Safari clipper

**Branch:** `cursor/pr38-menubar-safari-d2c1`  
**Based on:** `cursor/pr37-share-widget-d2c1`  
**Vault module:** `0.38.0-pr38`  
**Swift tests:** **346** green (was 336). **Playwright:** **80** green (integrations 10 + full suite). Evidence: `evidence/pr38/`

### Feature design
- Domain folder: `App/Platform/macOS/MenuBarCapture`, `App/Platform/macOS/SafariExtension` (no feature→feature imports)
- Writes vault? yes — `.loci/inbox/*.json` only from the extension / vault-only menu bar. Main app `appendToToday` when CaptureServing is ready.
- Reads index? **no** — Safari and vault-only menu bar must not open SQLite.
- Protocols: `CaptureServing.appendToToday`; `VaultServing` via `CaptureInboxWriter` / `SafariClipInbox`; `Navigating` / `loci://daily/today`.
- Pure helpers in LociCore: `SafariClipFactory.clip(fromUserInfo:)` (`url` / `title` / `selection`), `MenuBarCaptureFactory`, `MenuBarSafariProof`.
- Apple: `MenuBarCaptureController.install()` from `LociApp` (`#if os(macOS)`). Safari `messageReceived` maps JS payload then enqueues. Linux stubs stay.
- Missing vault → no crash (`SafariClipInbox.enqueueFromUserInfo` returns nil).

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-safari.sh
./scripts/demo-menubar.sh
cd DevHarness && npx playwright test e2e/integrations.spec.ts
./scripts/run-harness.sh   # ?panel=safari — menuBarWired / safariExtractsPage / inboxNotIndex
```

### Pitfalls
- Reuse `.loci/inbox/` — do not invent a second inbox.
- Extension process must never import LociIndex or open `index.sqlite`.
- No EventKit / SafariServices types in LociCore. Mapper tests pass `[String: Any]` userInfo only.
- Menu bar prefers `appendToToday`; vault-only (capture nil) enqueues. Missing vault is a no-op.
- `menuBarWired` / `safariExtractsPage` are factory + URL proofs on Linux (“code present” + mapping), not a live status-item / Safari run.
- Linux SPM tests stay green without AppKit / SafariServices.

### Next

Stacked after PR37. Parent opens the GitHub PR.

---

## PR37 — Share extension + Widget

**Branch:** `cursor/pr37-share-widget-d2c1`  
**Based on:** `cursor/pr36-eventkit-d2c1`  
**Vault module:** `0.37.0-pr37`  
**Swift tests:** **336** green (was 325). **Playwright:** **79** green (`work.spec.ts` capture proofs + full suite). Evidence: `evidence/pr37/`

### Feature design
- Domain folder: `App/Platform/iOS/ShareExtension`, `App/Platform/iOS/Widget` (no feature→feature imports)
- Writes vault? yes — `.loci/inbox/*.json` only from the extension process. Main app drains on foreground / `loci://` open.
- Reads index? **no** — Share and Widget must not open SQLite.
- Protocols: `VaultServing` via `CaptureInboxWriter`; `Navigating` for `loci://daily/today` and `loci://capture`.
- Pure helpers in LociCore: `ShareInboxFactory` (text-only → append; URL+title → create Page), `LociDeepLink`, `ShareWidgetProof`.
- Vault resolve: `CaptureVaultResolver` — ubiquity then local Documents; `nil` instead of crash.
- Apple: UIKit extraction stays in `ShareViewController` (`#if canImport(UIKit)`). WidgetKit + AppIntents in `LociWidgets.swift`. Linux `#else` stub stays.
- URL scheme `loci` registered on the main app. `LociApp` drains inbox on `scenePhase == .active`.

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-capture.sh
./scripts/demo-share-widget.sh
cd DevHarness && npx playwright test e2e/work.spec.ts
./scripts/run-harness.sh   # ?panel=capture — shareExtractsText / widgetOpenToday / inboxNotIndex
```

### Pitfalls
- Extension process must never import LociIndex or open `index.sqlite`.
- Share extension Documents sandbox ≠ main app Documents unless iCloud ubiquity (same container) is available. Local fallback still must not crash.
- `ShareInboxFactory` is the only mapping logic — do not fork a second inbox format.
- Widget Quick add enqueues when vault resolves; otherwise tell the user to open `loci://capture`.
- Linux SPM tests stay green without UIKit / WidgetKit / AppIntents.
- `shareExtractsText` / `widgetOpenToday` are factory + URL proofs on Linux (“code present” + mapping), not a Simulator share-sheet run.

### Next

Stacked after PR36. Parent opens the GitHub PR.

---

## PR36 — EventKit

**Branch:** `cursor/pr36-eventkit-d2c1`  
**Based on:** `cursor/pr35-media-pickers-d2c1`  
**Vault module:** `0.36.0-pr36`  
**Swift tests:** **325** green (was 315). **Playwright:** **79** green (integrations + architecture: 12). Evidence: `evidence/pr36/`

### Feature design
- Domain folder: `App/Features/AppleIntegrations/` (existing)
- Writes vault? listing events: **no**. Meeting create: `objects/meeting/` via ObjectServing. Reminders pull: today’s daily only when settings enabled + Sync.
- Reads index? Meeting idempotency via `event-id`; reminders push via `IndexQuerying.tasks`
- Protocols: `AppleCalendarServing` / `AppleRemindersServing` are now injectable store protocols (`calendarAuthorizationStatus`, `requestCalendarAccess`, events / reminders / upsert). `AppleIntegrationService` takes `any` store.
- Apple: `EventKitCalendarStore` / `EventKitRemindersStore` behind `#if canImport(EventKit)` in Vault. Maps `EKEvent` fields through `AppleCalendarEventMapper` (Core, no EventKit types).
- Linux / tests: `FakeAppleCalendarStore` / `FakeAppleRemindersStore`. Denied → empty list, daily.md unchanged, no crash.
- Info.plist: `NSCalendarsUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSRemindersUsageDescription`, `NSRemindersFullAccessUsageDescription`.

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-apple.sh
./scripts/e2e.sh
./scripts/run-harness.sh   # ?panel=apple — eventKitWired / linuxUsesFakes / dailyUnchanged
```

### Pitfalls
- Do not put EventKit types in LociCore. Mapper tests must not `import EventKit`.
- Listing events is chrome — never rewrite daily.md. Meeting create is the vault write.
- Reminders pull/push still require settings enabled **and** an explicit Sync tap.
- Denied EventKit → empty list + permission copy, not a fake fallback of sample events.
- `eventKitWired` / `linuxUsesFakes` are compile-time proof flags (`canImport(EventKit)`). Linux demo always uses injected fakes.
- `requestFullAccessToEvents` / `requestFullAccessToReminders` need the iOS 17 full-access Info.plist keys.
- Linux SPM tests stay green without EventKit.

### Next

Stacked after PR35. Parent opens the GitHub PR.

---

## PR35 — Media pickers

**Branch:** `cursor/pr35-media-pickers-d2c1`  
**Based on:** `cursor/pr34-pins-d2c1`  
**Vault module:** `0.35.0-pr35`  
**Swift tests:** **315** green (was 311). **Playwright:** **79** green (was 78). Evidence: `evidence/pr35/`

### Feature design
- Domain folder: `App/Features/Media/`
- Writes vault? yes — `media/images|files` via existing `MediaServing` (copy, never blobs in SQLite)
- Reads index? no
- Protocols: `MediaServing` (unchanged surface); `MediaPickerProof` / `MediaPickerNotes` in LociCore so tests never import PhotosUI
- iOS: real `PhotosPicker` (`#if canImport(PhotosUI)`), load `Data`, `attach`, insert markdown via `onInsertedMarkdown`
- macOS: `.onDrop` of files/images on attach controls + open editor; file URL/data → `attach`; never persist absolute paths
- Linux: demo-byte buttons + `attach(fileURL:)`. `#else` stubs compile without PhotosUI
- Reuses `ImageObjectFactory` / `MediaInserter` — no second media store

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-media.sh
./scripts/demo-media-pickers.sh
./scripts/e2e.sh
./scripts/run-harness.sh   # ?panel=media — photosPickerWired / dragDropWired
```

### Pitfalls
- Do not put PhotosUI or EventKit types in LociCore.
- Dropped Finder paths must not appear in note markdown — only vault-relative `media/…`.
- Index stays in Application Support; trash media does not rewrite notes.
- Linux cannot drive PhotosPicker / SwiftUI drop; XCTest + DevHarness prove the attach path.
- `photosPickerWired` / `dragDropWired` are “code present” flags on Linux fixtures.

### Next

Stacked after PR34. Parent opens the GitHub PR.

---

## PR34 — Pins

**Branch:** `cursor/pr34-pins-d2c1`  
**Based on:** `cursor/pr33-e2e-harness-d2c1`  
**Vault module:** `0.34.0-pr34`  
**Swift tests:** **311** green (was 303). **Playwright:** **78** green (was 77). Evidence: `evidence/pr34/`

### Feature design
- Domain folder: `App/Features/Pins/`
- Writes vault? yes — `.loci/space.json` field `pins` (ObjectID strings in order). Cap 24.
- Reads index? yes — title/type/path only (`IndexQuerying.object` then `ObjectServing.open`). Missing → “Missing pin”, still unpin-able.
- Protocols: `PinServing` (SchemaStore), `IndexQuerying`, `ObjectServing`, `Navigating`
- Events: none published; sidebar reloads on `pinRefreshNonce`
- Not the index: pins sync via iCloud because they live in space.json

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-pins.sh
./scripts/e2e.sh
./scripts/run-harness.sh   # sidebar Pinned section; data-harness=pin-row
```

### Pitfalls
- Do not store pins in SQLite. space.json is truth.
- Unpin of an unknown id is a no-op (no error).
- Pin of an already-pinned id is idempotent (order unchanged).
- Daily notes are allowed.
- Linux: SwiftUI Pins UI is not compiled; XCTest + DevHarness + Playwright must be green.
- Playwright: pin rows are enabled; do not expect the old disabled Inbox stub.

### Next

Stacked after PR33. Parent opens the GitHub PR.

---

## Takeover (2026-08-13)

`HANDOFF.md` from PR29 was absorbed here and deleted. Durable facts:

- **Loci** (repo `Jamiewarb/loki-notes`): Capacities-style PKM for macOS + iOS. Vault (markdown + YAML + media) in iCloud Drive is source of truth; disposable SQLite index lives only in Application Support.
- Waves A–C (**PR01–PR29**) are done as stacked GitHub PRs #1–#29. Merge in numeric order; each PR’s base is the previous branch.
- **Wave D (PR30–PR32)** — **complete** (AI + Apple Calendar/Reminders + Safari clipper).
- Swift 6.2: `export PATH=/opt/swift/usr/bin:$PATH`. Linux tests SPM packages + DevHarness only (`App/` SwiftUI is Apple).
- Hard rules: vault = truth; never put the index in the vault; no feature→feature imports; do not rewrite daily notes for derived UI; AI must not upload the vault unless the user opts in; typing must not wait on index/network.

Stacked PRs already opened: https://github.com/Jamiewarb/loki-notes/pull/1 … https://github.com/Jamiewarb/loki-notes/pull/33

Branch naming: `cursor/prNN-<short-name>-d2c1`.

---

## PR33 — Playwright feature harness

**Branch:** `cursor/pr33-e2e-harness-d2c1`  
**Based on:** `cursor/pr32-safari-d2c1`  
**Swift tests:** **303** green. **Playwright:** **77** green. Evidence: `evidence/pr33/`

### What landed

- Skill: `.cursor/skills/loci-playwright-feature-tests/SKILL.md` (locators, waits, what not to test)
- DevHarness Playwright: `playwright.config.ts` (Chromium, `testIdAttribute: data-harness`, Vite `webServer`, never `networkidle`)
- Helpers: `DevHarness/e2e/helpers.ts` (`gotoPanel`, `harness`, `PANEL_IDS`)
- Specs mapped to `docs/PLAN.md`: `shell`, `daily`, `types`, `editor`, `retrieval`, `work`, `vault`, `integrations`, `architecture`
- `./scripts/e2e.sh` + CI harness-smoke runs Playwright
- Gallery panel uses the shared `destination` contract
- Editor demo JSON restored `queryEmbed` so “query results not stored in body” is visible

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/e2e.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173
```

### Pitfalls

- Linux tests DevHarness, not SwiftUI. Do not duplicate XCTest in the browser.
- Vite HMR websocket: never `waitForLoadState('networkidle')`.
- Panels `fetch()` then replace `innerHTML` — wait on destination/proof locators.
- Fixture dates are frozen (e.g. `2026-08-13`); do not assert against `Date.now()`.
- Playwright 1.62 has no `test.each` — parametrize with `for...of`.
- `getByRole('button', { name: 'Daily' })` also matches Calendar (“Daily notes”) — scope to the Navigate nav.

### Next

Unplanned after Wave D. Optional later: Readwise, plugins, Windows — not scheduled.

---

## Wave D (PR30–PR32) — complete

**Milestone:** Integrations (v1.2). Optional later work (Readwise, plugins, Windows) is **not scheduled**.

---

## PR32 — Safari web clipper

**Branch:** `cursor/pr32-safari-d2c1`  
**Based on:** `cursor/pr31-apple-integrations-d2c1`  
**Vault module:** `0.32.0-pr32`  
**Tests:** **303** green (was 291). Evidence: `evidence/pr32/`

### What landed

- **Core:** `CaptureSource.safari`; `SafariClip` / `SafariClipDestination` / `SafariClipFactory`; `SafariClipServing`; `ObjectType.builtInWeblink` + `ObjectTypeID.weblink`; `Route.safari`; Weblink slug reserved
- **Vault:** `SafariClipService` (enqueue via Capture inbox; clip → today / Weblink); `CaptureService.applyCreate` sets `url` + `clipped-from` for weblink; SchemaStore seeds Weblink + `objects/weblink/`; `loci-safari-demo`
- **App:** `Features/SafariClipper/` panel; `App/Platform/macOS/SafariExtension/` stub; AppServices `safariClipper`; Route/AppRoute/Detail/Inspector/Settings wiring; project.yml `LociSafariExtension`
- **Harness:** `?panel=safari` + `demo-safari/safari.json`
- **Versions:** Vault `0.32.0-pr32`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-safari.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=safari
```

### Pitfalls

- Reuse Capture inbox (`.loci/inbox/`) — do not invent a second inbox
- Extension writes vault JSON only; main app drains + indexes
- Features talk `SafariClipServing` / `CaptureServing` / `ObjectServing` protocols only

### Next

Wave D complete. Follow-on **PR33** adds Playwright feature tests against DevHarness (`cursor/pr33-e2e-harness-d2c1`). Optional later: Readwise, plugins, Windows — not scheduled.

---

## PR31 — Apple Calendar and Reminders

**Branch:** `cursor/pr31-apple-integrations-d2c1`  
**Based on:** `cursor/pr30-ai-d2c1`  
**Tests:** **291** green. Evidence: `evidence/pr31/`

### What landed

- **Core:** `AppleCalendarEvent` / `AppleReminderItem` / `AppleIntegrationSettings`; `AppleEventDayFilter`, `MeetingObjectFactory`, `ReminderTaskMapper`; `FakeAppleCalendarStore` / `FakeAppleRemindersStore`; protocols `AppleCalendarServing` / `AppleRemindersServing` / `AppleIntegrationServing`; `ObjectType.builtInMeeting` + `ObjectTypeID.meeting`; `Route.apple`
- **Vault:** `AppleIntegrationService` (Application Support `Loci/apple/` settings); Meeting create via ObjectServing (idempotent on `event-id`); Reminders pull/push only when enabled + explicit; `loci-apple-demo`; SchemaStore seeds Meeting
- **App:** `Features/AppleIntegrations/` — DailyEventsPanel (inspector chrome), RemindersSyncView (Settings + Route.apple); AppServices always wires AppleIntegrationService with fakes
- **Harness:** `?panel=apple` + `demo-apple/apple.json`
- **Versions:** Vault `0.31.0-pr31`; Markdown/Index stay `0.2.0-pr30`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-apple.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=apple
```

---

## PR30 — AI assist

**Branch:** `cursor/pr30-ai-d2c1`  
**Tests:** **281** green. Evidence: `evidence/pr30/`

See `evidence/pr30/`. On-device heuristics by default; BYOK never uploads without opt-in.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR29 done · Wave D PR30–PR32 **complete**
