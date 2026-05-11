#!/usr/bin/env bash
# Structural test for architect agent.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/architect.md"
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
echo " architect: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/architect.md"
assert_grep "$AGENT" '^name: architect$' "frontmatter: name=architect"
assert_grep "$AGENT" '^color: blue$' "frontmatter: color=blue"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: max$' "frontmatter: effort=max"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## When You.re in Over Your Head' "section: escalation"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'QUESTION' "context field: QUESTION"
assert_grep "$AGENT" 'CODE_CONTEXT' "context field: CODE_CONTEXT"
assert_grep "$AGENT" 'CONSTRAINTS' "context field: CONSTRAINTS"
assert_grep "$AGENT" 'PRIOR_ATTEMPTS' "context field: PRIOR_ATTEMPTS"
assert_grep "$AGENT" 'DECISION_OWNER' "context field: DECISION_OWNER"

# Output structure
assert_grep "$AGENT" '### Options' "output: Options"
assert_grep "$AGENT" '### Recommendation' "output: Recommendation"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "status: NEEDS_CONTEXT"
assert_grep "$AGENT" 'NEEDS_RESCOPE' "status: NEEDS_RESCOPE"

# Anti-pattern: must say NOT to modify code
assert_grep "$AGENT" '[Dd]o NOT modify code|don.t modify code|does NOT modify code|Modify code' "anti-pattern: does not modify code"

# Fixture presence
assert_file "$FIX/pure-design-q.md" "fixture: pure-design-q.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
