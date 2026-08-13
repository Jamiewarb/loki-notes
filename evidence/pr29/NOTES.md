# PR29 — Richer editor evidence notes

## Summary

**Wave C depth complete for editor.** BlockAST gains GFM tables, `<details>` toggles, and `> [!kind]` callouts; code fences keep language tags with harness/CSS syntax highlight; Mermaid is a `mermaid` fence (stub on Linux). Block→object uses `ObjectServing.create` + wiki-link replace — no feature→feature imports. AI assist deferred to PR30.

## Write path (unchanged)

```text
User edit → EditorSession.applyLocalEdit (memory)
         → EditorSessionBridge debounce (500ms / 5s max)
         → serializeBody() → ObjectServing.save
         → Vault write → IndexUpdating.apply (async)

Turn into… → ObjectServing.create (explicit action)
          → EditorSession.replaceBlockWithObjectLink
          → debounced save (typing path still never awaits index)
```

## What landed

| Piece | Location |
|---|---|
| `table` / `toggle` / `callout` BlockNode + parse/serialize | `LociMarkdown` |
| `SlashBlockKind` table/toggle/callout/mermaid | `BlockEdit.swift` |
| `CodeSyntaxHighlight` + Mermaid HTML stub | `BlockASTHTML` |
| `replaceBlockWithObjectLink` / `objectTitleCandidate` | `EditorSession` |
| Turn into… context menu + chrome | `BlockEditorView` / bridge |
| Demo + harness Editor panel | `loci-editor-demo`, `EditorPanel.ts` |
| Tests | `RichBlocksRoundTripTests` (+8) |

## Versions

- LociMarkdown / LociIndex → `0.2.0-pr29`
- LociVault → `0.29.0-pr29`

## Tests

- **266** package tests, 0 failures
- Lint passed (`./scripts/lint.sh`)
- Round-trip: tables, toggles, callouts, slash inserts, block→object wiki-link, HTML harness markers

## Harness

- `http://127.0.0.1:5173/?panel=editor`
- Rich card shows kinds + Turn into Book wiki-link demo
- AST HTML includes table / toggle / callout / mermaid stub / tok-keyword highlight

## Artifacts

| File | Meaning |
|---|---|
| `test.log` | `./scripts/test.sh` (266 passed) |
| `lint.log` | `./scripts/lint.sh` |
| `demo-editor.log` | `./scripts/demo-editor.sh` |
| `editor.json` / `ast.html` / `serialized.md` | Demo fixtures |
| `harness.png` / `harness-dom.html` | Editor panel proof |

## Notes for PR30 (AI assist)

- Do **not** start AI in this PR — side panel summarize/rewrite/translate is PR30
- EditorSession + bridge remain the single writer; AI should propose `BlockEdit` / text patches, not write vault directly
- Prefer on-device / Apple Intelligence; BYOK opt-in; never upload vault by default
- Property auto-fill can reuse SchemaServing + ObjectServing.save — same protocol boundary as Turn into…
- Keep typing path free of network/index awaits; AI actions are explicit user gestures
