#!/usr/bin/env bash
# scripts/demo-safari.sh — Safari web clipper fixtures for DevHarness (PR32).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-safari"
mkdir -p "$OUT_DIR"

echo "==> loci-safari-demo"
swift run --package-path "$ROOT" loci-safari-demo > "$OUT_DIR/safari.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-safari")
data = json.loads((root / "safari.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
proof = data.get("proof") or {}
assert proof.get("dailyLineHasSafari") is True, proof
assert proof.get("weblinkPath") is True, proof
assert proof.get("weblinkURLProperty") is True, proof
assert proof.get("inboxEmpty") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert proof.get("directClip") is True, proof
assert data.get("pendingAfterDrain") == 0, data
assert str(data.get("weblinkPath", "")).startswith("objects/weblink/"), data
assert "· safari" in str(data.get("dailyLine", "")), data
print(
    f"dailyLine={data.get('dailyLine')!r} weblink={data.get('weblinkPath')} "
    f"inboxEmpty={data.get('pendingAfterDrain') == 0} "
    f"module={data.get('moduleVersion')}"
)
PY

echo "wrote DevHarness/public/demo-safari/safari.json"
