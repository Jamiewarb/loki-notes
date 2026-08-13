#!/usr/bin/env bash
# scripts/demo-tags.sh — Tags / #health cross-type fixtures for DevHarness (PR17).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-tags"
mkdir -p "$OUT_DIR"

echo "==> loci-tags-demo"
swift run --package-path "$ROOT" loci-tags-demo > "$OUT_DIR/tags.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-tags")
data = json.loads((root / "tags.json").read_text())
proof = data.get("proof") or {}
assert proof.get("healthCount", 0) == 2, proof
assert proof.get("crossType") is True, proof
assert set(proof.get("types") or []) == {"page", "book"}, proof
assert proof.get("aliasWellnessMatches") is True, proof
assert proof.get("completerHasHealth") is True, proof
assert proof.get("bodyHasHashHealth") is True, proof
assert data.get("indexInsideVault") is False, "index must not live in vault"
objs = data.get("healthObjects") or []
assert len(objs) == 2, objs
print(
    f"health={proof.get('healthCount')} types={proof.get('types')} "
    f"aliasOK={proof.get('aliasWellnessMatches')} indexOutsideVault=True"
)
PY

echo "==> wrote $OUT_DIR/tags.json"
echo "==> demo-tags complete"
