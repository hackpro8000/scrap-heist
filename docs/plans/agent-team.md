# Agent team

Status: design, shaped in conversation on 2026-11-11. The first version is built, uncommitted: the fixed core and playbook in `docs/team/`, the role definitions in `.claude/agents/`, and `scripts/agent-stats.sh` and `scripts/agent-watch.sh`. Not yet piloted on real work. The measurements behind it are in `agent-team-findings.md`.

## Goal

A team of agents for general game development that is fast, puts out high volume, keeps quality and stays efficient, on simple tasks and on the hardest and longest ones. It changes its own shape, rules and workflow whenever that serves the goal.

## First principle

The team always looks for a faster way to do its work, and never accepts one that lowers quality.

- Every agent notices waste in its own work and says so.
- A faster method is kept only if the result passes the same checks as before.
- Every task ends with "what would have made this faster?", and the answer goes into the playbook.
- Speed is measured per finished, passing item. Work that has to be redone counts as slow.

## Two layers

**Fixed core. Only the user changes it.**
- The goals above.
- The user's limits: spending, what gets pushed or published, anything that changes the game's look or design.
- The scoring: how results are measured, and the rule that a fresh checker who did not do the work decides a pass.
- The decision rule and the observer's rules, below.

**Playbook. The team owns and rewrites it.**
- Roles, team size, which model does what, workflow steps, checks, domain packs, brief templates, recipes and the rules themselves.
- It is a file in the repo, so every change is visible and reversible.

## Who decides what

| Kind of question | Who decides |
|---|---|
| Objective: a test, measurement or check can settle it | The team, automatically. This includes calling the strongest model. |
| Subjective: look, feel, style, game design, naming, tone | The user. |
| Subjective, and the user is away | The team decides and keeps the decision easy to reverse. |

- If two reasonable people could look at the same evidence and still disagree, it is subjective. When unsure, treat it as subjective.
- A choice made while the user is away keeps its alternatives, sits in one setting or its own commit, and has the work built on it tagged. The user gets one "Decided while you were away" list and can change any entry in one step.

## Roles

| Role | Model | Job |
|---|---|---|
| Lead (main session) | Opus 5.5 | Triages each task, does the cheap search, writes the setup and the briefs, merges results, talks to the user. Does small work itself. |
| Worker, routine | Sonnet 5.5 | Data tables, variants, mechanical changes. |
| Worker, difficult | Opus 5.5 | New systems, shared code, design. |
| Specialist | Fable 5.2 | Called for one hard piece: an escalation after Opus fails twice, an unknown-cause problem, a decision everything else builds on, a close call between approaches, or breaking a strong result. |
| Observer | Sonnet 5.5, plus scripts | Watches agents while they work. |
| Checker | Sonnet 5.5; Opus 5.5 on hard tasks | Judges the finished result with a fresh context. |
| Scout | Haiku 5.5 | Lookups, builds, logs, bulk clean-up. |

- A worker is a generalist that becomes a specialist through its brief and one short domain pack.
- Anything a script can verify stays a script.
- Effort level is the first dial: lower it for routine work before changing model, raise it before escalating.
- The assignment lives in the playbook. Sonnet moves to Opus after two failed checks, Opus to Fable after two more, and a recipe that keeps passing on Opus is tried on Sonnet.

## Shape

The Lead writes a short setup for each task: which roles, how many, which models, what order, and the pass bar. It may invent a role or workflow the playbook does not have. Starting points:

| Task | Starting shape |
|---|---|
| Trivial | The Lead does it. No agents. |
| Standard | One worker, the scripts, one checker. |
| Bulk | One plan and one approval for the batch, parallel workers in their own worktrees, one side-by-side audit. |
| Hard | Measure first and write the pass bar; two or three workers try different approaches on small samples; a fresh checker tries to break the winner. |
| Long | Milestones that each have a check, with progress in a state file any session can pick up. |

The shape changes mid-task when the evidence calls for it: a single worker can become a swarm of scouts and collapse back, builders can turn into designers when the design has a gap, a wide team can drop to one agent to settle a shared piece, and a team split by item can regroup by stage. When a setup stops fitting, the Lead replaces it. An agent changes role by loading a new brief and pack, keeping what it has read.

Signals that trigger a reshape: a check failing twice, workers waiting on builds or merges, workers colliding on the same files, and a task turning out bigger or different.

## Learning

- **Wins.** When a task beats its estimate and passes, the team keeps the setup, writes one line on why, and saves it as a recipe. A recipe is "unproven" until it holds on two or three more tasks, then it is the default and the estimate tightens to it.
- **Misses.** A defect the user catches that the checker passed becomes a check or a rule.
- **Repeats.** Any action that recurs, however small, is named on its second occurrence and replaced by its third: a script, a template, a saved recipe or a batched step. The replacement is checked once against the old way. The saving is recorded.
- **Rule changes.** A rule slowing one task can be suspended for that task, with the reason logged. A permanent change needs numbers, is watched over the next few tasks and is reverted if they get worse. Rules that never fire are pruned.

## The observer

It watches each agent while it works, by reading the new part of its transcript and its diff.

- **Looks for:** drift from the brief, stalls and loops, rule breaks, waste, repeats, and wins while the evidence is fresh.
- **Looks when:** on events (a failed check, a long silence, a budget milestone, an edit outside the agent's lane), with a slow timer as fallback. New or risky work is checked more often.
- **Can:** note, nudge the agent, pause it and call the Lead, or stop it and notify the user for a hard-limit breach.
- **Never:** does the work or changes rules.
- Its own record is tracked: how many flags were real, and what it missed.

## Keeping the team in check

1. **Tooling the team cannot edit.** Hooks and permissions block pushing, publishing, deleting and spending. The fixed core, the scoring scripts and the hooks are read-only to the team. Budget caps stop a task.
2. **The observer**, during the work.
3. **A fresh checker** on the finished result, against a pass bar written before work started.
4. **The user's spot checks**, the one check the team cannot predict or tune itself to pass.

## Delegation rules, from the measurements

1. Every role has its own narrow agent type. Tool lists come only from definition files.
2. The Lead finds the location and hands over file and line.
3. Briefs carry a standard block: work in as few steps as possible, run independent actions together, stay in the named files, final message is the report in N lines, stop when the pass bar is met.
4. Start same-model agents in bursts so they share the start-up cache.
5. Send follow-ups within five minutes, or start a fresh narrow agent.
6. Don't delegate what the Lead can do in a step or two. The floor is about 3 seconds and 9,000 tokens.
7. A new agent type is created by writing its definition file and waiting about a minute.
8. Noisy bulk work, such as archiving many sessions, goes to one Haiku scout.
9. Subagents suit short pieces. Cloud sessions suit long-lived workers and heavy jobs: their start-up is negligible on a ten-minute task, each brings its own machine, and their cache lasts an hour.

## Compute

The team actively looks for more computing power that costs nothing extra, in this order:

1. **Capacity running but idle:** the three idle cores during stroke laying, shards that finish early, standby machines between builds.
2. **Free capacity not yet used:** cloud session machines.
3. **Needing less:** skip unchanged work, predict before building.

The team never creates accounts or signs up for anything, stays inside each service's terms, asks before anything that could start billing, and uses a new source only if the output is identical on the sample set.

### Cloud machines as build workers

The user's idea: cloud session machines join the build coordinator directly, so jobs flow machine to machine with no agent prompts. Measured so far: 25 machines at once, 100 cores busy together, start-up under a second, and a machine can be started with no prompt and no tokens. What it still needs:

1. A stable public address for the coordinator. (User: the Tailscale tunnel points at a dead port.)
2. That address allowed in a cloud environment. (User, in Claude settings.)
3. A way for a cloud worker to prove itself to the coordinator, which today admits only GitHub machines. (Code change; the user picks the method.)
4. Something that starts the worker on each machine: a starting prompt, or the environment's setup script, which is untested.
5. Something that keeps a working machine from pausing.

## Open decisions

1. Rule changes: applied and reported, or asked first? (The decision rule above would settle it: objective ones automatic, subjective ones asked.)
2. Do the existing rules in the two `CLAUDE.md` files and `docs/art/pipeline.md` move into the playbook, or stay fixed? (Settled 2026-11-11: they stay fixed, and the user removed the global file's delegation rule; the playbook now governs delegation.)
3. A ceiling on parallel workers or cost.
4. How long the team waits before treating the user as away. Suggested: 10 minutes when work is blocked on the answer.
5. Whether the team may add agent definitions freely, or only uncommitted until approved.
6. How a cloud worker identifies itself to the coordinator.

## Next

- The untested items listed at the end of `agent-team-findings.md`.
- Write the playbook file, the role definitions and the first domain packs.
- Pilot on one small batch.
