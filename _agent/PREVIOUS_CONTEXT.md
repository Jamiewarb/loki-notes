# Previous context — Loci agents

Handoff notes updated after each stacked PR. Read this before starting the next PR.

---

## Wave C (PR22–)

**Milestone:** Wave C depth complete through PR29 (v1.1 feature-complete vs Part 5.8 depth set). Next: **PR30 AI assist**.

---

## PR29 — Richer editor

**Branch:** `cursor/pr29-editor-rich-d2c1`  
**Based on:** `cursor/pr28-type-convert-d2c1` tip `d74c90491b188c9404ed08143121f25b5cf2ad6c`  
**Tip:** `9a69b9687806aedf25645994066edcf36e44e523`

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

### Next: PR30 — AI assist

- Branch: `cursor/pr30-ai-d2c1` (or agent suffix)
- Side panel: summarize, rewrite, translate; property auto-fill; BYOK; Apple Intelligence when available
- Depends on: PR09, PR13

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
