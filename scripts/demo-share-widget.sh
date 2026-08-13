#!/usr/bin/env bash
# scripts/demo-share-widget.sh — PR37 Share + Widget proofs (reuses capture demo).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Same fixture as capture — ShareInboxFactory + loci://daily/today live there.
"$ROOT/scripts/demo-capture.sh"

python3 - <<'PY'
import json, pathlib
data = json.loads(pathlib.Path("DevHarness/public/demo-capture/capture.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
proof = data.get("proof") or {}
assert proof.get("shareExtractsText") is True, proof
assert proof.get("widgetOpenToday") is True, proof
assert proof.get("inboxNotIndex") is True, proof
assert proof.get("indexInsideVault") is False, proof
assert data.get("openTodayURL") == "loci://daily/today"
print(
    "shareExtractsText widgetOpenToday inboxNotIndex indexInsideVault=false "
    f"url={data.get('openTodayURL')}"
)
PY
