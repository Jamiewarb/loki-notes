# PR09 — Block editor MVP evidence notes

## Summary

**Wave B started.** Linux-testable `EditorSession` owns BlockAST dirty state; Apple `BlockEditor` UI (slash menu + keymap) replaces plain `TextEditor`; debounced save (500ms idle / 5s max) serializes via `LociMarkdown` then `ObjectServing.save` — typing never awaits index.

## Write path

```text
User edit → EditorSession.applyLocalEdit (memory)
         → EditorSessionBridge debounce (500ms / 5s max)
         → serializeBody() → ObjectServing.save
         → Vault write → IndexUpdating.apply (async)
```

## What landed

| Piece | Location |
|---|---|
| `EditorSession`, `BlockEdit`, `SlashBlockKind`, `BlockASTHTML` | `LociMarkdown` (Linux-tested) |
| `BlockEditorView`, `SlashMenuView`, `Keymap`, `EditorSessionBridge` | `App/Features/BlockEditor/` |
| Object host | `ObjectEditorView` uses BlockEditor |
| Demo CLI | `loci-editor-demo` + `scripts/demo-editor.sh` |
| Harness | Studio → **Editor** (`?panel=editor`) |

## Tests

- **84** package tests (was 78) — +6 `EditorSessionTests`
- Apply edits + serialize round-trip + slash convert + remote reload dirty guard + HTML preview
- Lint + build green

## Harness

- `http://127.0.0.1:5173/?panel=editor`
- Shows slash-simulated inserts, serialized MD, AST HTML with tasks/headings/lists
- Artifacts: `harness-editor.png`, `harness-editor-dom.html`, `editor.json`

## Artifacts

| File | Meaning |
|---|---|
| `test.log` | `./scripts/test.sh` (84 passed) |
| `lint.log` | `./scripts/lint.sh` |
| `demo-editor.log` | `./scripts/demo-editor.sh` |
| `editor.json` | EditorSession export fixture |
| `ast.html` / `serialized.md` | HTML + MD extracts |
| `harness-editor.png` | Editor panel screenshot |
| `harness-editor-dom.html` | rendered DOM |

## Notes for PR10 (Daily notes)

- Reuse `EditorSession` / `EditorSessionBridge` for daily body editing
- Deterministic path `daily/YYYY-MM-DD.md` + id `daily-{yyyy-mm-dd}`
- Auto-create today on launch; prev/next + date picker
- Do **not** rewrite daily body for “created today” (that is PR11 inspector)
- ObjectService create path for `.daily` type already exists via type folders — wire dedicated DailyNotes feature folder
