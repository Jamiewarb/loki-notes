# PR42 evidence

**Branch:** `cursor/pr42-kanban-d2c1`  
**Based on:** `cursor/pr41-dashboard-d2c1`  
**Vault module:** `0.42.0-pr42`  
**MARKETING_VERSION:** `0.42.0`  
**XCTest:** **396** passed (was 383).  
**Playwright:** **91** passed (was 88; +types kanban columns/Deep Work in Done, +types layout-not-in-markdown, +architecture kanban JSON).

Linux cannot compile `App/` SwiftUI. The Board lives in `App/Features/ObjectTypes/` (`TypeDashboardBoard` + `TypeDashboardStore.moveCard`) and is proven via XCTest (pure `KanbanMove` / `KanbanProof` + ObjectServing.save YAML) and DevHarness fixtures.

## Proof flags

`boardColumnsFromGroup` / `moveUpdatesVaultYAML` / `layoutNotWrittenToMarkdown` / `indexInsideVault: false`

Demo also records `dailyUnchanged: true`, `objectMarkdownUnchanged: true`, `yamlStatusDone: true`. Created four Books (To Read / Reading / Done), moved Deep Work Reading→Done via `KanbanMove` + `ObjectServing.save`. YAML `status` is Done; body unchanged; type schema `defaultView=board`; daily unchanged; index not in vault. Columns: To Read, Reading, Done (select option order).

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` (396) |
| `demo-kanban.log` | `./scripts/demo-kanban.sh` |
| `kanban.json` | copy of `DevHarness/public/demo-kanban/kanban.json` |
| `e2e-full.log` | `./scripts/e2e.sh` (91) |
| `harness.html` | DevHarness `/?panel=types` (SPA shell; proofs render after fetch) |

## Pitfalls

- Never write kanban layout into markdown. Only YAML frontmatter (property/tag) and type schema JSON may change on a move / view toggle.
- Move must work without drag: VoiceOver “Move to …” on every card. `.onDrag`/`.onDrop` is Apple-only and optional.
- Do not import Features/Queries for the board. Reuse `TypeDashboardStore` + `IndexQuerying.execute`.
- Select columns use schema option order (To Read, Reading, Done), not alphabetical grouping keys.
- Tag move: destination becomes the primary tag; previous grouping tag is removed; remaining tags stay.
- Stacked vault version assertions (`contains("pr41")`) must also accept `pr42`.
- Index stays in Application Support. Demo JSON `indexInsideVault: false`.
