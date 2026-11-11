# Team playbook

The team owns this file and rewrites it as it learns (rules for that are in `core.md`, which it cannot change). The Lead is the main session.

## Roles

| Role | Agent type | Model | Job |
|---|---|---|---|
| Lead | main session | Opus 5.5 | Triage, the cheap search, the setup and briefs, merging, talking to the user. Does small work itself. |
| Worker, routine | `worker` | Sonnet 5.5 | Data tables, variants, mechanical changes. |
| Worker, difficult | `worker-hard` | Opus 5.5 | New systems, shared code, design-heavy changes. |
| Specialist | `specialist` | Fable 5.2 | One hard, objective piece (see "Escalation"). |
| Observer | `observer` | Sonnet 5.5 | Looks at agents in motion when `scripts/agent-watch.sh` flags one, or on risky work. |
| Checker | `checker` | Sonnet 5.5; Opus 5.5 on hard tasks | Judges the finished result with a fresh context. |
| Scout | `scout` | Haiku 5.5 | Lookups, builds, logs, bulk clean-up. |

- A worker becomes a specialist in a domain through its brief and one pack from `packs/`.
- Model work keeps its own agents and rules (`model-critic`, `model-previewer`, `docs/art/pipeline.md`).
- A new role is a new file in `.claude/agents/`; it is callable about a minute later. New definitions stay uncommitted until the user approves them.
- Anything a script can verify stays a script.

## Every task

1. **Triage.** Pick a shape below. Write the pass bar: the commands or checks that decide "done".
2. **Search.** The Lead finds the files and lines (`rg`), so no agent explores.
3. **Setup.** One or two lines: roles, how many, models, order. Estimate the time.
4. **Run.** Briefs from the template. Agents in the background, with `scripts/agent-watch.sh --until-flag` running beside them.
5. **Check.** Scripts first, then a `checker` for anything a script can't decide.
6. **Close.** `scripts/agent-stats.sh` for the numbers. One line in `log.md`: shape, time against estimate, what would have made it faster. A win becomes a recipe; a repeat gets named.

## Shapes

| Task | Starting shape |
|---|---|
| Trivial (a step or two) | The Lead does it. No agents. |
| Standard | One worker, the scripts, one checker. |
| Bulk | One plan for the batch, parallel workers each owning its own files, one side-by-side check at the end. |
| Hard | Measure first; two or three workers try different approaches on small samples; a fresh checker tries to break the winner. |
| Long | Milestones that each have a check, with progress in a state file any session can pick up. |

Reshape mid-task when: a check fails twice, workers wait on builds or merges, two workers touch the same file, or the task turns out bigger or different. The Lead writes the new setup in one line and carries on.

## Parallel work

- Every file has one owner per task. Shared files (types, config tables) are settled by one agent first, then the wide team builds on them.
- Results are additive: each worker returns pieces nobody else produced. Nothing is reconciled by hand.
- Start same-model agents in one burst so they share the start-up cache.
- Send a follow-up within 5 minutes, or start a fresh narrow agent.

## Brief template

```
Task: <one sentence>
Where: <file:line, file:line>
Pack: <docs/team/packs/x.md, or none>
Pass bar: <command(s) that must pass>
Lane: <files you may edit>
Budget: <steps or tokens>
Report: <N lines: what changed (file:line), the check's last output, one line on waste>
```

The agent definitions already carry the standing rules (few steps, parallel actions, stay in lane, report only), so a brief does not repeat them.

## Escalation

- Lower the effort level for routine work before changing model; raise it before escalating.
- `worker` fails its pass bar twice: the piece goes to `worker-hard` with what was tried.
- `worker-hard` fails twice: it goes to `specialist`.
- The specialist is also called directly for a problem with an unknown cause, a decision everything else builds on, a close call between approaches, or breaking a strong result.
- A recipe that keeps passing on Opus is tried on Sonnet.

## Watching

- `scripts/agent-watch.sh --until-flag --lane '<regex>'` runs in the background whenever agents do. It ends at the first STALL, LOOP, BUDGET or LANE flag.
- On a flag the Lead looks at the row. Clear cases it handles itself (a nudge by SendMessage, or a stop). Unclear ones, and any new or risky work, go to the `observer` with the briefs and log paths.
- Observer verdicts and whether they were right go in `log.md`.

## Learning

- **Wins.** A task that beats its estimate and passes: keep the setup, write why in one line, save it in `recipes.md` as unproven. After it holds on two more tasks it is the default and the estimate tightens to it.
- **Misses.** A defect the user catches that the checker passed becomes a check or a rule here.
- **Repeats.** An action that recurs is named in `log.md` on its second occurrence and replaced by its third: a script, a template, a recipe or a batched step, checked once against the old way.
- **Rules.** A rule slowing one task may be suspended for that task with the reason logged. Rules that never fire are pruned.

## Delegation numbers

From `docs/plans/agent-team-findings.md`; update them when new measurements say so.

- Any agent costs about 3 seconds and 9,000 tokens before it does anything. Work the Lead can do in a step or two stays with the Lead.
- A narrow tool list is worth about 9 times fewer tokens; exact pointers are worth about 4 times less time.
- Never use `general-purpose` for team work: it loads about 77,000 tokens.
