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
- Those two changes skipped review; the user called it out. From here every change goes through review rounds (cloud renders + model-critic) before its checkpoint.
- Rocks given real meshwork with EditMesh: every edge chamfered (each face inset and lifted), one or two top corners chipped off flat, most tops stepped into a raised plateau and tilted, sides tapering. Pebbles the same, smaller. Chips only on top corners so no rock is cut away where it meets its neighbours. A hidden backing of rocks (flat slabs over the opening, long rocks along each wall) and four shoulder rocks at the porch corners close the gaps; flank rocks squatter and tilted.
- Renders and checkpoints run on the cloud machines (`FROM=` on `scripts/checkpoint-model.sh`); eyes 7 and 8 are raised overviews of the whole pile.
- Sizes made less uniform (user): about 50 rocks in a clear spread, a few big (a 10.5-wide boulder in the hub wall, an 11-wide 13-tall one in the far wall with a rock leaning on its foot, an 11 by 10 by 7 peak slab, a 14-wide roof slab), medium walls and roof, small 1.6 to 3 stud rocks at the foot and in the joints on top. Two review rounds; the far-side slit closed with a filler rock by the + porch.
- More detail (user): timber braces tried in three layouts and dropped; texture picked from three variants (worn rims / plus cracks / plus lichen): A, worn rims. Bold painted highlight strokes on every rock edge, tinted toward the stone, tapering from full width at corners to 15% mid-edge (falloff 0.6 studs, via the bake's cornerTaper, now passed through `taper` on a part entry in common.luau); each boulder its own tone. Pebbles get narrower, fainter rims and a darker base. Two review rounds.
- Rocks too uniform (user): each visible rock has a kind (BOULDER_KINDS): slab (steep sloped top, small chamfers), crag (narrows toward the top, two chipped corners), round (big chamfers, pulled 15% round), block (chamfered with a stepped plateau); chamfers vary per rock; pebbles round. Pulling round 30% softened edge folds below the highlight threshold and lost the rims, hence 15%. Rims raised to strength 1.8, band 0.6 studs. Three review rounds.

## Open
- Critic (after three rounds on the shape kinds): MED, rim highlights still faint on many boulders against the reference's bold bright rims (needs contrast, not just width); MED, the pile reads as one blue-grey mass from the far side (wider per-rock tone spread, darker joints). LOW: crag and round read alike; some lower-ring boulders still tall prisms; the big far-side boulder a tall flat-faced slab; flanks could use a few more mid-size rocks.
- The mouth shades stay opaque 4.5 in, as the user asked.
- The plan check's clearance can't measure this opening: it looks along X or Z, and the tunnel runs along Y.
- The clipping check flags the intended seating (boards, beams and pebbles tucked into the rocks).

## Next
- Bolder rims: paint them clearly lighter than the face, the same on the lower rocks.
- Wider per-rock tone spread with darker joints.
- Shorter, rounder lower-ring rocks and a stepped face on the big far boulder.
