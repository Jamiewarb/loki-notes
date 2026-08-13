#!/usr/bin/env bash
# scripts/demo-macos-ci.sh — PR39 macOS CI / shortcuts / VoiceOver / Dynamic Type proofs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-macos-ci"
mkdir -p "$OUT_DIR"

echo "==> loci-macos-ci-demo"
swift run --package-path "$ROOT" loci-macos-ci-demo > "$OUT_DIR/macos-ci.json"

python3 - <<'PY'
import json, pathlib

root = pathlib.Path(".")
workflow = (root / ".github/workflows/ci.yml").read_text()
assert "macos-14" in workflow, "ci.yml must contain macos-14"
assert "xcodebuild" in workflow, "ci.yml must contain xcodebuild"
assert "macos-xcode" in workflow, "ci.yml must contain macos-xcode job"
print("workflow: macos-14 + xcodebuild present")

data = json.loads((root / "DevHarness/public/demo-macos-ci/macos-ci.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("linuxCannotRunXcodebuild") is True, data
assert data.get("workflowRunner") == "macos-14", data
proof = data.get("proof") or {}
assert proof.get("macosCIWorkflowPresent") is True, proof
assert proof.get("shortcutsCatalogued") is True, proof
assert proof.get("voiceOverLabelsPresent") is True, proof
assert proof.get("dynamicTypeScales") is True, proof
assert proof.get("indexInsideVault") is False, proof
shortcuts = data.get("shortcuts") or []
assert len(shortcuts) == 4, shortcuts
ids = {s.get("actionID") for s in shortcuts}
assert ids == {"newPage", "search", "goToday", "quickCapture"}, ids
search = next(s for s in shortcuts if s.get("actionID") == "search")
assert search.get("key") == "k" and search.get("modifiers") == "command", search
capture = next(s for s in shortcuts if s.get("actionID") == "quickCapture")
assert capture.get("key") == "n" and "shift" in (capture.get("modifiers") or ""), capture
idents = data.get("accessibilityIdentifiers") or []
assert set(idents) == {
    "daily-note",
    "object-editor",
    "search-destination",
    "vault-settings",
}, idents
print(
    "macosCIWorkflowPresent shortcutsCatalogued voiceOverLabelsPresent "
    "dynamicTypeScales indexInsideVault=false"
)
PY
