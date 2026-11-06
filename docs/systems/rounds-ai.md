# Storm rounds

A storm is weather. It makes the belt richer and the Line dangerous, and
it ends with every yard's defences down. There are no bots and no arena.

## The cycle

`RoundService` keeps the clock (`Rounds/RoundClock`, pure and unit tested)
and tells everyone the phase; what each phase does lives in the services
that listen.

| Phase | Length | What happens |
|---|---|---|
| Calm | 4 min | Nothing special |
| Warning | 20 s | Players are told a storm is coming |
| Storm | 90 s | The belt runs at double speed and drops capsules twice as often, each one tier higher (`BeltService`, `BeltRules`). Parts rain on the walkways as pickups and lightning strikes (`StormService`) |
| Blackout | 30 s | The storm goes on, every gate drops and can't be locked, and a crate grab takes double (`RaidService`) |

Lengths are in `Config/Game.ROUND_DURATIONS`; everything else a storm does
is in `Config/Storm`.

## Parts rain

A pickup lands on the Line's walkways every second and a half and lies for
20 seconds. Walking into it takes it: 2 parts, more at higher ranks
(`StormRules.partsFor`). Parts buy junkrot stars.

## Lightning

Every 4 seconds a warning ring 10 studs across shows on the ground for a
second, then the bolt lands. Anyone inside is stunned for 2 seconds, takes
a little damage and drops their capsule. Strikes aim at players out on the
Line, mostly those carrying a capsule (`StormRules.pickTarget`). Yards are
safe: hiding costs you the haul and the parts.

## Debug

`/storm` starts a storm now; `/phase Calm|Warning|Storm|Blackout` jumps to
any phase.
