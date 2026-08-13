#!/usr/bin/env bash
# scripts/demo-media.sh — Media attach fixtures for DevHarness (PR20 / PR35 pickers).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-media"
mkdir -p "$OUT_DIR"

echo "==> loci-media-demo"
swift run --package-path "$ROOT" loci-media-demo > "$OUT_DIR/media.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-media")
data = json.loads((root / "media.json").read_text())
proof = data.get("proof") or {}
assert proof.get("imageInMediaImages") is True, proof
assert proof.get("fileInMediaFiles") is True, proof
assert proof.get("pageHasMarkdownImage") is True, proof
assert proof.get("imageObjectCreated") is True, proof
assert proof.get("blobNotInIndex") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert proof.get("photosPickerWired") is True, proof
assert proof.get("dragDropWired") is True, proof
assert proof.get("attachedViaFileURL") is True, proof
assert proof.get("markdownRelativePathStartsWithMedia") is True, proof
assert proof.get("noteBodyHasAbsolutePath") is False, proof
assert data.get("indexInsideVault") is False, "index must not live in vault"
body = (data.get("page") or {}).get("bodyMarkdown") or ""
assert "media/" in body, body
assert "/tmp/" not in body, body
assert "file://" not in body, body
assert not any(part.startswith("/") for part in __import__("re").findall(r"!\[[^\]]*\]\(([^)\s]+)", body)), body
listing = data.get("mediaListing") or {}
assert (listing.get("images") or []), listing
assert (listing.get("files") or []), listing
print(
    f"images={listing.get('images')} files={listing.get('files')} "
    f"pageImage={proof.get('pageHasMarkdownImage')} blobNotInIndex=True"
)
PY

echo "==> wrote $OUT_DIR/media.json"
echo "==> demo-media complete"
