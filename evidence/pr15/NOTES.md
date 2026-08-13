# PR15 — PARA starter pack

## Summary

Idempotent **Apply PARA pack** creates **Project** and **Area** types with starter properties and default templates. **Resource** uses `#resource` tag (no dedicated type). **Archive** uses `#archive` tag and/or `status=Archived` — dashboards hide archived by default; files are never folder-moved.

## Demo proof

| Check | Result |
|---|---|
| Project `project.default` | `.loci/templates/project.default.md` |
| Prefills `## Outcome` / `## Next actions` | `projectObject.prefilled=true` |
| Area `area.default` | Standards / Current focus |
| Resource approach | `tag:#resource` · no Resource type |
| Archive approach | `tag:#archive` · `hideArchived=true` · no folder move |
| Idempotent re-apply | `idempotent=true` |
| Index outside vault | `indexInsideVault=false` |

## What landed

| Piece | Location |
|---|---|
| `PARAPack.apply` + `ArchiveFilter` | `LociCore/Models/PARAPack.swift` |
| Space PARA fields | `SpaceSettings` (`paraPackApplied`, `hideArchived`, approaches) |
| Dashboard hide flag | `TypeDashboardConfig.hideArchived` |
| UI Apply + explainer | `Features/PARA/` + Settings |
| Type dashboard filter | `TypeDashboardView` via `ArchiveFilter` |
| Demo | `loci-para-demo` + `scripts/demo-para.sh` |
| Harness | Settings PARA card + Types Project/Area section |
| Version | `LociVaultModule` / `LociIndexModule` → pr15 |

## Design choices

1. **Resource = `#resource` tag** (not a type) — matches Capacities “whole space or `#resource` tag”.
2. **Archive = `#archive` / status** — filter hides; never filesystem move.
3. **Inbox = Daily** (already seeded).

## Tests

- **127** package tests (was 120)
- Lint + build green

## Harness

- `http://127.0.0.1:5173/?panel=settings` — Apply PARA explainer + proof
- `http://127.0.0.1:5173/?panel=types` — Project/Area rows + archive filter note
- Artifacts: `harness-settings.png`, `harness-types.png`, `para.json`

## Notes for PR16 (wiki-links)

- Object-select `area` property on Project can become real links once LinkResolver lands
- Backlinks panel will show Project↔Area references
- Do not put SQLite / index inside the vault
