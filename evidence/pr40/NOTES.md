# PR40 evidence

**Branch:** `cursor/pr40-object-select-d2c1`  
**Based on:** `cursor/pr39-macos-ci-d2c1`  
**Vault module:** `0.40.0-pr40`  
**MARKETING_VERSION:** `0.40.0`  
**XCTest:** **366** passed (was 353).  
**Playwright:** **85** passed (was 82; +types picker title/proofs, +types daily-unchanged, +architecture object-select JSON).

Linux cannot compile `App/` SwiftUI. The picker lives in `App/Features/Properties/` and is proven via XCTest (pure `ObjectSelectLinks` + ObjectServing save → backlinks) and DevHarness fixtures.

## Proof flags

`pickerUsesIndexCandidates` / `storesObjectIDs` / `createsRealLinks` / `doesNotRewriteBody` / `indexInsideVault: false`

Demo also records `dailyUnchanged: true` (ensured `daily/2026-08-13.md` then saved Person + Book; daily body unchanged). Book body has no `[[`. YAML `author` is a UUID, not a path.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` (366) |
| `demo-object-select.log` | `./scripts/demo-object-select.sh` |
| `object-select.json` | copy of `DevHarness/public/demo-object-select/object-select.json` |
| `e2e-full.log` | `./scripts/e2e.sh` (85) |
| `harness.html` | DevHarness `/?panel=types` (SPA shell; proofs render after fetch) |

## Pitfalls

- Properties must not import `LinkPickerView`. Duplicate a small picker; share `IndexQuerying.linkCandidates`.
- Bare YAML string arrays decode as object-select only when every entry is a UUID or `[[wiki-link]]`. Broken refs from the picker are **missing UUIDs**, not free-form slugs.
- Do not rewrite object/daily markdown with `[[id]]` when setting object-select. Links come from YAML + the disposable `links` table.
- Stacked vault version assertions (`contains("pr39")`) must also accept `pr40`.
