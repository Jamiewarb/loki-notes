# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Takeover (2026-08-13)

`HANDOFF.md` from PR29 was absorbed here and deleted. Durable facts:

- **Loci** (repo `Jamiewarb/loki-notes`): Capacities-style PKM for macOS + iOS. Vault (markdown + YAML + media) in iCloud Drive is source of truth; disposable SQLite index lives only in Application Support.
- Waves A–C (**PR01–PR29**) are done as stacked GitHub PRs #1–#29. Merge in numeric order; each PR’s base is the previous branch.
- **Wave D (PR30–PR32)** — **complete** (AI + Apple Calendar/Reminders + Safari clipper).
- Swift 6.2: `export PATH=/opt/swift/usr/bin:$PATH`. Linux tests SPM packages + DevHarness only (`App/` SwiftUI is Apple).
- Hard rules: vault = truth; never put the index in the vault; no feature→feature imports; do not rewrite daily notes for derived UI; AI must not upload the vault unless the user opts in; typing must not wait on index/network.

Stacked PRs already opened: https://github.com/Jamiewarb/loki-notes/pull/1 … https://github.com/Jamiewarb/loki-notes/pull/31

Branch naming: `cursor/prNN-<short-name>-d2c1`.

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

Wave D complete. No further stacked PRs in the plan. Optional later: Readwise, plugins, Windows — not scheduled.

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
