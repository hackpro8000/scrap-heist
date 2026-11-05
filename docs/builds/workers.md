# Build workers

Build workers are long-lived cloud sessions that run build jobs on request,
so builds don't load your machine. You set them up once; after that the
coordinating session (your desktop Claude session) sends them jobs and reads
their reports on [PR #1](https://github.com/hackpro8000/scrap-heist/pull/1).

## One-time setup

1. Optional, for uploads: add `ROBLOX_API_KEY` and `ROBLOX_CREATOR_ID` to the
   cloud environment's variables.
2. On claude.ai/code, start one cloud session per worker on
   `hackpro8000/scrap-heist`, branch `main`. Pick Haiku in the model menu if
   it's offered. Title each `Build worker W1`, `Build worker W2`, and so on,
   so the coordinator can find them.
3. Paste this as the first message, changing only the worker name:

```
You are build worker W1 for this repo. Reply "W1 ready" now and then wait. Every later message is a job line like `job <job id> <kind> <args>`. For each one, run `bash scripts/worker-job.sh W1 <job id> <kind> <args>` from the repo root and wait for it to finish (builds take minutes). Change no files yourself and don't fix failures; the script reports them. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with the script's last 5 lines and wait for the next job.
```

That's all. Tell the coordinator how many workers you started.

## Jobs

The coordinator sends one line per job:

| Job line | Does |
|---|---|
| `job servermap-a-s3 shard ServerMap 3/8` | builds shard 3 of 8, uploads its chunks |
| `job crane-a model MagnetCrane` | builds one model, sends back its preview |

Each job resets the worker's branch to the latest `main`, so any worker can
take any job. Results land in `art/jobs/<job id>/` on the worker's branch,
and the report comment names the branch and commit.
