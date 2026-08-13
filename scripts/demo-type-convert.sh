#!/usr/bin/env bash
# scripts/demo-type-convert.sh — Type conversion fixture for DevHarness (PR28).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-type-convert"
mkdir -p "$OUT_DIR"

echo "==> loci-type-convert-demo"
swift run --package-path "$ROOT" loci-type-convert-demo > "$OUT_DIR/type-convert.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-type-convert")
data = json.loads((root / "type-convert.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
proof = data.get("proof") or {}
assert proof.get("idStable") is True, proof
assert proof.get("movedFolder") is True, proof
assert proof.get("oldPathGone") is True, proof
assert proof.get("newPathExists") is True, proof
assert proof.get("statusMapped") is True, proof
assert proof.get("ratingToScore") is True, proof
assert proof.get("isbnDropped") is True, proof
assert proof.get("indexTypeUpdated") is True, proof
assert proof.get("indexPathUpdated") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert proof.get("refusedDaily") is True, proof
obj = data.get("object") or {}
assert obj.get("sourceType") == "book", obj
assert obj.get("targetType") == "person", obj
print(
    f"convert {obj.get('oldPath')} → {obj.get('newPath')} "
    f"proof_ok={sum(1 for v in proof.values() if v)}/{len(proof)} "
    f"module={data.get('moduleVersion')}"
)
PY

echo "wrote DevHarness/public/demo-type-convert/type-convert.json"
