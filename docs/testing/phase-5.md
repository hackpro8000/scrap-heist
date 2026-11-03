# Phase 5 test checklist: storm rounds and bots

Unit tests cover the round clock (including drift), loot rolls, the bot
state machine, targeting, stuck detection and wave sizes
(`lune run tests/run Rounds`, `lune run tests/run Bots`).

Tip: shorten `Config/Game.ROUND_DURATIONS` while testing, or use `/storm`
and `/phase Calm`.

## Cycle (solo)

1. Play. The banner reads "Calm. Storm 1 in 4:00" and counts down smoothly.
2. `/phase Warning`: yellow "STORM INCOMING 0:20", warning sound if set.
3. When it reaches 0 the storm starts: red banner, darker sky, you're
   moved to the arena (a gray disc at the centre), bots spawn around you.
4. When the storm ends: you're back in your yard, a results panel lists
   your rewards, then Calm again with "Storm 2".
5. Leave it running through 3+ cycles: no doubled banners or skipped
   phases; the Output shows no errors.

## Bots

1. `/storm`. Scrappers rush you, Zappers hit from range, Bruisers (later
   rounds, or `/spawnbots Bruiser`) wind up slowly: parry them with F.
2. Hit a far bot: it turns on you even if another player is closer.
3. Lead bots around a wall or corner: they path around it and don't stay
   stuck for more than a few seconds.
4. Walk into your yard: bots stop chasing you.
5. `/spawnbots Scrapper 25` plus a running storm: the server stays smooth
   (check the server Heartbeat in the Developer Console / MicroProfiler).
6. When the storm ends, every bot disappears.

## Raids during storms

1. Carry a bundle (see phase-4.md), then `/storm`: the bundle goes back to
   its owner's crate and grabbing is refused during the storm.

## Loot

1. Survive a storm outside your yard: rewards appear in the results and in
   your Bag.
2. Hide in your yard all storm: "You didn't make it" with no rewards.
3. Deal the most damage: a "#1 damage dealer" line and a rare item.

## Mid-round join (2 players)

1. Start a storm with Player1, then join Player2: Player2's banner shows
   the storm and the right countdown at once.
