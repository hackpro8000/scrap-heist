# Scrap Heist: systems overview

Five systems, each built to be shown to clients. Every explainer is one
page and links to the code.

| System | Explainer | Proves |
|---|---|---|
| Combat kit | [combat.md](combat.md) | Combos, block, parry, server-side hit validation |
| Player data | [data.md](data.md) | Session locking, safe saves, no duplication |
| Inventory and trading | [inventory-trading.md](inventory-trading.md) | Unique items, atomic two-player trades |
| Tycoon and raiding | [tycoon-raiding.md](tycoon-raiding.md) | Plots, machines, income, steal mechanic, anti-grief |
| Storm rounds and bots | [rounds-ai.md](rounds-ai.md) | Round state machine, pathfinding bots, loot tables |

## How the code is organised

- **Rules modules** (`src/server/Combat/CombatRules.luau`,
  `Trade/TradeSession.luau`, `Rounds/RoundClock.luau`, ...) hold each
  system's logic as plain functions over plain data. They don't touch
  Roblox objects, so each rule is unit tested (`tests/`, run with
  `lune run tests/run`).
- **Services** (`src/server/Services/`) connect the rules to the game:
  players, remotes, models, timers. Each has `init()` and `start()`, booted
  in order by `src/server/init.server.luau`.
- **Controllers** (`src/client/Controllers/`) are the client side: input,
  UI built in code, effects. They only ever send intent.
- **Config** (`src/shared/Config/`) holds every tuning number;
  `src/shared/Assets.luau` holds every asset ID.

## Security in one place

- Every client-to-server remote goes through `RemoteGuard.listen`, which
  rate-limits it and counts rejections.
- Every anti-exploit check is marked `-- SECURITY:` and every anti-dupe
  step `-- DUPE-SAFE:`. Search for them to walk a client through the
  protections: `rg "SECURITY:|DUPE-SAFE:" src`.
- The debug overlay (showcase mode) shows server hitboxes, bot paths and
  live rejection counts on screen.
