#!/usr/bin/env bash
# Structural test for using-project-knowledge skill.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/using-project-knowledge/SKILL.md"
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
echo " using-project-knowledge: structural tests"
echo "========================================"

# Skill file presence and frontmatter
assert_file "$SKILL" "skills/using-project-knowledge/SKILL.md"
assert_grep "$SKILL" '^name: using-project-knowledge$' "frontmatter: name=using-project-knowledge"
assert_grep "$SKILL" '^description: Use at the start' "frontmatter: description starts with 'Use at the start'"

# Required sections
assert_grep "$SKILL" '^## ' "section: at least one H2"
assert_grep "$SKILL" 'Announce at start' "skill announces itself at start"

# Behavior: tests for INDEX.md presence
assert_grep "$SKILL" 'knowledge/INDEX\.md' "references knowledge/INDEX.md path"
assert_grep "$SKILL" 'no `knowledge/`|no knowledge dir|proceeding without project knowledge' "silent return when knowledge absent"

# Guidance: do not auto-load topic files
assert_grep "$SKILL" 'do NOT auto-load|Do NOT auto-load|not auto-load every' "explicit no-auto-load guidance"

# Guidance: Read on hook match
assert_grep "$SKILL" 'Read.*topic|hook matches' "Read topic file when hook matches"

# Fixture for integration test
assert_file "$FIX/with-knowledge/knowledge/INDEX.md" "integration fixture: INDEX.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
