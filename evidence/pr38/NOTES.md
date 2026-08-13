# PR38 evidence

**Branch:** `cursor/pr38-menubar-safari-d2c1`  
**Based on:** `cursor/pr37-share-widget-d2c1`  
**Vault module:** `0.38.0-pr38`  
**XCTest:** 346 passed (was 336)  
**Playwright:** 80 passed (was 79; integrations.spec 10 including new safari/menu-bar proofs). Evidence from `./scripts/lint.sh`, `./scripts/test.sh`, `./scripts/demo-safari.sh`, `./scripts/demo-menubar.sh`, `./scripts/demo-capture.sh`, and `npx playwright test`.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` |
| `demo-safari.log` | `./scripts/demo-safari.sh` |
| `demo-menubar.log` | `./scripts/demo-menubar.sh` |
| `demo-capture.log` | `./scripts/demo-capture.sh` |
| `e2e.log` | `e2e/integrations.spec.ts` (10) |
| `e2e-work-arch.log` | `e2e/work.spec.ts` + `e2e/architecture.spec.ts` |
| `e2e-full.log` | full Playwright suite (80) |
| `harness.html` | DevHarness `/?panel=safari` |
| `safari.json` | `DevHarness/public/demo-safari/safari.json` |
| `capture.json` | `DevHarness/public/demo-capture/capture.json` |

Proof flags: `menuBarWired`, `safariExtractsPage`, `inboxNotIndex`, `indexInsideVault: false`.
