#!/usr/bin/env bash
# Backfill **Source:** lines on knowledge/ entries that are missing them.
# Appends `**Source:** observed_locally_unvetted` as the last non-blank line
# of each entry's body (before the next `### ` header or EOF).
# Idempotent: entries that already have a Source line are untouched.
#
# Usage: backfill-knowledge-sources.sh [<path-to-knowledge-dir>]
# Defaults to ./knowledge if no arg given.
#
# Exit codes:
#   0 — success (may have made changes or been a no-op)
#   1 — runtime error
#   2 — usage error
set -uo pipefail

KNOWLEDGE="${1:-./knowledge}"
if [ ! -d "$KNOWLEDGE" ]; then
    echo "ERROR: knowledge directory not found: $KNOWLEDGE" >&2
    exit 2
fi

INDEX="$KNOWLEDGE/INDEX.md"
META="$KNOWLEDGE/_meta"

# Process one topic file in-place via awk.
# State machine: walk entries delimited by ^### .
# When transitioning out of an entry (next ### or EOF), check whether the
# accumulated body contained a ^**Source:** line. If not, emit
# **Source:** observed_locally_unvetted just before the boundary.
process_topic() {
    local topic="$1"
    local tmp
    tmp=$(mktemp)
    awk '
        function flush_entry() {
            # Trim trailing blank lines from the body
            while (n > 0 && body[n] ~ /^[[:space:]]*$/) {
                n--
            }
            # Print body up to n
            for (i = 1; i <= n; i++) print body[i]
            # If no Source line found in this entry, inject one
            if (in_entry && !have_source) {
                print ""
                print "**Source:** observed_locally_unvetted"
            }
            # Reset
            n = 0
            have_source = 0
        }

        BEGIN { in_entry = 0; n = 0; have_source = 0 }

        /^### / {
            if (in_entry) {
                flush_entry()
                print ""
            }
            in_entry = 1
            n = 0
            have_source = 0
            print $0
            next
        }

        {
            if (in_entry) {
                if ($0 ~ /^\*\*Source:\*\* /) have_source = 1
                n++
                body[n] = $0
            } else {
                print $0
            }
        }

        END {
            if (in_entry) flush_entry()
        }
    ' "$topic" > "$tmp"

    # Replace only if content differs
    if ! cmp -s "$topic" "$tmp"; then
        mv "$tmp" "$topic"
    else
        rm -f "$tmp"
    fi
}

# Walk every topic file under $KNOWLEDGE, skipping INDEX.md and _meta/.
# Use process substitution so the loop runs in the current shell.
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    process_topic "$topic"
done < <(find "$KNOWLEDGE" -type f -name '*.md' \
            ! -path "$INDEX" ! -path "$META/*" 2>/dev/null)

exit 0
