# MineLoop notes

**Goal:** the hub's minecart loop diving into a hill of carved blue-grey stone columns, tunnelled through, with a timber porch sticking out of each mouth (art/concepts/mine-column-reference.png).

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
- Splotching tried and held (user): noise patches, then brush dabs (first square, then the bake's round brush, picked from three sizes); the user didn't like any of them, so the rocks have none for now. Strokes on a part entry can name their brush (`taper`, `round`, `sponge`) should it come back.
- The rocks are four parts, one per quarter of the pile, so each texture holds the item's 16 px per stud within 1024 (one was squeezed to about 10 before).
- Everything sits flat on the ground (user): rocks and pebbles on the ground have their undersides pressed flat across the footprint, lean by shearing so the base stays flat, and round ones round off only from the middle up; sleepers sit on the deck. Two review rounds; the rock that looks perched in the ground-level view is a flat base turned 45 degrees, seen with no ground drawn.
- Lanterns removed (user), with their bracket arms; the porches are timber only. One review round.
- Each rock its own gradient (user): darker and cooler at its foot, lighter at its top, tilted its own way, about a quarter either way with feet darkening a fifth more, small rocks stronger, each rock its own lightness and warmth. Which rock a texel is on comes from points sampled over each rock's real faces (nearest point on a face turned the same way); boxes misassigned texels where a small rock sits in front of a big one. Pebbles shade by height. Six review rounds.
- Cave rebuilt from scratch (user): the boulder pile, then sliced-rock piles, were dropped; the user asked for the Column Island method. A power diagram of stones (small near the summit, big at the foot), each cell a column rising to the slope with a tilted top and low ridge point, chiselled by 1 to 3 angled cuts and 3 to 6 chips facing out from the summit (only where the column stays closed). Inner columns taller than outer: a crown about 25 tall near the track, a ridge 17 tall along it, falling to the foot.
- The ends: first cut off, then cuttings (user: "cut into them"), then tunnelled through (user): the hill carries on past each mouth and the tunnel bores through it 4.9 either side of the track, the stone over each porch standing on its roof; the porch sticks out about 3.5 past the hill's face, its frame covering the bore's edges (user).
- No thin slivers by the mouths (user): three rows of like-sized columns round each mouth, set so their cells meet right on the tunnel-wall, mouth, bore and face lines. Chunks moved beside the track past each porch. Five review rounds.
- Bigger cells flatter on top (user): by the cell's footprint (none at 4 square studs, full at 12), less tilt (at most 70% less), a lower ridge point and cuts biting nearer level, so each still keeps a gentle break; the crown's columns keep their tilts so the summit stays a peak. Two review rounds.

## Open
- A few texels still take a neighbour's tone where a small rock tucks in front of a big one with faces turned the same way (LOW).
- Critic (after the flat tops), all LOW: bright edge lines on big flat tops read as outlines; columns over each porch close to one height; the rows beside the porch read a little like a picket row; light lines at some column bases from the ground level; tall faces show big texels.
- The mouth shades stay opaque 4.5 in, as the user asked.
- The plan check's clearance can't measure this opening: it looks along X or Z, and the tunnel runs along Y.
- The clipping check flags the intended seating (boards, beams and pebbles tucked into the rocks).

## Next
- Vary the over-porch columns' heights and stagger the rows beside each porch.
- Then IslandPreview re-rendered with the approved cave.
