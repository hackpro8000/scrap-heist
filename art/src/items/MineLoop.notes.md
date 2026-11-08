# MineLoop notes

**Goal:** the hub's minecart loop diving into a cave made of a stacked pile of chunky blue-grey boulders, with a timber porch at each mouth (art/concepts/mine-portal-reference.png).

## Decided
- A hill swept from one cross-section read as a smooth tube; three chunkier hill shapes (tiered, faceted, mesa) still didn't fit the art style. The user wants the cave composed of rocks, not a hill with rock decoration.
- The user's reference replaces the old sketch: rounded, chunky boulders stacked in tiers to a peak, and a square timber porch at each mouth (log posts, header and side beams, plank deck) instead of the stone arch and plank band.
- The black inside shades stay, as the user asked.
- Opening 6.4 wide by 6.6 tall: the 4 by 5.5 capsule has 1.2 spare each side and 1.1 overhead; the cart (3.6 by 4.9) passes.
- First build, three critic rounds: rocks made broad and squat with hard tilts, the far side a tier higher than the hub side, the peak a wide slab stepping down in overlapping slabs; flank rocks butt the porch boards; posts 1.2 thick; lantern hung on a bracket on the hub-side front post.
- The dark core behind the rocks showed as a "master rock"; the user wants the whole cave made of rocks. Removed.
- A thin dark tunnel lining left in its place still showed in the V-gaps between rounded slabs, so it went too: the rocks themselves wall and roof the tunnel, hub-side walls up to the roof with low steps outside, wider roof slabs overlapping both walls, every rock overlapping its neighbours by a stud or more. Only the mouths' shades are dark.
- Renders and checkpoints run on the cloud machines (`FROM=` on `scripts/checkpoint-model.sh`); eyes 7 and 8 are raised overviews of the whole pile.

## Open
- Critic (round 3, LOW only): the peak is only about a boulder above the rest, where the reference climbs higher; the flank rocks at the mouths are smooth, tall blocks; the stone lacks the reference's light edge highlights.
- The plan check's clearance can't measure this opening: it looks along X or Z, and the tunnel runs along Y.
- The clipping check flags the intended seating (boards, beams and pebbles tucked into the rocks).

## Next
- Raise the peak 1 to 2 studs so the pile climbs like the reference.
- Lighter top faces and edges on the rocks.
- Wooden braces between rocks, as in the reference.
