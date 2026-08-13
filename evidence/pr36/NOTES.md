# PR36 evidence

**Branch:** `cursor/pr36-eventkit-d2c1`  
**Based on:** `cursor/pr35-media-pickers-d2c1`  
**Vault module:** `0.36.0-pr36`  
**XCTest:** 325 passed (was 315)  
**Playwright:** 79 passed (integrations + architecture: 12). Evidence from `./scripts/lint.sh`, `./scripts/test.sh`, `./scripts/demo-apple.sh`, and `npx playwright test`.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` |
| `demo-apple.log` | `./scripts/demo-apple.sh` |
| `e2e.log` | `e2e/integrations.spec.ts` + `e2e/architecture.spec.ts` |
| `e2e-full.log` | full Playwright suite (79) |
| `harness.html` | DevHarness `/?panel=apple` |
| `apple.json` | `DevHarness/public/demo-apple/apple.json` |

Proof flags: `eventKitWired`, `linuxUsesFakes`, `dailyUnchanged`, `indexInsideVault: false`.
