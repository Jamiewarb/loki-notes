# PR43 evidence

**Branch:** `cursor/pr43-weblink-preview-d2c1`  
**Based on:** `cursor/pr42-kanban-d2c1`  
**Vault module:** `0.43.0-pr43`  
**MARKETING_VERSION:** `0.43.0`  
**XCTest:** **412** passed (was 396).  
**Playwright:** **94** passed (was 91; +integrations weblink preview card, +integrations cache-outside-vault / noFetchOnType, +architecture weblink JSON).

Linux cannot compile `App/` SwiftUI. The inspector card lives in `App/Features/Weblinks/` (`WeblinksFeature.preview` composed from `InspectorHostView`) and is proven via XCTest (pure `OpenGraphHTMLParser` / `LinkPreviewProof` + `LinkPreviewService` cache next to the index) and DevHarness fixtures. ObjectEditor does not import Weblinks.

## Proof flags

`parsesOpenGraph` / `cacheOutsideVault` / `noFetchOnType` / `indexInsideVault: false`

Demo also records `dailyUnchanged: true`, `cacheInsideVault: false`, `yamlContainsOgTitle: false`. Created a Weblink with `url=https://example.com/article`, ran `FakeLinkPreviewFetcher` on fixture HTML (`og:title` Example Article). Cache file is `previews.json` beside `index.sqlite` (temp Application Support stand-in), not under the vault. Typing save did not increment fetch count. Daily markdown unchanged. OG not written to YAML.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` (412) |
| `demo-weblink-preview.log` | `./scripts/demo-weblink-preview.sh` |
| `weblink-preview.json` | copy of `DevHarness/public/demo-weblink-preview/weblink-preview.json` |
| `e2e-full.log` | `./scripts/e2e.sh` (94) |
| `harness.html` | DevHarness `/?panel=safari` (SPA shell; proofs render after fetch) |

## Pitfalls

- Never put `previews.json` / SQLite inside the vault. Cache sits next to `index.sqlite` (Application Support).
- Do not persist `og-title` / `og-description` onto weblink YAML (iCloud churn). Cache-only is the default.
- Do not fetch on editor typing debounce. Fetch on weblink open, after create if url present, or Refresh preview.
- Failures: empty placeholder; do not crash; do not rewrite markdown. Only GET the user-stored weblink URL (http(s)).
- Linux uses FakeLinkPreviewFetcher — URLSession is Apple-only (`FoundationNetworking` is not imported). No live internet in CI.
- ObjectEditor must not import Weblinks. AppShell / InspectorHostView composition is the pattern.
- Stacked vault version assertions (`contains("pr42")`) must also accept `pr43`.
- Index stays in Application Support. Demo JSON `indexInsideVault: false`.
