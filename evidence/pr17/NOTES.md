# PR17 evidence — Tags

## Checks

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr17/lint.log`) |
| `./scripts/test.sh` | **152** tests, 0 failures (`evidence/pr17/test.log`) |
| `./scripts/demo-tags.sh` | health=2 types=book,page aliasOK (`demo-tags.log`) |
| DevHarness `?panel=tags` | rendered (`harness-tags-dom.html` + `harness.png`) |

## Demo proof

- Page **Morning walk** (frontmatter `tags: [health]`) + Book **Atomic Habits** (body `#health`)
- Tag page lists both (cross-type)
- Alias `wellness → health` expands queries
- `#` completer matches `hea` → health
- Index outside vault

## Artifacts

- `lint.log`, `test.log`, `demo-tags.log`
- `tags.json`, `harness.html`, `harness-tags-dom.html`, `harness.png`, `harness.log`
