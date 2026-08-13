# Loci (`loki-notes`)

**Loci** is a Capacities-style personal knowledge management (PKM) app for **macOS and iOS**. Notes are typed objects in a network, stored as human-readable markdown (+ media + schema) in an **iCloud Drive vault**. Sync is Apple’s file sync — there is no Loci server. A disposable SQLite **index** lives only in Application Support (never inside the vault).

GitHub repository: [Jamiewarb/loki-notes](https://github.com/Jamiewarb/loki-notes).

This repo is developed as a stacked-PR sequence documented in [`docs/PLAN.md`](docs/PLAN.md). Cloud agents run on **Linux** (Swift package tests + DevHarness browser UI). Apple UI builds require **Xcode** on macOS.

## Layout

```text
Package.swift              # SPM: LociCore, LociVault, LociMarkdown, LociIndex, LociDesignSystem
App/                       # SwiftUI app (composition root + Features/) — Apple platforms
DevHarness/                # Vite visual shell for Linux Cloud agents
scripts/                   # test.sh, lint.sh, run-harness.sh
docs/PLAN.md               # product + architecture + PR plan
.cursor/skills/loci-feature-architecture/
```

## Quick start (Linux / Cloud agents)

```bash
export PATH=/opt/swift/usr/bin:$PATH   # after toolchain install; see AGENTS.md
./scripts/lint.sh
./scripts/test.sh
./scripts/run-harness.sh               # http://127.0.0.1:5173
```

## Quick start (macOS / Xcode)

1. Install Xcode 15+ (iOS 17 / macOS 14 deployment).
2. Open or generate an Xcode project that depends on this local SPM package and compiles `App/` sources (see `project.yml` + XcodeGen, or File → New → App and add local package).
3. Run on Mac or iOS Simulator — placeholder `LociApp` shows the brand screen.
4. Still run `./scripts/test.sh` for package unit tests.

## Architecture (short)

- **Vault files = truth** (markdown, schema, media).
- **Index = local projection** (Application Support only).
- **Features** live under `App/Features/<Domain>/` and talk through `LociCore` protocols — no cross-feature imports.
- **Local vault fallback** is mandatory for CI and devices without iCloud.

Read [`.cursor/skills/loci-feature-architecture/SKILL.md`](.cursor/skills/loci-feature-architecture/SKILL.md) before implementing features.

## Branch naming

```text
cursor/prNN-<short-name>-d2c1
```

## License

Private / WIP unless otherwise stated.
