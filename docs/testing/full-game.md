# Full game playtest

A 20-minute session with 2+ players (Test > Clients and Servers, or a
published place with friends). Keep the Output window open the whole time:
**the goal is zero errors and zero warnings.**

Before starting: `wally install`, Studio API access on, all asset IDs may
still be placeholders.

## 0:00 New player

- [ ] Each player spawns in their own yard, facing the crate, with their
      name on the yard post.
- [ ] Tutorial prompt: "buy your first salvage machine". Scrap: 50.
- [ ] Buy on Pad1: prompt moves on to "collect it for scrap".
- [ ] Collect: the raiding tip appears; "Got it" dismisses it.
- [ ] The player list shows Scrap and Raids for everyone.

## 0:05 Build

- [ ] Collect a few times, buy Pad2 when affordable, upgrade Pad1.
- [ ] Scrap in the HUD and the player list always match.

## 0:08 Raid

- [ ] Player2 raids Player1's crate (Player1 gets the red banner).
- [ ] Player1 chases and kills Player2; the bundle drops; Player1 recovers it.
- [ ] Player2 raids again later and banks it; Raids goes up by 1 on the
      leaderboard.

## Storm (every ~6.5 minutes with default timing)

- [ ] Warning banner and the storm tip for first-timers.
- [ ] Storm: both players moved to the arena, bots arrive in waves, raiding
      refused ("paused during the storm").
- [ ] One player hides in their yard: bots ignore them.
- [ ] Storm ends: everyone is back in their yard, results screens show,
      the fighter outside the yard got loot, the hider got none.

## Trade

- [ ] Trade a rare storm drop for parts; complete it end to end.
- [ ] Both bags update; the rare item keeps its `#` ID.

## Leave and rejoin

- [ ] Player2 leaves mid-raid (carrying): parts go back to Player1's crate.
- [ ] Player2 rejoins: same yard progress, scrap, items; offline earnings toast.

## Throughout

- [ ] No errors or warnings in the Output (server and both clients).
- [ ] Server stays smooth during storms (MicroProfiler, Developer Console).
