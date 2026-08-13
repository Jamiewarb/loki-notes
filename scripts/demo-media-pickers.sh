#!/usr/bin/env bash
# scripts/demo-media-pickers.sh — Photos / drop attach proofs (PR35).
# Linux uses MediaServing.attach(fileURL:); photosPickerWired / dragDropWired mean “code present”.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

# Reuse the media demo binary — same attach(fileURL:) path as Photos / drop.
"$ROOT/scripts/demo-media.sh"

python3 - <<'PY'
import json, pathlib, re
root = pathlib.Path("DevHarness/public/demo-media")
data = json.loads((root / "media.json").read_text())
proof = data.get("proof") or {}
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert proof.get("photosPickerWired") is True, proof
assert proof.get("dragDropWired") is True, proof
assert proof.get("attachedViaFileURL") is True, proof
assert proof.get("markdownRelativePathStartsWithMedia") is True, proof
assert proof.get("noteBodyHasAbsolutePath") is False, proof
body = (data.get("page") or {}).get("bodyMarkdown") or ""
assert "media/" in body, body
assert "/tmp/" not in body and "file://" not in body, body
for url in re.findall(r"!\[[^\]]*\]\(([^)]+)\)", body):
    dest = url.split()[0].strip("\"'")
    assert not dest.startswith("/"), dest
    assert not dest.startswith("file:"), dest
    assert "media/" in dest, dest
rel = (data.get("imageAttachment") or {}).get("relativePath") or ""
assert rel.startswith("media/"), rel
picker = data.get("picker") or {}
assert picker.get("photosUIStaysInApp") is True, picker
print(
    f"photosPickerWired={proof.get('photosPickerWired')} "
    f"dragDropWired={proof.get('dragDropWired')} "
    f"attachedViaFileURL={proof.get('attachedViaFileURL')} "
    f"indexInsideVault={data.get('indexInsideVault')} "
    f"relative={rel}"
)
PY

echo "==> demo-media-pickers complete"
