# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR38 — Menu bar + Safari clipper

**Branch:** `cursor/pr38-menubar-safari-d2c1`  
**Based on:** `cursor/pr37-share-widget-d2c1`  
**Vault module:** `0.38.0-pr38`

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
