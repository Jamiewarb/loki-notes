# PR31 evidence — Apple Calendar and Reminders

**Branch:** `cursor/pr31-apple-integrations-d2c1`  
**Vault module:** `0.31.0-pr31`  
**Tests:** **291** green (was 281)

## Artifacts

| File | Notes |
|---|---|
| `lint.log` | `./scripts/lint.sh` passed (incl. AppleIntegrations feature folder) |
| `test.log` | `./scripts/test.sh` — 291 tests, 0 failures |
| `demo-apple.log` | `./scripts/demo-apple.sh` |
| `apple.json` | Fixture from `loci-apple-demo` |
| `harness.html` | `curl http://127.0.0.1:5173/?panel=apple` |
| `harness.png` | Headless Chrome screenshot (`--user-data-dir=/tmp/loci-chrome-pr31`) |
| `harness.log` | Chrome stdout |

## Proofs (from apple.json)

- Events listed for 2026-08-13 (“Design review”) without rewriting daily markdown
- Meeting created under `objects/meeting/`; second create idempotent on `event-id`
- Reminders sync (enabled) pulled “Ship PR31” into daily as `- [ ] Ship PR31`
- Index + settings outside vault

## Next: PR32 Safari clipper

Share/inbox pattern like Capture; Linux capture-like writer; Safari App Extension stub under `App/Platform/`.
