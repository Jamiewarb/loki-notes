# PR01 verification evidence

Date: 2026-08-13 (UTC)

## Environment

- OS: Ubuntu 24.04.4 LTS (x86_64)
- Swift: 6.2 (swift-6.2-RELEASE) at `/opt/swift`
- Node: v22.14.0 / npm 10.9.7

## Commands run

```bash
export PATH=/opt/swift/usr/bin:$PATH
./scripts/lint.sh    # → evidence/pr01/lint.log — PASSED
./scripts/test.sh    # → evidence/pr01/test.log — PASSED (8 tests, 0 failures)
./scripts/run-harness.sh
curl http://127.0.0.1:5173/   # → evidence/pr01/harness.html — HTTP 200, title "Loci — DevHarness"
```

## Verified

- [x] `swift build` succeeds for Linux SPM packages
- [x] `swift test` green (ObjectID round-trip + stubs)
- [x] No TODO crash stubs in Sources
- [x] DevHarness serves homepage with brand **Loci**
- [x] `/src/main.ts` returns HTTP 200 under Vite

## Not verified on this host

- Xcode / iOS Simulator / macOS app launch (no Xcode on Linux VM)
- `xcodegen generate` (Mac-only; `project.yml` provided for Mac agents)
