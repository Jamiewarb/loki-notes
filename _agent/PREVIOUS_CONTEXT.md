# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR02 — Design system (current)

**Branch:** `cursor/pr02-design-system-d2c1`  
**Based on:** `cursor/pr01-scaffold-d2c1` @ `a01d4ac`

### What landed

- **`LociDesignSystem`** fleshed out (no longer a stub):
  - **Tokens (Linux-testable, no SwiftUI):** `Tokens/Colors.swift`, `Typography.swift`, `Spacing.swift`, `Radius.swift`, `Elevation.swift`
  - **Components (`#if canImport(SwiftUI)`):** `LociButton`, `LociTextField`, `LociListRow`, `LociEmptyState`, `LociIcon`, `LociDivider`
  - **Motion:** `Motion/Transitions.swift` — brand rise, soft appear, panel transition (`lociAppear`, `lociPanelTransition`)
- **Apple gallery:** `App/Features/AppShell/DesignGalleryView.swift` (+ `LociAtmosphereBackground`); `LociApp` roots to the gallery
- **DevHarness:** CSS vars `--loci-*` mirror tokens; **Design** nav + `src/panels/DesignGalleryPanel.ts`
- **Tests:** `LociDesignSystemTests` (6 cases) — spacing scale, hex palette, typography families, accent moss range. Total package tests: **14** (was 8 in PR01)
- Evidence: `evidence/pr02/` (`lint.log`, `test.log`, `harness.log`, `harness.html`, `harness-dom.html`, `harness.png`)

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

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173 — open Design panel
```

### Pitfalls for PR03

- SwiftUI components compile only where SwiftUI exists; **tokens stay pure Swift** for Linux CI.
- App target is still **not** in SPM — DesignGalleryView is Apple-only; use DevHarness for Linux visual proof.
- Keep CSS `--loci-*` hexes in sync when changing `LociColors` / spacing.
- Do not start vault I/O here — PR04 owns that.
- Headless Chrome may hang after `--screenshot` / `--dump-dom` in this environment; prefer `timeout` + unique `--user-data-dir`.

### Next: PR03 — App shell navigation

- Shared nav model: macOS `NavigationSplitView`, iOS tab/stack placeholders
- Destinations: Daily, Search, Types, Settings (+ pin stub)
- Reuse `LociListRow`, `LociAtmosphereBackground`, motion helpers, DevHarness shell chrome
- Branch: `cursor/pr03-app-shell-d2c1`
- Wire `Navigating` / `Route` from Core; keep Design gallery reachable (debug or Settings)

---

## PR01 — Scaffold

**Branch:** `cursor/pr01-scaffold-d2c1`

### What exists

- Git repo initialized; SPM monorepo via root `Package.swift`
- Packages: `LociCore` (minimal real code + ObjectID tests), `LociVault` / `LociMarkdown` / `LociIndex` stubs; DesignSystem now implemented in PR02
- `App/LociApp.swift` + `App/Composition/AppServices.swift`
- Protocols in Core: VaultServing, SchemaServing, ObjectServing, IndexQuerying, IndexUpdating, Navigating, SyncStatusProviding + `Route`
- Scripts: `scripts/lint.sh`, `scripts/test.sh`, `scripts/run-harness.sh`
- Docs: `README.md`, `AGENTS.md`, CI workflow `.github/workflows/ci.yml`
- Evidence: `evidence/pr01/`

### Swift on Linux

- Swift **6.2 (swift-6.2-RELEASE)** at `/opt/swift`
- `export PATH=/opt/swift/usr/bin:$PATH`
