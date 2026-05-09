# Superpowers (personal fork)

Personal Claude-Code-only fork of [obra/superpowers](https://github.com/obra/superpowers). Same skills, slimmer surface area: one harness, no marketplace publishing, no upstream merge concerns.

## What it is

A complete software development methodology for Claude Code, built on a set of composable skills and a session-start hook that bootstraps them into every session.

It starts from the moment you fire up Claude Code. As soon as it sees you're building something, it doesn't jump into writing code — it steps back, asks what you're really trying to do, teases a spec out of the conversation, and shows it to you in chunks. Once you've signed off, it puts together an implementation plan that's clear enough for an enthusiastic junior engineer with no project context to follow. Then, on "go", it launches a subagent-driven-development process with two-stage review.

The skills trigger automatically. You don't do anything special.

## Installation

This fork is set up as a local Claude Code plugin marketplace.

```bash
/plugin marketplace add /Users/marcin/Projects/superpowers
/plugin install superpowers@superpowers-personal
```

(Or point at a remote git URL if you push it somewhere.)

## The Basic Workflow

1. **brainstorming** — refines rough ideas through questions, presents design in sections for validation.
2. **using-git-worktrees** — creates isolated workspace on a new branch.
3. **writing-plans** — breaks work into bite-sized tasks (2-5 minutes each).
4. **subagent-driven-development** or **executing-plans** — dispatches fresh subagent per task with two-stage review, or executes in batches with checkpoints.
5. **test-driven-development** — RED-GREEN-REFACTOR; deletes code written before tests.
6. **requesting-code-review** — reviews against plan, reports issues by severity.
7. **finishing-a-development-branch** — verifies tests, presents merge/PR/keep/discard options.

## What's Inside

**Testing** — test-driven-development.

**Debugging** — systematic-debugging, verification-before-completion.

**Collaboration** — brainstorming, writing-plans, executing-plans, dispatching-parallel-agents, requesting-code-review, receiving-code-review, using-git-worktrees, finishing-a-development-branch, subagent-driven-development.

**Meta** — writing-skills, using-superpowers.

## Philosophy

- **Test-Driven Development** — Write tests first, always
- **Systematic over ad-hoc** — Process over guessing
- **Complexity reduction** — Simplicity as primary goal
- **Evidence over claims** — Verify before declaring success

## License

MIT — see LICENSE.

## Credits

Built on [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent and Prime Radiant. This fork strips harness-specific code paths for personal use; the skill content is theirs.
