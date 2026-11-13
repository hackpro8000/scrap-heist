# Team log

The team appends here. Newest entries at the bottom of each section.

## Decided while you were away

Subjective choices the team made without the user. Each keeps its alternatives and says how to change it. The user sees this list first on their return; an entry is removed once they confirm or change it.

| Date | Decision | Alternatives kept | How to change it |
|---|---|---|---|

## Tasks

One line per finished task: date, task, shape, time against estimate, what would have made it faster.

- 2026-11-11, smoke test (two-line fix in a scratch file): Standard shape, `worker` 11.6 s and 35k tokens, `checker` PASS; estimate 12 s. Faster next time: nothing found. Gap found: the worker edited from the shell, so the watch script saw no edited files; worker definitions now say to use Edit.
- 2026-11-11, multi-machine milestones 1a and 1b: Standard shape, `worker-hard` then `checker` (Opus for 1b), one fix round. Agent time about 14 minutes in all. Faster next time: test a new hook through the shell before any agent runs (lost one run); put the hook's grep/sed rule in definitions (done); check `gh secret list` before planning a route that needs a secret (1a could not be tested).

## Repeats

An action seen twice is named here; by the third time it is replaced.

| Action | Seen | Replaced by | Saving |
|---|---|---|---|
| The `jq` one-liner for agent time and tokens | many, 2026-11-11 | `scripts/agent-stats.sh` | one command, same numbers |
| Agents losing a step to the hook that blocks `grep`/`sed` | 3 agents, 2026-11-11 | one line in every agent definition | a step or two per agent |
| "N of M agents back" status messages | many, 2026-11-11 | one report per round | fewer turns |

## Rule changes

Date, the change, the evidence, and the result after the next few tasks (kept or reverted).

## Observer record

Date, flag, what the observer said, whether it was right, and anything it missed.

- 2026-11-11, smoke test: no flags, correctly. Missed: an edit made through the shell (not visible to LANE).
- 2026-11-11, milestone 1: the watch script called a resumed agent done (it read the old hand-back). Fixed: a follow-up message now counts as a restart. The observer agent was not needed; no real flags.
- 2026-11-12, GLB render + renderer speedups (long, two worker-hard lanes, code edited locally, every check on the machines): lane B passed in 2 rounds (bit-identical, 4.08×); lane A works (render-only 19 views in 5.5-8 s, 650 MB peak) but misses its written max ≤ 2 bar on f32 edge pixels, user's call. ~3 h against a 1 h estimate; most of the overrun was mine: two phantom "hangs" were cloud machines seated by `client.py build` and then pausing, and a test step pushing ~19 large PNGs a share through the tunnel, which blocked heartbeats. Faster next time: build with `--no-seat` unless the cloud machines are known live; keep test output small or on branches only; stream every run under Monitor from the start; never `pkill -f` a pattern that is in the shell's own command line. laneA 5.9M tokens processed (46 calls), laneB 1.7M (23).
