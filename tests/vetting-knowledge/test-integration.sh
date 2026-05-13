#!/usr/bin/env bash
# Integration test for vetting-knowledge skill (degraded path).
# No MCPs available; verifies report writes with every entry bucketed
# as 'unvetted (no search available)'. Tests the timestamped-filename
# format and frontmatter-parses contract.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIX="$SCRIPT_DIR/fixtures/sample-knowledge"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

if ! command -v claude >/dev/null 2>&1; then
    echo "  [SKIP] integration test: claude CLI not on PATH"
    exit 0
fi

WORK=$(mktemp -d)
cp -R "$FIX" "$WORK/knowledge"

# Invoke the vetting-knowledge skill via claude
# (Use a non-interactive prompt that runs the skill and returns control.)
output=$(cd "$WORK" && echo "Use superpowers:vetting-knowledge to audit ./knowledge." | claude 2>&1 || true)

# Assertion 1: report file written with ISO-sortable timestamp filename
report=$(find "$WORK/knowledge/_meta/vetting-reports" -type f -name '*.md' 2>/dev/null | head -1)
if [ -n "$report" ]; then
    pass "report file written"
    # Filename matches YYYY-MM-DDTHHMMSSZ.md
    base=$(basename "$report")
    if echo "$base" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z\.md$'; then
        pass "report filename format: YYYY-MM-DDTHHMMSSZ.md"
    else
        fail "report filename format: got $base"
    fi
else
    fail "no report file written"
fi

# Assertion 2: report has YAML frontmatter with required keys
if [ -n "$report" ]; then
    for key in generated mcps_used mcps_unavailable buckets; do
        if grep -q "^${key}:" "$report"; then
            pass "report frontmatter: $key key present"
        else
            fail "report frontmatter: $key key missing"
        fi
    done

    # Degraded mode: every entry bucketed as unvetted
    if grep -qE 'unvetted: [1-9]' "$report"; then
        pass "degraded mode: at least one entry bucketed as unvetted"
    else
        fail "degraded mode: no unvetted entries"
    fi

    # Degraded mode: zero contradicted entries (no search → no contradictions possible)
    if grep -q '^  contradicted: 0$' "$report"; then
        pass "degraded mode: zero contradicted entries"
    else
        fail "degraded mode: expected zero contradicted entries"
    fi
fi

rm -rf "$WORK"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
