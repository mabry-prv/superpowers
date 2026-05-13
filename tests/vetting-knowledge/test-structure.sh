#!/usr/bin/env bash
# Structural test for vetting-knowledge skill.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/vetting-knowledge/SKILL.md"
FIX="$SCRIPT_DIR/fixtures/sample-knowledge"

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
echo " vetting-knowledge: structural tests"
echo "========================================"

# Skill file presence and frontmatter
assert_file "$SKILL" "skills/vetting-knowledge/SKILL.md"
assert_grep "$SKILL" '^name: vetting-knowledge$' "frontmatter: name=vetting-knowledge"
assert_grep "$SKILL" '^description: Use to audit' "frontmatter: description starts with 'Use to audit'"
assert_grep "$SKILL" 'Announce at start' "skill announces itself at start"

# Required steps (1-8 in order) — assert presence
for label in 'Preflight' 'Enumerate' 'Vet each entry' '[Cc]odebase grep' 'Write the report' '[Ss]urface results' 'Fix loop' 'Async resume'; do
    assert_grep "$SKILL" "$label" "step present: $label"
done

# MCP detection
assert_grep "$SKILL" 'mcp__exa__|mcp__ref__' "MCP detection: exa/Ref prefixes"
assert_grep "$SKILL" 'exa.Ref unavailable|degraded' "degraded-mode language"

# Classifications
assert_grep "$SKILL" 'Confirmed|confirmed' "classification: Confirmed"
assert_grep "$SKILL" 'Unvetted|unvetted' "classification: Unvetted"
assert_grep "$SKILL" 'Contradicted|contradicted' "classification: Contradicted"

# Report path + filename format
assert_grep "$SKILL" '_meta/vetting-reports' "report path: _meta/vetting-reports/"
assert_grep "$SKILL" 'YYYY-MM-DDTHHMMSSZ|ISO|sortable' "report filename: ISO-sortable timestamp"

# Report frontmatter shape
assert_grep "$SKILL" 'generated:|mcps_used:|buckets:' "report frontmatter: machine-readable YAML"
assert_grep "$SKILL" 'confirmed:|unvetted:|contradicted:' "report frontmatter: bucket counts"
assert_grep "$SKILL" 'contradicted:' "report frontmatter: contradicted[] list"

# Per-call block to reviser (5 fields)
for field in ENTRY_PATH ENTRY_TITLE CURRENT_ENTRY_TEXT CANONICAL_URL CANONICAL_SUMMARY; do
    assert_grep "$SKILL" "$field" "reviser per-call field: $field"
done
assert_grep "$SKILL" 'subagent_type=reviser|Task\(subagent_type=reviser' "reviser dispatch: subagent_type=reviser"

# Async resume
assert_grep "$SKILL" 'apply fixes from|async resume' "async resume documented"

# Anti-patterns
assert_grep "$SKILL" 'DO NOT auto-commit|do not auto-commit' "anti-pattern: no auto-commit"
assert_grep "$SKILL" '[Dd]o NOT modify .*INDEX|not modify INDEX' "anti-pattern: do not modify INDEX"
assert_grep "$SKILL" '_meta' "anti-pattern: do not vet _meta/"

# Fixture presence
assert_file "$FIX/INDEX.md" "integration fixture: INDEX.md"
assert_file "$FIX/patterns/sample.md" "integration fixture: sample topic"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
