# PR21 evidence — Sync UX and resilience (Wave B MVP)

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr21/lint.log`) |
| `./scripts/test.sh` | **189** tests, 0 failures (`evidence/pr21/test.log`) |
| `./scripts/demo-sync.sh` | passed — conflict status + markdown/media conflicts + rebuild (`demo.log`, `sync.json`) |
| DevHarness `?panel=settings` | served; DOM + screenshot (`harness-settings-dom.html`, `harness-settings.png`) |

## Demo proof

- Local baseline derives **local-only** (`proof.localOnlyBaseline`)
- Planted conflicted copies elevate live status to **conflict** (`proof.conflictStatusFromCopies`)
- Markdown + media conflicts listed (`hasMarkdownConflict`, `hasMediaConflict`)
- Ensure-downloaded no-op on local (`ensureDownloadedNoOp`)
- Rebuild index from vault (`rebuildIndexOk`)
- Reveal vault path returns path string (`pathRevealed`)
- Simulated chip states for Linux harness (local / syncing / offline / iCloud / conflict / error)

## MVP summary (Wave B)

PR09–PR21 deliver Capacities-core daily loop + types + templates + PARA + links + tags + search + tasks + media + sync UX, with vault-as-truth and disposable Application Support index.

## Handoff

Next: **PR22 Collections** — manual collections per type; membership file; type dashboard tabs.
