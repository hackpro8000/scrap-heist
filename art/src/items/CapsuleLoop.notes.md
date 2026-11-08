# CapsuleLoop notes

**Goal:** the hub's capsule belt, one lap at radius 72, through one small steel factory that crushes old capsules at one mouth and makes new ones at the other (art/concepts/capsule-loop-sketch.png).

## Decided
- Replaces MineLoop's rock cave and minecart track (user). One building does both ends, on the track's circle.
- Each mouth 7 wide by 6.6 tall: the 4 by 5.5 capsule has 1.5 spare each side and 1.1 overhead.
- Previews render at max detail (user: whenever 20 machines are up). At max detail `chunkedPart` keeps the chunk sizes of the layout's own density and only its textures scale, or the belt split into 1-stud chunks and ran the machines out of memory.
- Belt as chunks (critic: its one texture over a 149-stud lap was coarse): Tread and BeltRails are `chunkedPart`s, so each chunk holds the item's density.
- Cogs removed (user): a gear pair on the far wall was tried in three forms (gold plate with spoked gears; bronze gears after the sky cog that meshed; the same with a gearbox casing and drive shaft to the press) and never fit the building. The far wall is plain corrugated steel.
- Hazard tape not hand-painted (user): the frames, the press and the belt go on `crisp`, a new bake option that lays the coat texel by texel in the paint fn's colours instead of brush strokes, which smeared the stripes and hid the belt's ribs. Painted rims dropped on those parts.

- First build, six critic rounds: shed of corrugated steel on a concrete footing with a pitched standing-seam roof; yellow hazard frames round each mouth with crisp 45-degree tape; a green plate with a fresh capsule over the +Y mouth and a red one with a crushed capsule pressed flat by arrows over the -Y mouth; rubber curtain strips; black shades inside each mouth; on the roof a closed dark press housing with a lighter hip cap, silver ram and hazard band over the crush end, an orange hopper with chute and legs over the make end, a stack and pipes; a beacon at each frame's top corner; the belt a ribbed rubber tread with a lighter centre band between slim mid-steel rails on small feet.
- The sheet lap on the walls is a rivet row with a little rust, not an open seam (critic: the crack line read as damage).

## Open
- The game's belt path (src/shared/Config/Belt.luau) is still the old stadium.
- Critic, all LOW: the far long wall is a large blank expanse now the gears are gone (a stencil, vent or number plate would give the eye one landmark; left plain for now); the crushed icon's arrows are small at mouth range; the belt's centre band is faint from far off.
- The plan check's clearance can't measure the mouths: it looks along X or Z, and the belt runs along Y.
- The clipping check flags the intended seating (press and stack into the roof).

## Next
- Put CapsuleLoop in place of MineLoop in art/src/layouts/IslandPreview.luau and re-render the island.
