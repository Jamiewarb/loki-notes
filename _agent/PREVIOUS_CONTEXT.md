# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## PR01 — Scaffold (current)

**Branch:** `cursor/pr01-scaffold-d2c1`

### What exists

- Git repo initialized; SPM monorepo via root `Package.swift`
- Packages: `LociCore` (minimal real code + ObjectID tests), `LociVault` / `LociMarkdown` / `LociIndex` / `LociDesignSystem` (stubs)
- `App/LociApp.swift` + `App/Composition/AppServices.swift` — SwiftUI placeholder (Apple platforms only; not in Linux SPM build)
- `App/Features/AppShell/` placeholder folder
- Protocols in Core: VaultServing, SchemaServing, ObjectServing, IndexQuerying, IndexUpdating, Navigating, SyncStatusProviding + `Route`
- Scripts: `scripts/lint.sh`, `scripts/test.sh`, `scripts/run-harness.sh`
- `DevHarness/` Vite + TS visual shell (sidebar Daily/Search/Types/Settings)
- Docs: `README.md`, `AGENTS.md`, CI workflow `.github/workflows/ci.yml`
- Evidence: `evidence/pr01/`

### Swift on Linux

- Swift **6.2 (swift-6.2-RELEASE)** at `/opt/swift`
- `export PATH=/opt/swift/usr/bin:$PATH`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173
```

### Pitfalls

- **No Xcode on Cloud VMs** — do not rely on `xcodebuild` or Simulator. Use SPM tests + DevHarness for visual work.
- `App/` sources use SwiftUI / Observation; they are **not** SPM targets. Linux CI only builds package targets.
- Index must remain **outside** the vault (Application Support). Stubs already document this.
- If `npm install` fails in DevHarness, ensure Node 20+ is on PATH (nvm or system).
- Git remote may be absent — commit locally; push only if `origin` appears.

### Next: PR02 — Design system

- Implement tokens + primitives in `LociDesignSystem` (colors, type, spacing, `LociButton`, etc.)
- Add a design gallery surface (SwiftUI on Apple; optionally mirror tokens in DevHarness)
- Follow `.cursor/skills/loci-feature-architecture/SKILL.md`
- Branch: `cursor/pr02-design-system-d2c1`
- Do not start vault I/O or editor work in PR02
