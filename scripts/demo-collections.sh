#!/usr/bin/env bash
# scripts/demo-collections.sh — Book Favorites collection fixtures for DevHarness (PR22).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-collections"
mkdir -p "$OUT_DIR"

echo "==> loci-collections-demo"
swift run --package-path "$ROOT" loci-collections-demo > "$OUT_DIR/collections.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-collections")
data = json.loads((root / "collections.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("membershipIsVaultFile") is True, data
assert data.get("collectionsDirectory") == ".loci/collections", data
fav = data.get("favorites") or {}
assert fav.get("id") == "book.favorites", fav
assert fav.get("exists") is True, fav
assert fav.get("memberCount") == 2, fav
assert fav.get("relativePath") == ".loci/collections/book.favorites.json", fav
assert data.get("allBooksCount") == 3, data
assert data.get("tabs") == ["All", "Favorites", "Reading List"], data
cols = data.get("collections") or []
assert len(cols) == 2, cols
print(
    f"favorites={fav.get('id')} members={fav.get('memberCount')} "
    f"all={data.get('allBooksCount')} vault={fav.get('relativePath')}"
)
PY

# Refresh Types panel fixtures with collection proof.
TYPES_DIR="$ROOT/DevHarness/public/demo-types"
mkdir -p "$TYPES_DIR"
python3 - <<'PY'
import json, pathlib
col = json.loads(pathlib.Path("DevHarness/public/demo-collections/collections.json").read_text())
existing = {}
types_path = pathlib.Path("DevHarness/public/demo-types/types.json")
if types_path.exists():
    existing = json.loads(types_path.read_text())
out = dict(existing)
out["moduleVersion"] = col.get("moduleVersion")
out["collections"] = col.get("collections")
out["favorites"] = col.get("favorites")
out["readingList"] = col.get("readingList")
out["collectionTabs"] = col.get("tabs")
out["books"] = col.get("books")
out["allBooksCount"] = col.get("allBooksCount")
out["membershipIsVaultFile"] = col.get("membershipIsVaultFile")
out["collectionsNote"] = col.get("note")
types_path.write_text(json.dumps(out, indent=2) + "\n")
print("wrote DevHarness/public/demo-types/types.json (with collections)")
PY

SCHEMA_DIR="$ROOT/DevHarness/public/demo-schema"
mkdir -p "$SCHEMA_DIR/collections"
python3 - <<'PY'
import json, pathlib
col = json.loads(pathlib.Path("DevHarness/public/demo-collections/collections.json").read_text())
schema = pathlib.Path("DevHarness/public/demo-schema")
collections_dir = schema / "collections"
collections_dir.mkdir(parents=True, exist_ok=True)
for c in col.get("collections") or []:
    payload = {
        "id": c.get("id"),
        "typeID": c.get("typeID"),
        "name": c.get("name"),
        "memberIDs": c.get("memberIDs") or [],
    }
    (collections_dir / f"{c['id']}.json").write_text(json.dumps(payload, indent=2) + "\n")

manifest_path = schema / "manifest.json"
manifest = {}
if manifest_path.exists():
    manifest = json.loads(manifest_path.read_text())
manifest["collections"] = col.get("collections")
manifest["collectionsDemo"] = {
    "favorites": col.get("favorites"),
    "tabs": col.get("tabs"),
    "allBooksCount": col.get("allBooksCount"),
    "membershipIsVaultFile": col.get("membershipIsVaultFile"),
}
manifest["note"] = (manifest.get("note") or "") + " · PR22 collections"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print("wrote", collections_dir, "and updated manifest")
PY

echo "==> wrote $OUT_DIR/collections.json"
echo "==> demo-collections complete"
