# AGENTS.md — Loci

Guidance for humans and Cloud agents working on this repository.

## What Loci is

**Loci** is an Apple-only (macOS + iOS), Capacities-inspired personal knowledge base. Every object is a markdown file (plus YAML frontmatter) inside a user-owned vault directory on iCloud Drive, with a mandatory **local Documents fallback** when iCloud is unavailable. Search, backlinks, and “created today” come from a **local SQLite index** under Application Support — the index is disposable, rebuildable, and **must never live inside the vault**.

The product vision, vault format, package boundaries, and stacked PR plan live in [`docs/PLAN.md`](docs/PLAN.md). Architecture research: [`docs/architecture-best-practices.md`](docs/architecture-best-practices.md). Feature hard rules: [`.cursor/skills/loci-feature-architecture/SKILL.md`](.cursor/skills/loci-feature-architecture/SKILL.md).

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
./scripts/run-harness.sh    # leave running; open http://127.0.0.1:5173
```

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
