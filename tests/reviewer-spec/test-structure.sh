#!/usr/bin/env bash
# Structural test for reviewer-spec agent.
# Pure grep + file existence checks — no `claude` CLI dependency.
# Catches regressions in agent envelope, frontmatter, verdict strings,
# and fixture presence.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/reviewer-spec.md"
FIX="$SCRIPT_DIR/fixtures"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

assert_file() {
    local path="$1" name="$2"
    if [ -f "$path" ]; then pass "$name exists"; else fail "$name missing: $path"; fi
}

assert_grep() {
    local path="$1" pattern="$2" name="$3"
    if grep -qE "$pattern" "$path" 2>/dev/null; then
        pass "$name"
    else
        fail "$name (pattern '/$pattern/' not in $path)"
    fi
}

echo "========================================"
echo " reviewer-spec: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/reviewer-spec.md"
assert_grep "$AGENT" '^name: reviewer-spec$' "frontmatter: name=reviewer-spec"
assert_grep "$AGENT" '^color: red$' "frontmatter: color=red"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'TASK_NUMBER' "context field: TASK_NUMBER"
assert_grep "$AGENT" 'TASK_NAME' "context field: TASK_NAME"
assert_grep "$AGENT" 'TASK_REQUIREMENTS' "context field: TASK_REQUIREMENTS"
assert_grep "$AGENT" 'IMPLEMENTER_REPORT' "context field: IMPLEMENTER_REPORT"
assert_grep "$AGENT" 'FILES_TO_REVIEW' "context field: FILES_TO_REVIEW"

# Required verdict strings
assert_grep "$AGENT" 'Spec compliant' "verdict: Spec compliant"
assert_grep "$AGENT" 'Issues found' "verdict: Issues found"

# Fixture presence
assert_file "$FIX/compliant.md" "fixture: compliant.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
