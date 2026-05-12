#!/usr/bin/env bash
# Structural test for curator agent.
# Pure grep + file existence checks. Cross-file checks added by later tasks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/curator.md"
SCHEMA="$REPO_ROOT/docs/knowledge-schema.md"
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
echo " curator: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/curator.md"
assert_grep "$AGENT" '^name: curator$' "frontmatter: name=curator"
assert_grep "$AGENT" '^color: (teal|cyan)$' "frontmatter: color in librarian palette"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"

# Required per-call context fields (all 8)
for field in WORKING_DIRECTORY TASK_DESCRIPTION PLAN_OR_SPEC BASE_SHA HEAD_SHA IMPLEMENTER_REPORT REVIEWER_REPORTS EXISTING_INDEX; do
    assert_grep "$AGENT" "$field" "context field: $field"
done

# Status verdicts
assert_grep "$AGENT" 'DONE' "verdict: DONE"
assert_grep "$AGENT" 'NOTHING_TO_LEARN' "verdict: NOTHING_TO_LEARN"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "verdict: NEEDS_CONTEXT"

# Anti-pattern: librarian does NOT escalate BLOCKED:ARCHITECTURAL
assert_grep "$AGENT" 'NOT escalate.*BLOCKED:ARCHITECTURAL|never emit.*BLOCKED:ARCHITECTURAL|does NOT emit.*BLOCKED:ARCHITECTURAL' "anti-pattern: no architect escalation"

# Fixture presence
assert_file "$FIX/sample-branch.md" "fixture: sample-branch.md"

# Cross-file: schema doc curator-input fields match agent's declared fields
for field in WORKING_DIRECTORY TASK_DESCRIPTION PLAN_OR_SPEC BASE_SHA HEAD_SHA IMPLEMENTER_REPORT REVIEWER_REPORTS EXISTING_INDEX; do
    assert_grep "$SCHEMA" "$field" "schema doc references field: $field"
done

# Cross-file slots (added by Tasks 5 and 10 — included now, expected to fail until those tasks complete)
CURATING_SKILL="$REPO_ROOT/skills/curating-knowledge/SKILL.md"
FINISHING_SKILL="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"
if [ -f "$CURATING_SKILL" ]; then
    assert_grep "$CURATING_SKILL" 'subagent_type=curator' "curating-knowledge: dispatches subagent_type=curator"
else
    fail "curating-knowledge skill not yet created (Task 5)"
fi
if grep -q 'curator' "$FINISHING_SKILL" 2>/dev/null; then
    assert_grep "$FINISHING_SKILL" 'curator' "finishing-a-development-branch: references curator"
else
    fail "finishing-a-development-branch skill not yet updated (Task 10)"
fi

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
