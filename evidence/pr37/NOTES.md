# PR37 evidence

**Branch:** `cursor/pr37-share-widget-d2c1`  
**Based on:** `cursor/pr36-eventkit-d2c1`  
**Vault module:** `0.37.0-pr37`  
**XCTest:** 336 passed (was 325)  
**Playwright:** 79 passed (`e2e/work.spec.ts` capture proofs + full suite). Evidence from `./scripts/lint.sh`, `./scripts/test.sh`, `./scripts/demo-capture.sh`, `./scripts/demo-share-widget.sh`, and `npx playwright test`.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` |
| `demo-capture.log` | `./scripts/demo-capture.sh` |
| `demo-share-widget.log` | `./scripts/demo-share-widget.sh` |
| `e2e.log` | `e2e/work.spec.ts` + `e2e/architecture.spec.ts` |
| `e2e-full.log` | full Playwright suite (79) |
| `harness.html` | DevHarness `/?panel=capture` |
| `capture.json` | `DevHarness/public/demo-capture/capture.json` |

Proof flags: `shareExtractsText`, `widgetOpenToday`, `inboxNotIndex`, `indexInsideVault: false`.
