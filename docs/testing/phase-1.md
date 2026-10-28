# Phase 1 test checklist: combat

Unit tests already cover the rules (`lune run tests/run Combat`). These steps
check the parts that need Studio: hitboxes, input, replication and NPCs.

## Setup

1. `rojo serve`, connect from Studio.
2. Press **Play** (solo). Output shows `[Server] init CombatService` and
   `[Client] init CombatController`, with no errors or warnings.
3. A brown training dummy stands at `(0, 5, -20)` (Studio only).

## Attacks and hitbox

1. Walk up to the dummy and click. Each click while in range shows a red
   flash on the dummy and lowers its health bar.
2. Click repeatedly: hits come in a three-hit rhythm (Bat). Clicking much
   faster does **not** add hits, because the server ignores swings until the
   last one recovers.
3. Stand 10+ studs away and click: no flash, no damage.
4. Turn your back to the dummy and click: no hit (the hitbox is in front).
5. Third combo hit pushes the dummy back.

## Block, parry, guard break

1. Stand next to the dummy and wait for it to swing at you (every 2 s).
2. Hold **F** (or right-click) a moment before its swing lands: blue flash,
   you take a quarter of the damage, and you walk slower while holding.
3. Press F *just* as the swing lands: yellow flash, no damage, the dummy
   is stunned (its next swing comes late).
4. Hold block through several dummy swings: after five blocked hits an
   orange flash shows a guard break; you're stunned and slow for 1.5 s.
5. Tap F rapidly through a swing: you should **not** get a parry (block
   re-raised too soon has no parry window).
6. Stand behind the dummy while blocking with your back turned to it: hits
   land at full damage.

## Weapons

1. Press **2**: hits are slower and heavier (Big Spanner, two-hit combo).
2. Press **1**: back to the Bat. Switching mid-swing is ignored.
3. Respawn (reset character): you keep the weapon you picked.

## NPCs

1. Kill the dummy. It disappears and respawns 3 s later in the same spot.

## Two players (Test > Clients and Servers, 2 players)

1. Players can hit and block each other the same way.
2. Being knocked back by the third Bat hit moves your character (pushed
   on your own client).
3. Both clients see each other's hit flashes.

## Placeholders

All asset IDs in `src/shared/Assets.luau` are still placeholders. Check the
Output shows no warnings about missing animations or sounds.
