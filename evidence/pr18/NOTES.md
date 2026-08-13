# PR18 evidence — Global FTS search

## Checks

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr18/lint.log`) |
| `./scripts/test.sh` | **159** tests, 0 failures (`evidence/pr18/test.log`) |
| `./scripts/demo-search.sh` | hits=3 groups=2 title+body+grouped (`demo-search.log`) |
| DevHarness `?panel=search` | rendered (`harness-search-dom.html` + `harness.png`) |

## Demo proof

- Query `focus`:
  - **Title hit:** Page “Focus Rituals”
  - **Body hits:** Page “Weekend Notes”, Book “Deep Work”
- Results **grouped by type** (page + book); title ranked first via `SearchRanking.preferTitleMatches`
- Index outside vault
- Optional bulk: `LOCI_SEARCH_BULK=1000 ./scripts/demo-search.sh`

## Artifacts

- `lint.log`, `test.log`, `demo-search.log`
- `search.json`, `harness.html`, `harness-search-dom.html`, `harness.png`, `harness.log`
