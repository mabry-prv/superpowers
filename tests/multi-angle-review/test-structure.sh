#!/usr/bin/env bash
# Structural test for multi-angle-review skill.
# No `claude` CLI dependency — pure grep + file existence checks.
# Catches regressions in template structure, placeholders, verdict strings,
# and SKILL.md routing-table integrity.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$REPO_ROOT/skills/multi-angle-review"
SKILL_MD="$SKILL_DIR/SKILL.md"
TEMPLATES_DIR="$SKILL_DIR/templates"

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
    if grep -qiE "$pattern" "$path" 2>/dev/null; then
        pass "$name"
    else
        fail "$name (pattern '/$pattern/' not found in $path)"
    fi
}

assert_grep_count() {
    local path="$1" pattern="$2" expected="$3" name="$4"
    local actual
    actual=$(grep -cE "$pattern" "$path" 2>/dev/null || echo 0)
    if [ "$actual" -eq "$expected" ]; then
        pass "$name (found $actual)"
    else
        fail "$name (expected $expected, got $actual)"
    fi
}

echo "========================================"
echo " multi-angle-review: structural tests"
echo "========================================"
echo ""

# --- Skill file presence ------------------------------------------------------

echo "--- Skill files exist ---"
assert_file "$SKILL_MD" "SKILL.md"
assert_file "$TEMPLATES_DIR/reviewer-multitenant-isolation.md" "multitenant-isolation template"
assert_file "$TEMPLATES_DIR/reviewer-migration-safety.md" "migration-safety template"
assert_file "$TEMPLATES_DIR/reviewer-security.md" "security template"
echo ""

# --- SKILL.md frontmatter & verdict strings -----------------------------------

echo "--- SKILL.md frontmatter and terminal verdicts ---"
assert_grep "$SKILL_MD" "^name: multi-angle-review$" "SKILL.md frontmatter name"
assert_grep "$SKILL_MD" "^description: " "SKILL.md frontmatter description"
assert_grep "$SKILL_MD" "no concerns triggered by this diff" "SKILL.md zero-fire string"
assert_grep "$SKILL_MD" "APPROVED — multi-angle review clean" "SKILL.md all-approved string"
assert_grep "$SKILL_MD" "BLOCKED — N total Critical" "SKILL.md blocked string"
echo ""

# --- SKILL.md routing table integrity -----------------------------------------

echo "--- SKILL.md routing table ---"
# The routing table has a header row + separator + 3 data rows = 5 markdown
# table lines starting with '|'. Check for at least 3 templates referenced.
assert_grep "$SKILL_MD" "templates/reviewer-multitenant-isolation.md" "routing references multitenant template"
assert_grep "$SKILL_MD" "templates/reviewer-migration-safety.md" "routing references migration template"
assert_grep "$SKILL_MD" "templates/reviewer-security.md" "routing references security template"
echo ""

# --- Per-template required sections ------------------------------------------

for t in reviewer-multitenant-isolation reviewer-migration-safety reviewer-security; do
    f="$TEMPLATES_DIR/$t.md"
    echo "--- $t.md sections ---"
    assert_grep "$f" "## Severity Rules" "$t has Severity Rules section"
    assert_grep "$f" "### Critical" "$t has Critical tier"
    assert_grep "$f" "### Important" "$t has Important tier"
    assert_grep "$f" "### Suggestion" "$t has Suggestion tier"
    assert_grep "$f" "## Output Format" "$t has Output Format section"
    assert_grep "$f" "## Anti-Patterns" "$t has Anti-Patterns section"
    echo ""
done

# --- Placeholder presence in every template ----------------------------------

echo "--- Placeholders ---"
for t in reviewer-multitenant-isolation reviewer-migration-safety reviewer-security; do
    f="$TEMPLATES_DIR/$t.md"
    assert_grep "$f" '\{DESCRIPTION\}' "$t has {DESCRIPTION}"
    assert_grep "$f" '\{PLAN_OR_REQUIREMENTS\}' "$t has {PLAN_OR_REQUIREMENTS}"
    assert_grep "$f" '\{FILES_TO_REVIEW\}' "$t has {FILES_TO_REVIEW}"
done
echo ""

# --- Verdict strings present in every template -------------------------------

echo "--- Verdict strings in templates ---"
for t in reviewer-multitenant-isolation reviewer-migration-safety reviewer-security; do
    f="$TEMPLATES_DIR/$t.md"
    assert_grep "$f" 'BLOCKED — N Critical' "$t has BLOCKED verdict"
    assert_grep "$f" 'APPROVED WITH SUGGESTIONS' "$t has APPROVED-WITH-SUGGESTIONS verdict"
    assert_grep "$f" '\*\*Verdict: APPROVED\*\*' "$t has APPROVED verdict"
done
echo ""

# --- Severity coverage in security template (Critical #1 regression guard) ---

echo "--- Security template severity coverage (regression guard) ---"
SEC="$TEMPLATES_DIR/reviewer-security.md"
assert_grep "$SEC" "path traversal" "security covers path traversal"
assert_grep "$SEC" "insecure deserialization" "security covers insecure deserialization"
assert_grep "$SEC" "pickle\\.loads" "security mentions pickle.loads"
assert_grep "$SEC" "open redirect" "security covers open redirect"
assert_grep "$SEC" "redos|catastrophic.backtracking" "security covers ReDoS"
assert_grep "$SEC" "ssrf" "security covers SSRF"
assert_grep "$SEC" "xxe|xml external entity" "security covers XXE"
echo ""

# --- Migration-safety NEW-NULL+server_default rule (Critical #2 guard) -------

echo "--- Migration template severity coverage (regression guard) ---"
MIG="$TEMPLATES_DIR/reviewer-migration-safety.md"
assert_grep "$MIG" "non-constant.+server_default|server_default.+now\\(\\)|gen_random_uuid" "migration covers non-constant server_default rule"
assert_grep "$MIG" "ACCESS EXCLUSIVE|table rewrite" "migration mentions table-rewrite locking impact"
echo ""

# --- Fixtures present --------------------------------------------------------

echo "--- Fixtures checked into the repo ---"
FIX="$SCRIPT_DIR/fixtures"
assert_file "$FIX/composite-bug/app/api.py" "composite-bug api.py"
assert_file "$FIX/composite-bug/app/auth.py" "composite-bug auth.py"
assert_file "$FIX/composite-bug/app/billing.py" "composite-bug billing.py"
assert_file "$FIX/composite-bug/alembic/versions/0002_destructive.py" "composite-bug destructive migration"
assert_file "$FIX/composite-clean/app/api.py" "composite-clean api.py"
assert_file "$FIX/composite-clean/alembic/versions/0002_safe.py" "composite-clean safe migration"
echo ""

# --- Summary ------------------------------------------------------------------

echo "========================================"
echo " Results: $passed passed, $failed failed"
echo "========================================"

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
