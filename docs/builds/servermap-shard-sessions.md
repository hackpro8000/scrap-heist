# Starting the ServerMap shard sessions

On claude.ai/code (phone or browser), start 8 cloud sessions on
`hackpro8000/scrap-heist`, branch `main`, one per brief below. Pick Haiku in
the model menu if it's offered. Each brief is one message; paste it as is.

Before starting, add `ROBLOX_API_KEY` and `ROBLOX_CREATOR_ID` to the cloud
environment's variables if you want the chunks uploaded. Without them each
session still builds its shard and reports, with the upload skipped.

Each session reports on
[PR #1](https://github.com/hackpro8000/scrap-heist/pull/1) with `S<i> DONE`
or `S<i> FAILED`.

## Briefs

```
Run `bash scripts/shard-session.sh 1 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

```
Run `bash scripts/shard-session.sh 2 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

```
Run `bash scripts/shard-session.sh 3 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

```
Run `bash scripts/shard-session.sh 4 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

```
Run `bash scripts/shard-session.sh 5 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

```
Run `bash scripts/shard-session.sh 6 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

```
Run `bash scripts/shard-session.sh 7 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

```
Run `bash scripts/shard-session.sh 8 8` from the repo root and wait for it to finish (several minutes). Change no files yourself. If it prints a "report" block because it couldn't comment, post that block as a comment on PR #1 in hackpro8000/scrap-heist. Then reply with its last 5 lines.
```

## After

Tell the coordinating session the reports are in. It fetches the shard
branches, checks that the shards' parts don't overlap, and merges their IDs
and anchors into `src/shared/Assets.luau` and `src/shared/Config/MapChunks.luau`.
