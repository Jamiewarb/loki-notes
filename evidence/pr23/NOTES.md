# PR23 evidence — Saved queries + embeds

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr23/lint.log`) |
| `./scripts/test.sh` | **202** tests, 0 failures (`evidence/pr23/test.log`) — was 194 on PR22 |
| `./scripts/demo-queries.sh` | passed — reading-focus query, 2 live hits (`demo.log`, `queries.json`) |
| DevHarness `?panel=types` / `?panel=editor` | served; DOM snapshot (`harness-types-dom.html`, `harness.html`) |

## Demo proof

- Definition file `.loci/queries/reading-focus.json` exists (`query.exists`, `definitionOnly=true`)
- Live hits: Deep Work + Range (type=book, tag=focus, status=Reading)
- `/query` embed stores slug only (`storesResultsInBody=false`)
- Index not inside vault (`indexInsideVault=false`, `definitionIsVaultFile=true`)
- Pinned to book type dashboard (`pinnedQueryIDs=["reading-focus"]`)

## Handoff

Next: **PR24 Graph view** — force-directed / adjacency graph from links table; filter by type; open on node tap; performance cap.
