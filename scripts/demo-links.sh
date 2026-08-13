#!/usr/bin/env bash
# scripts/demo-links.sh — Wiki-links / backlinks fixtures for DevHarness (PR16).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-links"
mkdir -p "$OUT_DIR"

echo "==> loci-links-demo"
swift run --package-path "$ROOT" loci-links-demo > "$OUT_DIR/links.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-links")
data = json.loads((root / "links.json").read_text())
proof = data.get("proof") or {}
assert proof.get("aLinksToB") is True, proof
assert proof.get("backlinkCount", 0) >= 1, proof
assert proof.get("brokenCount", 0) >= 1, proof
assert proof.get("resolvedCount", 0) >= 1, proof
assert proof.get("preferredTargetIsObjectID") is True, proof
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert (data.get("resolve") or {}).get("brokenIsNil") is True
backs = data.get("backlinksOnB") or []
assert any(b.get("sourceTitle") == "Page A" for b in backs), backs
html = data.get("html") or ""
assert "wiki-link" in html, html
assert "is-broken" in html, html
print(
    f"a→b backlinks={proof.get('backlinkCount')} broken={proof.get('brokenCount')} "
    f"resolved={proof.get('resolvedCount')} indexOutsideVault=True"
)
PY

echo "==> wrote $OUT_DIR/links.json"
echo "==> demo-links complete"
