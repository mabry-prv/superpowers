# Agent Set Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote the three reviewer prompt templates into named agent files, add `planner` and `architect` agents, align consuming skills to dispatch by `subagent_type=...`, and ship `agents/README.md` plus structural tests for each new agent.

**Architecture:** Each new agent is a markdown file under `/agents/` with the standard 9-section envelope (frontmatter, role statement, per-call context, before-you-begin, your job, role-specific guidance, when in over your head, self-review, report format). Skills shrink to thin dispatchers that build a per-call context block and call `Task(subagent_type=<agent-name>, prompt=<context>)`. Test runner gets explicit additions for each new agent's structural test.

**Tech Stack:** Markdown for agent and skill content. Bash for structural tests (pure grep + file existence). The plugin's existing `Task` tool with `subagent_type=<bare agent name>` for dispatch.

**Spec:** [docs/superpowers/specs/2026-05-10-agent-set-extension-design.md](../specs/2026-05-10-agent-set-extension-design.md)

---

## File Structure

### New files (13)

| Path | Purpose |
|---|---|
| `agents/reviewer-spec.md` | Per-task spec compliance reviewer (content lifted from `subagent-driven-development/spec-reviewer-prompt.md`) |
| `agents/reviewer-code-quality.md` | Per-task and whole-branch code-quality reviewer; one body, `SCOPE` field gates which checklist applies (merges `subagent-driven-development/code-quality-reviewer-prompt.md` + `requesting-code-review/code-reviewer.md`) |
| `agents/planner.md` | Spec → plan transformer (content adapted from `writing-plans/SKILL.md`) |
| `agents/architect.md` | Non-interactive design consultant (fresh content) |
| `agents/README.md` | Agent family conventions, frontmatter contract, per-call context table, "how to add a new agent" |
| `tests/reviewer-spec/test-structure.sh` | Pure-grep checks: agent file exists, envelope sections present, verdict strings present |
| `tests/reviewer-spec/fixtures/compliant.md` | Happy-path fixture (single requirement, matching implementation) |
| `tests/reviewer-code-quality/test-structure.sh` | Pure-grep checks |
| `tests/reviewer-code-quality/fixtures/clean.md` | Happy-path fixture (clean per-task implementation) |
| `tests/planner/test-structure.sh` | Pure-grep checks |
| `tests/planner/fixtures/small-spec.md` | Happy-path fixture (~3-task spec) |
| `tests/architect/test-structure.sh` | Pure-grep checks |
| `tests/architect/fixtures/pure-design-q.md` | Happy-path fixture (a scoped design question) |

### Modified files (8)

| Path | Change |
|---|---|
| `skills/subagent-driven-development/SKILL.md` | Dispatch reviewer-spec by name; dispatch reviewer-code-quality by name with `SCOPE: per-task`; add architect-on-BLOCKED handling |
| `skills/requesting-code-review/SKILL.md` | Dispatch reviewer-code-quality by name with `SCOPE: whole-branch` |
| `skills/brainstorming/SKILL.md` | Terminal step changes from "invoke writing-plans skill" to "dispatch planner subagent" |
| `skills/writing-plans/SKILL.md` | Becomes thin wrapper: ~30 lines that build the per-call block and dispatch `subagent_type=planner` |
| `agents/implementer-fastapi.md` | Add architectural-escalation paragraph in "When You're in Over Your Head" |
| `agents/implementer-expo.md` | Same |
| `agents/implementer-default.md` | Same |
| `tests/claude-code/run-skill-tests.sh` | Add four entries to `tests=(...)` array (around line 105) |

### Deleted files (4)

| Path | Reason |
|---|---|
| `skills/subagent-driven-development/spec-reviewer-prompt.md` | Content now in `agents/reviewer-spec.md` |
| `skills/subagent-driven-development/code-quality-reviewer-prompt.md` | Content merged into `agents/reviewer-code-quality.md` |
| `skills/subagent-driven-development/implementer-prompt.md` | Already redundant with implementer agent files (matches the existing "delete templates/ dirs" cleanup pattern from recent commits) |
| `skills/requesting-code-review/code-reviewer.md` | Content merged into `agents/reviewer-code-quality.md` |

---

## Phase A — `reviewer-spec` agent

### Task 1: Create `agents/reviewer-spec.md` with frontmatter + role statement

**Files:**
- Create: `/Users/marcin/Projects/superpowers/agents/reviewer-spec.md`

- [ ] **Step 1: Read source content for the body**

Run: `cat /Users/marcin/Projects/superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md`

You'll lift the prose body of this file into the new agent. Note the existing reviewer envelope shape in `agents/reviewer-multitenant-isolation.md` for reference — same frontmatter style, same section ordering.

- [ ] **Step 2: Write the agent file with frontmatter, role statement, per-call context, and section skeletons**

Write to `/Users/marcin/Projects/superpowers/agents/reviewer-spec.md`:

```markdown
---
name: reviewer-spec
description: Use when reviewing whether a per-task implementation matches its spec — verifying nothing was skipped, nothing extra was added, and no requirement was misinterpreted. Dispatched by superpowers:subagent-driven-development after the implementer reports DONE.
color: red
model: opus
effort: xhigh
---

You are reviewing whether an implementation matches its specification. Your sole concern is spec compliance — did the implementer build exactly what the task asked for? Do NOT comment on code quality, security, or migration safety — those have separate reviewers. Stay focused on spec compliance.

## Per-Call Context

The dispatcher provides five pieces of per-call context in your prompt:

- **TASK_NUMBER** — task number from the plan (e.g., "Task 3")
- **TASK_NAME** — short task name from the plan
- **TASK_REQUIREMENTS** — full text of the task as it appears in the plan
- **IMPLEMENTER_REPORT** — what the implementer claims they built
- **FILES_TO_REVIEW** — list of files (paths or git diff range) covering this task's commits

If any are missing or unclear, ask the dispatcher before proceeding.

## CRITICAL: Do Not Trust the Report

The implementer's report may be incomplete, inaccurate, or optimistic. You MUST verify everything independently.

**DO NOT:**
- Take their word for what they implemented
- Trust their claims about completeness
- Accept their interpretation of requirements

**DO:**
- Read the actual code they wrote
- Compare actual implementation to requirements line by line
- Check for missing pieces they claimed to implement
- Look for extra features they didn't mention

## Your Job

Read the implementation code and verify three things:

**Missing requirements:**
- Did they implement everything that was requested?
- Are there requirements they skipped or missed?
- Did they claim something works but didn't actually implement it?

**Extra/unneeded work:**
- Did they build things that weren't requested?
- Did they over-engineer or add unnecessary features?
- Did they add "nice to haves" that weren't in spec?

**Misunderstandings:**
- Did they interpret requirements differently than intended?
- Did they solve the wrong problem?
- Did they implement the right feature but wrong way?

**Verify by reading code, not by trusting report.**

## Report Format

End with exactly one of:

**✅ Spec compliant** (after code inspection — every requirement met, nothing extra)

**❌ Issues found:**
- Missing: [requirement, with `file:line` showing where it should have been]
- Extra: [unrequested feature, with `file:line` showing what to remove]
- Misunderstood: [requirement, with explanation of the mismatch]

For each issue, give a `file:line` reference and a one-sentence explanation. Be specific — vagueness lets bugs through.

## Anti-Patterns — What NOT to Do

**DO:**
- Read every line of every file in `FILES_TO_REVIEW` before forming a verdict
- Compare requirements to code one by one, not in bulk
- Flag missing requirements even when the implementer's report claims completion
- Flag extras even when they "seem reasonable" — the spec is authoritative

**DON'T:**
- Comment on code quality, naming, or style — that's the code-quality reviewer's job
- Approve based on the implementer's claims alone
- Skip a requirement check because "the implementer probably did it"
- Be vague — every issue needs a `file:line`
```

- [ ] **Step 3: Verify file exists and frontmatter parses**

Run: `head -7 /Users/marcin/Projects/superpowers/agents/reviewer-spec.md`
Expected: lines 1-7 show the frontmatter block, ending with `---` on line 7.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add agents/reviewer-spec.md
git commit -m "$(cat <<'EOF'
feat(agents): add reviewer-spec agent for per-task spec-compliance review

Promotes content from skills/subagent-driven-development/spec-reviewer-prompt.md
into a named agent file with pinned model/effort. Old template will be deleted
in the wiring task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Write structural test for `reviewer-spec`

**Files:**
- Create: `/Users/marcin/Projects/superpowers/tests/reviewer-spec/test-structure.sh`
- Create: `/Users/marcin/Projects/superpowers/tests/reviewer-spec/fixtures/compliant.md`

- [ ] **Step 1: Create the fixtures directory and a happy-path fixture**

```bash
mkdir -p /Users/marcin/Projects/superpowers/tests/reviewer-spec/fixtures
```

Write to `/Users/marcin/Projects/superpowers/tests/reviewer-spec/fixtures/compliant.md`:

```markdown
# Fixture: compliant per-task implementation

## TASK_REQUIREMENTS

Task 1: Add a function `greet(name: str) -> str` in `lib/greet.py` that returns `f"Hello, {name}!"`. Add a passing test in `tests/test_greet.py`.

## IMPLEMENTER_REPORT

Implemented `greet` in `lib/greet.py:1-2`. Added `test_greet_basic` in `tests/test_greet.py:1-4`. All tests pass.

## FILES_TO_REVIEW

```python
# lib/greet.py
def greet(name: str) -> str:
    return f"Hello, {name}!"
```

```python
# tests/test_greet.py
from lib.greet import greet

def test_greet_basic():
    assert greet("world") == "Hello, world!"
```

## EXPECTED VERDICT

✅ Spec compliant
```

- [ ] **Step 2: Write the structural test**

Write to `/Users/marcin/Projects/superpowers/tests/reviewer-spec/test-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural test for reviewer-spec agent.
# Pure grep + file existence checks — no `claude` CLI dependency.
# Catches regressions in agent envelope, frontmatter, verdict strings,
# and fixture presence.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/reviewer-spec.md"
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
echo " reviewer-spec: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/reviewer-spec.md"
assert_grep "$AGENT" '^name: reviewer-spec$' "frontmatter: name=reviewer-spec"
assert_grep "$AGENT" '^color: red$' "frontmatter: color=red"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'TASK_NUMBER' "context field: TASK_NUMBER"
assert_grep "$AGENT" 'TASK_NAME' "context field: TASK_NAME"
assert_grep "$AGENT" 'TASK_REQUIREMENTS' "context field: TASK_REQUIREMENTS"
assert_grep "$AGENT" 'IMPLEMENTER_REPORT' "context field: IMPLEMENTER_REPORT"
assert_grep "$AGENT" 'FILES_TO_REVIEW' "context field: FILES_TO_REVIEW"

# Required verdict strings
assert_grep "$AGENT" 'Spec compliant' "verdict: Spec compliant"
assert_grep "$AGENT" 'Issues found' "verdict: Issues found"

# Fixture presence
assert_file "$FIX/compliant.md" "fixture: compliant.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

- [ ] **Step 3: Make the test executable and run it**

```bash
chmod +x /Users/marcin/Projects/superpowers/tests/reviewer-spec/test-structure.sh
bash /Users/marcin/Projects/superpowers/tests/reviewer-spec/test-structure.sh
```

Expected: all assertions pass, "Results: N passed, 0 failed".

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add tests/reviewer-spec/
git commit -m "$(cat <<'EOF'
test(reviewer-spec): structural test + happy-path fixture

Pure-grep checks for agent envelope, frontmatter, per-call context fields,
and verdict strings. One fixture covers the compliant case; expanding
to missing-requirement and extra-feature fixtures is follow-up work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Wire `reviewer-spec` into `subagent-driven-development/SKILL.md`; delete the old prompt template

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/SKILL.md`
- Delete: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md`
- Modify: `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`

- [ ] **Step 1: Read the current SKILL.md to find the spec-review dispatch step**

Run: `grep -n "spec-reviewer-prompt" /Users/marcin/Projects/superpowers/skills/subagent-driven-development/SKILL.md`

You should see references in the "Per Task" flowchart and the "Prompt Templates" section. Both need updating.

- [ ] **Step 2: In `SKILL.md`, replace the "Prompt Templates" bullet for spec-reviewer**

Find this in `skills/subagent-driven-development/SKILL.md`:

```
- `./spec-reviewer-prompt.md` - Dispatch spec compliance reviewer subagent
```

Replace with:

```
- Dispatch spec compliance reviewer via `Task(subagent_type=reviewer-spec, prompt=<per-call context block>)`
```

- [ ] **Step 3: In `SKILL.md`, add a "Per-Call Context Block: reviewer-spec" subsection above "Prompt Templates"**

Insert this just before the "## Prompt Templates" heading:

````markdown
## Per-Call Context Blocks

When dispatching reviewer subagents from this skill, build the per-call context block with all fields populated and pass it as the Task `prompt` argument. Verify all fields are populated before dispatch — a missing field would cause the reviewer to hallucinate output on empty context.

### reviewer-spec

```
TASK_NUMBER: <e.g. "Task 3">
TASK_NAME: <short task name from the plan>
TASK_REQUIREMENTS: <full text of the task as it appears in the plan>
IMPLEMENTER_REPORT: <what the implementer claims they built>
FILES_TO_REVIEW: <paths or git range covering this task's commits>
```
````

- [ ] **Step 4: Update the flowchart text**

Find this in the `digraph process` block:

```
"Dispatch spec reviewer subagent (./spec-reviewer-prompt.md)" [shape=box];
```

Replace with:

```
"Dispatch reviewer-spec subagent" [shape=box];
```

Also update the three flowchart edges that reference `./spec-reviewer-prompt.md` — change the node label to match.

- [ ] **Step 5: Delete the old prompt template**

```bash
git rm /Users/marcin/Projects/superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md
```

- [ ] **Step 6: Wire the new structural test into the runner**

Edit `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`. Find the `tests=(...)` array (around line 105):

```bash
tests=(
    "test-subagent-driven-development.sh"
    "../multi-angle-review/test-structure.sh"
)
```

Replace with:

```bash
tests=(
    "test-subagent-driven-development.sh"
    "../multi-angle-review/test-structure.sh"
    "../reviewer-spec/test-structure.sh"
)
```

- [ ] **Step 7: Run the full structural test suite**

```bash
bash /Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh
```

Expected: all tests pass (no integration tests run because `--integration` flag not used).

- [ ] **Step 8: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add skills/subagent-driven-development/SKILL.md \
        tests/claude-code/run-skill-tests.sh
git commit -m "$(cat <<'EOF'
refactor(sdd): dispatch reviewer-spec by subagent_type, drop old template

skills/subagent-driven-development/SKILL.md now dispatches the spec-compliance
reviewer as `Task(subagent_type=reviewer-spec)`. The old prompt template
file is deleted; its content lives in agents/reviewer-spec.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase B — `reviewer-code-quality` agent

### Task 4: Create `agents/reviewer-code-quality.md` with frontmatter + per-call context

**Files:**
- Create: `/Users/marcin/Projects/superpowers/agents/reviewer-code-quality.md`

- [ ] **Step 1: Read both source templates to understand the merge**

```bash
cat /Users/marcin/Projects/superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md
cat /Users/marcin/Projects/superpowers/skills/requesting-code-review/code-reviewer.md
```

The per-task version emphasizes file responsibility and plan-structure adherence; the whole-branch version emphasizes architecture, integration, and production readiness. Both share the Strengths/Issues/Recommendations/Assessment output format.

- [ ] **Step 2: Write the agent file with frontmatter and per-call context block**

Write to `/Users/marcin/Projects/superpowers/agents/reviewer-code-quality.md`:

```markdown
---
name: reviewer-code-quality
description: Use when reviewing per-task or whole-branch code quality — clean separation, tests, naming, file size, architecture, integration, production readiness. Dispatched by superpowers:subagent-driven-development (per-task) and superpowers:requesting-code-review (whole-branch). The SCOPE field selects which checklist applies.
color: red
model: opus
effort: xhigh
---

You are reviewing code quality. Your concerns are clean separation of concerns, test discipline, naming, file size, architectural soundness, and production readiness. Do NOT comment on spec compliance (separate reviewer), security defects (separate reviewer), multi-tenant isolation (separate reviewer), or migration safety (separate reviewer). Stay focused on code quality.

## Per-Call Context

The dispatcher provides five pieces of per-call context in your prompt:

- **SCOPE** — `per-task` (one task's commits) or `whole-branch` (entire branch from base)
- **DESCRIPTION** — brief summary of what was built
- **PLAN_OR_REQUIREMENTS** — plan file path, task text, or requirements
- **BASE_SHA** — starting commit
- **HEAD_SHA** — ending commit

If any are missing or unclear, ask the dispatcher before proceeding.

## Reading the Diff

```bash
git diff --stat $BASE_SHA..$HEAD_SHA   # overview
git diff $BASE_SHA..$HEAD_SHA          # full content
```

Read every changed file before forming a verdict. The verdict is meaningless if the review is partial.

## What to Check (per SCOPE)

### SCOPE: per-task

Focused on whether this task's commits, on their own, are well-built:

- **Single responsibility per file:** Does each file you read have one clear responsibility with a well-defined interface?
- **Unit testability:** Can each unit be understood and tested independently?
- **Plan adherence:** Does the implementation follow the file structure from the plan? Deviations need justification.
- **File-size growth:** Did this implementation create new files that are already large, or significantly grow existing files? (Don't flag pre-existing file sizes — focus on what THIS change contributed.)
- **Test discipline:** Do tests verify real behavior, not mocks? Are edge cases covered? Did TDD happen if the task required it?
- **Naming:** Do names describe what things do, not how they work? Consistent with surrounding code?
- **YAGNI:** Did the implementer build only what was requested, or add speculative abstractions/hooks/configs?

### SCOPE: whole-branch

Focused on whether the branch, as a coherent unit, is ready to merge:

- **Plan alignment:** Does the implementation match the plan/requirements? Are deviations justified improvements or problematic departures?
- **Architecture:** Sound design decisions? Reasonable scalability and performance? Integrates cleanly with surrounding code?
- **Cross-file integration:** Do the pieces compose? Are there interfaces that drift across tasks?
- **Test coverage:** Tests verify real behavior, not mocks? Edge cases covered? Integration tests where they matter? All tests passing?
- **Production readiness:** Migration strategy if schema changed? Backward compatibility considered? Documentation complete? No obvious bugs?
- **Discipline:** No dead code, no overbuilding, no unused configuration knobs.

## Calibration

Categorize issues by actual severity. Not everything is Critical.

Acknowledge what was done well before listing issues — accurate praise helps the implementer trust the rest of the feedback.

If you find significant deviations from the plan, flag them specifically so the implementer can confirm whether the deviation was intentional. If you find issues with the plan itself rather than the implementation, say so.

## Output Format

### Strengths

[What's well done? Be specific.]

### Issues

#### Critical (Must Fix)

[Bugs, security issues, data loss risks, broken functionality]

#### Important (Should Fix)

[Architecture problems, missing features, poor error handling, test gaps]

#### Minor (Nice to Have)

[Code style, optimization opportunities, documentation polish]

For each issue:
- `file:line` reference
- What's wrong
- Why it matters
- How to fix (if not obvious)

### Recommendations

[Improvements for code quality, architecture, or process]

### Assessment

**Ready to merge?** [Yes | No | With fixes]

**Reasoning:** [1-2 sentence technical assessment]

## Anti-Patterns — What NOT to Do

**DO:**
- Read every line of every diff in the SHA range before forming a verdict
- Categorize issues by actual severity
- Be specific (`file:line`, not vague)
- Explain WHY each issue matters
- Acknowledge strengths
- Give a clear merge verdict

**DON'T:**
- Say "looks good" without checking
- Mark nitpicks as Critical
- Give feedback on code you didn't actually read
- Be vague ("improve error handling" without specifics)
- Comment on spec compliance, security, multi-tenant isolation, or migration safety — those have separate reviewers
- Skip the merge verdict
```

- [ ] **Step 3: Verify file**

Run: `head -10 /Users/marcin/Projects/superpowers/agents/reviewer-code-quality.md`
Expected: frontmatter ending at line 7, role statement on line 9.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add agents/reviewer-code-quality.md
git commit -m "$(cat <<'EOF'
feat(agents): add reviewer-code-quality agent (per-task + whole-branch)

Single agent with two checklists gated by per-call SCOPE field. Merges
content from skills/subagent-driven-development/code-quality-reviewer-prompt.md
and skills/requesting-code-review/code-reviewer.md. Old templates will be
deleted in the wiring task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Write structural test for `reviewer-code-quality`

**Files:**
- Create: `/Users/marcin/Projects/superpowers/tests/reviewer-code-quality/test-structure.sh`
- Create: `/Users/marcin/Projects/superpowers/tests/reviewer-code-quality/fixtures/clean.md`

- [ ] **Step 1: Create the fixtures directory and a happy-path fixture**

```bash
mkdir -p /Users/marcin/Projects/superpowers/tests/reviewer-code-quality/fixtures
```

Write to `/Users/marcin/Projects/superpowers/tests/reviewer-code-quality/fixtures/clean.md`:

```markdown
# Fixture: clean per-task implementation

## SCOPE

per-task

## DESCRIPTION

Added a `parse_csv_line(line: str) -> list[str]` helper with tests.

## PLAN_OR_REQUIREMENTS

Task 1: Add `parse_csv_line` in `lib/csv.py`. Handle quoted fields with embedded commas. Add tests covering: simple line, line with quoted field, line with empty fields.

## DIFF (BASE → HEAD)

```python
# lib/csv.py (new file)
import csv
from io import StringIO

def parse_csv_line(line: str) -> list[str]:
    return next(csv.reader(StringIO(line)))
```

```python
# tests/test_csv.py (new file)
import pytest
from lib.csv import parse_csv_line

def test_simple():
    assert parse_csv_line("a,b,c") == ["a", "b", "c"]

def test_quoted_field_with_comma():
    assert parse_csv_line('a,"b,c",d') == ["a", "b,c", "d"]

def test_empty_fields():
    assert parse_csv_line("a,,c") == ["a", "", "c"]
```

## EXPECTED VERDICT

APPROVED — three tests cover the spec'd cases, single-responsibility file, idiomatic use of stdlib `csv`. Ready to merge.
```

- [ ] **Step 2: Write the structural test**

Write to `/Users/marcin/Projects/superpowers/tests/reviewer-code-quality/test-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural test for reviewer-code-quality agent.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/reviewer-code-quality.md"
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
echo " reviewer-code-quality: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/reviewer-code-quality.md"
assert_grep "$AGENT" '^name: reviewer-code-quality$' "frontmatter: name"
assert_grep "$AGENT" '^color: red$' "frontmatter: color=red"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## What to Check' "section: What to Check"
assert_grep "$AGENT" '^## Output Format' "section: Output Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'SCOPE' "context field: SCOPE"
assert_grep "$AGENT" 'DESCRIPTION' "context field: DESCRIPTION"
assert_grep "$AGENT" 'PLAN_OR_REQUIREMENTS' "context field: PLAN_OR_REQUIREMENTS"
assert_grep "$AGENT" 'BASE_SHA' "context field: BASE_SHA"
assert_grep "$AGENT" 'HEAD_SHA' "context field: HEAD_SHA"

# Both scope checklists present
assert_grep "$AGENT" 'SCOPE: per-task' "checklist: per-task"
assert_grep "$AGENT" 'SCOPE: whole-branch' "checklist: whole-branch"

# Required output sections
assert_grep "$AGENT" '### Strengths' "output: Strengths"
assert_grep "$AGENT" '### Issues' "output: Issues"
assert_grep "$AGENT" '### Assessment' "output: Assessment"
assert_grep "$AGENT" 'Ready to merge' "output: merge verdict"

# Fixture presence
assert_file "$FIX/clean.md" "fixture: clean.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

- [ ] **Step 3: Make executable and run**

```bash
chmod +x /Users/marcin/Projects/superpowers/tests/reviewer-code-quality/test-structure.sh
bash /Users/marcin/Projects/superpowers/tests/reviewer-code-quality/test-structure.sh
```

Expected: all assertions pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add tests/reviewer-code-quality/
git commit -m "$(cat <<'EOF'
test(reviewer-code-quality): structural test + happy-path fixture

Pure-grep checks for envelope, both SCOPE checklists, and output sections.
One fixture covers the per-task clean case; whole-branch and quality-issue
fixtures are follow-up work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Wire `reviewer-code-quality` into both consuming skills; delete old templates

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `/Users/marcin/Projects/superpowers/skills/requesting-code-review/SKILL.md`
- Delete: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md`
- Delete: `/Users/marcin/Projects/superpowers/skills/requesting-code-review/code-reviewer.md`
- Modify: `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`

- [ ] **Step 1: Update `subagent-driven-development/SKILL.md` — replace the code-quality dispatch reference**

Find this in `skills/subagent-driven-development/SKILL.md`:

```
- `./code-quality-reviewer-prompt.md` - Dispatch code quality reviewer subagent
```

Replace with:

```
- Dispatch code-quality reviewer via `Task(subagent_type=reviewer-code-quality, prompt=<per-call context block with SCOPE: per-task>)`
```

- [ ] **Step 2: Add the per-call context block for reviewer-code-quality**

In the same file, under the "Per-Call Context Blocks" section you added in Task 3, append:

````markdown
### reviewer-code-quality (per-task scope)

```
SCOPE: per-task
DESCRIPTION: <brief summary of what the implementer built for THIS task>
PLAN_OR_REQUIREMENTS: <plan file path + task number, or full task text>
BASE_SHA: <commit before this task started>
HEAD_SHA: <current commit after implementer finished>
```
````

- [ ] **Step 3: Update flowchart references**

In the same `digraph process` block, find:

```
"Dispatch code quality reviewer subagent (./code-quality-reviewer-prompt.md)" [shape=box];
```

Replace with:

```
"Dispatch reviewer-code-quality subagent (SCOPE: per-task)" [shape=box];
```

Also update edges that reference the old node label.

- [ ] **Step 4: Update `requesting-code-review/SKILL.md`**

Replace the entire body of `skills/requesting-code-review/SKILL.md` with:

````markdown
---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch the `reviewer-code-quality` agent at whole-branch scope to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development (use SCOPE: per-task — see superpowers:subagent-driven-development)
- After completing a major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**

```bash
BASE_SHA=$(git merge-base HEAD origin/main)   # branch base
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch reviewer-code-quality at whole-branch scope:**

```
Task(
  subagent_type=reviewer-code-quality,
  description="Review whole-branch code quality",
  prompt=<per-call context block below>
)
```

**Per-call context block (verify all fields populated before dispatch):**

```
SCOPE: whole-branch
DESCRIPTION: <brief summary of what you built>
PLAN_OR_REQUIREMENTS: <plan file path or requirements>
BASE_SHA: <starting commit>
HEAD_SHA: <ending commit>
```

**3. Act on the verdict:**

- Fix Critical issues immediately
- Fix Important issues before merging
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Follow-up: Multi-Angle Review

If the project has the multi-angle-review skill conventions (typically: a multi-tenant SaaS with FastAPI + Postgres + Alembic), after `reviewer-code-quality` returns APPROVED, run `superpowers:multi-angle-review` as a follow-up. It dispatches role-specific reviewers (multitenant-isolation, migration-safety, security) based on what the diff touches. Critical findings from multi-angle-review block the same way the standard reviewer's Critical findings do.

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification
````

- [ ] **Step 5: Delete the old templates**

```bash
cd /Users/marcin/Projects/superpowers
git rm skills/subagent-driven-development/code-quality-reviewer-prompt.md
git rm skills/requesting-code-review/code-reviewer.md
```

- [ ] **Step 6: Wire the structural test into the runner**

In `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`, append `"../reviewer-code-quality/test-structure.sh"` to the `tests=(...)` array. The array should now read:

```bash
tests=(
    "test-subagent-driven-development.sh"
    "../multi-angle-review/test-structure.sh"
    "../reviewer-spec/test-structure.sh"
    "../reviewer-code-quality/test-structure.sh"
)
```

- [ ] **Step 7: Run the test suite**

```bash
bash /Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh
```

Expected: all four tests in the array pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add skills/subagent-driven-development/SKILL.md \
        skills/requesting-code-review/SKILL.md \
        tests/claude-code/run-skill-tests.sh
git commit -m "$(cat <<'EOF'
refactor: dispatch reviewer-code-quality by subagent_type at both scopes

skills/subagent-driven-development uses SCOPE: per-task; skills/requesting-code-review
uses SCOPE: whole-branch. Both old prompt-template files deleted; their content
lives in agents/reviewer-code-quality.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase C — `planner` agent

### Task 7: Create `agents/planner.md` with frontmatter + per-call context

**Files:**
- Create: `/Users/marcin/Projects/superpowers/agents/planner.md`

- [ ] **Step 1: Read the writing-plans skill content as the source body**

```bash
cat /Users/marcin/Projects/superpowers/skills/writing-plans/SKILL.md
```

You'll lift the planning rules (Bite-Sized Task Granularity, Plan Document Header, Task Structure, No Placeholders, Self-Review) into the agent body. The skill's "Execution Handoff" and "Announce at start" sections do NOT belong in the agent — those are concerns of the skill's caller, not the planner subagent.

- [ ] **Step 2: Write the agent file**

Write to `/Users/marcin/Projects/superpowers/agents/planner.md`:

````markdown
---
name: planner
description: Use when transforming a design spec into an implementation plan with bite-sized, TDD-shaped tasks. Dispatched by superpowers:brainstorming (terminal step) and superpowers:writing-plans (when invoked directly).
color: green
model: opus
effort: max
---

You are a planner subagent. Your job is to transform a design spec into a comprehensive implementation plan with bite-sized tasks. Assume the engineer who will execute this plan has zero context for the codebase and questionable taste — document everything they need: which files to touch for each task, code, testing, docs to check, how to verify. DRY, YAGNI, TDD, frequent commits.

Assume they are a skilled developer but know almost nothing about the project's toolset or problem domain. Assume they don't know good test design very well.

## Per-Call Context

The dispatcher provides four pieces of per-call context in your prompt:

- **SPEC_PATH** — path to the approved design spec (e.g., `docs/superpowers/specs/2026-05-10-foo-design.md`)
- **WORKING_DIRECTORY** — where you should work from
- **PROJECT_CONTEXT** — relevant existing structure (apps/api layout, tech stack, conventions)
- **CONSTRAINTS** — any hard constraints from brainstorm (must not break X, must ship by Y, etc.)

If any are missing or unclear, ask the dispatcher before starting.

## Before You Begin

1. Read `SPEC_PATH` in full.
2. Confirm the spec is single-scope (not multiple independent subsystems). If it covers multiple subsystems, surface this to the dispatcher and request a decomposition before proceeding — each plan should produce working, testable software on its own.
3. If you have questions about scope, sequencing, or assumptions, ask the dispatcher before writing the plan.

## Your Job

1. Map out the file structure (created/modified/deleted) before defining tasks.
2. Write a comprehensive plan to `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (or wherever the project's existing plans live — follow established convention if one exists).
3. Self-review the plan against the spec.
4. Commit the plan.
5. Report back the plan path, task count, and any open questions.

## File Structure (do this first)

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure — but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**

- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

A task can have many steps; tasks themselves are typically 30 minutes to 1.5 hours.

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

Each task uses this template:

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for the patterns above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. If you find a spec requirement with no task, add the task.

## Report Format

When done, report:

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Plan path
- Task count, decomposition summary (e.g., "17 tasks across 5 phases")
- Any open questions surfaced for the planning phase to resolve later
- Self-review findings (if any)

Use DONE_WITH_CONCERNS if the plan is written but you noted scope or type-consistency concerns. Use BLOCKED if the spec is too underspecified to plan against. Use NEEDS_CONTEXT if a per-call context field was incomplete.

## Anti-Patterns — What NOT to Do

**DO:**
- Read the spec in full before starting
- Map file structure before writing tasks
- Show concrete code/commands in every step
- Commit the plan when finished

**DON'T:**
- Write placeholder steps
- Plan implementation that wasn't in the spec
- Skip the self-review
- Plan in your head without actually writing the file
````

- [ ] **Step 3: Verify the file**

Run: `head -10 /Users/marcin/Projects/superpowers/agents/planner.md`
Expected: frontmatter through line 7, role statement on line 9.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add agents/planner.md
git commit -m "$(cat <<'EOF'
feat(agents): add planner agent for spec → plan transformation

Adapts content from skills/writing-plans/SKILL.md into a subagent envelope.
Per-call SPEC_PATH + PROJECT_CONTEXT input; writes plan file output and
reports path back. The skill itself becomes a thin dispatcher in a
follow-up task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Write structural test for `planner`

**Files:**
- Create: `/Users/marcin/Projects/superpowers/tests/planner/test-structure.sh`
- Create: `/Users/marcin/Projects/superpowers/tests/planner/fixtures/small-spec.md`

- [ ] **Step 1: Create fixtures directory and a happy-path fixture**

```bash
mkdir -p /Users/marcin/Projects/superpowers/tests/planner/fixtures
```

Write to `/Users/marcin/Projects/superpowers/tests/planner/fixtures/small-spec.md`:

```markdown
# Fixture: small spec — slugify utility

## Goal

Add a `slugify(s: str) -> str` helper that lowercases input and replaces non-alphanumeric runs with single hyphens, trimming hyphens from the ends.

## File Structure

- `lib/slugify.py` — single function `slugify`
- `tests/test_slugify.py` — unit tests

## Acceptance criteria

- `slugify("Hello World")` → `"hello-world"`
- `slugify("  foo--bar  ")` → `"foo-bar"`
- `slugify("a/b/c")` → `"a-b-c"`
- `slugify("")` → `""`

## EXPECTED PLAN SHAPE

A 2-3 task plan: (1) write failing tests, (2) implement minimal slugify, (3) commit. Each task has Files block, numbered steps with code, expected output. No placeholders.
```

- [ ] **Step 2: Write the structural test**

Write to `/Users/marcin/Projects/superpowers/tests/planner/test-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural test for planner agent.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/planner.md"
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
echo " planner: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/planner.md"
assert_grep "$AGENT" '^name: planner$' "frontmatter: name=planner"
assert_grep "$AGENT" '^color: green$' "frontmatter: color=green"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: max$' "frontmatter: effort=max"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Bite-Sized Task Granularity' "section: Bite-Sized Task Granularity"
assert_grep "$AGENT" '^## No Placeholders' "section: No Placeholders"
assert_grep "$AGENT" '^## Self-Review' "section: Self-Review"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'SPEC_PATH' "context field: SPEC_PATH"
assert_grep "$AGENT" 'WORKING_DIRECTORY' "context field: WORKING_DIRECTORY"
assert_grep "$AGENT" 'PROJECT_CONTEXT' "context field: PROJECT_CONTEXT"
assert_grep "$AGENT" 'CONSTRAINTS' "context field: CONSTRAINTS"

# Status enumeration
assert_grep "$AGENT" 'DONE_WITH_CONCERNS' "status: DONE_WITH_CONCERNS"
assert_grep "$AGENT" 'BLOCKED' "status: BLOCKED"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "status: NEEDS_CONTEXT"

# Fixture presence
assert_file "$FIX/small-spec.md" "fixture: small-spec.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

- [ ] **Step 3: Make executable and run**

```bash
chmod +x /Users/marcin/Projects/superpowers/tests/planner/test-structure.sh
bash /Users/marcin/Projects/superpowers/tests/planner/test-structure.sh
```

Expected: all assertions pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add tests/planner/
git commit -m "$(cat <<'EOF'
test(planner): structural test + happy-path fixture

Pure-grep checks for envelope, per-call context fields, status enumeration.
One fixture covers a small-spec case; medium-spec and too-large-spec
fixtures are follow-up work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Convert `writing-plans/SKILL.md` to thin dispatcher; update brainstorming terminal step; wire test

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/skills/writing-plans/SKILL.md`
- Modify: `/Users/marcin/Projects/superpowers/skills/brainstorming/SKILL.md`
- Modify: `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`

- [ ] **Step 1: Replace the body of `writing-plans/SKILL.md`**

Write to `/Users/marcin/Projects/superpowers/skills/writing-plans/SKILL.md`:

````markdown
---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

This skill dispatches the `planner` agent to transform a design spec into an implementation plan with bite-sized, TDD-shaped tasks. The agent's system prompt holds the canonical planning rules (file structure, task granularity, no-placeholders, self-review). This skill is a thin dispatcher.

**Announce at start:** "I'm using the writing-plans skill to dispatch the planner agent."

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (the agent does this — user preferences for plan location override this default and should be passed in `PROJECT_CONTEXT`).

## When to Use

- After `superpowers:brainstorming` produces an approved spec.
- When a user types `/writing-plans` directly with a spec already in hand.

Do NOT use this skill if no spec exists. Brainstorm first.

## How to Dispatch

Build the per-call context block with all four fields populated:

```
SPEC_PATH: <path to the approved design spec>
WORKING_DIRECTORY: <where the planner should work from>
PROJECT_CONTEXT: <relevant existing structure — apps/api layout, tech stack, conventions, existing plans dir if non-default>
CONSTRAINTS: <hard constraints from brainstorm — must not break X, must ship by Y, etc.>
```

Verify all fields are populated before dispatch — a missing field would cause the planner to plan against empty context.

Then dispatch:

```
Task(
  subagent_type=planner,
  description="Write implementation plan for <feature>",
  prompt=<the per-call context block>
)
```

## After the Plan Is Written

The planner reports back with:

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Plan path
- Task count, decomposition summary
- Open questions (if any)

Handle each status:

- **DONE**: proceed to execution handoff (below)
- **DONE_WITH_CONCERNS**: read the concerns, decide whether to address before execution
- **BLOCKED**: spec is too underspecified — return to brainstorming
- **NEEDS_CONTEXT**: provide the missing context field and re-dispatch

## Execution Handoff

After the plan is committed, offer the user execution choice:

> "Plan complete and saved to `<plan-path>`. Two execution options:
>
> **1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
>
> **2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.
>
> Which approach?"

If Subagent-Driven chosen: REQUIRED SUB-SKILL: superpowers:subagent-driven-development.
If Inline Execution chosen: REQUIRED SUB-SKILL: superpowers:executing-plans.
````

- [ ] **Step 2: Update `brainstorming/SKILL.md` terminal step**

Find this in `skills/brainstorming/SKILL.md`:

```
9. **Transition to implementation** — invoke writing-plans skill to create implementation plan
```

Replace with:

```
9. **Transition to implementation** — dispatch the `planner` subagent (via the `superpowers:writing-plans` skill, which is now a thin dispatcher) to create the implementation plan
```

- [ ] **Step 3: Update the brainstorming flowchart**

Find this node in the `digraph brainstorming` block:

```
"Invoke writing-plans skill" [shape=doublecircle];
```

Replace with:

```
"Dispatch planner subagent (via writing-plans skill)" [shape=doublecircle];
```

Update the edge label from `"Invoke writing-plans skill"` to `"Dispatch planner subagent (via writing-plans skill)"`.

- [ ] **Step 4: Wire the structural test into the runner**

In `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`, append `"../planner/test-structure.sh"` to the `tests=(...)` array:

```bash
tests=(
    "test-subagent-driven-development.sh"
    "../multi-angle-review/test-structure.sh"
    "../reviewer-spec/test-structure.sh"
    "../reviewer-code-quality/test-structure.sh"
    "../planner/test-structure.sh"
)
```

- [ ] **Step 5: Run the test suite**

```bash
bash /Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh
```

Expected: all five tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add skills/writing-plans/SKILL.md \
        skills/brainstorming/SKILL.md \
        tests/claude-code/run-skill-tests.sh
git commit -m "$(cat <<'EOF'
refactor: writing-plans skill becomes thin dispatcher for planner agent

skills/writing-plans/SKILL.md now ~30 lines: build the per-call context
block and dispatch Task(subagent_type=planner). brainstorming's terminal
step updated to dispatch via the new path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase D — `architect` agent

### Task 10: Create `agents/architect.md`

**Files:**
- Create: `/Users/marcin/Projects/superpowers/agents/architect.md`

- [ ] **Step 1: Write the agent file**

Write to `/Users/marcin/Projects/superpowers/agents/architect.md`:

```markdown
---
name: architect
description: Use as a non-interactive design consultant when an implementer is BLOCKED on an architectural ambiguity, or when main session needs a one-off design recommendation. Returns 2-3 options with tradeoffs and a recommendation. Does NOT modify code.
color: blue
model: opus
effort: max
---

You are a design consultant subagent. The dispatcher has come to you with a scoped architectural question. Your job is to return 2-3 options with tradeoffs and a clear recommendation. You do NOT modify code, do NOT write tests, do NOT implement anything. The decision owner — usually the main session or an implementer — will act on your recommendation.

## Per-Call Context

The dispatcher provides five pieces of per-call context in your prompt:

- **QUESTION** — the specific design question, single and scoped
- **CODE_CONTEXT** — relevant file contents or excerpts, what already exists
- **CONSTRAINTS** — invariants, conventions, performance / security / compliance requirements
- **PRIOR_ATTEMPTS** — what's been tried or considered, if any
- **DECISION_OWNER** — who will act on the recommendation (main session, or implementer for Task N)

If any are missing or unclear, ask the dispatcher before proceeding.

## Before You Begin

Read CODE_CONTEXT in full. Re-read QUESTION carefully — make sure you're answering the actual question, not a question you would have preferred. If the question is too broad to give a focused recommendation, ask the dispatcher to scope it down before proceeding.

If the question is vague or ambiguous in a way that materially changes the answer, ask one clarifying question rather than inventing assumptions.

## Your Job

Produce 2-3 design options. For each:

1. **Name the option** — short label (3-5 words)
2. **Describe it concretely** — what shape does the code take, what files change, what are the new types/functions/conventions
3. **Tradeoffs** — what does this option buy, what does it cost, what does it preclude
4. **When this is right** — under what conditions would you pick this option

Then give your **recommendation** with reasoning. Be concrete: "I recommend Option B because <specific property of the constraint set>." Avoid hedging like "it depends" without saying *what* it depends on.

If the right answer is "wait" or "do nothing," say that. Don't invent options for the sake of having three.

## When You're in Over Your Head

It is OK to say "this is the wrong question" or "I need more context to give a useful answer." Bad recommendations are worse than no recommendation.

**STOP and escalate when:**
- The question requires running the code or testing behavior to answer
- The question depends on information that wasn't in CODE_CONTEXT and you can't reasonably infer
- The question is actually a product/scope question, not an architectural one — surface this back to the decision owner
- You're being asked to design something that's already designed (look at CODE_CONTEXT first — sometimes the answer is "use the existing X")

**How to escalate:** Report back with status NEEDS_CONTEXT or NEEDS_RESCOPE. Describe specifically what you need.

## Report Format

When done, report:

**Status:** DONE | NEEDS_CONTEXT | NEEDS_RESCOPE

### Options

**Option A: <name>**

[Concrete description]

- **Buys:** [what this option gets you]
- **Costs:** [what it costs]
- **Right when:** [conditions favoring this option]

**Option B: <name>**

[same structure]

**Option C: <name>** (if a meaningful third option exists)

[same structure]

### Recommendation

**I recommend Option <X>.**

**Reasoning:** [1-3 sentences tying the recommendation to specific constraints in CONSTRAINTS or properties of CODE_CONTEXT]

### Notes for the decision owner

[Any caveats, follow-up questions, or things they should verify before acting]

## Anti-Patterns — What NOT to Do

**DO:**
- Read CODE_CONTEXT and CONSTRAINTS before generating options
- Give 2-3 distinct options, not 3 variations of the same option
- State the tradeoffs concretely (file count, type complexity, test surface, performance, future flexibility)
- Recommend with specific reasoning tied to the constraint set
- Stop and ask if the question is underspecified

**DON'T:**
- Modify code (you don't have that responsibility — that's the implementer's job)
- Write tests (same — that's the implementer's job)
- Hedge endlessly with "it depends" without specifying *what* it depends on
- Invent a third option just to fill the slot — two options is fine if there are only two
- Recommend without giving reasoning grounded in CONSTRAINTS or CODE_CONTEXT
- Restate the question back as your recommendation (a recommendation must commit to a specific direction)
```

- [ ] **Step 2: Verify the file**

Run: `head -10 /Users/marcin/Projects/superpowers/agents/architect.md`
Expected: frontmatter through line 7, role statement on line 9.

- [ ] **Step 3: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add agents/architect.md
git commit -m "$(cat <<'EOF'
feat(agents): add architect agent for non-interactive design consultation

Fresh content — no source template. Inputs: QUESTION + CODE_CONTEXT +
CONSTRAINTS + PRIOR_ATTEMPTS + DECISION_OWNER. Output: 2-3 options with
tradeoffs and a recommendation. Explicitly does NOT modify code or write
tests; the decision owner acts on the recommendation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Write structural test for `architect`

**Files:**
- Create: `/Users/marcin/Projects/superpowers/tests/architect/test-structure.sh`
- Create: `/Users/marcin/Projects/superpowers/tests/architect/fixtures/pure-design-q.md`

- [ ] **Step 1: Create fixtures directory and a happy-path fixture**

```bash
mkdir -p /Users/marcin/Projects/superpowers/tests/architect/fixtures
```

Write to `/Users/marcin/Projects/superpowers/tests/architect/fixtures/pure-design-q.md`:

```markdown
# Fixture: pure design question — column vs JSON

## QUESTION

We're adding a `metadata` field to the `Order` model that holds 5-10 user-supplied key/value pairs. Should it be a `JSONB` column on `orders`, or a separate `OrderMetadata` table with `(order_id, key, value)` rows?

## CODE_CONTEXT

```python
# apps/api/app/models/order.py
class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(primary_key=True)
    org_id: Mapped[int] = mapped_column(ForeignKey("orgs.id"), nullable=False)
    total_cents: Mapped[int] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
```

## CONSTRAINTS

- Postgres 15+
- We rarely query metadata (read-mostly during order display, never indexed)
- We never aggregate across orders' metadata
- Schema is in Alembic — adding a JSONB column is a single migration; adding a table is two migrations (add table, then start writing)

## PRIOR_ATTEMPTS

None — this is greenfield.

## DECISION_OWNER

implementer for Task 3

## EXPECTED RESPONSE SHAPE

Two clearly-distinct options (Option A: JSONB column, Option B: separate table — possibly Option C: hstore or a typed sub-table for special fields). Each with Buys/Costs/Right-when. A recommendation that picks one specifically based on the constraints (read-mostly, no aggregation → Option A is the obvious fit). Reasoning tied to those constraints.
```

- [ ] **Step 2: Write the structural test**

Write to `/Users/marcin/Projects/superpowers/tests/architect/test-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural test for architect agent.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/architect.md"
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
echo " architect: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/architect.md"
assert_grep "$AGENT" '^name: architect$' "frontmatter: name=architect"
assert_grep "$AGENT" '^color: blue$' "frontmatter: color=blue"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: max$' "frontmatter: effort=max"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## When You.re in Over Your Head' "section: escalation"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"

# Required per-call context fields
assert_grep "$AGENT" 'QUESTION' "context field: QUESTION"
assert_grep "$AGENT" 'CODE_CONTEXT' "context field: CODE_CONTEXT"
assert_grep "$AGENT" 'CONSTRAINTS' "context field: CONSTRAINTS"
assert_grep "$AGENT" 'PRIOR_ATTEMPTS' "context field: PRIOR_ATTEMPTS"
assert_grep "$AGENT" 'DECISION_OWNER' "context field: DECISION_OWNER"

# Output structure
assert_grep "$AGENT" '### Options' "output: Options"
assert_grep "$AGENT" '### Recommendation' "output: Recommendation"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "status: NEEDS_CONTEXT"
assert_grep "$AGENT" 'NEEDS_RESCOPE' "status: NEEDS_RESCOPE"

# Anti-pattern: must say NOT to modify code
assert_grep "$AGENT" '[Dd]o NOT modify code|don.t modify code|does NOT modify code|Modify code' "anti-pattern: does not modify code"

# Fixture presence
assert_file "$FIX/pure-design-q.md" "fixture: pure-design-q.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

- [ ] **Step 3: Make executable and run**

```bash
chmod +x /Users/marcin/Projects/superpowers/tests/architect/test-structure.sh
bash /Users/marcin/Projects/superpowers/tests/architect/test-structure.sh
```

Expected: all assertions pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add tests/architect/
git commit -m "$(cat <<'EOF'
test(architect): structural test + happy-path fixture

Pure-grep checks for envelope, per-call context fields, and the
"does NOT modify code" anti-pattern guard. One fixture covers a
column-vs-JSON design question; refactor-q and ambiguous-q
fixtures are follow-up work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Update implementer agents and SDD skill for architectural-escalation handling; wire test

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/agents/implementer-default.md`
- Modify: `/Users/marcin/Projects/superpowers/agents/implementer-fastapi.md`
- Modify: `/Users/marcin/Projects/superpowers/agents/implementer-expo.md`
- Modify: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`

- [ ] **Step 1: Update each implementer agent's "When You're in Over Your Head" section**

Each of the three implementer files has a "When You're in Over Your Head" section ending with a "How to escalate" paragraph. Add the following paragraph immediately after the existing "How to escalate" paragraph in each file:

```markdown
**Architectural blockers specifically:** If the blocker is "the task requires architectural decisions with multiple valid approaches" (the first STOP-and-escalate condition above), include in your BLOCKED report the explicit text `BLOCKED:ARCHITECTURAL` on a line by itself, plus a one-paragraph framing of the question. The orchestrator will dispatch the `architect` agent with your question, then re-dispatch you with the architect's recommendation included as additional CONTEXT.
```

Apply this edit to:
- `agents/implementer-default.md`
- `agents/implementer-fastapi.md`
- `agents/implementer-expo.md`

- [ ] **Step 2: Verify the same paragraph is in all three files**

```bash
grep -l 'BLOCKED:ARCHITECTURAL' /Users/marcin/Projects/superpowers/agents/implementer-*.md | wc -l
```

Expected output: `3`

- [ ] **Step 3: Update `subagent-driven-development/SKILL.md` to handle BLOCKED:ARCHITECTURAL**

In `skills/subagent-driven-development/SKILL.md`, find the "Handling Implementer Status" section. After the existing "BLOCKED:" bullet (which describes the four ways to handle BLOCKED), add a new subsection:

````markdown
### Architectural Escalation (BLOCKED:ARCHITECTURAL)

When an implementer reports BLOCKED with the literal text `BLOCKED:ARCHITECTURAL` on a line by itself, the blocker is a design question with multiple valid answers. The implementer's report includes a one-paragraph framing of the question.

Handle this differently from generic BLOCKED:

1. **Read the implementer's question framing.** It should be specific and scoped. If it's vague, that's a separate problem — surface to human.

2. **Dispatch the architect agent** to get a recommendation:

   ```
   Task(
     subagent_type=architect,
     description="Architectural consultation for Task N",
     prompt=<per-call context block below>
   )
   ```

   Per-call block:

   ```
   QUESTION: <the implementer's question framing>
   CODE_CONTEXT: <the relevant file contents or excerpts the implementer was working with>
   CONSTRAINTS: <project conventions and constraints; pull from the plan and existing patterns>
   PRIOR_ATTEMPTS: <what the implementer tried or considered>
   DECISION_OWNER: implementer for Task N
   ```

3. **Wait for the architect's recommendation.**

4. **Re-dispatch the same implementer agent** for the same task. Append the architect's full report (Options + Recommendation + Reasoning) to the original CONTEXT field, prefixed with "## Architect's Recommendation". The implementer now has a specific direction to implement.

5. **Re-enter the normal flow** — implementer reports DONE, dispatch reviewer-spec, then reviewer-code-quality.

If the architect returns NEEDS_CONTEXT or NEEDS_RESCOPE, treat the situation as an escalation to the human — the question wasn't answerable from what was provided, and another agent dispatch won't fix it.
````

- [ ] **Step 4: Wire architect test into the runner**

In `/Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh`, append `"../architect/test-structure.sh"` to the `tests=(...)` array:

```bash
tests=(
    "test-subagent-driven-development.sh"
    "../multi-angle-review/test-structure.sh"
    "../reviewer-spec/test-structure.sh"
    "../reviewer-code-quality/test-structure.sh"
    "../planner/test-structure.sh"
    "../architect/test-structure.sh"
)
```

- [ ] **Step 5: Run the full test suite**

```bash
bash /Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh
```

Expected: all six tests in the array pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add agents/implementer-default.md \
        agents/implementer-fastapi.md \
        agents/implementer-expo.md \
        skills/subagent-driven-development/SKILL.md \
        tests/claude-code/run-skill-tests.sh
git commit -m "$(cat <<'EOF'
feat: BLOCKED:ARCHITECTURAL escalation path to architect agent

Each implementer escalates architectural blockers with a literal
BLOCKED:ARCHITECTURAL line plus a question framing. SDD orchestrator
dispatches the architect agent, then re-dispatches the implementer
with the recommendation in CONTEXT.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase E — README and final cleanup

### Task 13: Create `agents/README.md`

**Files:**
- Create: `/Users/marcin/Projects/superpowers/agents/README.md`

- [ ] **Step 1: Write the README**

Write to `/Users/marcin/Projects/superpowers/agents/README.md`:

````markdown
# Agents

Plugin-shipped agents dispatched via `Task(subagent_type=<agent-name>, prompt=<per-call context block>)`. The subagent's system prompt holds the canonical role-specific knowledge; consuming skills are thin dispatchers that build the per-call context block.

## Agent families

| Family | Naming | Color | Role |
|---|---|---|---|
| Implementer | `implementer-<stack>` | warm (pink, orange, yellow) | Writes code + tests for one task |
| Reviewer | `reviewer-<concern>` | red | Reads code, returns verdict + findings |
| Designer | `planner` / `architect` | cool (green, blue) | Produces plans or design recommendations |

## Frontmatter contract

Every agent file has frontmatter with: `name`, `description`, `color`, `model`, `effort`.

The `name` MUST equal the filename minus `.md` — that's the `subagent_type` lookup key. A mismatch means the agent is undiscoverable.

`color` follows the family convention above. `model` is `opus` for all current agents. `effort` is one of: `xhigh` (mechanical or rules-driven work) or `max` (high-judgment generative work).

## System prompt envelope

Every agent follows the same nine-section structure:

1. Frontmatter
2. Role statement (single paragraph)
3. Per-Call Context (labeled fields the dispatcher must populate)
4. Before You Begin
5. Your Job
6. Role-specific guidance (the meaty middle — varies by agent)
7. When You're in Over Your Head (escalation)
8. Self-review (where applicable — implementers and planner have it; reviewers and architect generally don't)
9. Anti-Patterns + Report Format

Reviewers add a `Severity Rules` subsection (Critical / Important / Suggestion) and an `Output Format` block with a verdict line at the end.

## Per-call context contract

Every dispatcher MUST populate every field in the agent's per-call context block before calling. A missing field would cause the agent to hallucinate output on empty context. Verify before dispatch.

## Per-call context fields by agent

| Agent | Per-call fields |
|---|---|
| `implementer-default` / `implementer-fastapi` / `implementer-expo` | TASK_NUMBER, TASK_NAME, TASK_DESCRIPTION, CONTEXT, WORKING_DIRECTORY |
| `reviewer-spec` | TASK_NUMBER, TASK_NAME, TASK_REQUIREMENTS, IMPLEMENTER_REPORT, FILES_TO_REVIEW |
| `reviewer-code-quality` | SCOPE, DESCRIPTION, PLAN_OR_REQUIREMENTS, BASE_SHA, HEAD_SHA |
| `reviewer-security` / `reviewer-multitenant-isolation` / `reviewer-migration-safety` | DESCRIPTION, PLAN_OR_REQUIREMENTS, FILES_TO_REVIEW |
| `planner` | SPEC_PATH, WORKING_DIRECTORY, PROJECT_CONTEXT, CONSTRAINTS |
| `architect` | QUESTION, CODE_CONTEXT, CONSTRAINTS, PRIOR_ATTEMPTS, DECISION_OWNER |

## Adding a new agent

1. **Write the agent body**, following an existing agent in the same family as a template.
2. **If routing logic is needed** (multiple variants), add a row to the relevant dispatching skill (`dispatching-domain-agents` for implementers, `multi-angle-review` for reviewers). Single-variant designers (`planner`, `architect`) don't need a routing skill.
3. **Add a fixture-based test** under `tests/<agent-name>/`. Pure-grep `test-structure.sh` is required; integration test is encouraged but optional.
4. **Wire the structural test** into `tests/claude-code/run-skill-tests.sh` — append the path to the `tests=(...)` array.
5. **Pressure-test RED → GREEN** if the agent has any nontrivial role-specific guidance.
6. **Commit fixture + agent + skill change + README row update + runner update** together.

## Dispatch model

The dispatch model is uniform across families:

```
Task(
  subagent_type=<bare agent name, e.g. "reviewer-spec">,
  description=<one-line description for tooling>,
  prompt=<the structured per-call context block as plain text>
)
```

`subagent_type=general-purpose` is reserved for ad-hoc Explore-style searches that don't fit a role. Role-bearing calls always use a named agent.

## Files in this directory

| File | Purpose |
|---|---|
| `implementer-default.md` | Mixed-path / fallback implementer |
| `implementer-fastapi.md` | `apps/api/**` implementer (FastAPI / SQLAlchemy 2.0 / Alembic / Pydantic v2) |
| `implementer-expo.md` | `apps/mobile/**` implementer (Expo / expo-router / Hermes / MobileMCP) |
| `reviewer-spec.md` | Per-task spec compliance |
| `reviewer-code-quality.md` | Per-task and whole-branch code quality |
| `reviewer-security.md` | Security defects (FastAPI + SQLAlchemy) |
| `reviewer-multitenant-isolation.md` | Tenant boundary correctness |
| `reviewer-migration-safety.md` | Production-safe Alembic migrations |
| `planner.md` | Spec → plan |
| `architect.md` | Design consultation |
````

- [ ] **Step 2: Verify the README**

```bash
wc -l /Users/marcin/Projects/superpowers/agents/README.md
```

Expected: ~80-100 lines.

- [ ] **Step 3: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git add agents/README.md
git commit -m "$(cat <<'EOF'
docs(agents): README documenting families, frontmatter, dispatch contract

Codifies the conventions implicit in the existing agents and the four new
ones — agent families and their colors, frontmatter contract, the nine-
section envelope, per-call fields by agent, dispatch model, and the
process for adding new agents.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Final cleanup — delete `implementer-prompt.md`; final verification

**Files:**
- Delete: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/implementer-prompt.md`

- [ ] **Step 1: Confirm `implementer-prompt.md` is no longer referenced anywhere**

```bash
grep -rn "implementer-prompt.md" /Users/marcin/Projects/superpowers/skills/ /Users/marcin/Projects/superpowers/agents/ /Users/marcin/Projects/superpowers/tests/ 2>/dev/null
```

Expected: no output (no remaining references).

If references remain, fix them before deleting.

- [ ] **Step 2: Delete the file**

```bash
cd /Users/marcin/Projects/superpowers
git rm skills/subagent-driven-development/implementer-prompt.md
```

- [ ] **Step 3: Run the full test suite one final time**

```bash
bash /Users/marcin/Projects/superpowers/tests/claude-code/run-skill-tests.sh
```

Expected: all six structural tests pass.

- [ ] **Step 4: Confirm the agent set is at 10 files**

```bash
ls /Users/marcin/Projects/superpowers/agents/*.md | wc -l
```

Expected output: `10` (the 10 agents — README.md is also in the directory but matches the glob, so this should actually show `11`. If 11, that's correct: 10 agents + README.)

If the count is unexpected, list:

```bash
ls /Users/marcin/Projects/superpowers/agents/*.md
```

Verify all 10 agents and the README are present.

- [ ] **Step 5: Confirm no orphaned prompt-template files remain**

```bash
find /Users/marcin/Projects/superpowers/skills -name '*prompt*.md' -o -name 'code-reviewer.md'
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
cd /Users/marcin/Projects/superpowers
git commit -m "$(cat <<'EOF'
chore: remove orphan implementer-prompt.md from subagent-driven-development

Final cleanup after the agent-set extension. Implementer logic lives in
agents/implementer-{default,fastapi,expo}.md; the skill orchestrates
dispatch by name. The plugin's agent set is now: 3 implementers, 5
reviewers, 2 designers (10 total).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Deferred Follow-Up (out of scope for this plan)

The original spec called for both structural tests AND integration tests for each new agent, mirroring `tests/multi-angle-review/`. This plan delivers structural tests only — same gate as 11 of the 13 existing skills/agents in the repo. Integration tests are tracked as a separate, follow-up plan because:

- Integration tests use `claude -p` (CLI), are slow (10–30 min per test), and are opt-in via `--integration` flag.
- Each meaningful integration test needs at least 2 fixtures (RED bug + GREEN clean) plus a test script — substantial work per agent.
- The structural test is the daily-development gate; integration is validation that the agent's prompt produces the right output, valuable but separable.

A follow-up plan should add for each of `reviewer-spec`, `reviewer-code-quality`, `planner`, `architect`:

- A second fixture: the unhappy-path / RED case (for reviewers: a fixture that should produce a "found issues" verdict; for planner: a too-large-spec fixture; for architect: an underspecified-question fixture).
- `test-integration.sh` mirroring `tests/multi-angle-review/test-integration.sh` (~80–150 lines per agent).
- Wire each into the runner's `integration_tests=(...)` array.
- RED→GREEN pressure-testing iteration on the agent body if the integration test exposes prompt weaknesses.

## Verification Checklist (post-execution)

Run after Task 14 to confirm the end-state matches the spec.

- [ ] All 10 agent files exist: `ls agents/*.md` → 10 agents + README.md
- [ ] No orphan prompt templates: `find skills -name '*prompt*.md' -o -name 'code-reviewer.md'` → empty
- [ ] All structural tests pass: `bash tests/claude-code/run-skill-tests.sh` → STATUS: PASSED
- [ ] Skill files mention the new dispatch pattern: `grep -l 'subagent_type=reviewer-spec\|subagent_type=reviewer-code-quality\|subagent_type=planner\|subagent_type=architect' skills/**/*.md` → at least 4 matches
- [ ] Each implementer has the architectural-escalation paragraph: `grep -c 'BLOCKED:ARCHITECTURAL' agents/implementer-*.md` → all three return 1
- [ ] `agents/README.md` documents all 10 agents in the per-call-fields table
