#!/usr/bin/env bash
# scripts/demo-sync.sh — Sync UX fixtures for DevHarness Settings (PR21).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-sync"
mkdir -p "$OUT_DIR"

echo "==> loci-sync-demo"
swift run --package-path "$ROOT" loci-sync-demo > "$OUT_DIR/sync.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-sync")
data = json.loads((root / "sync.json").read_text())
proof = data.get("proof") or {}
assert proof.get("localOnlyBaseline") is True, proof
assert proof.get("conflictStatusFromCopies") is True, proof
assert proof.get("hasMarkdownConflict") is True, proof
assert proof.get("hasMediaConflict") is True, proof
assert proof.get("ensureDownloadedNoOp") is True, proof
assert proof.get("rebuildIndexOk") is True, proof
assert proof.get("pathRevealed") is True, proof
conflicts = data.get("conflicts") or []
assert len(conflicts) >= 2, conflicts
sim = data.get("simulatedStatuses") or []
assert len(sim) >= 4, sim
print(
    f"status={data.get('status')} conflicts={len(conflicts)} "
    f"simulated={len(sim)} rebuild={proof.get('rebuildIndexOk')}"
)
PY

echo "==> wrote $OUT_DIR/sync.json"
echo "==> demo-sync complete"
