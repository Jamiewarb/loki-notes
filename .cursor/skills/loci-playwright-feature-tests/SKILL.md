---
name: loci-playwright-feature-tests
description: Write Playwright feature tests for Loci DevHarness. Use when adding, changing, or reviewing e2e/feature tests, Playwright specs, data-harness selectors, or CI browser tests against the product spec.
---
# Loci Playwright Feature Tests

Use this skill whenever you write or change Playwright tests. Canonical product spec: [`docs/PLAN.md`](../../../docs/PLAN.md) Parts 5–6, 10, success criteria, and architecture hard rules. Feature boundaries: [loci-feature-architecture](../loci-feature-architecture/SKILL.md).

Linux cannot drive SwiftUI. These tests run against **DevHarness** (`http://127.0.0.1:5173`), the fixture-driven browser shell. Swift XCTest (`./scripts/test.sh`) remains the package unit suite. Do not treat Playwright as a second unit runner.

## Research summary (apply these)

Sources: [Playwright best practices](https://playwright.dev/docs/best-practices), locators, isolation, traces; Kent C. Dodds testing trophy (“write tests, not too many, mostly integration”).

### Playwright

1. **Test user-visible behavior**, not implementation (CSS classes, innerHTML structure, function names).
2. **Isolate every test.** Fresh browser context; no shared mutable state; a test must pass alone.
3. **Locator priority:** `getByRole` → `getByLabel` / `getByPlaceholder` → `getByText` → `getByTestId` → CSS/XPath last.
4. **Web-first assertions only:** `await expect(locator).toBeVisible()` retries. Never `expect(await locator.isVisible()).toBe(true)`.
5. **No hard waits.** Ban `waitForTimeout`. Ban `waitForLoadState('networkidle')` (hangs on Vite HMR / websockets).
6. **Wait on the thing you assert** (element state or a specific response), not “the network went quiet.”
7. **Fixtures over Page Object Model** for a small suite. Fixtures represent *actions* (`gotoPanel('daily')`), not wrapped Playwright APIs.
8. **Traces on CI retry**, not on every run (`trace: 'on-first-retry'`). Debug flakes with the trace viewer before rewriting tests.
9. **Chromium-only on CI** unless the product is a multi-browser web app. Install `chromium --with-deps` only.
10. **Lint tests:** TypeScript; no floating promises. `forbidOnly` on CI.

### Testing apps like Loci (local-first PKM + Linux harness)

Loci’s confidence stack is already a trophy, not a pyramid:

| Layer | Where | What it proves |
|---|---|---|
| Static | `swift-format` / `tsc` | Types, crash-stub bans |
| Unit | `./scripts/test.sh` (XCTest) | Markdown round-trip, index, vault I/O, heuristics |
| Feature (this skill) | Playwright → DevHarness | Shell + panels render spec proofs from committed fixtures |
| Out of reach on Linux | Xcode / Simulator | Real SwiftUI, iCloud two-device sync |

Playwright here is **feature testing of the Linux-visible product surface**, not a clone of the Mac app. DevHarness panels `fetch()` committed JSON under `DevHarness/public/demo-*` then replace `innerHTML`. Tests must:

- Assert **spec contracts** the user (and agents) can see: nav, destinations, proof flags (`index inside vault: never`, `daily .md unchanged`).
- **Not** re-implement Swift unit tests in the browser.
- **Not** screenshot-compare (fonts, DPI, motion). Evidence PNGs are manual.
- **Not** drive `App/` SwiftUI.

Prefer a few tests per domain that would fail if a spec hard rule broke, over exhaustive clicks.

## Hard rules for this repo

1. **Harness, not SwiftUI.** Target `DevHarness`. If a behavior only exists in `App/Features/**/*.swift`, cover it with XCTest fakes — do not pretend Playwright hit it.
2. **Configure `testIdAttribute: "data-harness"`.** That attribute is the explicit Linux proof contract. Use `getByTestId(...)` for proof nodes. Use `getByRole` for user actions (nav buttons, calendar days, tabs).
3. **Never CSS/XPath on layout classes** (`.vault-card`, `.shell`, `.graph-node`). Those change with design tokens.
4. **Wait for loaded panels.** Every panel paints a loading node then replaces the tree. After `goto`, assert `[data-harness=destination][data-destination=<id>]` (or the panel’s proof node) — not that loading text vanished for one tick.
5. **Use locators, never ElementHandles.** `innerHTML` replacement detaches nodes; locators re-query.
6. **Read frozen fixtures.** Demo JSON dates (e.g. `2026-08-13`) are from the last `scripts/demo-*.sh` run. Do not assert against `new Date()`. Do not require re-running demo scripts in Playwright if `public/demo-*` is committed.
7. **Do not assert `moduleVersion` strings.** They bump every PR.
8. **Do not assert graph/calendar pixel layout** (SVG `x`/`y`, force-directed positions, CSS motion).
9. **Do not visual-regression screenshot.** Pixel diffs are flaky on Linux CI.
10. **One independent test per behavior.** `test.each` for “every panel loads” is fine (each row is isolated). Do not click all 19 nav items in a single serial test.
11. **Architecture proofs belong in tests**, not comments: `indexInsideVault === false`, `dailyUnchanged`, `uploadRefusedWithoutOptIn`, credentials/settings outside vault.
12. **No retries as a flake fix.** If a test needs `retries` locally, the wait is wrong.

## Suite layout

```text
DevHarness/
  playwright.config.ts      # chromium, baseURL, webServer=vite, trace on-first-retry
  e2e/
    helpers.ts              # gotoPanel, harness, expectPanelLoaded
    shell.spec.ts           # Part 6 navigation + deep links
    daily.spec.ts           # 5.1 daily + created-today
    types.spec.ts           # 5.3–5.4 PARA, types, templates, collections, queries, convert
    editor.spec.ts          # 5.7 editor + query embed
    retrieval.spec.ts       # 5.5–5.6 links, graph, tags, search
    work.spec.ts            # 5.8 tasks, media, calendar, capture
    vault.spec.ts           # 5.2 markdown, import, settings/sync
    integrations.spec.ts    # Wave D: AI, Apple, Safari
    architecture.spec.ts    # Part 10 hard rules via request + a couple of rendered proofs
```

Helpers (business actions, not POM classes):

```ts
// helpers.ts — sketch
export async function gotoPanel(page: Page, id: PanelId) {
  await page.goto(`/?panel=${id}`); // default waitUntil: load — never networkidle
  await expect(page.getByTestId("destination")).toHaveAttribute("data-destination", id);
}

export function harness(page: Page, id: string) {
  return page.getByTestId(id);
}
```

Playwright config sketch:

- `testDir: "./e2e"`
- `fullyParallel: true` (fixtures are static GET JSON; no shared writes)
- `retries: process.env.CI ? 2 : 0` with `trace: "on-first-retry"`
- `use.testIdAttribute: "data-harness"`
- `webServer`: `npx vite --host 127.0.0.1 --port 5173`, `reuseExistingServer: !process.env.CI`
- Projects: Chromium only

## What to test vs what not to test

### Worth testing (would catch a spec regression)

| Spec | Signal in the harness |
|---|---|
| Part 6 shell | Sidebar + detail + inspector present; default panel is Daily; `?panel=` deep link; primary nav roles (Daily, Tasks, Search, Types, Settings) switch `data-panel` |
| 5.1 Daily | Path `daily/YYYY-MM-DD.md`; idempotent ensure; prev/today/next from fixture; created-today list; click a row reveals detail; proof **daily .md unchanged** |
| 5.2 Markdown / import | Round-trip pane visible; import proof flags; vault paths look like files not a DB |
| 5.3–5.4 Types | PARA starter names; Book type / collections tabs; convert refuses daily |
| 5.5 Links / graph | Backlinks list; graph has nodes; **click a node** updates selection text (interaction exists) |
| 5.6 Tags / queries | Aliases; pinned query results; query embed **does not store results in body** |
| 5.7 Editor | Rich block kinds listed; slash simulation list; not a contenteditable workout |
| 5.8 Tasks / media / calendar / capture | Today/open lists; media paths under `media/`; calendar day click → `daily/<key>.md`; capture inbox drain |
| Wave D | AI: upload refused without opt-in; credentials outside vault. Apple: daily unchanged by event chrome. Safari: same `.loci/inbox`, weblink url |
| Part 10 | Scan demo JSON with `request` (no browser): every `indexInsideVault` is `false` |

### Do not test (flaky, duplicated, or false confidence)

- SwiftUI TabView / NavigationSplitView / Dynamic Type / VoiceOver (not in DevHarness).
- iCloud two-device success criterion #1 (Mac book template → iPhone). XCTest + local vault only.
- **Typing in a real editor** — harness shows AST HTML preview, not EditorSession.
- **Checkbox toggles that persist** — fixture already recorded `pageToggleCompleted`; the harness does not write a vault.
- Graph force layout coordinates, calendar cell pixel size, design-gallery motion replay.
- Exact marketing copy, kicker text, `moduleVersion`, long `note` fields.
- External sites (`example.com` URLs in fixtures).
- Generating fixtures (`scripts/demo-*.sh`) inside Playwright — that is Swift. Missing JSON should fail fast with “run demo-X.sh”.
- Multi-browser matrix (Firefox/WebKit). Product is Apple native; Chromium is the Linux agent browser.
- Visual snapshots / screenshot diffs.
- `networkidle`, `waitForTimeout`, `locator.first()` on ambiguous lists (scope with `filter({ hasText })` instead).

## Flake sources specific to DevHarness

1. **Async `fetch` + `innerHTML` replace.** Always assert a post-load locator. Loading text is a trap if you snapshot too early.
2. **Vite HMR websocket.** `networkidle` may never fire. Use default `load` + element assertions.
3. **Inspector loads in parallel with detail** (daily created-today inspector). Assert inspector nodes separately; do not assume they exist at the same tick as the daily body.
4. **Strict-mode collisions.** Many `[data-harness=destination]` must not exist; after nav, only one. Graph nodes are many — filter by `data-object-id` or title text.
5. **Pinned Inbox stub is `disabled`.** Do not click it.
6. **Date drift.** Fixtures are frozen; “today” in JSON may not equal CI’s calendar day. Read `dayNav.today` from the fixture or the rendered `daily-today` node.
7. **Parametrized panel smoke.** Keep assertions to “destination appeared / not stuck on Loading”. Panel-specific proofs live in domain specs.

If a test flakes: open the trace, confirm whether the panel was still on `*-status` loading, then tighten the wait. Do not add sleep.

## Authoring checklist

Copy before writing a spec:

```markdown
### Feature test: <domain>
- Spec slice: (PLAN.md § …)
- Panel: `?panel=<id>`
- User-visible assertions: …
- Proof flags / JSON: …
- Interactions (only if the harness handles click/keydown): …
- Explicitly not testing: …
```

Then:

- [ ] `gotoPanel` + web-first `expect`
- [ ] `getByRole` for buttons/tabs; `getByTestId` for proof contracts
- [ ] No CSS layout selectors, no `networkidle`, no `waitForTimeout`
- [ ] No `moduleVersion`, no screenshot, no layout coordinates
- [ ] Test name states the spec rule (“created-today does not rewrite daily.md”)
- [ ] Passes in isolation (`npx playwright test e2e/foo.spec.ts -g "name"`)

## Commands

```bash
cd DevHarness
npx playwright install --with-deps chromium
npx playwright test
npx playwright test --ui          # local debug
npx playwright show-report
```

Repo wrapper (once added): `./scripts/e2e.sh`.

Still required every PR: `./scripts/lint.sh` and `./scripts/test.sh`.
