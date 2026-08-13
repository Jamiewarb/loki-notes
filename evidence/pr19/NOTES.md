# PR19 evidence — Tasks

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr19/lint.log`) |
| `./scripts/test.sh` | **163** tests, 0 failures (`evidence/pr19/test.log`) |
| `./scripts/demo-tasks.sh` | passed — page toggle → completed; daily open present (`demo.log`, `tasks.json`) |
| DevHarness `?panel=tasks` | served; DOM + screenshot (`harness-tasks-dom.html`, `harness-tasks.png`) |

## Demo proof

- Check task in a Page → appears in `completedTasks` (`proof.pageToggleCompleted`)
- Today list includes daily note open task (`proof.dailyHasOpen`)
- Index outside vault (`proof.indexOutsideVault`)

## Handoff

Next: **PR20 Media** — attach into `media/`, Image type, markdown images.
