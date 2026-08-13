# PR41 evidence

**Branch:** `cursor/pr41-dashboard-d2c1`  
**Based on:** `cursor/pr40-object-select-d2c1`  
**Vault module:** `0.41.0-pr41`  
**MARKETING_VERSION:** `0.41.0`  
**XCTest:** **383** passed (was 366).  
**Playwright:** **88** passed (was 85; +types grouped list/proofs, +types markdown-unchanged, +architecture dashboard JSON).

Linux cannot compile `App/` SwiftUI. The dashboard lives in `App/Features/ObjectTypes/` and is proven via XCTest (pure `DashboardGrouping` / `DashboardQuery` / `DashboardViewProof` + QueryEngine execute → saveType) and DevHarness fixtures.

## Proof flags

`filterApplied` / `sortApplied` / `groupApplied` / `resultsNotWrittenToMarkdown` / `indexInsideVault: false`

Demo also records `dailyUnchanged: true` and `objectMarkdownUnchanged: true` (ensured `daily/2026-08-13.md`, created four Books, then saved dashboard defaults to `.loci/types/book.json` only). Filtered titles: Deep Work, Range. Grouped section keys include Reading.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` (383) |
| `demo-dashboard.log` | `./scripts/demo-dashboard.sh` |
| `dashboard.json` | copy of `DevHarness/public/demo-dashboard/dashboard.json` |
| `e2e-full.log` | `./scripts/e2e.sh` (88) |
| `harness.html` | DevHarness `/?panel=types` (SPA shell; proofs render after fetch) |

## Pitfalls

- Do not write filter/sort/group results into object or daily markdown. Only type schema JSON may change.
- Do not import Features/Queries for the dashboard list. Use `IndexQuerying.execute`.
- Collections are vault JSON — keep membership as a post-filter on `memberIDs`.
- `defaultSort` tokens: `title` / `titleAsc` / `updated` / `created` (and *Desc / *Asc). A property id falls back to title in SQL and sorts in memory.
- Group-by is derived UI. Kanban board is **PR42** — do not build a board.
- Stacked vault version assertions (`contains("pr40")`) must also accept `pr41`.
