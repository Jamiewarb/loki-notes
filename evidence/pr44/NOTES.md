# PR44 evidence

**Branch:** `cursor/pr44-unlinked-mentions-d2c1`  
**Based on:** `cursor/pr43-weblink-preview-d2c1`  
**Vault module:** `0.44.0-pr44`  
**MARKETING_VERSION:** `0.44.0`  
**XCTest:** **427** passed (was 412).  
**Playwright:** **97** passed (was 94; +retrieval unlinked list, scan does not rewrite until Link, explicit Link inserts wiki-link).

Linux cannot compile `App/` SwiftUI. The inspector panel lives in `App/Features/Links/` (`LinksFeature.unlinkedMentions` composed from `InspectorHostView` next to `BacklinksPanel`) and is proven via XCTest (`UnlinkedMentionScanner` / `UnlinkedMentionProof` + `IndexQuerying.unlinkedMentions`) and DevHarness fixtures.

## Proof flags

`detectsPlainTitle` / `ignoresExistingWikiLink` / `doesNotRewriteBody` / `indexInsideVault: false`

Demo: Page **Deep Work**; Page **Notes** body contains plain “Deep Work”; Page **Journal** already wiki-links and is excluded. Mentions list includes Notes. Notes.md has no `[[` until the recorded Link step (`notesBodyAfterLink`). Daily markdown unchanged. Index outside vault.

| Artifact | Source |
|---|---|
| `lint.log` | `./scripts/lint.sh` |
| `test.log` | `./scripts/test.sh` (427) |
| `demo-unlinked-mentions.log` | `./scripts/demo-unlinked-mentions.sh` |
| `unlinked-mentions.json` | copy of `DevHarness/public/demo-unlinked-mentions/unlinked-mentions.json` |
| `e2e-full.log` | `./scripts/e2e.sh` (97) |
| `harness.html` | DevHarness `/?panel=links` (SPA shell; proofs render after fetch) |

## Pitfalls

- Do not auto-rewrite markdown for mentions. Derived UI only. Link is an explicit tap.
- Typing must never wait on mention scan.
- FTS body flattens wiki-links to display text — exclude resolved outgoing links before trusting FTS, then verify on vault markdown with the scanner (skip `[[...]]`, word-boundary / phrase).
- Short titles (< 3 chars) are skipped. “deep working” must not match “Deep Work”.
- `ObjectServing` save/open may drop a trailing newline; that is serializer normalize, not a mention rewrite. Proof compares trimmed bodies.
- Stacked vault version assertions (`contains("pr43")`) must also accept `pr44`.
- Index stays in Application Support. Demo JSON `indexInsideVault: false`.
