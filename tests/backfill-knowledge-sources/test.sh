#!/usr/bin/env bash
# Test for scripts/backfill-knowledge-sources.sh.
# Asserts:
#   1. Entries missing **Source:** get observed_locally_unvetted appended
#   2. Entries with existing **Source:** are untouched
#   3. Second run is a no-op (idempotent)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKFILL="$REPO_ROOT/scripts/backfill-knowledge-sources.sh"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

# Make a fresh working copy of the fixture (don't mutate the committed fixture)
WORK=$(mktemp -d)
cp -R "$SCRIPT_DIR/fixtures/mixed/knowledge" "$WORK/knowledge"

echo "========================================"
echo " backfill-knowledge-sources: first run"
echo "========================================"

bash "$BACKFILL" "$WORK/knowledge" >/dev/null 2>&1
first_exit=$?
if [ "$first_exit" -eq 0 ]; then pass "first run exits 0"; else fail "first run exited $first_exit"; fi

# Entry that was missing source should now have observed_locally_unvetted
if grep -q '^\*\*Source:\*\* observed_locally_unvetted$' "$WORK/knowledge/patterns/topic-a.md"; then
    pass "topic-a missing-source entry: backfilled with observed_locally_unvetted"
else
    fail "topic-a missing-source entry not backfilled"
fi

# Existing URL source preserved verbatim
if grep -q '^\*\*Source:\*\* https://example\.com/canonical$' "$WORK/knowledge/gotchas/topic-b.md"; then
    pass "topic-b URL source: preserved"
else
    fail "topic-b URL source disturbed"
fi

# Existing observed_locally_unvetted (with hint) preserved verbatim
if grep -q '^\*\*Source:\*\* observed_locally_unvetted (sample hint)$' "$WORK/knowledge/gotchas/topic-b.md"; then
    pass "topic-b parenthetical-hint source: preserved"
else
    fail "topic-b parenthetical-hint source disturbed"
fi

# Snapshot post-first-run state
checksum1=$(find "$WORK/knowledge" -type f -name '*.md' | sort | xargs cat | shasum | awk '{print $1}')

echo ""
echo "========================================"
echo " backfill-knowledge-sources: second run (idempotent)"
echo "========================================"

bash "$BACKFILL" "$WORK/knowledge" >/dev/null 2>&1
second_exit=$?
if [ "$second_exit" -eq 0 ]; then pass "second run exits 0"; else fail "second run exited $second_exit"; fi

checksum2=$(find "$WORK/knowledge" -type f -name '*.md' | sort | xargs cat | shasum | awk '{print $1}')
if [ "$checksum1" = "$checksum2" ]; then pass "second run is idempotent (no file changes)"; else fail "second run mutated files (not idempotent)"; fi

rm -rf "$WORK"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
