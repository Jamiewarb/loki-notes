#!/usr/bin/env bash
# scripts/demo-queries.sh — Saved query + /query embed fixtures for DevHarness (PR23).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-queries"
mkdir -p "$OUT_DIR"

echo "==> loci-queries-demo"
swift run --package-path "$ROOT" loci-queries-demo > "$OUT_DIR/queries.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-queries")
data = json.loads((root / "queries.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("definitionIsVaultFile") is True, data
assert data.get("queriesDirectory") == ".loci/queries", data
q = data.get("query") or {}
assert q.get("id") == "reading-focus", q
assert q.get("exists") is True, q
assert q.get("definitionOnly") is True, q
assert q.get("relativePath") == ".loci/queries/reading-focus.json", q
assert data.get("resultCount") == 2, data
assert set(data.get("resultTitles") or []) == {"Deep Work", "Range"}, data
assert data.get("pinnedQueryIDs") == ["reading-focus"], data
embed = data.get("embed") or {}
assert embed.get("storesResultsInBody") is False, embed
assert embed.get("roundTripKind") == "reading-focus", embed
assert "query-embed" in (embed.get("html") or ""), embed
print(
    f"query={q.get('id')} hits={data.get('resultCount')} "
    f"vault={q.get('relativePath')} embed_results_in_body={embed.get('storesResultsInBody')}"
)
PY

# Refresh Types panel fixtures with query proof.
TYPES_DIR="$ROOT/DevHarness/public/demo-types"
mkdir -p "$TYPES_DIR"
python3 - <<'PY'
import json, pathlib
q = json.loads(pathlib.Path("DevHarness/public/demo-queries/queries.json").read_text())
existing = {}
types_path = pathlib.Path("DevHarness/public/demo-types/types.json")
if types_path.exists():
    existing = json.loads(types_path.read_text())
out = dict(existing)
out["moduleVersion"] = q.get("moduleVersion")
out["queries"] = [q.get("query")]
out["pinnedQueries"] = q.get("pinnedQueryIDs")
out["queryResults"] = q.get("results")
out["queryResultTitles"] = q.get("resultTitles")
out["queryResultCount"] = q.get("resultCount")
out["queriesDirectory"] = q.get("queriesDirectory")
out["definitionIsVaultFile"] = q.get("definitionIsVaultFile")
out["queriesNote"] = q.get("note")
if q.get("allBooksCount"):
    out["allBooksCount"] = q.get("allBooksCount")
    out["booksCount"] = q.get("allBooksCount")
types_path.write_text(json.dumps(out, indent=2) + "\n")
print("wrote DevHarness/public/demo-types/types.json (with queries)")
PY

# Editor fixtures: append query embed proof when editor.json exists.
EDITOR_DIR="$ROOT/DevHarness/public/demo-editor"
mkdir -p "$EDITOR_DIR"
python3 - <<'PY'
import json, pathlib
q = json.loads(pathlib.Path("DevHarness/public/demo-queries/queries.json").read_text())
editor_path = pathlib.Path("DevHarness/public/demo-editor/editor.json")
existing = {}
if editor_path.exists():
    existing = json.loads(editor_path.read_text())
out = dict(existing)
out["queryEmbed"] = q.get("embed")
out["queryModuleVersion"] = q.get("markdownModuleVersion")
out["note"] = ((out.get("note") or "") + " · PR23 /query embed").strip(" ·")
editor_path.write_text(json.dumps(out, indent=2) + "\n")
print("wrote DevHarness/public/demo-editor/editor.json (with query embed)")
PY

SCHEMA_DIR="$ROOT/DevHarness/public/demo-schema"
mkdir -p "$SCHEMA_DIR/queries"
python3 - <<'PY'
import json, pathlib
q = json.loads(pathlib.Path("DevHarness/public/demo-queries/queries.json").read_text())
schema = pathlib.Path("DevHarness/public/demo-schema")
queries_dir = schema / "queries"
queries_dir.mkdir(parents=True, exist_ok=True)
query = q.get("query") or {}
payload = {
    "id": query.get("id"),
    "name": query.get("name"),
    "pinnedTypeID": query.get("pinnedTypeID"),
    "definition": {
        "typeID": "book",
        "tags": query.get("tags") or [],
        "properties": [{"key": "status", "op": "equals", "text": "Reading"}],
    },
}
(queries_dir / f"{query['id']}.json").write_text(json.dumps(payload, indent=2) + "\n")

manifest_path = schema / "manifest.json"
manifest = {}
if manifest_path.exists():
    manifest = json.loads(manifest_path.read_text())
manifest["queries"] = [payload]
manifest["queriesDemo"] = {
    "query": query,
    "resultCount": q.get("resultCount"),
    "resultTitles": q.get("resultTitles"),
    "definitionIsVaultFile": q.get("definitionIsVaultFile"),
}
manifest["note"] = (manifest.get("note") or "") + " · PR23 queries"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print("wrote", queries_dir, "and updated manifest")
PY

echo "==> wrote $OUT_DIR/queries.json"
echo "==> demo-queries complete"
