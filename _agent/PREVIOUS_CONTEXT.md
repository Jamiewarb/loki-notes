# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Takeover (2026-08-13)

`HANDOFF.md` from PR29 was absorbed here and deleted. Durable facts:

- **Loci** (repo `Jamiewarb/loki-notes`): Capacities-style PKM for macOS + iOS. Vault (markdown + YAML + media) in iCloud Drive is source of truth; disposable SQLite index lives only in Application Support.
- Waves A–C (**PR01–PR29**) are done as stacked GitHub PRs #1–#29. Merge in numeric order; each PR’s base is the previous branch.
- **PR29 tip (functional):** `cursor/pr29-editor-rich-d2c1` @ `a75d2f8c28dde997dd8ec1598ac6d7c16a48e286` (266 tests).
- **Wave D (PR30–PR32)** — PR30 AI assist lands on this branch.
- Swift 6.2: `export PATH=/opt/swift/usr/bin:$PATH`. Linux tests SPM packages + DevHarness only (`App/` SwiftUI is Apple).
- Hard rules: vault = truth; never put the index in the vault; no feature→feature imports; do not rewrite daily notes for derived UI; AI must not upload the vault unless the user opts in; typing must not wait on index/network.

Stacked PRs already opened: https://github.com/Jamiewarb/loki-notes/pull/1 … https://github.com/Jamiewarb/loki-notes/pull/29

Branch naming: `cursor/prNN-<short-name>-d2c1`.

---

## Wave D (PR30–)

**Milestone:** Integrations (v1.2). Next after PR30: **PR31 Apple Calendar/Reminders**.

---

## PR30 — AI assist

**Branch:** `cursor/pr30-ai-d2c1`  
**Based on:** `cursor/pr29-editor-rich-d2c1`  
**Tip:** `3535848cd78e4915a7bbc1187e16adf5780fc632` (**281** tests)

### What landed

- **Core:** `AIServing`, `AIModels`, `AIHeuristics`, `AIPrivacy`; `Route.ai`; `LociError` AI cases
- **Vault:** `AIService`, `AICredentialStore` (Application Support JSON; Keychain stub on Apple); `loci-ai-demo`
- **Markdown:** `EditorSession.applyProposedBody` (applies even when dirty, marks dirty)
- **App:** `Features/AI/` panel + settings; object inspector AI slot; AppServices always wires AI
- **Harness:** `?panel=ai` + `demo-ai/ai.json`
- **Privacy:** upload refused unless `uploadVaultOptIn && allowRemoteUpload`; credentials never in vault
- **Versions:** Vault `0.30.0-pr30`; Markdown/Index `0.2.0-pr30`
- Evidence: `evidence/pr30/`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-ai.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=ai
```

### Pitfalls for PR31 (Apple Calendar / Reminders)

- Event list on daily note; create Meeting-type object from event; optional Reminders sync for tasks
- Do not rewrite daily markdown for derived calendar chrome
- EventKit / EventKitUI are Apple-only — keep Linux fakes / stubs for package tests
- No feature→feature imports; talk protocols only
- Depends on: PR10, PR19, PR12

### Next: PR31 — Apple Calendar and Reminders

- Branch: `cursor/pr31-apple-integrations-d2c1`
- Then PR32 Safari clipper (`cursor/pr32-safari-d2c1`)

---

## PR29 — Richer editor

**Branch:** `cursor/pr29-editor-rich-d2c1`  
**Tip:** `a75d2f8c28dde997dd8ec1598ac6d7c16a48e286` (266 tests)

Tables / toggles / callouts / mermaid; slash + Turn into…. See `evidence/pr29/`.

---

## PR28 — Type conversion

Type convert with property mapping; ObjectID stable; daily notes cannot convert. See `evidence/pr28/`.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR29 done · Wave D PR30 done · next PR31
