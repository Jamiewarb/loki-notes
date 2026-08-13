#!/usr/bin/env bash
# scripts/demo-capture.sh — Capture inbox → daily fixtures for DevHarness (PR26).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-capture"
mkdir -p "$OUT_DIR"

echo "==> loci-capture-demo"
swift run --package-path "$ROOT" loci-capture-demo > "$OUT_DIR/capture.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-capture")
data = json.loads((root / "capture.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
proof = data.get("proof") or {}
assert proof.get("inboxThenDrain") is True, proof
assert proof.get("appendLandedInDaily") is True, proof
assert proof.get("directMenuBarInDaily") is True, proof
assert proof.get("createdTypedObject") is True, proof
assert proof.get("inboxStagingRemoved") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert (data.get("dailyPath") or "").startswith("daily/"), data.get("dailyPath")
assert (data.get("pendingAfter") or []) == [], data.get("pendingAfter")
surfaces = data.get("surfaces") or []
assert len(surfaces) >= 3, surfaces
print(
    f"day={data.get('dayKey')} daily={data.get('dailyPath')} "
    f"drain={len(data.get('drain') or [])} pendingAfter={len(data.get('pendingAfter') or [])}"
)
PY

echo "wrote DevHarness/public/demo-capture/capture.json"
