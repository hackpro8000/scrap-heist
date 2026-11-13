# Agent team: what was measured

Status: measurements from 2026-11-11, taken while planning `agent-team.md`. Every number is a single sample unless it says otherwise, so a gap of a second or two is noise. Costs are estimates at API list rates (table dated 2026-10-06); on a subscription the same ratios apply to usage limits.

Times and tokens for subagents come from each agent's own log, read with `scripts/agent-stats.sh`, so the main session's reaction time is not in them.

## 1. Starting a subagent

A one-word "hello" on each model.

| Agent type | Tokens loaded before any work | Time to a hello |
|---|---|---|
| `general-purpose` (all tools) | about 77,500 | 3.0–6.6 s |
| `minimal-reader` (Read only) | about 7,400 | 2.9–3.3 s |
| `worker` (Read, Edit, Grep, Glob, Bash) | about 9,000 | 2.9 s |

- The token load is the same on Haiku, Sonnet, Opus and Fable 5.2. It is mostly tool definitions and rules.
- Model choice does not change start-up time. The floor is about 3 s: setup about 0.7 s, one model call 1.5–2 s, hand-back about 0.7 s.
- A cold all-tools start costs about 1 cent on Haiku, 20 cents on Sonnet, 40 cents on Opus and about a dollar on a Fable-tier model. A cold `worker` start on Opus is about 4 cents.
- Agents on the same model started within 5 minutes share the start-up cache: 62,400 of 77,500 tokens were read from cache.
- A brief saying "finish in one step, no text before the report" took Haiku from two model calls to one (6.6 s to 4.9 s). The larger models already used one.
- The Agent tool's `fable` option resolves to `claude-fable-5-2`.
- The session allows 20 subagents at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`).

## 2. A small lookup: brief and tool list

Task: find two functions and answer four questions about them. Three set-ups on Haiku, Sonnet and Opus.

| Set-up | Time | Model calls | Tokens processed | Correct |
|---|---|---|---|---|
| One-sentence brief, all tools | 31–37 s | 6–9 | 525k–760k | 2 of 3 |
| Exact files and lines, "one step", 6-line report, all tools | 7–10 s | 2–3 | 160k–240k | 3 of 3 |
| Same tuned brief on `minimal-reader` | 7–8 s | 2 | about 17,600 | 3 of 3 |

- The brief sets the time (about 4 times faster) because it removes searching. The tool list sets the tokens (about 9 times fewer on top) because every step re-reads the agent's whole context.
- The plain brief cost accuracy on the small model: Haiku took the generated copies in `art/models` for the source of `chunkedPart` and missed `art/src/common.luau:728`.
- Plain-brief reports were three to six times longer.
- The pointers came from one `rg` by the main session, about a second of work.

## 3. Reusing an agent

A follow-up question to agents that had already read the file, against fresh agents.

| Set-up | Time | Model calls | Tokens at full price |
|---|---|---|---|
| Follow-up to a Read-only agent | 3.5–4.8 s | 1 | about 10,700 |
| Follow-up to an all-tools agent | 3.4–4.1 s | 1 | about 82,500 |
| Fresh `minimal-reader` | 4.5–6.7 s | 2 | about 7,750 |

- Reuse saves one step.
- The follow-ups went out about 6 minutes after the agents last ran, past the 5-minute cache, so each re-paid its whole context. A stale all-tools agent costs ten times a fresh narrow one.

## 4. A small edit

Task: fix two bugs in a 27-line Luau module so its test passes. All 13 runs passed, changed exactly two lines and left the test file alone (checked by running each test).

| Run | Time | Model calls | Tokens processed |
|---|---|---|---|
| Plain brief, all tools: Haiku / Sonnet / Opus | 18.6 / 16.6 / 13.2 s | 4 / 4 / 3 | 324k / 322k / 241k |
| Tuned brief, all tools: Haiku | 21.2 s | 3 | 243k |
| Tuned, all tools, Sonnet at low / medium / high effort | 16.8 / 13.4 / 13.5 s | 3 | about 241k |
| Tuned, all tools, Opus at low / medium / high effort | 12.2 / 10.0 / 13.3 s | 3 | about 241k |
| Tuned, `worker`: Haiku / Sonnet / Opus | 13.0 / 11.7 / 9.8 s | 3 | about 33k |

- The tuned brief barely helped here: the plain brief already named the directory and the test command.
- Effort level showed no effect. Thinking was 0–108 tokens at every level; the task was too easy to test it.
- Opus was fastest and Haiku slowest.
- `worker` did the same fix for about a seventh of the tokens, with equal or better time.

## 5. New agent types mid-session

- A new `.claude/agents/worker.md` was not callable for about the first minute ("Agent type 'worker' not found", twice), then appeared by itself. The app watches the agents folder; the docs say "within a few seconds".
- An early "not found" means "not yet".
- Tools cannot be set per call. The Agent tool takes a model and an effort level only, so a narrow tool list needs a definition file.
- Reported by a docs lookup and not checked further: inline agent definitions exist only at launch (`claude --agents`, or the Agent SDK's `agents` option); a restart is still needed when the agents folder did not exist at session start.

## 6. Cloud sessions

This session runs on the user's own computer (bridge environment "Death-Machine": AMD Athlon 200GE, 2 cores / 4 threads, 29 GB, no Nvidia GPU). A cloud session gets its own machine.

### Start-up and cost

| Measure | Result |
|---|---|
| Machine allocated after creation | 0.7–0.8 s |
| Agent process started | under 0.1 s more (pre-warmed spare) |
| Cloning this repo | 23.7 s |
| First reply, no repo attached | about 4–6 s after creation |
| First reply, repo attached | about 30 s after creation |
| Tokens loaded on the first prompt | about 79,000 (59 tools), cached for 1 hour |
| Cost of a first prompt on Haiku | 0.4 cents with the shared cache, 1.6 cents cold |
| Cost of a later prompt on Haiku | about a quarter of a cent |

- **A session created with no prompt still starts its machine**, with no model call and zero tokens used.
- Nothing runs on that machine without a prompt. The only hook before the agent is the environment's setup script (start-up steps: provision, clone, setup_script, start_cc). Whether a process started there keeps running is untested.

### The machine

- 4 cores, 15 GB memory, 30 GB disk (docs: about 4 vCPUs and 16 GB), Ubuntu 24.04, running as root. The same size as a GitHub `ubuntu-24.04` runner.
- No separate charge for the machine (docs).
- It pauses after a few minutes without activity and may later be reclaimed; the next message restores it. Background commands keep running for up to 30 minutes after a turn (docs, not measured).
- Nothing can connect in: no SSH server, no inbound port. A worker has to dial out, and only to hosts the environment allows. The `Default` environment allows package registries and no extra hosts.
- Hashing benchmark (64 MB sha256 rounds per core per minute): cloud mean about 908, slowest machine about 742, fastest about 1,111. This computer: about 375 per thread. A GitHub runner has not been benchmarked.

### How many

| Test | Result |
|---|---|
| 25 requested by the main session, one command each | 23 created in 18 s and all ran; 2 requests failed with a dropped connection |
| 25 requested, each running 60 s on 4 cores | 25 of 25; all overlapped for about 41 s, so 100 cores were busy at once |
| 20 created by 20 subagents at once | create times within 4.5 s; all done 11.4 s after the first create |

- No cap on concurrent cloud sessions was hit at 25. The docs give no number.
- The main session's create calls go out one after another, about 0.75 s each.
- Fanning out through subagents did not help end to end (about 20 s either way): each agent needed about 8 s to start and reach its create call. Three of the 20 agents also created a duplicate session.
- Each test cost about 10 cents at API rates.

### Driving a cloud session

- The prompt given at creation is its task. Commands sent afterwards from the parent session with `send_message` were refused: the session said its user had not asked for them.
- A probe that combined reading machine facts with outbound requests to tunnel addresses was blocked by the cloud session's permission system as "Exfil Scouting". Machine facts alone ran without trouble.
- A cloud session does not report back when it finishes cleanly. Check it with `get_session` or `list_sessions` (the post-turn summary carries the result line).
- It sees only what is pushed to GitHub.
- `get_environment`, `create_environment` and `update_environment` do not work from this session, because it is not in a cloud environment. Environment changes are made in the user's Claude settings.
- `archive_session` returns about 900 tokens per call. One Haiku subagent archived 23 sessions and returned three lines.

### From the command line

- `claude --cloud "<text>" --model haiku` creates a cloud session and exits in about 6 s, printing the session id.
- It refuses without a terminal, so a script needs a pseudo-terminal (`script -qfc '...' /dev/null`), and it must start from a folder that is already trusted.
- It attaches the folder's repo and names an outcome branch.
- It cannot choose the cloud environment: `--environment` accepts only self-hosted `ccpool_...` ids. The one session made this way landed in the `google-classroom` environment.

### Terms

A docs lookup of the cloud-session pages and Anthropic's Consumer Terms, Commercial Terms and Usage Policy found no clause on general computing or hosting, and nothing on what the machine may be used for. The terms restrict automated access outside permitted means and "bypassing" systems, and say parallel sessions use rate limits proportionately. The quotes came through fetch summaries; re-check the wording before relying on it.

## 7. The build machines today

- 20 GitHub `ubuntu-24.04` runners, 4 cores and 16 GB each. The repo is public.
- GitHub's limits page: 20 concurrent jobs on Free, 40 on Pro, 60 on Team, 500 on Enterprise; 6 hours per job; 256 jobs per matrix.
- The coordinator listens on port 8765 and was up over a Cloudflare quick tunnel, whose address changes each start. It admits a machine only with GitHub's identity token for the standby workflow.
- The Tailscale public tunnel `death-machine.tail4967ce.ts.net:443` forwards to port 9876, where nothing listens.
- Idle capacity already paid for: stroke laying uses one core of four for about 35% of a cold map build, and two machines with equal work took 134 s and 271 s.

## 8. Model prices used for the estimates

Per million tokens, input / output, from a table dated 2026-10-06.

| Model | Price |
|---|---|
| Fable 5.1 | $10 / $50 |
| Opus 5.5 | $4 / $20 |
| Sonnet 5.5 | $2 / $10 |
| Haiku 5.5 | $0.10 / $0.50 |

Fable 5.2 is not in that table; it is assumed to be priced like 5.1.

## 9. Corrections made along the way

- "A new agent type needs a restart" was wrong. It loads after about a minute.
- "Keep-alive prompts will strain the usage limits" was wrong. Haiku prompts cost a fraction of a cent; the usage warnings came from the main session's own large context and its test agents.
- "Starting a cloud machine takes one prompt" was wrong. A session created with no prompt starts its machine for nothing.
- The concern that cloud machines as build workers might break the terms was an inference; the lookup found no rule against it.

## 10. Not yet tested

- Effort levels on a task hard enough to need thinking.
- Long or hard tasks; everything above was a small lookup or a two-line fix.
- Fable on real work.
- Repeat runs, to put error bars on any of this.
- A worker started from an environment setup script, and whether it survives.
- How long an idle cloud machine lasts, and whether a running worker counts as activity.
- More than 25 cloud machines, or load for longer than a minute.
- A GitHub runner on the same benchmark.
- A truly simultaneous start of many cloud sessions.
