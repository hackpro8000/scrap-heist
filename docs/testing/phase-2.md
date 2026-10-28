# Phase 2 test checklist: data

Unit tests cover the template, migrations and currency rules
(`lune run tests/run Data`). These steps need Studio and real DataStores.

## Setup

1. Run `wally install` so `ServerPackages/ProfileStore` exists.
2. In Studio: **Game Settings > Security > Enable Studio Access to API
   Services** (otherwise ProfileStore uses a mock and nothing persists).
3. Play. Output shows `[Server] init DataService` and no errors.

## Persistence

1. Type `/givescrap 500` in chat. A toast says "Gave 500 scrap".
2. In the Explorer, your Player has the attribute `Scrap = 500`.
3. Stop, play again. `Scrap` is still 500.
4. `/resetdata`: you're kicked with "Your data was reset". Play again:
   `Scrap` is 0.

## Bad input

1. `/givescrap -50`, `/givescrap 0`, `/givescrap abc`: each shows the usage
   message and scrap doesn't change.

## Session lock (published place, two servers)

1. Publish, join server A.
2. From another device, or by teleporting, join a second server while
   still in A. You can't play on both: the second server waits or kicks A's
   session (`OnSessionEnd` kicks you from A).
3. Your scrap is the same in whichever server you end up in.

## Admin gate (published place)

1. With your user ID **not** in `Config/Game.ADMIN_USER_IDS`, `/givescrap`
   does nothing in a live server.
