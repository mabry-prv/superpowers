#!/usr/bin/env bash
# Test for scripts/lint-knowledge.sh.
# Runs the lint against bad + clean fixtures; asserts expected diagnostics.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$REPO_ROOT/scripts/lint-knowledge.sh"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

assert_exit_code() {
    local actual="$1" expected="$2" name="$3"
    if [ "$actual" -eq "$expected" ]; then pass "$name (exit=$actual)"; else fail "$name (got $actual, expected $expected)"; fi
}

assert_report_contains() {
    local report="$1" pattern="$2" name="$3"
    if grep -qE "$pattern" "$report" 2>/dev/null; then pass "$name"; else fail "$name (pattern '/$pattern/' not in $report)"; fi
}

assert_report_clean() {
    local report="$1" name="$2"
    if grep -qE '^Errors:[[:space:]]+0' "$report" 2>/dev/null; then pass "$name"; else fail "$name (errors found in $report)"; fi
}

echo "========================================"
echo " lint-knowledge: bad fixture sweep"
echo "========================================"

BAD="$SCRIPT_DIR/fixtures/bad/knowledge"
bash "$LINT" "$BAD" >/dev/null 2>&1
bad_exit=$?
assert_exit_code "$bad_exit" 1 "lint exits 1 on bad fixture"

BAD_REPORT="$BAD/_meta/lint-report.md"
assert_report_contains "$BAD_REPORT" 'orphan-hook|patterns/orphan-hook' "detects orphan INDEX hook"
assert_report_contains "$BAD_REPORT" 'no-frontmatter|missing frontmatter' "detects missing frontmatter"
assert_report_contains "$BAD_REPORT" 'oversized|>200 words' "detects oversized entry"
assert_report_contains "$BAD_REPORT" 'dangling|since.*does not resolve|cat-file' "detects dangling since-SHA"

echo ""
echo "========================================"
echo " lint-knowledge: clean fixture pass"
echo "========================================"

CLEAN="$SCRIPT_DIR/fixtures/clean/knowledge"
bash "$LINT" "$CLEAN" >/dev/null 2>&1
clean_exit=$?
assert_exit_code "$clean_exit" 0 "lint exits 0 on clean fixture"

CLEAN_REPORT="$CLEAN/_meta/lint-report.md"
assert_report_clean "$CLEAN_REPORT" "clean fixture produces no errors"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
