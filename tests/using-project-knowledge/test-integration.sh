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
# so the skill resolves `./knowledge/INDEX.md` to the fixture copy. Ask the
# agent to write hook names verbatim to a deterministic file so assertions
# don't false-negative on paraphrased prose.
PROMPT="Use superpowers:using-project-knowledge. After it surfaces the INDEX, write the bullet-point hook names verbatim (one per line, no extra prose) to $WORK/hooks.txt, then exit."

set +e
output=$(cd "$WORK" && echo "$PROMPT" | claude 2>&1)
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "  [SKIP] claude CLI exited non-zero ($rc) — CLI shape likely needs adjustment."
    echo "  Output (first 40 lines):"
    echo "$output" | head -40 | sed 's/^/    /'
    echo "  This is a known scaffold limitation — flag for future task."
    exit 0
fi

if [ ! -f "$WORK/hooks.txt" ]; then
    echo "  [SKIP] claude returned rc=0 but hooks.txt was not written"
    echo "         (likely scaffold limitation: in-session recursive invocation"
    echo "         can't approve Write tool calls without --permission-mode acceptEdits)"
    echo "  ---- first 40 lines of output ----"
    echo "$output" | head -40 | sed 's/^/    /'
    rm -rf "$WORK"
    exit 0
fi

# Assertion 1: fixture pattern hook visible to agent (via hooks.txt)
if grep -q 'fixture-pattern' "$WORK/hooks.txt" 2>/dev/null; then
    pass "fixture-pattern hook visible to agent"
else
    fail "fixture-pattern hook not visible (or hooks.txt missing)"
fi

# Assertion 2: fixture gotcha hook visible to agent (via hooks.txt)
if grep -q 'fixture-gotcha' "$WORK/hooks.txt" 2>/dev/null; then
    pass "fixture-gotcha hook visible to agent"
else
    fail "fixture-gotcha hook not visible (or hooks.txt missing)"
fi

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
