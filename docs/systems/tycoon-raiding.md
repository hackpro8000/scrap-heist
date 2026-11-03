# Tycoon loop and raiding

Build salvage machines in your yard, collect what they make, and steal
from everyone else's yards while defending your own.

## The loop

1. Every player gets a **yard** when their profile loads (8 per server).
2. Each yard has four **pads**. Buy a salvage machine on a pad, then
   upgrade it twice (three tiers). Later pads cost more.
3. Machines produce **parts** into the yard's **storage crate** every
   second, up to its capacity.
4. **Collect** the crate to turn parts into scrap.
5. Coming back after time away pays **offline earnings**: half rate, capped
   at two hours, straight into your scrap (so it can't be raided).

All income is calculated on the server from the machines saved in the
profile (`MachineRules.incomePerSecond`). The client never says how much it
earned. Buying uses `DataService.trySpend`, so it fails cleanly without
enough scrap.

## Raiding

1. Walk into another player's yard and hold **Grab parts** at their crate.
2. You take a bundle (a quarter of the crate, within limits) and carry it
   on your back. You're slowed while carrying.
3. Reach **your own** yard to bank the bundle as scrap.
4. Die on the way and the bundle drops. The owner can pick it up to put it
   straight back in their crate. Another raider can carry it on. Left
   alone, it returns to the crate after 30 seconds.

### Server checks for a grab

`RaidRules.canGrab` checks every one of these on the server:

- you're not the owner, and you have a yard to bring it home to
- raids aren't paused (they pause during storms)
- you're inside that yard and within grab distance of the crate
- you're not already carrying a bundle
- the yard isn't shielded
- the level gap is fair
- the crate holds enough to steal

### Anti-grief (Config/Raid)

- **Raid shield:** a raided yard can't be raided again for 5 minutes.
- **Level gap:** you can't raid a yard more than 4 levels below yours
  (yard level = total machine levels). Weaker players can always raid up.
- **Defender's edge:** while raiders are in your yard you get an alert and
  take 30% less damage.

## Files

- `src/server/Tycoon/MachineRules.luau`, `RaidRules.luau`, `YardLayout.luau`:
  rules and geometry, all unit tested
- `src/server/Services/PlotService.luau`: yards, spawns, crate contents
- `src/server/Services/MachineService.luau`: buying, upgrades, production,
  collecting, offline earnings
- `src/server/Services/RaidService.luau`: grab, carry, drop, bank, alerts
- `src/client/Controllers/PlotController.luau`: prompt filtering, raid banner
- Config: `src/shared/Config/Economy.luau`, `Raid.luau`, `Game.luau`

## Art drop-in points

- `ServerStorage.YardTemplate`: a Model with parts or models named
  `Pad1`-`Pad4`, `Crate`, `PlotMarker`
- `workspace.YardSpots`: parts named `Yard1`..`Yard8` to place yards on the
  real map (otherwise yards form a ring around the centre)
- `ServerStorage.MachineModels.SalvageMachine1`..`3`: one model per tier
- `ServerStorage.PartBundle`: a MeshPart for carried and dropped bundles
