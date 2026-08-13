# PR39 evidence

**Branch:** `cursor/pr39-macos-ci-d2c1`  
**Based on:** `cursor/pr38-menubar-safari-d2c1`  
**Vault module:** `0.39.0-pr39`  
**MARKETING_VERSION:** `0.39.0`  
**XCTest:** **353** passed (was 346).  
**Playwright:** **82** passed (was 80; +architecture macos-ci JSON + settings proof flags).

Linux cannot execute the `macos-xcode` GitHub Actions job (`runs-on: macos-14` / `xcodebuild`). The workflow YAML is the Mac CI deliverable. Do not treat any log here as a passing xcodebuild run.

## iOS Simulator destination

Workflow uses:

```
platform=iOS Simulator,name=iPhone 15
```

**Why:** GitHub-hosted `macos-14` runners with Xcode 15.4 typically include the iPhone 15 simulator. A later image that drops that name can switch to `generic/platform=iOS Simulator` (commented in `.github/workflows/ci.yml`). Unsigned Debug uses `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` so Share/Widget/Safari extensions skip real signing.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` |
| `demo-macos-ci.log` | `./scripts/demo-macos-ci.sh` (also python-asserts `ci.yml` contains `macos-14` and `xcodebuild`) |
| `macos-ci.json` | copy of `DevHarness/public/demo-macos-ci/macos-ci.json` |
| `e2e-full.log` | `./scripts/e2e.sh` (82) |
| `harness.html` | DevHarness `/?panel=settings` |

Proof flags: `macosCIWorkflowPresent`, `shortcutsCatalogued`, `voiceOverLabelsPresent`, `dynamicTypeScales`, `indexInsideVault: false`.
