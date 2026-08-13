# PR30 evidence — AI assist

## Summary

Side-panel AI assist: summarize / rewrite / translate / property autofill.
On-device heuristics by default; BYOK settings + credentials live under Application Support
(never the vault). Remote upload requires `uploadVaultOptIn` **and** per-request
`allowRemoteUpload`. Apply goes through `ObjectServing.save` / `EditorSession.applyProposedBody`
— AI never writes vault files itself.

## Versions

| Module | Version |
|---|---|
| LociVault | `0.30.0-pr30` |
| LociMarkdown | `0.2.0-pr30` |
| LociIndex | `0.2.0-pr30` |
| MARKETING_VERSION | `0.30.0` |

## Write path

```
User taps Summarize/Rewrite/Translate/Autofill
  → AIServing.run (heuristics or BYOK if opt-in)
  → AIProposal (uploaded=false unless remote transport actually sent bytes)
  → AIServing.apply → ObjectServing.open/save/open
  → or EditorSession.applyProposedBody + applyProperties (when editor open)
```

Credentials: `AICredentialStore` → Application Support `Loci/ai/credentials.json` (0600).
Settings: `AIService` → same directory `settings.json`. Index remains outside vault.

## Privacy

- Default `AISettings.uploadVaultOptIn = false`
- `AIPrivacy.remotePayloadAllowed` requires opt-in **and** `request.allowRemoteUpload`
- Payload text is **this object's** title+body only
- Demo proves BYOK without opt-in throws `aiUploadNotAllowed`
- Vault scan: no `index.sqlite`, no API key string, no `credentials.json`

## Tests

- Suite: **281** tests, 0 failures (was 266 at PR29)
- New: `AIHeuristicsTests`, `AIServiceTests`, `EditorSession.applyProposedBody`, `Route.ai`

## Artifacts

| File | Notes |
|---|---|
| `lint.log` | `./scripts/lint.sh` passed (includes App/Features/AI) |
| `test.log` | `./scripts/test.sh` — 281 green |
| `demo-ai.log` / `ai.json` | `./scripts/demo-ai.sh` |
| `harness.log` / `harness.html` / `harness.png` | `?panel=ai` |

## Harness

```bash
./scripts/demo-ai.sh
./scripts/run-harness.sh
# http://127.0.0.1:5173/?panel=ai
```

## Next

PR31 — Apple Calendar / Reminders (`cursor/pr31-apple-integrations-d2c1`).
EventKit is Apple-only; keep Linux stubs. Do not rewrite daily markdown for chrome.
