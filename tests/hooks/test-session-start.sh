#!/usr/bin/env bash
# Structural test for hooks/session-start INDEX injection.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

echo "========================================"
echo " session-start hook: INDEX injection"
echo "========================================"

# Case 1: no knowledge/ dir — hook produces output, no INDEX block
tmpdir=$(mktemp -d)
output=$(cd "$tmpdir" && bash "$HOOK")
if echo "$output" | grep -q '"hookEventName": "SessionStart"'; then pass "no-knowledge: hook emits valid output"; else fail "no-knowledge: hook output malformed"; fi
if echo "$output" | grep -q 'Project knowledge index'; then fail "no-knowledge: hook leaks INDEX block when no knowledge/"; else pass "no-knowledge: no INDEX block"; fi
rm -rf "$tmpdir"

# Case 2: knowledge/INDEX.md present — hook injects the content
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/knowledge"
cat > "$tmpdir/knowledge/INDEX.md" <<'EOF'
# Knowledge Index

## Patterns

- **fixture-auth** — Sample hook for fixture-auth pattern — `patterns/fixture-auth.md`
EOF
output=$(cd "$tmpdir" && bash "$HOOK")
if echo "$output" | grep -q '"hookEventName": "SessionStart"'; then pass "with-knowledge: hook emits valid output"; else fail "with-knowledge: hook output malformed"; fi
if echo "$output" | grep -q 'Project knowledge index'; then pass "with-knowledge: INDEX block appears"; else fail "with-knowledge: INDEX block missing"; fi
if echo "$output" | grep -q 'fixture-auth'; then pass "with-knowledge: INDEX content present"; else fail "with-knowledge: INDEX content not in output"; fi
rm -rf "$tmpdir"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
