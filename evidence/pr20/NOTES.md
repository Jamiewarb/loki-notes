# PR20 evidence — Media

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr20/lint.log`) |
| `./scripts/test.sh` | **175** tests, 0 failures (`evidence/pr20/test.log`) |
| `./scripts/demo-media.sh` | passed — image/file in `media/`; markdown image; blob not in index (`demo.log`, `media.json`) |
| DevHarness `?panel=media` | served; DOM + screenshot (`harness-media-dom.html`, `harness-media.png`) |

## Demo proof

- Attach image → `media/images/` (`proof.imageInMediaImages`)
- Attach file → `media/files/` (`proof.fileInMediaFiles`)
- Page body contains `![Hero](../../media/images/…)` (`proof.pageHasMarkdownImage`)
- Image object created with `media-path` property (`proof.imageObjectCreated`)
- Blob bytes absent from SQLite (`proof.blobNotInIndex`)
- Index outside vault (`proof.indexOutsideVault`)

## Handoff

Next: **PR21 Sync UX** — status chip, ensure-downloaded (incl. media), conflicts, rebuild index.
