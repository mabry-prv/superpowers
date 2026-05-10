#!/usr/bin/env bash
# Integration test for multi-angle-review skill.
# Requires the `claude` CLI; uses headless mode (`claude -p`) to apply
# each reviewer agent (read from agents/) against the checked-in fixtures
# and assert verdicts.
# Slow (one Claude invocation per reviewer × per fixture). Opt-in via
# the runner's --integration flag.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPERS="$REPO_ROOT/tests/claude-code/test-helpers.sh"
AGENTS="$REPO_ROOT/agents"
FIX="$SCRIPT_DIR/fixtures"

# Per-reviewer timeout. Each dispatch involves Read tool + reasoning over
# the agent body + fixture; 180s is generous enough for normal latency.
TIMEOUT="${MAR_INTEGRATION_TIMEOUT:-180}"

if [ ! -f "$HELPERS" ]; then
    echo "ERROR: helpers file missing at $HELPERS"
    exit 1
fi
# shellcheck disable=SC1090
source "$HELPERS"

if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: claude CLI not found in PATH — required for --integration tests"
    exit 1
fi

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

# Run a reviewer agent against a fixture and capture the verdict line.
# Args: reviewer_name fixture_dir files_csv description
# Sets global RUN_OUTPUT to the captured text.
#
# Note: this test reads the agent file's body as the rule set rather than
# dispatching Task(subagent_type=reviewer-<name>) directly. Headless `claude
# -p` does not reliably surface plugin-shipped agents as subagent_types, so
# the test simulates the dispatch by handing Claude the agent body + the
# per-call context and asking it to apply the rules.
run_reviewer() {
    local reviewer="$1" fixture="$2" files="$3" description="$4"
    local agent_path="$AGENTS/reviewer-${reviewer}.md"
    if [ ! -f "$agent_path" ]; then
        fail "agent missing: $agent_path"
        return 1
    fi

    local prompt
    prompt=$(cat <<EOF
You are simulating the $reviewer agent. Apply the agent definition at $agent_path strictly.

Step 1: Read the agent file at $agent_path. Treat its body (everything after the YAML frontmatter) as your system prompt — the canonical patterns, severity rules, output format, and anti-patterns.

Step 2: Read the fixture files: $files

Step 3: Apply the agent's severity rules to the fixture. The per-call context for this dispatch is:
- DESCRIPTION: $description
- PLAN_OR_REQUIREMENTS: Standard B2B SaaS conventions; org-scoped data; zero-downtime deploys; secret + webhook hygiene.
- FILES_TO_REVIEW: $files

Step 4: Output your full review using the exact format the agent specifies (severity-grouped findings + final Verdict line). Stay strictly in scope for $reviewer; do not comment on out-of-scope concerns.
EOF
)

    RUN_OUTPUT=$(run_claude "$prompt" "$TIMEOUT" "Read,Bash" 2>&1 || true)
}

run_fixture() {
    local label="$1" fixture="$2" expect="$3"
    echo ""
    echo "=== Fixture: $label ($fixture) — expecting $expect verdicts ==="

    # multitenant-isolation: review app/api.py + app/models.py
    local mt_files="$fixture/app/api.py $fixture/app/models.py"
    run_reviewer "multitenant-isolation" "$fixture" "$mt_files" \
        "Org-scoped Notes API (list/get/create/update/delete) over the Note model"
    if [ "$expect" = "BLOCKED" ]; then
        case "$RUN_OUTPUT" in
            *BLOCKED*) pass "$label / multitenant-isolation → BLOCKED" ;;
            *)         fail "$label / multitenant-isolation expected BLOCKED, got: $(echo "$RUN_OUTPUT" | tail -3)" ;;
        esac
    else
        case "$RUN_OUTPUT" in
            *BLOCKED*) fail "$label / multitenant-isolation unexpected BLOCKED" ;;
            *APPROVED*) pass "$label / multitenant-isolation → APPROVED variant" ;;
            *)         fail "$label / multitenant-isolation no recognized verdict; got: $(echo "$RUN_OUTPUT" | tail -3)" ;;
        esac
    fi

    # migration-safety: review the alembic migration files
    local mig_files
    mig_files=$(find "$fixture/alembic/versions" -name '*.py' -type f | tr '\n' ' ')
    run_reviewer "migration-safety" "$fixture" "$mig_files" \
        "Alembic migrations for users/notes feature; production Postgres; zero-downtime deploys"
    if [ "$expect" = "BLOCKED" ]; then
        case "$RUN_OUTPUT" in
            *BLOCKED*) pass "$label / migration-safety → BLOCKED" ;;
            *)         fail "$label / migration-safety expected BLOCKED, got: $(echo "$RUN_OUTPUT" | tail -3)" ;;
        esac
    else
        case "$RUN_OUTPUT" in
            *BLOCKED*) fail "$label / migration-safety unexpected BLOCKED" ;;
            *APPROVED*) pass "$label / migration-safety → APPROVED variant" ;;
            *)         fail "$label / migration-safety no recognized verdict; got: $(echo "$RUN_OUTPUT" | tail -3)" ;;
        esac
    fi

    # security: review auth.py + billing.py
    local sec_files="$fixture/app/auth.py $fixture/app/billing.py"
    run_reviewer "security" "$fixture" "$sec_files" \
        "Auth (signup + login) and Stripe webhook handlers"
    if [ "$expect" = "BLOCKED" ]; then
        case "$RUN_OUTPUT" in
            *BLOCKED*) pass "$label / security → BLOCKED" ;;
            *)         fail "$label / security expected BLOCKED, got: $(echo "$RUN_OUTPUT" | tail -3)" ;;
        esac
    else
        case "$RUN_OUTPUT" in
            *BLOCKED*) fail "$label / security unexpected BLOCKED" ;;
            *APPROVED*) pass "$label / security → APPROVED variant" ;;
            *)         fail "$label / security no recognized verdict; got: $(echo "$RUN_OUTPUT" | tail -3)" ;;
        esac
    fi
}

echo "========================================"
echo " multi-angle-review: integration tests"
echo "========================================"
echo "Agents:   $AGENTS"
echo "Fixtures: $FIX"
echo "Per-reviewer timeout: ${TIMEOUT}s"
echo ""

run_fixture "composite-bug"   "$FIX/composite-bug"   "BLOCKED"
run_fixture "composite-clean" "$FIX/composite-clean" "APPROVED"

echo ""
echo "========================================"
echo " Results: $passed passed, $failed failed"
echo "========================================"

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
