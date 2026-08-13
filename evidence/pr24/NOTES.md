# PR24 evidence — Graph view

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr24/lint.log`) |
| `./scripts/test.sh` | **211** tests, 0 failures (`evidence/pr24/test.log`) — was 202 on PR23 |
| `./scripts/demo-graph.sh` | passed — 4 nodes / 4 edges, books filter 2/1, cap 2/1 (`demo.log`, `graph.json`) |
| DevHarness `?panel=graph` | served; DOM snapshot (`harness-graph-dom.html`, `harness.html`) |

## Demo proof

- Graph from `IndexQuerying.graph` over links table (not markdown scrape)
- Unresolved broken link counted (`unresolvedLinkCount >= 1`)
- Type filter `book` → 2 nodes / 1 edge (Range → Deep Work)
- Caps `maxNodes=2, maxEdges=1` → `truncated=true`
- Index not inside vault (`indexInsideVault=false`)
- Deterministic layout positions embedded in fixture nodes (`x`/`y`)

## Handoff

Next: **PR25 Calendar UI** — month/week around daily notes; dots for days with content/creations; jump to daily.
