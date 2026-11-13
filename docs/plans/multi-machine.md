# Multi-machine system

Status file for the team's first task (started 2026-11-11). Any session can pick this up: milestones, what is done, what is blocked. The team's rules are in `docs/team/`.

## Goal

One hub, one connection per machine. The coordinator runs on GitHub build machine 1, not on the user's computer. Every other machine (GitHub build machines now, Claude cloud session machines later) dials out to it and pulls work. This session is a client like the rest. Small messages go through the hub; big files go straight to storage.

## Facts that shape it

- The repo has no `TS_AUTHKEY` secret (`gh secret list`: only the two Roblox ones), so build machines cannot join the Tailscale network. The Tailscale route below is built but cannot be tested until the user adds one.
- A Cloudflare quick tunnel needs no account: it gives a public `https://<words>.trycloudflare.com` address for one local port, new on every start.
- The agent port is safe to expose: a machine is admitted only with GitHub's identity token for this repo's standby workflow (`tools/coordinator/oidc.py`).
- The control port has no admission at all. It must never be exposed without one.
- Workflow inputs and logs are public (public repo). Nothing secret may pass through them.
- Claude cloud session machines can only dial out, and only to hosts their environment allows. Quick-tunnel names change, so they need either an environment with unrestricted network access or a fixed name. The user sets that in Claude settings.

## Milestones

| # | Milestone | Pass bar | Status |
|---|---|---|---|
| 1a | Live control link over Tailscale: `--control-host`, `COORDINATOR_CONTROL`, `scripts/coordinator.sh attach <run id>` | Local checks | Built and checked 2026-11-11. Real test blocked: no `TS_AUTHKEY`. |
| 1b | The same link with no Tailscale: machine 1 opens quick tunnels, publishes their addresses, and admits this session to the control port by a signature | From here, `status` shows 2 machines up on a coordinator running on machine 1 | Done 2026-11-11: run 42950174987, `machines=2 up=2` through the signed link; a wrong key was refused. |
| 2 | A build sent through the link, merged on machine 1, results streamed back | A small build returns the same tables as the local route | |
| 3 | Hand-over at the 5-hour limit | A task list survives a coordinator restart | |
| 4 | Claude cloud session machines as workers | One cloud machine takes a task and returns a result | Network cleared 2026-11-11: the user set the `Default` cloud environment to unrestricted (`RemoteDev` is too). Admission: one-time tokens (design below). Still open: this session's permission check refused `create_session` once. |

## Design of 1b

- **Control admission by signature, no shared secret.** `scripts/coordinator.sh key` makes an ed25519 key pair once with `ssh-keygen` in `~/.cache/scrap-heist/control-key` (never leaves this computer) and prints the public key. The public key goes to the workflow as input `control_key`.
- `coordinator.py serve --control-key "<public key>"`: on every control connection the coordinator first sends `{"type": "challenge", "nonce": <32 random bytes, hex>}`, and the client must answer `{"type": "answer", "signature": <output of ssh-keygen -Y sign -n scrap-heist-control>}` over the nonce. The coordinator verifies with `ssh-keygen -Y verify` against an allowed-signers file holding only that key, within 30 s, and closes the socket on any failure. Without `--control-key` the control port behaves as today and `serve` refuses a `--control-host` other than 127.0.0.1 or a Tailscale address (100.64.0.0/10).
- `client.py`: when the first message on a control connection is a challenge, sign it with the local key and go on as before. One helper used by every command.
- **Workflow, when `coordinator == 'machine-1'` and there is no Tailscale key:** machine 1 installs `cloudflared` (GitHub release binary), starts the coordinator on 127.0.0.1 with `--control-key`, opens one quick tunnel to the agent port and one to the control port, and publishes both addresses plus the run id as `address.json` on the branch `build-results/coordinator-address` (force-push, the job's own token). Machines 2..N wait for an `address.json` with their run id (fetching that branch every 3 s, 3 minutes at most), then run `scripts/standby-agent.py` against the agent address. Machine 1 does the same against its own address.
- `scripts/coordinator.sh attach` with no run id reads `address.json` through `gh api` and writes the remote state (`control` = the control tunnel as `wss://`). `scripts/standby-start.sh --on-machine` passes the public key.
- The Tailscale path from 1a stays for when a key exists.

## Design of 2

Measured 2026-11-11: `scripts/merge-shards.sh` on a 20-shard result takes 0.06 s, and a task's results without objects are about 1 MB of text. So the merge stays in the session, unchanged, against the session's own tables; only the transport changes. Objects (`.glb`) never come home: they go machine to machine 1 to Roblox.

- `coordinator.py serve --relay-results` (machine 1 uses it in place of `--git-link` when it has a control key): every result file a machine sends that is not a `.glb`, every preview image the coordinator stores, and the task's `uploaded.tsv` and `summary.txt` are also sent to the task's watchers as one binary message each (`wire.pack`, header `{"type": "result-file", "task", "path"}` with `path` relative to the folder the coordinator wrote it under: the task's results folder, or the repo root for previews, marked by `"root": "results"` or `"repo"`). They are sent before the `finished` event. The coordinator does not merge in this mode.
- `client.py build`: a binary message is unpacked and written under `.standby-results/<task>/` or the repo root. Paths are checked: relative, no `..`, and for `"repo"` only `art/models/<Name>/(preview|views).png` and the like that the local coordinator already writes. On `finished` with no merge result from the coordinator, an uploaded and fully successful task is merged here with `scripts/merge-shards.sh` exactly as `Coordinator.merge` does, and `new-assets.txt` is written as today.
- `scripts/send-build.sh` works unchanged: it finds the coordinator through `client.py status`.

## Design of 3

- Machine 1 keeps the coordinator alive: a small loop restarts it if it exits, on the same ports, so the tunnels keep working.
- The coordinator writes each posted task (id, ref, upload, previews, build) to a tasks file beside its state and removes it when the task completes. On start it reloads them; machines that reconnect are sent the task again and resend what they built (existing behaviour).
- `client.py build` reconnects for up to 60 s when its control connection drops mid-task and asks to watch the same task again (`{"type": "watch-task", "task": id}`); if the task is unknown or the hub stays gone it exits 3 with a clear message.
- The 5-hour limit: a standby run ends then by design, builds take minutes, and `scripts/standby-start.sh` brings up a new hub. Nothing is carried across runs.

## Design of 4

- A worker that is not a GitHub machine is admitted by a one-time token. `client.py mint-workers <count>` asks the coordinator (signed control link) for `count` random tokens bound to a new pool id and shard numbers 1..count; each token admits one live connection for its shard (a reconnect with the same token is allowed, a second simultaneous one is not). In `hello` the worker sends `{"token": "worker:<token>"}`; the coordinator fills run, shard and count from the token, never from the worker.
- `scripts/cloud-worker.sh <agent address> <token>` does on any Ubuntu 24.04 machine with the repo checked out what the standby workflow's steps do before "Wait for tasks" (tools, toolchain, the websocket library), then runs `scripts/standby-agent.py`. It needs no GitHub secrets and does no uploads.
- A Claude cloud session is started with the repo attached and a prompt that runs that one command. It needs an environment that can reach `*.trycloudflare.com` (unrestricted network, since the name changes each run).
- A task goes to one pool at a time (the newest), as today. Mixing GitHub and cloud machines on one task needs the pull queue, which is a later piece of work.

## Alerts

Abnormalities print as one line, `ALERT <KIND>: <what happened> | <what to do>`, once per occurrence, and `CLEARED <KIND>: ...` when one resolves. `client.py build` and `status` print them on stdout; a machine's own alerts go to its job log and, when connected, through the hub to `build`.

| Kind | Printed by | Trigger | What to do |
| --- | --- | --- | --- |
| TUNNEL_DOWN | workflow (machine 1), `standby-agent.py`, `client.py` | Machine 1's own public tunnel address answers 530/502/nothing (it reopens the tunnel up to 3 times before publishing); a machine fails to connect 3 times in a row (HTTP status logged); a control connection fails | If it stays down, cancel the run and start a new one |
| WEDGED | `client.py build` | A working machine unheard for 300 s | Restart it, or let the run finish without its share. The hub does not re-deal a wedged machine's preview share: a machine works out its share from its shard number, so re-dealing needs a new task message naming explicit shares |
| BAD_REF | `client.py build` | The ref is not on GitHub (`gh api .../commits/<ref>`); a commit id is posted as its full sha | Push it (`scripts/push-wip.sh`) and post again |
| ALL_FAILED | `client.py build` | Every shard failed within 30 s of posting; names the first failure line | Fix the cause before posting again |
| STRANDED_TASK | `client.py status` | Open tasks (over 60 s old, no uploads in flight) and no machine working on any | `client.py clear-tasks` |
| SHORT | `client.py status`, `build` | Fewer machines connected than the run asked for, 120 s after its first machine connected or after posting | Check the missing jobs; build with what is up or start a new run |
| LIFETIME | `client.py status`, `build` | The hub ends within 15 minutes by its idle or max limit (from `STANDBY_SINCE`, `STANDBY_IDLE_MINUTES`, `STANDBY_MAX_MINUTES`, set by the workflow) | Post a task (idle), or start a new run (max) |
| LOW_RESOURCES | `client.py build` | A heartbeat reports under 2 GB free disk (work folder) or available memory | Expect that machine's build to fail; restart it if it does |
| QUEUED | `standby-start.sh`, `standby-status.sh` | The standby run is still queued 60 s after starting; names the runs holding slots | Cancel them or wait |

Bake races are not an alert: when two machines save the same bake, the loser's `cannot lock ref ... reference already exists` is taken as success (one log line, the branch's commit used). Files over 1 MB go from a machine in 1 MB parts, so its heartbeats keep coming while it sends results.

## Log

- 2026-11-11: 1a built by `worker-hard` (112 s after a lost first run), `checker` PASS. Lost run: a hook added that day had a quoting error and blocked every edit.
- 2026-11-11: 1b built by `worker-hard` (273 s). Opus `checker` FAIL: the public control port took 64 MB messages before admission (47 MB to 1 GB with 20 connections), plus four low findings. All five fixed (58 s; the same attack now adds 2.2 MB). Real test passed on two build machines about a minute after start.
- Next: milestone 2. In machine-1 mode the coordinator still runs with `--git-link`, so results go to a branch and nothing merges; the live link carries control only.
- 2026-11-11: milestones 2-4 built by one `worker-hard` (about 12 min), Opus `checker` FAIL with ten findings (three real: machine-supplied names used as paths, a malformed tasks file crashing start-up, the client trusting the coordinator's folder), all fixed in one round. The user then asked for security work to stay in proportion; no second adversarial round.
- 2026-11-11: milestone 2 passed for real. Run 42954144860: 20 of 20 machines up on machine 1's coordinator, a no-upload build of 4,700 parts in 241 s through the signed link, 102 result files (1.2 MB) relayed home, same file set as the local route, no objects sent home. Not yet tested for real: uploads and the merge after them, previews, the restart loop (no way to kill machine 1's coordinator from here).
- 2026-11-11: milestone 4, first cloud worker: `create_session` was allowed, the session started (Default environment, repo at wip/coordinator), but its own permission layer blocked the launch command as "Code from External" and it asked for its user's direct confirmation. Not worked around. Ways forward, all the user's: confirm in that session (session_0172GAw2WT77pLFsuV4iPzyn), or put the worker's start-up in an environment setup script. Token admission itself is proven only with local fake workers.
- 2026-11-11: set-up is now one script per purpose in `scripts/machine-setup/`; `map-build.sh` is the first and `scripts/cloud-worker.sh` calls it. Tested on a real cloud session machine (third try): 2.2 s the first run, 0.35 s the second. The machine already has cargo, rg, sd and jq, and Python 3.13, for which websockets 10.4 has no ready-made build and will not compile; the script falls back to 13.1, and the coordinator and client ran on it there. A cloud environment for map building runs it from its setup script (the line is in the script's header). A setup script cannot start the worker: the address and one-time token change every run.
- 2026-11-11: cloud machines now build, by a second route that needs no coordinator. A cloud session refused to start a worker that dials out to the hub, so each session instead runs `scripts/cloud-shard.sh <index> <count>` (set-up, one shard from its own checkout, no upload) and pushes the small result files to its own branch `cloud-results/<task>/s<index>`; `scripts/cloud-results.sh <task> <count>` collects them into `.standby-results/<task>/` for the normal merge. One machine: shard 19 of 20 in 142 s (GitHub machine: 116 s), parts.txt and manifest.json byte-identical. 25 machines at once (task t2): 25 of 25 DONE, builds 95-172 s (mean 130 s), all branches in about 4 minutes after the first session was created, and the 4,700 parts identical to the 20-machine GitHub build. Costs: one Haiku prompt and one repo clone per machine per build; no live progress; no uploads or previews on this route yet. Sessions are created one by one with `create_session` (about 1 s each), source revision the build's branch, outcome branch the result branch.
- 2026-11-11: prompt-free builds from an environment setup script do NOT work for getting results home. The user made the `scrap-map-build` environment (unrestricted network, setup script `if [ -d scrap-heist ]; then scrap-heist/scripts/cloud-task.sh; fi`). 20 sessions were created with no prompt on per-shard task branches (`scripts/cloud-dispatch.sh`): no result branch arrived. A diagnostic session's summary: the start-up build ran and exited 0, but the commit failed (commit signing returned 401) and the push failed for lack of GitHub credentials. So at setup time a machine can clone and build but cannot commit or push. Also seen, not confirmed: that diagnostic session answered 23 s after creation, far too soon for a 140 s build, which suggests the environment reuses a cached result of the setup script instead of running it for each session. `scripts/cloud-task.sh` and `scripts/cloud-dispatch.sh` are kept but are not a working route; the setup line still prepares machines. The working cloud route remains one short prompt per machine (`scripts/cloud-shard.sh`, then commit and push by the agent).
- 2026-11-11: persistent cloud workers are closed as a route. The user's design was one set-up prompt per machine, a one-token keep-alive, and all work over the hub's live link. Four separate permission checks refused parts of it: the cloud session would not start a dial-out worker; this session was refused when writing the permission rule into `.claude/settings.json` (self-modification), and when creating a session to start the worker (auto-mode bypass). Bypass-permissions mode cannot be selected from mobile and is not available in cloud sessions at all, so it would not have helped. The only untried route was the user starting each worker session by hand, which they ruled out. Decision: cloud machines build by one prompt per shard per build (`scripts/cloud-shard.sh`); the hub is for GitHub machines. `scripts/cloud-worker.sh` (with `--detach`) and the token admission stay in the code, unused by cloud sessions.
- Next for the cloud route, in order of value: a one-line prompt (the script commits; the agent only pushes); uploads through a GitHub workflow that holds the Roblox key; evenly sized tasks.
- 2026-11-11, later: persistent cloud workers reopened after the user added, in their own `~/.claude/settings.json`, an `autoMode.environment` describing the repo and coordinator as theirs and an allow rule for `create_session`. One worker session was created, started the worker and joined the hub about a minute after creation. Then 20: only 8 joined. The other 12 sessions' own check denied the start command ("cloud-worker start denied by auto mode; awaiting approval"; the session asks for a Bash permission rule for `scripts/cloud-worker.sh`). The 8 that joined took the build, then all dropped within about five minutes of their session's turn ending and never came back: a cloud machine is paused a few minutes after its turn ends, and the detached worker dies with it. Nothing was built. Two fixes follow from that: the permission rule in the repo's `.claude/settings.json` (the user's edit), and keeping each session's turn open (`scripts/cloud-worker.sh --wait`, run repeatedly by the session while it prints "running").

## Decision (2026-11-11)

The cloud route is one prompt per shard per build. A session runs the single command `scripts/cloud-shard.sh <task> <index> <count>`, which sets up, builds, commits and pushes to `cloud-results/<task>/s<index>` by itself; `scripts/cloud-results.sh` collects them. Proven at 25 machines, output identical to the 20-machine GitHub build.

Persistent cloud workers on the hub are closed. With the user's `autoMode.environment` describing the repo and coordinator as theirs, an allow rule for `create_session` in user settings, and a `Bash(scripts/cloud-worker.sh:*)` allow rule in the repo's `.claude/settings.json`, the per-session permission classifier still admitted only about 8 of 20 worker sessions, at random (it is a model judging each case, not a fixed rule, and a dial-out worker sits near its line). A pool needs every shard, so a ~40% pass rate cannot carry it. The ways to raise the rate further (hiding from the session what it runs, retrying sessions until enough pass) are refusals of the safety review, not fixes, and were not taken. The hub stays for GitHub machines, which hold their connection and pay the overhead once. `scripts/cloud-worker.sh` (with --detach/--wait) and the token admission remain in the tree, unused by cloud sessions.

Overhead: the GitHub hub pays set-up once and reuses warm machines (zero tokens per later build). The cloud route pays per build and per machine (one Haiku prompt ~0.6c, plus a ~24-30s clone), because a cloud machine is reclaimed after its turn and cannot persist. Use the hub for <=20 machines; use the cloud route for more machines, or instant machines, on demand.

Next for the cloud route: uploads via a GitHub workflow that holds the Roblox key (cloud shards push objects to branches, one GitHub machine uploads); evenly sized shards so the slowest machine does not set the finish time.

## Lanes: filling each machine (2026-11-12)

One build keeps about half of a 4-core machine busy, so `scripts/standby-task.sh` runs `LANES` builds side by side on each machine, each of its own share (machine i of n builds shards (i-1)*LANES+1 to i*LANES of n*LANES). Lane 1 is the checkout; further lanes are worktrees in `.git/scrap-lanes/`, made once per machine (about 30 s the first time). The results are merged into one before they go back, so the hub sees nothing new.

Cold builds on 43 cloud machines, 4,700 parts each time:

| Lanes | CPU busy (median) | Memory peak | Machine build time (median / slowest) |
| --- | --- | --- | --- |
| 1 (50 machines) | 48% | 5.8 GB | 71 s / 102 s |
| 2 | 79% | 6.1 GB | 66 s / 89 s |
| 3 | 93% | 7.4 GB | 57 s / 88 s |

The buffers: under 1 GB of free memory the last lane started is stopped and built again once the others are done (tested by setting the buffer to 11 GB: 39 machines held a lane, every one finished); under 2 GB of free disk the build stops and the caches go. The slowest machine is now set by the uneven deal, not by idle cores.
