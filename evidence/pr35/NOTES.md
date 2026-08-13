# PR35 evidence

**Branch:** `cursor/pr35-media-pickers-d2c1`  
**Vault module:** `0.35.0-pr35`  
**XCTest:** 315 passed (was 311)  
**Playwright:** 79 passed (was 78)

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` |
| `harness.log` | `./scripts/demo-media.sh` + `./scripts/demo-media-pickers.sh` |
| `e2e.log` | `e2e/work.spec.ts` + `e2e/architecture.spec.ts` then `./scripts/e2e.sh` |
| `harness.html` | DevHarness `/?panel=media` |

Proof flags from `demo-media/media.json`: `indexInsideVault: false`, `photosPickerWired`, `dragDropWired`, `attachedViaFileURL`, `markdownRelativePathStartsWithMedia`, `noteBodyHasAbsolutePath: false`.
