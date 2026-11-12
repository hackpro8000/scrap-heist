# Map changes

What Tristen doesn't like about the current Server Map and wants changed.
Each item is in their words first, then what it means in the map (layout
file, model, area) once that's pinned down. Items stay open until the change
is built and approved.

## Open

1. **No streets in the hub.** "Remove the streets from within the hub, they
   make no sense for the small size of the hub."
   - `art/src/layouts/ServerMap.luau`, slab `Streets` (~line 647): Walks,
     RoadMarks (ring road edge lines), LaneMarks, Drains, Kerbs, LampPosts;
     and slab `Plaza` (~line 169), whose paving turns to asphalt ring road
     between `HUB_PAVED` and `HUB_ROAD`.
   - Open question: what the hub floor becomes once streets go (plain
     concrete plaza, packed dirt, a mix). Ask before building.

2. **Props follow the hub's circle, not the world axes.** "There are drains
   and streetlights in the hub that are not oriented in the circular hub
   shape."
   - Drains, drain bars and lamp posts are `box()` calls at polar positions
     with no turn (`Streets`, ~lines 694-795), so each sits square to the
     world. Most of these go with #1; anything that stays must turn with
     its bearing.
   - Sweep the rest of the map for the same thing (yard pieces, rough-edge
     sites, crossings).

3. **Dirt paths from the yards to the hub, no pavement.** "Just paint dirt
   paths from the yards to the hub, I don't like the pavement."
   - Today: kerbed `Tracks` and `Kerbs` from each gate to the ring road
     (`Streets`), plus the asphalt ring road (`Plaza`). Replace them with
     paths painted into the island's ground texture, no raised geometry.

4. **Ground shades sit on the ground.** "The ground shades on props are
   lifted around ~1 stud off the ground; keep it as close to the ground as
   possible, maybe 0.01 studs lift max."
   - The layout's shade sheets are set to `DECK + 0.03` (`SHADE_Z`, ~line
     71), but the ground isn't level everywhere (turf stands proud of `DECK`,
     paving sits at `DECK + 0.05`), so a sheet can float or sink depending
     on what's under it. Needs a look at the spot in Studio to confirm
     which shade is lifted. Then lay each sheet 0.01 over the surface
     actually under it.

5. **Nothing to trip over on walkable ground.** "I don't want anything
   running across the ground that could trip someone over in real life
   such as cables, pipes, etc. The post-apocalyptic props around the rough
   edge are fine, but the wires running from the landmark are ruining the
   aesthetic."
   - `Conduits` (`Streets`, ~line 745): the runs from the landmark's plinth
     to the Market, Tinkerer and Stage, with their walk-over cover plates.
     Remove them; feed buildings from below or overhead if they need a
     visible feed at all.
   - Rough-edge wreckage (half-buried pipe, tyres, slabs) stays.

6. **One object's colour leaks onto its neighbour.** "The stock piles at
   the market show a green object leaking its colour onto an orange one."
   - `art/src/items/HubShop.luau` `StockPiles` (~line 307) colours by world
     position bands (`x > 13`, `x > 9`, ...), and the crate at x 13.8 is
     2 wide, so it straddles the `x > 13` line and takes two colours.
     `shared/TownClutter.luau` `supplyTones` does the same on a ~3-stud
     grid. Colour must be chosen per object, not per region of space.
   - Check the bake's brush strokes don't carry colour across touching
     objects too.

7. **Stacked things float.** "The stacked supply barrels where the top one
   floats at roughly 0.05-0.1 studs above the bottom ones... this must be
   prevented from happening in the future."
   - `HubShop.luau` ~line 503 puts the top barrel at `FLOOR + 1.86`; a
     `barrel` (`TownClutter.luau`) is 1.8 tall, so it floats 0.06. Its bung
     (top at 1.92) also pokes into the barrel above.
   - Prevention: a mechanical check that flags pieces resting a few
     hundredths of a stud off what holds them, plus the critic rule.

8. **Yard rebirth press and build bay are doubled.** "The yard rebirth
   machine and hatching bay both get copies placed during runtime,
   oriented in world space of course; you can do whatever solution fits
   best here."
   - The map builds a Bay and a Press into every yard (`ServerMap.luau`
     ~lines 560-561), and `PlotService` clones the real, movable ones from
     the kit at runtime. Plan: drop the map's copies, keep the runtime
     ones (they carry the prompts and move with the player's layout), and
     check in Studio that they turn with the yard.

9. **3D text needs work.** For another session. Remind Tristen when this
   list is done.

10. **Pipes run straight, turn only at right angles.** "All pipes must
    travel in straight lines, and when there is a turn it must form an
    angle that is a multiple of 90, never anything in between."
    - Already a critic rule ("Swept shapes keep their section"), so the
      critic missed it; the rule is sharpened. Sweep the map's models for
      bent or angled pipes.

## Done
