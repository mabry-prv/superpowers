#!/usr/bin/env bash
# Integration test for using-project-knowledge skill (happy path).
#
# Verifies the skill loads ./knowledge/INDEX.md content into the agent's
# context when present. Asserts the fixture's INDEX hooks ("fixture-pattern"
# and "fixture-gotcha") appear in the agent's output, which is evidence
# the INDEX surfaced as a system-reminder.
#
# Best-effort: SKIPs cleanly if `claude` is not on PATH. CLI-shape mismatch
# (recursive in-session invocation) is a known limitation across the
# integration scaffolds in this repo — see tests/reviser/test-integration.sh
# and tests/vetting-knowledge/test-integration.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIX="$SCRIPT_DIR/fixtures/with-knowledge/knowledge"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

echo "========================================"
echo " using-project-knowledge: integration test (scaffold)"
echo "========================================"

if ! command -v claude >/dev/null 2>&1; then
    echo "  [SKIP] integration test: claude CLI not on PATH"
    echo "  (Install Claude Code to run this test: https://code.claude.com)"
    exit 0
fi

WORK=$(mktemp -d -t using-project-knowledge-integration.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

cp -R "$FIX" "$WORK/knowledge"

# Invoke the using-project-knowledge skill via claude from inside $WORK,
# so the skill resolves `./knowledge/INDEX.md` to the fixture copy.
output=$(cd "$WORK" && echo "Use superpowers:using-project-knowledge then describe what you see." | claude 2>&1 || true)

# Assertion 1: fixture pattern hook appears in agent output
if echo "$output" | grep -q 'fixture-pattern'; then
    pass "INDEX surfaced: 'fixture-pattern' hook present in agent output"
else
    fail "INDEX did not surface: 'fixture-pattern' hook missing from agent output"
fi

# Assertion 2: fixture gotcha hook appears in agent output
if echo "$output" | grep -q 'fixture-gotcha'; then
    pass "INDEX surfaced: 'fixture-gotcha' hook present in agent output"
else
    fail "INDEX did not surface: 'fixture-gotcha' hook missing from agent output"
fi

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
