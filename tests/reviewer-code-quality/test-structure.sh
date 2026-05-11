#!/usr/bin/env bash
# Structural test for reviewer-code-quality agent.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/reviewer-code-quality.md"
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
echo " reviewer-code-quality: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/reviewer-code-quality.md"
assert_grep "$AGENT" '^name: reviewer-code-quality$' "frontmatter: name"
assert_grep "$AGENT" '^color: red$' "frontmatter: color=red"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## What to Check' "section: What to Check"
assert_grep "$AGENT" '^## Output Format' "section: Output Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'SCOPE' "context field: SCOPE"
assert_grep "$AGENT" 'DESCRIPTION' "context field: DESCRIPTION"
assert_grep "$AGENT" 'PLAN_OR_REQUIREMENTS' "context field: PLAN_OR_REQUIREMENTS"
assert_grep "$AGENT" 'BASE_SHA' "context field: BASE_SHA"
assert_grep "$AGENT" 'HEAD_SHA' "context field: HEAD_SHA"

# Both scope checklists present
assert_grep "$AGENT" 'SCOPE: per-task' "checklist: per-task"
assert_grep "$AGENT" 'SCOPE: whole-branch' "checklist: whole-branch"

# Required output sections
assert_grep "$AGENT" '### Strengths' "output: Strengths"
assert_grep "$AGENT" '### Issues' "output: Issues"
assert_grep "$AGENT" '### Assessment' "output: Assessment"
assert_grep "$AGENT" 'Ready to merge' "output: merge verdict"

# Fixture presence
assert_file "$FIX/clean.md" "fixture: clean.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
