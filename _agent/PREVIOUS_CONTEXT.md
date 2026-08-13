# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Takeover (2026-08-13)

`HANDOFF.md` from PR29 was absorbed here and deleted. Durable facts:

- **Loci** (repo `Jamiewarb/loki-notes`): Capacities-style PKM for macOS + iOS. Vault (markdown + YAML + media) in iCloud Drive is source of truth; disposable SQLite index lives only in Application Support.
- Waves A–C (**PR01–PR29**) are done as stacked GitHub PRs #1–#29. Merge in numeric order; each PR’s base is the previous branch.
- **PR29 tip (functional):** `cursor/pr29-editor-rich-d2c1` @ `a75d2f8c28dde997dd8ec1598ac6d7c16a48e286` (266 tests). HANDOFF commit was `72c6f8e964`.
- **Wave D (PR30–PR32)** starts here. Do not redo PR01–PR29.
- Uncommitted PR30 WIP mentioned in HANDOFF (`AIServing`, `AIService`, heuristics, credential store on `cursor/pr30-ai-d2c1`) was **never pushed**. Prior cloud agent `bc-019ffc67-5506-7827-81c7-bc3aff44cbbe` had an empty transcript. Restart PR30 from PR29 tip; do not expect to resurrect that WIP.
- Swift 6.2: `export PATH=/opt/swift/usr/bin:$PATH`. Linux tests SPM packages + DevHarness only (`App/` SwiftUI is Apple).
- Hard rules: vault = truth; never put the index in the vault; no feature→feature imports; do not rewrite daily notes for derived UI; AI must not upload the vault unless the user opts in; typing must not wait on index/network.

Stacked PRs already opened: https://github.com/Jamiewarb/loki-notes/pull/1 … https://github.com/Jamiewarb/loki-notes/pull/29

Branch naming: `cursor/prNN-<short-name>-d2c1`.

---

## Wave C (PR22–)

**Milestone:** Wave C depth complete through PR29 (v1.1 feature-complete vs Part 5.8 depth set). Next: **PR30 AI assist**.

---

## PR29 — Richer editor

**Branch:** `cursor/pr29-editor-rich-d2c1`  
**Based on:** `cursor/pr28-type-convert-d2c1` tip `d74c90491b188c9404ed08143121f25b5cf2ad6c`  
**Tip:** `a75d2f8c28dde997dd8ec1598ac6d7c16a48e286` (functional). Later `72c6f8e964` added `HANDOFF.md` (deleted after takeover).

### What landed

- **Markdown:** `BlockNode.table` / `.toggle` / `.callout`; GFM pipe tables; HTML `<details>` toggles; `> [!kind] title` callouts; Mermaid stays fenced `mermaid`; `CodeSyntaxHighlight` for harness HTML
- **EditorSession:** slash kinds `table` / `toggle` / `callout` / `mermaid`; `replaceBlockWithObjectLink` + `objectTitleCandidate` (ObjectServing.create happens in UI host)
- **Apple:** BlockEditor chrome + context menu **Turn into…** via schema types; bridge `turnFocusedBlockIntoObject`
- **Harness:** Editor panel PR29 card + CSS for table/toggle/callout/tokens/mermaid stub
- **Tests:** `RichBlocksRoundTripTests` (+8); suite **266** green
- Evidence: `evidence/pr29/`
- Versions: Markdown/Index `0.2.0-pr29`; Vault `0.29.0-pr29`

### How to run checks

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh
./scripts/test.sh
./scripts/demo-editor.sh
./scripts/run-harness.sh   # http://127.0.0.1:5173/?panel=editor
```

### Pitfalls for PR30 (AI assist)

- Do not auto-start AI on typing; explicit side-panel actions only
- Propose edits through EditorSession / BlockEdit — never bypass ObjectServing for vault writes
- BYOK + on-device preference; never upload vault unless user opts in
- Property auto-fill: SchemaServing defs + ObjectServing.save; keep index async
- No feature→feature imports (AI feature talks protocols only)
- Credentials / API keys never in the vault (Application Support / Keychain). Heuristics must be Linux-testable with no network.

### Next: PR30 — AI assist

- Branch: `cursor/pr30-ai-d2c1`
- Side panel: summarize, rewrite, translate; property auto-fill; BYOK; Apple Intelligence when available
- Depends on: PR09, PR13
- Then PR31 Apple Calendar/Reminders (`cursor/pr31-apple-integrations-d2c1`), PR32 Safari clipper (`cursor/pr32-safari-d2c1`)

---

## PR28 — Type conversion

**Branch:** `cursor/pr28-type-convert-d2c1`  
**Tip:** `d74c90491b188c9404ed08143121f25b5cf2ad6c`

Type convert with property mapping; ObjectID stable; daily notes cannot convert. See `evidence/pr28/`.

---

## PR27 — Import

Import markdown / Obsidian / Capacities with dry-run. See `evidence/pr27/`.

---

## Wave A (PR01–PR08) · Wave B (PR09–PR21) **MVP complete** · Wave C PR22–PR29 done · next PR30
