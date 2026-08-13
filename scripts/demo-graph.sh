#!/usr/bin/env bash
# scripts/demo-graph.sh — Link graph fixtures for DevHarness (PR24 / PR45 polish).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-graph"
mkdir -p "$OUT_DIR"

echo "==> loci-graph-demo"
swift run --package-path "$ROOT" loci-graph-demo > "$OUT_DIR/graph.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-graph")
data = json.loads((root / "graph.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
g = data.get("graph") or {}
assert g.get("nodeCount", 0) >= 3, g
assert g.get("edgeCount", 0) >= 3, g
assert g.get("unresolvedLinkCount", 0) >= 1, g
assert len(g.get("nodes") or []) == g.get("nodeCount")
assert len(g.get("edges") or []) == g.get("edgeCount")
books = data.get("booksFilter") or {}
assert books.get("nodeCount") == 2, books
assert books.get("edgeCount") == 1, books
cap = data.get("capProof") or {}
assert cap.get("truncated") is True, cap
assert cap.get("nodeCount", 99) <= 2, cap
assert cap.get("edgeCount", 99) <= 1, cap
proof = data.get("proof") or {}
assert proof.get("hubLinksToBooks") is True, proof
assert proof.get("booksLinkInternally") is True, proof
assert proof.get("unresolvedCounted") is True, proof
assert proof.get("hidesHighDegree") is True, proof
assert proof.get("focusNeighbors") is True, proof
assert proof.get("layoutNotWrittenToVault") is True, proof
assert proof.get("indexInsideVault") is False, proof
hide = data.get("hideHubs") or {}
assert hide.get("hiddenHubs") is True, hide
assert "Deep Work" not in (hide.get("titles") or []), hide
focus = data.get("focusNeighbors") or {}
assert focus.get("isolatedFocus") is True, focus
assert "Focus Notes" not in (focus.get("titles") or []), focus
assert data.get("layoutNotWrittenToVault") is True, data
print(
    f"nodes={g.get('nodeCount')} edges={g.get('edgeCount')} "
    f"books={books.get('nodeCount')}/{books.get('edgeCount')} "
    f"capped={cap.get('nodeCount')}/{cap.get('edgeCount')} "
    f"unresolved={g.get('unresolvedLinkCount')} "
    f"hide={hide.get('nodeCount')} focus={focus.get('nodeCount')}"
)
PY

echo "wrote DevHarness/public/demo-graph/graph.json"
