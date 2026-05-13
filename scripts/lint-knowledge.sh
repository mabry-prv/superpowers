#!/usr/bin/env bash
# Lint pass for knowledge/ directory health.
# Usage: lint-knowledge.sh [<path-to-knowledge-dir>]
# Defaults to ./knowledge if no arg given.
#
# Exit codes:
#   0 — clean (no errors; warnings may be present)
#   1 — errors found
#   2 — usage error
set -uo pipefail

KNOWLEDGE="${1:-./knowledge}"
if [ ! -d "$KNOWLEDGE" ]; then
    echo "ERROR: knowledge directory not found: $KNOWLEDGE" >&2
    exit 2
fi

INDEX="$KNOWLEDGE/INDEX.md"
META="$KNOWLEDGE/_meta"
REPORT="$META/lint-report.md"
mkdir -p "$META"

errors=()
warnings=()
suggestions=()

err()  { errors+=("$1"); }
warn() { warnings+=("$1"); }
sug()  { suggestions+=("$1"); }

# 1. INDEX present
if [ ! -f "$INDEX" ]; then
    err "INDEX.md missing at $INDEX"
fi

# 2. Every INDEX hook resolves to an existing file
if [ -f "$INDEX" ]; then
    while IFS= read -r line; do
        # Lines of the form: - **<slug>** — <hook> — `<category>/<slug>.md`
        path=$(printf '%s' "$line" | sed -nE 's/.*`([^`]+\.md)`.*/\1/p')
        if [ -n "$path" ] && [ ! -f "$KNOWLEDGE/$path" ]; then
            err "orphan INDEX hook: \`$path\` referenced but file missing"
        fi
    done < "$INDEX"
fi

# 3. Every topic file has frontmatter (single YAML block at top)
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    first=$(head -1 "$topic" 2>/dev/null)
    if [ "$first" != "---" ]; then
        err "missing frontmatter in topic file: $topic"
        continue
    fi
    # Check required keys
    for key in topic category last-updated last-since; do
        if ! awk '/^---$/{c++} c==1 && /^'"$key"':/{found=1} c==2{exit} END{exit !found}' "$topic"; then
            warn "topic $topic missing frontmatter key: $key"
        fi
    done
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 4. Each entry has a since-SHA annotation
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    if grep -E '^### ' "$topic" 2>/dev/null | grep -vqE '\(since [^)]+\)'; then
        warn "topic $topic has entries without (since <SHA>) annotation"
    fi
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 4b. Every entry has a **Source:** line matching one of three valid forms.
#     Valid: starts with http:// or https://; equals observed_locally_unvetted;
#     starts with "observed_locally_unvetted (". Anything else: hard error.
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    # Walk entries inside the topic; for each entry section search the body
    # for ^**Source:** lines and classify. Use awk to split into per-entry
    # streams keyed by entry title.
    while IFS=$'\t' read -r entry_title source_value; do
        [ -z "$entry_title" ] && continue
        if [ -z "$source_value" ]; then
            err "missing **Source:** line in entry: $topic:$entry_title"
            continue
        fi
        # Validate the value matches one of the three accepted forms.
        case "$source_value" in
            "http://"*|"https://"*) : ;;  # URL form — OK
            "observed_locally_unvetted") : ;;  # literal — OK
            "observed_locally_unvetted ("*) : ;;  # parenthetical hint — OK
            *)
                err "malformed **Source:** value in entry: $topic:$entry_title (got: $source_value)"
                ;;
        esac
    done < <(awk '
        /^### / {
            if (in_entry) {
                # Emit a TAB-separated record: title<TAB>source_value
                # (source_value is empty when no Source line was found)
                print prev_title "\t" source
            }
            in_entry = 1
            prev_title = $0
            sub(/^### /, "", prev_title)
            source = ""
            next
        }
        in_entry && /^\*\*Source:\*\* / {
            # Strip the marker, keep the value verbatim
            line = $0
            sub(/^\*\*Source:\*\* /, "", line)
            source = line
            next
        }
        END {
            if (in_entry) print prev_title "\t" source
        }
    ' "$topic")
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 5. SHA resolution via git cat-file (catches dangling SHAs after rebase/squash)
#    Only run if we're inside a git repo
if git -C "$(dirname "$KNOWLEDGE")" rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r topic; do
        [ -z "$topic" ] && continue
        # Extract all "since <SHA>" refs
        while IFS= read -r sha; do
            [ -z "$sha" ] && continue
            # HEAD is a valid ref; literal SHAs must resolve
            if ! git -C "$(dirname "$KNOWLEDGE")" cat-file -e "$sha" 2>/dev/null; then
                err "dangling since-SHA in $topic: $sha does not resolve"
            fi
        done < <(grep -oE '\(since [0-9a-fA-F]{7,40}\)|\(since HEAD\)' "$topic" | sed -E 's/.*since ([^)]+).*/\1/')
    done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")
fi

# 6. Soft size cap — entries > 200 words
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    # Split by H3 headings, count words per section.
    # Use process substitution (not a pipe) so the inner `while` runs in the
    # current shell and `warn()` array modifications persist.
    while IFS=: read -r f title wc; do
        warn "oversized entry in $topic (>200 words): $title ($wc words)"
    done < <(awk '
        /^### / { if (entry) { words=split(entry, _, /[[:space:]]+/); if (words > 200) print FILENAME ":" prev_title ":" words }
                  prev_title=$0; entry=""; next }
        { entry = entry $0 "\n" }
        END { if (entry) { words=split(entry, _, /[[:space:]]+/); if (words > 200) print FILENAME ":" prev_title ":" words }
        }
    ' "$topic")
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 7. Soft topic size cap — > 300 lines
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    lines=$(wc -l < "$topic")
    if [ "$lines" -gt 300 ]; then
        warn "oversized topic file (>300 lines): $topic ($lines lines)"
    fi
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 8. Best-effort duplicate detection: H3 titles repeated across files
#    Strip date prefix and since-SHA; remaining title text
all_titles=$(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$META/*" -exec grep -H '^### ' {} \; \
    | sed -E 's/^([^:]+):### [0-9-]+ — ([^(]+) \(since [^)]+\)$/\1\t\2/' | sort)
dup=$(printf '%s\n' "$all_titles" | awk -F'\t' '{print $2}' | sort | uniq -d)
if [ -n "$dup" ]; then
    while IFS= read -r d; do
        [ -z "$d" ] && continue
        sug "possible duplicate entry title across topics: \"$d\""
    done <<< "$dup"
fi

# --- Write report ---
{
    echo "# Knowledge lint report"
    echo ""
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "Errors: ${#errors[@]}"
    echo "Warnings: ${#warnings[@]}"
    echo "Suggestions: ${#suggestions[@]}"
    echo ""
    if [ "${#errors[@]}" -gt 0 ]; then
        echo "## Errors"
        for e in "${errors[@]}"; do echo "- $e"; done
        echo ""
    fi
    if [ "${#warnings[@]}" -gt 0 ]; then
        echo "## Warnings"
        for w in "${warnings[@]}"; do echo "- $w"; done
        echo ""
    fi
    if [ "${#suggestions[@]}" -gt 0 ]; then
        echo "## Suggestions"
        for s in "${suggestions[@]}"; do echo "- $s"; done
        echo ""
    fi
} > "$REPORT"

if [ "${#errors[@]}" -gt 0 ]; then exit 1; else exit 0; fi
