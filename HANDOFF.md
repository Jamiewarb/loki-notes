# HANDOFF — next agent must read this first

**Delete this file** (`HANDOFF.md`) in your first commit after you have absorbed it (copy anything still needed into `_agent/PREVIOUS_CONTEXT.md`). Do not leave a permanent handoff doc in the tree.

---

## What this project is

**Loci** (repo: [Jamiewarb/loki-notes](https://github.com/Jamiewarb/loki-notes)) is a Capacities.io-style personal PKM for **macOS + iOS**.

- Vault of markdown + YAML frontmatter + media in an **iCloud Drive directory** (local Documents fallback required).
- **Files are source of truth.** SQLite index is a disposable projection in **Application Support only** — never inside the vault.
- One SwiftUI codebase (Apple). Linux Cloud agents test via **SPM packages + DevHarness** (Vite at `http://127.0.0.1:5173`).
- Product/architecture/build plan: [`docs/PLAN.md`](docs/PLAN.md) (Parts 1–14).
- Hard rules skill: [`.cursor/skills/loci-feature-architecture/SKILL.md`](.cursor/skills/loci-feature-architecture/SKILL.md).
- Testing bible: [`AGENTS.md`](AGENTS.md).
- Per-PR notes: [`_agent/PREVIOUS_CONTEXT.md`](_agent/PREVIOUS_CONTEXT.md).
- Research (not the plan): [`docs/architecture-best-practices.md`](docs/architecture-best-practices.md).

---

## Your first 15 minutes

1. Read this file fully, then **delete `HANDOFF.md`** in a later commit on your working branch (after copying durable notes into `_agent/PREVIOUS_CONTEXT.md`).
2. Read `AGENTS.md`, `.cursor/skills/loci-feature-architecture/SKILL.md`, `docs/PLAN.md` Parts 12–14, `_agent/PREVIOUS_CONTEXT.md`.
3. `export PATH=/opt/swift/usr/bin:$PATH` (Swift 6.2). Install `libsqlite3-dev` if Index tests fail to compile.
4. `./scripts/lint.sh && ./scripts/test.sh` — expect **266** tests green on PR29 tip.
5. Continue **PR30 AI assist** (Wave D). Do not re-do PR01–PR29.

---

## Progress (authoritative)

| Wave | PRs | Status |
|---|---|---|
| A Foundation | PR01–PR08 | **Done**, on GitHub |
| B MVP | PR09–PR21 | **Done**, on GitHub |
| C Depth | PR22–PR29 | **Done**, on GitHub |
| D Intelligence | PR30–PR32 | **Not done** — start here |

**Latest completed git tip (use this as base):**

- Branch: `cursor/pr29-editor-rich-d2c1`
- SHA: `a75d2f8c28dde997dd8ec1598ac6d7c16a48e286`
- GitHub PR: https://github.com/Jamiewarb/loki-notes/pull/29
- Remote: `https://github.com/Jamiewarb/loki-notes.git`

**Current checkout when this file was written:** `cursor/pr30-ai-d2c1` (same commit as PR29 tip, plus **uncommitted PR30 WIP** — see below).

### GitHub stacked PRs (already opened)

Merge **in numeric order**. Each PR’s base is the previous branch (PR1 → `main`).

| # | Branch | URL |
|---|---|---|
| 1 | `cursor/pr01-scaffold-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/1 |
| 2 | `cursor/pr02-design-system-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/2 |
| 3 | `cursor/pr03-app-shell-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/3 |
| 4 | `cursor/pr04-vault-io-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/4 |
| 5 | `cursor/pr05-schema-domain-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/5 |
| 6 | `cursor/pr06-markdown-kit-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/6 |
| 7 | `cursor/pr07-indexer-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/7 |
| 8 | `cursor/pr08-object-crud-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/8 |
| 9 | `cursor/pr09-block-editor-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/9 |
| 10 | `cursor/pr10-daily-notes-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/10 |
| 11 | `cursor/pr11-created-today-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/11 |
| 12 | `cursor/pr12-custom-types-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/12 |
| 13 | `cursor/pr13-properties-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/13 |
| 14 | `cursor/pr14-templates-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/14 |
| 15 | `cursor/pr15-para-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/15 |
| 16 | `cursor/pr16-wikilinks-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/16 |
| 17 | `cursor/pr17-tags-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/17 |
| 18 | `cursor/pr18-search-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/18 |
| 19 | `cursor/pr19-tasks-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/19 |
| 20 | `cursor/pr20-media-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/20 |
| 21 | `cursor/pr21-sync-ux-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/21 |
| 22 | `cursor/pr22-collections-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/22 |
| 23 | `cursor/pr23-queries-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/23 |
| 24 | `cursor/pr24-graph-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/24 |
| 25 | `cursor/pr25-calendar-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/25 |
| 26 | `cursor/pr26-share-widget-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/26 |
| 27 | `cursor/pr27-import-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/27 |
| 28 | `cursor/pr28-type-convert-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/28 |
| 29 | `cursor/pr29-editor-rich-d2c1` | https://github.com/Jamiewarb/loki-notes/pull/29 |

Branch naming: `cursor/prNN-<short-name>-d2c1`.

---

## What to build next (from `docs/PLAN.md`)

### PR30 — AI assist (in progress / incomplete)

**Branch:** `cursor/pr30-ai-d2c1` (already created locally; **not pushed**).

**Uncommitted WIP to review (do not blindly discard):**

- `LociCore/Sources/LociCore/Models/AICredentialStore.swift`
- `LociCore/Sources/LociCore/Models/AIHeuristics.swift`
- `LociCore/Sources/LociCore/Models/AIModels.swift`
- `LociCore/Sources/LociCore/Models/AIService.swift`
- `LociCore/Sources/LociCore/Protocols/AIServing.swift`
- Modified: `LociCore/Sources/LociCore/Errors/LociError.swift`

**Required product:**

- Side panel: summarize, rewrite, translate
- Property auto-fill from title/body
- BYOK provider settings
- Prefer on-device / Apple Intelligence when available
- **Never upload vault** unless user explicitly opts in
- Explicit actions only — not on the typing path
- Propose edits via `EditorSession` / `ObjectServing.save` — AI must not write files itself
- `App/Features/AI/` domain folder; protocols in Core; composition in `AppServices`
- Linux-testable heuristics/fakes (no real network required in unit tests)
- DevHarness AI panel + `evidence/pr30/`
- Update `_agent/PREVIOUS_CONTEXT.md`

### PR31 — Apple Calendar and Reminders

- Event list on daily note; Meeting-type object from event
- Optional Reminders sync for tasks
- Depends on PR10, PR19, PR12
- Apple EventKit is `#if` / stub on Linux; keep models + daily wiring testable
- Branch: `cursor/pr31-apple-integrations-d2c1`

### PR32 — Safari web clipper

- Safari App Extension: send selection/page to daily note or Weblink object
- Depends on PR08, PR20
- Linux: capture-like inbox writer + stubs (same pattern as PR26)
- Branch: `cursor/pr32-safari-d2c1`

After PR32: Wave D complete. Optional later (not scheduled): Readwise/Kindle, plugin marketplace, Windows/Android/web.

---

## How to orchestrate (do this — it is how the repo was built)

You are the **parent orchestrator**. For each remaining PR:

1. Launch **one** `generalPurpose` subagent with model **`cursor-grok-4.5-high`** (iOS/macOS expert).
2. Give it:
   - Paths to `AGENTS.md`, `docs/PLAN.md` (the specific PR section + Parts 13–14), the skill, `_agent/PREVIOUS_CONTEXT.md`
   - Exact branch name, base SHA
   - Feature goals, hard constraints, watch-outs from the previous PR
   - Mandatory test/evidence bar (below)
3. **Do not mark a subagent done** until it returns evidence paths and you have re-run `./scripts/test.sh` yourself (or confirmed their logs).
4. After each PR: commit, `git push -u origin <branch>`, `gh pr create --base <previous-branch> --head <this-branch>`.
5. Update `_agent/PREVIOUS_CONTEXT.md` every PR.
6. Sequential only (PR30 then 31 then 32). Do not parallelize these — they stack.

### Subagent prompt skeleton

```text
You are an expert iOS/macOS engineer executing PRNN — <name> for Loci.
Read: AGENTS.md, _agent/PREVIOUS_CONTEXT.md, docs/PLAN.md (that PR + Parts 13–14),
      .cursor/skills/loci-feature-architecture/SKILL.md
Git: branch from <prev tip> → cursor/prNN-...-d2c1
PATH: /opt/swift/usr/bin
Goals: <from plan>
Constraints: vault=truth; index in Application Support; no feature→feature imports;
             local vault fallback; no derived UI written into daily.md
Testing: ./scripts/lint.sh + ./scripts/test.sh → evidence/prNN/;
         DevHarness proof; update PREVIOUS_CONTEXT; commit; push if origin works
Return: branch, SHA, evidence, notes for next PR, blockers
```

---

## Architecture the next agent must not violate

- **Vault files = truth.** Index never in the iCloud/vault folder.
- **Per-type schema:** `.loci/types/<slug>.json` — not one monolithic schema.json.
- **Daily notes:** `daily/YYYY-MM-DD.md`, logical id `daily-YYYY-MM-DD`, deterministic UUID. Two devices must not fork “today”.
- **Created-today / calendar dots / query results:** index-derived UI. Do not rewrite daily `.md` for chrome.
- **EditorSession** is the single writer for an open object. Debounced save. Index updates after save, async.
- **Packages:** `LociCore`, `LociVault`, `LociMarkdown`, `LociIndex`, `LociDesignSystem`. Features are folders under `App/Features/<Domain>/`, not extra SPM packages.
- **Protocols** in Core; `App/Composition/AppServices.swift` is the composition root.
- Identity = frontmatter `ObjectID`. Do not persist absolute ubiquity URLs as sole identity.
- Extensions (Share/Widget/Safari) write inbox/vault files; main app indexes on foreground.

### Design system

Editorial-sage: ink `#1A2421`, paper `#E8EFE8`, moss-teal `#0F6B5C`. Fonts: Fraunces + Source Sans 3. Brand **Loci** must read as a hero-level signal. No purple-default AI look.

---

## How to test (Linux Cloud agents)

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/run-harness.sh    # http://127.0.0.1:5173
```

Save proof under `evidence/prNN/` (`lint.log`, `test.log`, `harness.html` / screenshot, demo logs).

Useful demos (already in `scripts/`): `demo-vault.sh`, `demo-schema.sh`, `demo-objects.sh`, `demo-daily.sh`, `demo-created-today.sh`, `demo-properties.sh`, `demo-templates.sh`, `demo-para.sh`, `demo-links.sh`, `demo-tags.sh`, `demo-search.sh`, `demo-tasks.sh`, `demo-media.sh`, `demo-sync.sh`, `demo-collections.sh`, `demo-graph.sh`, `demo-calendar.sh`, `demo-capture.sh`, `demo-import.sh`, `demo-type-convert.sh`, `demo-editor.sh`.

Harness panels use `?panel=<name>` (`daily`, `search`, `types`, `settings`, `editor`, `tags`, `tasks`, `media`, `graph`, `calendar`, `capture`, `import`, `type-convert`, …).

**Apple:** `App/` SwiftUI is **not** in the Linux SPM build. Visual proof on Linux = DevHarness. Xcode on Mac for Simulator.

Headless Chrome can hang — use `timeout` + unique `--user-data-dir`.

Baseline at PR29: **266** package tests, 0 failures.

---

## Environment / git / GitHub

- Repo: `https://github.com/Jamiewarb/loki-notes`
- This Cloud Agent run often **starts without a GitHub checkout**. Push needs a PAT with **Contents: Write** and **Pull requests: Write** on `Jamiewarb/loki-notes`, exposed as `GH_TOKEN` (do not commit tokens; do not paste them into files).
- Fine-grained tokens that can only *read* will 403 on `git push` even if `gh api user` works.
- After push: `gh pr create --repo Jamiewarb/loki-notes --head cursor/prNN-... --base cursor/pr(N-1)-...`
- **Do not store PATs in the repo.** A token was used once in chat to open PRs 1–29; the user intended to revoke it. Request a new secret if you need to push.
- `git remote` should stay `https://github.com/Jamiewarb/loki-notes.git` with **no embedded token**.

---

## Key code map

```text
Package.swift
LociCore/          models, IDs, protocols
LociVault/         VaultService, ObjectService, SchemaStore, DailyNoteService, …
LociMarkdown/      BlockAST, parser/serializer, EditorSession
LociIndex/         GRDB IndexService (Application Support)
LociDesignSystem/  tokens + SwiftUI primitives
App/LociApp.swift
App/Composition/AppServices.swift
App/Features/<Domain>/
DevHarness/        Vite visual shell
scripts/           lint.sh test.sh run-harness.sh demo-*.sh
evidence/pr01 … evidence/pr29
```

Write path: Feature → `ObjectServing` → Markdown serialize → `VaultServing` → event → `IndexUpdating` (async).  
Read lists/search/panels: `IndexQuerying`.  
Open body: `ObjectServing.open` → parse → `EditorSession`.

---

## Acceptance for each remaining PR

- [ ] Builds / `swift test` green; no regression vs 266 (count will rise)
- [ ] Works against **local vault** in CI
- [ ] Disk format changes have round-trip tests
- [ ] No index.sqlite inside the vault (`indexInsideVault: false` in demos)
- [ ] No cross-feature imports
- [ ] Evidence under `evidence/prNN/`
- [ ] PREVIOUS_CONTEXT updated
- [ ] Branch pushed; stacked PR opened against previous branch
- [ ] `HANDOFF.md` deleted once you have taken over

---

## Do not

- Re-scaffold the app or redo Wave A–C
- Put SQLite in the vault
- Auto-write “created today” or query results into daily markdown
- Upload vault contents to an AI provider by default
- Create one SPM package per feature
- Finish a PR without lint + tests + harness evidence
