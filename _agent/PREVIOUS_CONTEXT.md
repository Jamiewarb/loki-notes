# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR03 — App shell navigation (current)

**Branch:** `cursor/pr03-app-shell-d2c1`  
**Based on:** `cursor/pr02-design-system-d2c1` @ `0c17eda`

### What landed

- **`LociCore.Route`:** primary destinations Daily / Search / Types / Settings + `designGallery` + `object(ObjectID)`; titles/icons/subtitles; `primaryDestinations`
- **`AppServices`:** conforms to `Navigating`; owns `selectedRoute` (default `.daily`)
- **AppShell (Apple sources under `App/Features/AppShell/`):**
  - `AppRoute.swift` — sidebar destinations + pin stub
  - `AppShellView.swift` — macOS `NavigationSplitView` (sidebar | detail | inspector); iOS `TabView` + stack + inspector sheet
  - `SidebarView.swift` — hero **Loci** brand, Navigate / Pinned / Studio
  - `DetailHostView.swift` + placeholders; Design gallery hosted for `.designGallery`
  - `InspectorHostView.swift` — contextual trailing column
  - `LociAtmosphereBackground.swift` (extracted from gallery)
- **`LociApp`:** roots to `AppShellView` (not gallery alone)
- **DevHarness:** sectioned sidebar; destination panels switch for Daily/Search/Types/Settings/Design; `?panel=` for headless proof
- **Tests:** +5 `RouteTests` → **19** package tests (was 14)
- Evidence: `evidence/pr03/` (lint, test, harness.log/html/png/dom, `screenshots/harness-*-{png,dom.html}`)

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=daily|search|types|settings|gallery
```

### Pitfalls for PR04

- App/ SwiftUI is **not** in Linux SPM — DevHarness remains visual proof for shell chrome.
- Headless Chrome may hang after screenshot/dump-dom — use `timeout` + unique `--user-data-dir`.
- Index must never live inside the vault (Application Support only).
- Local Documents fallback is mandatory when iCloud is unavailable.
- Do not implement real daily notes / editor / indexer here — VaultIO only.

### Next: PR04 — VaultIO + iCloud Documents

- Ubiquity container + local sandbox fallback
- Vault skeleton (`.loci/space.json`), coordinated read/write
- `NSMetadataQuery` events + conflicted-copy hook
- Settings “Create vault” demo path
- Branch: `cursor/pr04-vault-io-d2c1`
- Wire concretes into `AppServices`; keep features on `VaultServing` only

---

## PR02 — Design system

**Branch:** `cursor/pr02-design-system-d2c1`  
**Based on:** `cursor/pr01-scaffold-d2c1` @ `a01d4ac`

### What landed

- **`LociDesignSystem`** fleshed out (no longer a stub):
  - **Tokens (Linux-testable, no SwiftUI):** `Tokens/Colors.swift`, `Typography.swift`, `Spacing.swift`, `Radius.swift`, `Elevation.swift`
  - **Components (`#if canImport(SwiftUI)`):** `LociButton`, `LociTextField`, `LociListRow`, `LociEmptyState`, `LociIcon`, `LociDivider`
  - **Motion:** `Motion/Transitions.swift` — brand rise, soft appear, panel transition (`lociAppear`, `lociPanelTransition`)
- **Apple gallery:** `App/Features/AppShell/DesignGalleryView.swift`; atmosphere shared with shell
- **DevHarness:** CSS vars `--loci-*` mirror tokens; Design nav + `DesignGalleryPanel.ts`
- **Tests:** `LociDesignSystemTests` (6 cases). PR02 total was **14**; PR03 raised to **19**
- Evidence: `evidence/pr02/`

### Design direction — **editorial-sage**

| Token | Value |
|---|---|
| Ink | `#1A2421` |
| Paper | `#E8EFE8` |
| Accent (moss-teal) | `#0F6B5C` |
| Accent soft | `#C5E4DC` |
| Display font | Fraunces |
| Body font | Source Sans 3 |
| Spacing scale | 2, 4, 8, 12, 16, 24, 32, 48 |

Avoided: purple-on-white, cream+terracotta cliché, dark-mode-first.

---

## PR01 — Scaffold

**Branch:** `cursor/pr01-scaffold-d2c1`

### What exists

- Git repo initialized; SPM monorepo via root `Package.swift`
- Packages: `LociCore`, `LociVault` / `LociMarkdown` / `LociIndex` stubs; DesignSystem (PR02); AppShell (PR03)
- Protocols in Core: VaultServing, SchemaServing, ObjectServing, IndexQuerying, IndexUpdating, Navigating, SyncStatusProviding + `Route`
- Scripts: `scripts/lint.sh`, `scripts/test.sh`, `scripts/run-harness.sh`
- Docs: `README.md`, `AGENTS.md`, CI workflow `.github/workflows/ci.yml`
- Evidence: `evidence/pr01/`

### Swift on Linux

- Swift **6.2 (swift-6.2-RELEASE)** at `/opt/swift`
- `export PATH=/opt/swift/usr/bin:$PATH`
