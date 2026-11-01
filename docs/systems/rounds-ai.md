# Storm rounds and scrap bots

Every few minutes a storm hits the whole server. Scrap bots pour into the
arena, everyone fights, and survivors earn loot.

## Round state machine

`Calm -> Warning -> Storm -> Results -> Calm`, forever. Durations are in
`Config/Game.ROUND_DURATIONS`.

The phase is never counted down. `RoundClock.stateAt(startTime, now)`
works it out from one fixed start time each tick, so:

- **No drift:** after 10,000 cycles the storm starts at exactly the right
  second (there's a unit test for this).
- **No overlap:** there is one start time, so two rounds can't run at once.
- **Mid-round joiners** ask for the current state when their client
  starts. Every message carries the phase's end time on the shared server
  clock, so every countdown agrees.

## During a storm

- Everyone alive becomes a participant and, in Arena mode, is moved to the
  arena. Dying knocks you out.
- **Raiding pauses.** Bundles being carried or lying on the ground go back
  to their owners' crates.
- **Yards are safe.** Bots never target anyone standing in a yard. But only
  participants alive *outside* a yard when the storm ends count as
  survivors: hiding is safe, but it earns nothing.

## Scrap bots

Three types (Config/Bots): the fast, weak **Scrapper**, the slow **Bruiser**
tank with big parryable slams, and the ranged **Zapper**, which backs off
when hurt. Waves grow with the round number and with each wave inside a
storm, capped at 30 alive.

- **State machine** (`BotBrain.decide`): Idle -> Chase -> Attack -> Retreat.
- **Targeting** (`BotBrain.pickTarget`): nearest player, pulled toward
  whoever has hurt the bot most. Old grudges fade.
- **Pathfinding:** `PathfindingService`, recomputed at most once a second
  per bot and only when the target has moved 6+ studs. Bots chase directly
  when close.
- **Stuck handling** (`BotBrain.checkStuck`): no progress for 1.5 s -> jump
  and repath; still stuck at 4 s -> hop toward the next waypoint.
- **Same combat kit:** bots are CombatService fighters. A bot swing goes
  through the same windup, hitbox and block/parry rules as a player's. The
  Zapper's bolt is a long, narrow hitbox.
- **Pooling:** bot models are built once and reused. Humanoid death is off
  for bots, so a "killed" bot goes back to the pool instead of being
  destroyed.

## Loot

When a storm ends (`LootService`):

- each survivor rolls the Survivor table and gets scrap that grows with the
  round number
- the top 3 damage dealers against bots roll the TopDamage table (Reactor
  Cores, Golden Cogs)
- rolls are weighted (`LootRules.roll`); rare items become unique items
  with GUIDs through InventoryService
- `LootRules.claim` makes sure a player is rewarded at most once per round
- rare finds are announced to the server

## Files

- `src/server/Rounds/RoundClock.luau`, `LootRules.luau`: rules, unit tested
- `src/server/Bots/BotBrain.luau`, `WaveRules.luau`: AI rules, unit tested
- `src/server/Services/RoundService.luau`, `BotService.luau`, `LootService.luau`
- `src/client/Controllers/RoundController.luau`: banner, countdown, results
- Config: `Game.luau` (durations), `Rounds.luau`, `Bots.luau`, `Loot.luau`
