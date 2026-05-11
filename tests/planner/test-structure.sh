#!/usr/bin/env bash
# Structural test for planner agent.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/planner.md"
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
echo " planner: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/planner.md"
assert_grep "$AGENT" '^name: planner$' "frontmatter: name=planner"
assert_grep "$AGENT" '^color: green$' "frontmatter: color=green"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: max$' "frontmatter: effort=max"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Bite-Sized Task Granularity' "section: Bite-Sized Task Granularity"
assert_grep "$AGENT" '^## No Placeholders' "section: No Placeholders"
assert_grep "$AGENT" '^## Self-Review' "section: Self-Review"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'SPEC_PATH' "context field: SPEC_PATH"
assert_grep "$AGENT" 'WORKING_DIRECTORY' "context field: WORKING_DIRECTORY"
assert_grep "$AGENT" 'PROJECT_CONTEXT' "context field: PROJECT_CONTEXT"
assert_grep "$AGENT" 'CONSTRAINTS' "context field: CONSTRAINTS"

# Status enumeration
assert_grep "$AGENT" 'DONE_WITH_CONCERNS' "status: DONE_WITH_CONCERNS"
assert_grep "$AGENT" 'BLOCKED' "status: BLOCKED"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "status: NEEDS_CONTEXT"

# Fixture presence
assert_file "$FIX/small-spec.md" "fixture: small-spec.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
