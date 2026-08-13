#!/usr/bin/env bash
# scripts/demo-apple.sh — Apple Calendar / Reminders fixtures for DevHarness (PR31 / PR36).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-apple"
mkdir -p "$OUT_DIR"

echo "==> loci-apple-demo"
swift run --package-path "$ROOT" loci-apple-demo > "$OUT_DIR/apple.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-apple")
data = json.loads((root / "apple.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("settingsInsideVault") is False, "settings must not live in vault"
proof = data.get("proof") or {}
assert proof.get("eventsListed") is True, proof
assert proof.get("meetingPath") is True, proof
assert proof.get("idempotent") is True, proof
assert proof.get("dailyUnchanged") is True, proof
assert proof.get("reminderSynced") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert proof.get("settingsOutsideVault") is True, proof
assert proof.get("eventKitWired") is True, proof
assert proof.get("linuxUsesFakes") is True, proof
assert data.get("dailyUnchangedAfterEvents") is True
assert data.get("eventKitWired") is True
assert data.get("linuxUsesFakes") is True
assert data.get("dailyUnchanged") is True
assert data.get("reminderSynced") is True
meeting = data.get("meeting") or {}
assert str(meeting.get("path", "")).startswith("objects/meeting/"), meeting
events = data.get("events") or []
assert len(events) == 1 and events[0].get("title") == "Design review", events
print(
    f"events={len(events)} meeting={meeting.get('path')} "
    f"dailyUnchanged={data.get('dailyUnchangedAfterEvents')} "
    f"reminderSynced={data.get('reminderSynced')} "
    f"module={data.get('moduleVersion')}"
)
PY

echo "wrote DevHarness/public/demo-apple/apple.json"
