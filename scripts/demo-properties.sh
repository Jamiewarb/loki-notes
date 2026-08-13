#!/usr/bin/env bash
# scripts/demo-properties.sh — Book status/rating fixture for DevHarness (PR13).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-properties"
mkdir -p "$OUT_DIR"

echo "==> loci-properties-demo"
swift run --package-path "$ROOT" loci-properties-demo > "$OUT_DIR/properties.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-properties")
data = json.loads((root / "properties.json").read_text())
assert data.get("survivedReload") is True, "property values must survive reload"
assert data.get("statusIndexed") is True, "status must land in properties_idx"
assert data.get("ratingIndexed") is True, "rating must land in properties_idx"
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert int(data.get("filterStatusReadingCount") or 0) == 1, "filter by status=Reading"
obj = data.get("object") or {}
props = obj.get("properties") or {}
assert props.get("status") == "Reading", props
assert props.get("rating") in ("5", 5, "5.0") or str(props.get("rating")).startswith("5"), props
book = data.get("bookType") or {}
ids = {p.get("id") for p in (book.get("properties") or [])}
assert "status" in ids and "rating" in ids, ids
fm = data.get("frontmatterSnippet") or ""
assert "status" in fm and "rating" in fm, fm
print(
    f"survived={data.get('survivedReload')} statusIdx={data.get('statusIndexed')} "
    f"ratingIdx={data.get('ratingIndexed')} filter={data.get('filterStatusReadingCount')} "
    f"props={list(ids)}"
)
PY

# Refresh Types panel fixtures so Books shows property defs + Deep Work values.
TYPES_DIR="$ROOT/DevHarness/public/demo-types"
mkdir -p "$TYPES_DIR"
python3 - <<'PY'
import json, pathlib
props = json.loads(pathlib.Path("DevHarness/public/demo-properties/properties.json").read_text())
book = props.get("bookType") or {}
obj = props.get("object") or {}
# Merge into types.json shape expected by TypesSchemaPanel.
out = {
    "moduleVersion": props.get("moduleVersion"),
    "space": {"name": "Demo Properties", "schemaVersion": 1, "pins": []},
    "types": [
        {
            "id": "book",
            "name": book.get("name", "Books"),
            "icon": book.get("icon", "book"),
            "color": book.get("color", "#8B5A2B"),
            "isBuiltIn": False,
            "properties": book.get("properties") or [],
        },
        {
            "id": "daily",
            "name": "Daily",
            "icon": "sun.max",
            "color": "#3D6B5C",
            "isBuiltIn": True,
            "properties": [],
        },
        {
            "id": "page",
            "name": "Page",
            "icon": "doc.text",
            "color": "#0F6B5C",
            "isBuiltIn": True,
            "properties": [],
        },
    ],
    "bookObject": {
        "id": obj.get("id"),
        "type": obj.get("type"),
        "title": obj.get("title"),
        "relativePath": obj.get("relativePath"),
        "tags": obj.get("tags") or [],
        "properties": obj.get("properties") or {},
    },
    "booksCount": 1,
    "pagesCount": 0,
    "appearsOnlyUnderBooks": True,
    "objectsFolder": "objects/book",
    "objectsFolderExists": True,
    "pageDeleteBlocked": True,
    "survivedReload": props.get("survivedReload"),
    "statusIndexed": props.get("statusIndexed"),
    "ratingIndexed": props.get("ratingIndexed"),
    "propertiesIdx": props.get("propertiesIdx"),
    "frontmatterSnippet": props.get("frontmatterSnippet"),
    "note": props.get("note"),
}
pathlib.Path("DevHarness/public/demo-types/types.json").write_text(
    json.dumps(out, indent=2) + "\n"
)
print("wrote DevHarness/public/demo-types/types.json (with properties)")
PY

SCHEMA_DIR="$ROOT/DevHarness/public/demo-schema"
mkdir -p "$SCHEMA_DIR/types"
python3 - <<'PY'
import json, pathlib
props = json.loads(pathlib.Path("DevHarness/public/demo-properties/properties.json").read_text())
schema = pathlib.Path("DevHarness/public/demo-schema")
space = {"name": "Demo Properties", "schemaVersion": 1, "pins": []}
(schema / "space.json").write_text(json.dumps(space, indent=2) + "\n")
book = props.get("bookType") or {}
types = [
    {
        "id": "book",
        "name": book.get("name", "Books"),
        "icon": book.get("icon", "book"),
        "color": book.get("color", "#8B5A2B"),
        "isBuiltIn": False,
        "properties": book.get("properties") or [],
    },
    {"id": "daily", "name": "Daily", "icon": "sun.max", "color": "#3D6B5C", "isBuiltIn": True, "properties": []},
    {"id": "page", "name": "Page", "icon": "doc.text", "color": "#0F6B5C", "isBuiltIn": True, "properties": []},
]
types_dir = schema / "types"
for t in types:
    (types_dir / f"{t['id']}.json").write_text(json.dumps(t, indent=2) + "\n")
manifest = {
    "space": space,
    "types": types,
    "propertiesDemo": {
        "object": props.get("object"),
        "survivedReload": props.get("survivedReload"),
        "statusIndexed": props.get("statusIndexed"),
        "ratingIndexed": props.get("ratingIndexed"),
        "propertiesIdx": props.get("propertiesIdx"),
    },
    "note": "Generated by scripts/demo-properties.sh — Book status + rating (PR13).",
}
(schema / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("wrote", schema / "manifest.json")
PY

echo "==> wrote $OUT_DIR/properties.json"
echo "==> demo-properties complete"
