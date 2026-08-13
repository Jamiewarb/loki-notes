#!/usr/bin/env bash
# scripts/demo-menubar.sh — PR38 menu bar + Safari proofs (reuses safari demo).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/demo-safari.sh"

python3 - <<'PY'
import json, pathlib
data = json.loads(pathlib.Path("DevHarness/public/demo-safari/safari.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
proof = data.get("proof") or {}
assert proof.get("menuBarWired") is True, proof
assert proof.get("safariExtractsPage") is True, proof
assert proof.get("inboxNotIndex") is True, proof
assert proof.get("indexInsideVault") is False, proof
assert data.get("openTodayURL") == "loci://daily/today"
print(
    "menuBarWired safariExtractsPage inboxNotIndex indexInsideVault=false "
    f"url={data.get('openTodayURL')}"
)
PY
