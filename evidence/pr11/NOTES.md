# PR11 — Created-today auto links

## Summary

**Created-today is index-only UI.** `CreatedTodayPanel` lists objects from `IndexQuerying.created(on:)` in the Daily inspector. Creating a Page does **not** rewrite `daily/YYYY-MM-DD.md` (proven by content fingerprint + mtime + bytes).

## UX decision

| Choice | Rationale |
|---|---|
| **Exclude Daily-type** objects from the panel | You’re already viewing that day’s note; listing it is noise |
| Raw `created(on:)` still includes the daily note | Index query stays complete for other consumers |
| No auto wiki-links / embeds in daily body | Avoids cross-device thrash (PLAN Part 14) |

## What landed

| Piece | Location |
|---|---|
| `CreatedTodayPanel` | `App/Features/DailyNotes/UI/CreatedTodayPanel.swift` |
| Daily inspector wiring | `InspectorHostView` + `AppServices.inspectedDailyDay` |
| Day sync | `DailyNoteView` / `DaySwitcher` updates inspected day |
| Non-mutation tests | `CreatedTodayNonMutationTests` (fingerprint + mtime + bytes) |
| Demo CLI | `loci-created-today-demo` + `scripts/demo-created-today.sh` |
| Harness | Daily panel section + inspector links from `demo-created-today/` |
| Version | `LociVaultModule` → `0.11.0-pr11` |

## Proof: daily file unchanged

From `created-today.json` / unit test:

- `proof.dailyUnchanged = true`
- `beforeHash == afterHash`
- `beforeMtime == afterMtime`
- Daily markdown body does not contain created Page titles

## Tests

- **97** package tests (was 95) — +`testCreatePageDoesNotMutateDailyMarkdownBytes`, +`testCreatedOnQueryIncludesPageAndDailySeparately`
- Lint + build green

## Harness

- `http://127.0.0.1:5173/?panel=daily`
- Shows Created today list (Deep Work Notes, Second Capture) + inspector links + “daily .md unchanged ✓”
- Artifacts: `harness-daily.png`, `harness-daily-dom.html`, `created-today.json`, `today.md`

## Notes for PR12 (Custom object types)

- Created-today panel already filters only `.daily`; custom types will appear automatically via `created(on:)` once indexed
- Type dashboards / sidebar entries are PR12 — do not invent type folders here
- Keep CreatedToday writes = none
