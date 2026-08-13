#!/usr/bin/env bash
# scripts/demo-search.sh — Global FTS search fixtures for DevHarness (PR18).
# Optional: LOCI_SEARCH_BULK=1000 ./scripts/demo-search.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-search"
mkdir -p "$OUT_DIR"

echo "==> loci-search-demo"
swift run --package-path "$ROOT" loci-search-demo > "$OUT_DIR/search.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-search")
data = json.loads((root / "search.json").read_text())
proof = data.get("proof") or {}
assert proof.get("titleHit") is True, proof
assert proof.get("bodyHit") is True, proof
assert proof.get("bookBodyHit") is True, proof
assert proof.get("groupedByType") is True, proof
assert proof.get("titleFirst") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert (proof.get("hitCount") or 0) >= 3, proof
groups = data.get("grouped") or []
types = {g.get("type") for g in groups}
assert types == {"page", "book"}, types
print(
    f"hits={proof.get('hitCount')} groups={proof.get('groupCount')} "
    f"objects={proof.get('objectCount')} bulk={data.get('bulkSeeded', 0)} "
    f"titleFirst={proof.get('titleFirst')} indexOutsideVault=True"
)
PY

echo "==> wrote $OUT_DIR/search.json"
echo "==> demo-search complete"
