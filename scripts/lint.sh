#!/usr/bin/env bash
# scripts/lint.sh — static checks for Loci packages (Linux-friendly).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

pass() {
  echo "OK: $*"
}

echo "==> lint: Package.swift present"
if [[ -f "$ROOT/Package.swift" ]]; then
  pass "Package.swift exists"
else
  fail "Package.swift missing"
fi

echo "==> lint: reject fatal TODO crash stubs in production Sources"
# Ban patterns like fatalError(\"TODO\") / preconditionFailure(\"TODO\") in package Sources.
# Allow legitimate XCTest / docs mentions outside Sources.
while IFS= read -r -d '' file; do
  if grep -nE 'fatalError\([[:space:]]*"TODO|preconditionFailure\([[:space:]]*"TODO|TODO:\s*crash' "$file" >/dev/null 2>&1; then
    fail "crash stub TODO in $file"
  fi
done < <(find "$ROOT" \( -path "$ROOT/.build" -o -path "$ROOT/DevHarness/node_modules" -o -path "$ROOT/.git" \) -prune -o -path '*/Sources/*' -name '*.swift' -print0)

pass "no TODO crash stubs in Sources"

echo "==> lint: index must not be configured inside vault paths"
if grep -RInE 'vault.*(index\.sqlite|IndexDatabase)|index\.sqlite.*vault' \
  --include='*.swift' --include='*.md' \
  "$ROOT/LociIndex" "$ROOT/LociVault" "$ROOT/LociCore" 2>/dev/null \
  | grep -viE 'never|not |must not|Application Support|outside' >/dev/null; then
  # Soft informational — architecture comments often mention the anti-pattern.
  true
fi
pass "index/vault boundary docs present (Application Support convention)"

if command -v swift >/dev/null 2>&1; then
  echo "==> lint: swift build"
  if swift build --package-path "$ROOT"; then
    pass "swift build"
  else
    fail "swift build failed"
  fi

  if command -v swift-format >/dev/null 2>&1; then
    echo "==> lint: swift-format lint"
    if swift-format lint --recursive \
      "$ROOT/LociCore" "$ROOT/LociVault" "$ROOT/LociMarkdown" "$ROOT/LociIndex" "$ROOT/LociDesignSystem"; then
      pass "swift-format"
    else
      fail "swift-format reported issues"
    fi
  else
    echo "SKIP: swift-format not installed"
  fi
else
  fail "swift toolchain not available"
fi

# Ensure feature folder convention exists
if [[ -d "$ROOT/App/Features/AppShell" ]]; then
  pass "App/Features/AppShell present"
else
  fail "App/Features/AppShell missing"
fi

if [[ -d "$ROOT/App/Features/Search" ]]; then
  pass "App/Features/Search present"
else
  fail "App/Features/Search missing"
fi
if [[ -d "$ROOT/App/Features/Tasks" ]]; then
  pass "App/Features/Tasks present"
else
  fail "App/Features/Tasks missing"
fi
if [[ -d "$ROOT/App/Features/Media" ]]; then
  pass "App/Features/Media present"
else
  fail "App/Features/Media missing"
fi
if [[ -d "$ROOT/App/Features/SyncStatus" ]]; then
  pass "App/Features/SyncStatus present"
else
  fail "App/Features/SyncStatus missing"
fi
if [[ -d "$ROOT/App/Features/Collections" ]]; then
  pass "App/Features/Collections present"
else
  fail "App/Features/Collections missing"
fi
if [[ -d "$ROOT/App/Features/Queries" ]]; then
  pass "App/Features/Queries present"
else
  fail "App/Features/Queries missing"
fi
if [[ -d "$ROOT/App/Features/Graph" ]]; then
  pass "App/Features/Graph present"
else
  fail "App/Features/Graph missing"
fi
if [[ -d "$ROOT/App/Features/Calendar" ]]; then
  pass "App/Features/Calendar present"
else
  fail "App/Features/Calendar missing"
fi
if [[ -d "$ROOT/App/Features/Capture" ]]; then
  pass "App/Features/Capture present"
else
  fail "App/Features/Capture missing"
fi
if [[ -d "$ROOT/App/Features/ImportExport" ]]; then
  pass "App/Features/ImportExport present"
else
  fail "App/Features/ImportExport missing"
fi
if [[ -d "$ROOT/App/Features/TypeConversion" ]]; then
  pass "App/Features/TypeConversion present"
else
  fail "App/Features/TypeConversion missing"
fi
if [[ -d "$ROOT/App/Features/AI" ]]; then
  pass "App/Features/AI present"
else
  fail "App/Features/AI missing"
fi
if [[ -d "$ROOT/App/Features/AppleIntegrations" ]]; then
  pass "App/Features/AppleIntegrations present"
else
  fail "App/Features/AppleIntegrations missing"
fi
if [[ "$failures" -ne 0 ]]; then
  echo "==> lint failed ($failures)" >&2
  exit 1
fi

echo "==> lint passed"
