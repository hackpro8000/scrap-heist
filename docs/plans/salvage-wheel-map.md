# Salvage Wheel map plan

Goal: replace the avenue layout in `art/src/layouts/ServerMap.luau` with the
hub-and-spoke Salvage Wheel from `art/concepts/server-map-wheel-sketch.png`.
Every yard ends up the same walk from the belt, the shop and the arena.

## Target layout

| Piece | Now | Wheel |
| --- | --- | --- |
| Centre | Arena drone at deck level, ring road on its grating ring | New **hub island**: junk mountain, spawn, crane, belt loop |
| Arena drone | At the centre, its rim level with the road | Hovers **overhead** at `DRONE_ALTITUDE`; storms teleport players up, as `RoundService.arenaSpot` already does |
| Ring road | The drone's grating ring (`ROAD_INNER`, `ROAD_OUTER` = 75, 90) | Its own arcs round the hub island, outside the belt |
| Yards | 8 off four plaza pads (`PAD_XS`, `YARD_OFFSET`) | 8 on a ring at `YARD_RADIUS`, at `(i - 0.5) * 45` degrees, gates facing the hub |
| Bridges | `Avenue1`-`Avenue5` flat, `Bridge1`-`Bridge8` pad to yard | `Bridge1`-`Bridge8` ring road to yard gate, sloping `DECK` up to `YARD_TIER` |
| Side bridges | none | `Side1`-`Side8`, flat at `YARD_TIER`, joining neighbouring yards |
| Market | Its own island at `MARKET_X` | A pocket in the ring road rim, between two spokes |
| Pads, `MarketIsland` | Pad1-Pad4 and the market island | Removed |

## New constants (first guesses, settle in Studio)

- `HUB_RADIUS` about 70: hub island turf.
- `BELT_INNER`, `BELT_OUTER` about 72 and 82: belt loop on the hub's edge.
- `ROAD_INNER`, `ROAD_OUTER` about 86 and 101: ring road outside the belt.
- `YARD_RADIUS` about 200: far enough that neighbouring yard islands (48-stud plots, scaled
  islands) leave a gap long enough for a side bridge. Check `YARD_ISLAND` clearance.
- `DRONE_ALTITUDE` about 120: high enough to read as "overhead" from the yards
  without filling the view from the hub.
- `MARKET_ANGLE`: the rim pocket, set between two spokes so no bridge lands on it.

## Stages

Each stage is one change, rebuilt and checkpointed (`scripts/checkpoint-model.sh`)
with a screenshot to the user, following `docs/art/pipeline.md`.

1. **Lift the drone.** Raise `ArenaDrone` and everything placed with it
   (`Spawn`, `Beacon`, `Ramps`, `ArenaWall`, `Cover1`-`Cover8`, `Hatch1`-`Hatch4`,
   `Light1`-`Light4`, `Cones1`-`Cones8`) by `DRONE_ALTITUDE`. The cleanest way is one
   z offset passed through `heightAt` and the arena placements, not editing each call.
   Drop the drone end of the avenue bridge (`droneEnd`).
2. **Hub island.** A new `floatingIsland` at the origin with a flat top at
   `DECK`, dressed with existing props (`JunkMountain`, `CarStack`, `CrushedCar`,
   `TyreStack`) as the junk mountain. Spawn moves to its foot.
3. **Ring road.** Build it with `arc` round the hub island, asphalt as now, with a
   gap at each spoke for the bridges and one at `MARKET_ANGLE`.
4. **Yards on the ring.** Replace the `for i = 1, 2 * #PAD_XS` loop: place each
   `Island{i}`, `Plot{i}`, `yardTemplate` and `Spoke{i}` at `polar(YARD_RADIUS, angle)`,
   turned so the gate faces the hub, with `Bridge{i}` running from `ROAD_OUTER` to the
   gate. Remove `PAD_XS`, `PAD_PLAZA`, `YARD_OFFSET` and the avenue loop.
5. **Market in the rim.** Move `Shop`, `Vending`, `Bench`, `Landmark` and the
   palms off `MARKET_X` into the rim pocket. Remove `MarketIsland`, `MARKET_X` and
   `MARKET_PLAZA`.
6. **Side bridges.** `bridge()` between each pair of neighbouring yard islands,
   flat at `YARD_TIER`, landing on the fence side rather than the gate. Each yard
   needs a fence opening (`YardFenceHalf`) where its side bridges land.
7. **Crane and belt (new models).** `MagnetCrane` and `ConveyorBelt` need sketch
   approval before modelling (CLAUDE.md, model work). Placed on the hub once
   approved. Until then the hub stays open.
8. **Chunks.** Rebuild, re-chunk (`chunkedPart`, 128 studs) and regenerate
   `src/shared/Config/MapChunks.luau`, then `scripts/upload-chunks.sh`. Estimate
   the cache size first; the hub island and ring road are new large meshes.

## Game code to update

- `PlotService` places yards from the `YardSpots` folder, otherwise from the ring
  fallback in `src/server/Tycoon/YardLayout.luau`. Make sure `Yard1`-`Yard8`
  spots match the new yard positions and facings.
- `RoundService.arenaSpot` and the storm teleport: check the arena position
  lookup (`workspace.Arena`) still finds the raised floor, and that players
  return to the hub (or their yard) when the round ends.
- `PropellerController` finds `Map.ArenaDrone` by name: no change if the name stays.
- Spawn: new players spawn on the hub instead of round the crusher. Update
  wherever the spawn location is read.
- `README.md` "Dropping in art" and the `ServerMap.luau` header comment and labels list.

## Studio checks after each stage

- The avatar walks from spawn round the ring road and over every bridge into
  every yard, under each gate.
- Nothing intersects: islands, bridges, props, the raised drone and its propellers.
- Storm round: players go up to the drone and come back down.
- Each yard's spot, crate and pads line up with the map.

## Open questions

- `DRONE_ALTITUDE`, and whether players ride a lift or only teleport.
- Side bridges on every gap, or every other gap, and how a level unlock blocks
  them (a gate, a barrier, a collapsed span).
- Where in the rim the market goes, and whether it needs more room than a pocket.
- The shared belt and bundle gameplay is a separate roadmap task. This plan only
  builds the map it runs on.
