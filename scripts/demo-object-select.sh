#!/usr/bin/env bash
# scripts/demo-object-select.sh — Person + Book author object-select proofs (PR40).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-object-select"
mkdir -p "$OUT_DIR"

echo "==> loci-object-select-demo"
swift run --package-path "$ROOT" loci-object-select-demo > "$OUT_DIR/object-select.json"

python3 - <<'PY'
import json, pathlib, re

root = pathlib.Path("DevHarness/public/demo-object-select")
data = json.loads((root / "object-select.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("dailyUnchanged") is True, data
assert data.get("bookBodyContainsWikiLink") is False, data
assert data.get("yamlContainsAbsolutePath") is False, data
proof = data.get("proof") or {}
assert proof.get("pickerUsesIndexCandidates") is True, proof
assert proof.get("storesObjectIDs") is True, proof
assert proof.get("createsRealLinks") is True, proof
assert proof.get("doesNotRewriteBody") is True, proof
assert proof.get("indexInsideVault") is False, proof
person = data.get("person") or {}
book = data.get("book") or {}
assert person.get("title") == "Cal Newport", person
assert book.get("title") == "Deep Work", book
author_ids = data.get("authorIDs") or []
assert author_ids, author_ids
pid = person.get("id") or ""
assert pid in author_ids, (pid, author_ids)
assert re.fullmatch(r"[0-9a-f-]{36}|daily-\d{4}-\d{2}-\d{2}", pid), pid
fm = data.get("frontmatterSnippet") or ""
assert pid.lower() in fm.lower(), fm
assert "[[" not in (book.get("bodyMarkdown") or "")
backs = data.get("backlinksOnPerson") or []
assert any((b.get("sourceTitle") == "Deep Work") for b in backs), backs
outgoing = data.get("outgoingFromBook") or []
assert any((o.get("resolvedTitle") == "Cal Newport") for o in outgoing), outgoing
cands = data.get("candidates") or []
assert any((c.get("title") == "Cal Newport") for c in cands), cands
print(
    "pickerUsesIndexCandidates storesObjectIDs createsRealLinks "
    "doesNotRewriteBody dailyUnchanged indexInsideVault=false"
)
PY

echo "==> wrote $OUT_DIR/object-select.json"
echo "==> demo-object-select complete"
