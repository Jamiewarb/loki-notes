# PR45 evidence

**Branch:** `cursor/pr45-graph-polish-d2c1`  
**Based on:** `cursor/pr44-unlinked-mentions-d2c1`  
**Vault module:** `0.45.0-pr45`  
**MARKETING_VERSION:** `0.45.0`  
**XCTest:** **436** passed (was 427).  
**Playwright:** **99** passed (was 97; +graph polish proof flags, hide hubs drops Deep Work).

Linux cannot compile `App/` SwiftUI. Graph polish UI lives in `App/Features/Graph/` (`GraphView` / `GraphInspectorView`, session state on `AppServices`) and is proven via XCTest (`GraphAssembly` / `GraphPolishProof` + `IndexQuerying.graph`) and DevHarness fixtures.

## Proof flags

`hidesHighDegree` / `focusNeighbors` / `layoutNotWrittenToVault` / `indexInsideVault: false`

Demo: Deep Work is degree 3 (hub). Hide hubs at ≥ 3 drops Deep Work and its edges; Range / Reading List / Focus Notes remain. Focus neighbors on Range keeps Range + Deep Work + Reading List (drops Focus Notes). Object markdown unchanged; no layout coordinates in the vault. Index outside vault.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` (436) |
| `demo-graph.log` | `./scripts/demo-graph.sh` |
| `graph.json` | copy of `DevHarness/public/demo-graph/graph.json` |
| `e2e-full.log` | `./scripts/e2e.sh` (99) |

## Pitfalls

- Do not persist graph layout into markdown. Hide/focus are session-only (`AppServices`).
- Hide hubs (drop high-degree clutter) is the opposite of node-cap (keep hubs). Hide runs **before** caps.
- `focusObjectID` is protected from hide so focusing a hub still isolates its neighborhood.
- Typing never waits on graph layout.
- Do not screenshot-compare or assert SVG x/y in Playwright.
- Re-running `demo-graph.sh` regenerates ObjectIDs — update the Deep Work UUID in `retrieval.spec.ts`.
- Stacked vault version assertions (`contains("pr44")`) must also accept `pr45`.
- Index stays in Application Support. Demo JSON `indexInsideVault: false`.
