#!/usr/bin/env bash
# Structural test for reviser agent.
# Pure grep + file existence checks. Cross-file mention checks README.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/reviser.md"
README="$REPO_ROOT/agents/README.md"
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
echo " reviser: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/reviser.md"
assert_grep "$AGENT" '^name: reviser$' "frontmatter: name=reviser"
assert_grep "$AGENT" '^color: (teal|cyan)$' "frontmatter: color in librarian palette"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"
assert_grep "$AGENT" '^description: ' "frontmatter: description present"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Before You Begin' "section: Before You Begin"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"

# Step 0: using-project-knowledge invocation
assert_grep "$AGENT" 'superpowers:using-project-knowledge' "step 0: using-project-knowledge invocation"

# Required per-call context fields (all 5)
for field in ENTRY_PATH ENTRY_TITLE CURRENT_ENTRY_TEXT CANONICAL_URL CANONICAL_SUMMARY; do
    assert_grep "$AGENT" "$field" "context field: $field"
done

# Job behavior assertions
assert_grep "$AGENT" 'WebFetch' "job: uses WebFetch to verify canonical URL"
assert_grep "$AGENT" 'H3|### YYYY-MM-DD|dated H3' "job: H3 header concept present"
assert_grep "$AGENT" 'preserve.*H3|H3.*preserve|verbatim.*H3|H3.*verbatim' "job: H3 preservation rule"
assert_grep "$AGENT" 'since.*SHA|since-SHA|since:' "job: since-SHA preservation rule"
assert_grep "$AGENT" '\*\*Source:\*\*.*CANONICAL_URL|Source.*match.*CANONICAL_URL|Source.*=.*CANONICAL_URL' "job: Source line matches CANONICAL_URL"
assert_grep "$AGENT" 'in.place|replace in place|rewrite.*in place' "job: in-place replacement"

# Anti-patterns: no H3 change, no modify other entries, no INDEX modify, no architect escalation
assert_grep "$AGENT" '[Dd]o not (change|modify|edit|rewrite).*H3|H3 (header )?MUST NOT|never (change|edit|modify|rewrite).*H3' "anti-pattern: do not change H3"
assert_grep "$AGENT" 'other entries|other entry|surrounding entries' "anti-pattern: do not touch other entries in file"
assert_grep "$AGENT" 'INDEX\.md' "anti-pattern: do not modify INDEX.md"
assert_grep "$AGENT" 'NOT escalate.*BLOCKED:ARCHITECTURAL|never emit.*BLOCKED:ARCHITECTURAL|does NOT emit.*BLOCKED:ARCHITECTURAL|do NOT emit.*BLOCKED:ARCHITECTURAL' "anti-pattern: no architect escalation"

# Status verdicts
assert_grep "$AGENT" 'DONE' "verdict: DONE"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "verdict: NEEDS_CONTEXT"

# Fixture presence
assert_file "$FIX/contradicted-entry.md" "fixture: contradicted-entry.md"

# Cross-file: README.md mentions reviser in librarian family + per-call fields table + files table
assert_grep "$README" 'reviser' "README: mentions reviser"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
