# BuildBay notes

**Goal:** the yard's hatching bay, remade with height and a clear read of what it's for: a capsule seated on a raised drum, a tool wall behind it, the front open to the gate (art/concepts/build-bay-sketch.png).

## Decided
- Remake (user: the old yard props were too flat and small, too plain, and didn't say what they do). Same 10 by 10 footprint; 8.1 tall against the old 3.9. Front is -y, toward the gate.
- The game seats a capsule by dropping a ray from above the bay's middle and taking the first surface it hits (`PlotService.seatOf`). So only the Deck and Cradle cover the middle: a first idea with a gantry and chain hoist over the cradle would have put the capsule on the beam, so the frame went on the back edge, the work lamp's arm stops about 0.8 short, and the clamps and lamps are split so that no part spans the seat whatever collision shape Roblox gives it (critic caught the lamps).
- The game also centres the art's bounding box on the bay's cells, so nothing passes the deck's 10 by 10.
- Every capsule tier was measured: the widest is 3.6 by 2.3 (corner 2.14 from the middle), the deepest 2.7, the tallest 3.4. The drum's flat top is at height 1.7, the claws' pads stop at radius 2.33 and the lamp's shade stays above 5.5.
- Baked at the yard kit's 40 px per stud (`useTexelDensity(40)`, `KIT_DENSITY` in the ServerMap layout). Previews at max detail.
- Machine finishes are `crisp` (the deck's tape and chequer plate, the drum, the pegboard, the panel) so nothing looks hand-painted.
- Added beyond the approved sketch, so an empty bay says what it's for: a yellow target ring and ticks on the seat, a painted ring on the deck round the drum, HATCH stencilled low on the board where a seated capsule mostly hides it, and two braces crossing behind the board. Also a small spanner and a hammer on the board, and no chain hoist.
- First build, two critic rounds.
- Clearance: the player steps up the deck's 0.5 from the front or either side and stands at the drum. The two front lamps are 7.7 apart at head height, against the 4 wide capsule, and nothing is overhead in front of the drum. The apron between the drum's foot and the front edge is 2.15 deep, so a player at the drum stands with their middle near the deck's edge. The back is closed by the frame. `LOAD_DISTANCE` is 11 and the whack and steal prompts reach 12, so the drum's size doesn't put a capsule out of reach.

- Second pass, after the critic gained its rules (`docs/art/critic-rules.md`): the tools hang as they really would, with every peg placed from the same numbers as the board's painted holes. The claws are swept cast arms pinned between steel lugs on the deck. The seat has lathe rings. Machine parts use the crisp coat with bold edge highlights in their own colour, and riveted parts have light contact shadows.
- The bronze here is yellower than the family's, because the old tone read as wood. The press and sky props still have the old one, and the press should be matched when it's next reviewed.

## Open
- Whether a capsule really lands on the drum depends on Roblox's collision shapes, which can't be tested from the preview. Check in Studio once the new kit is uploaded.
- Critic, all LOW: bolt heads are close to the plate's tone; the lugs have no foot plates; a speckled band inside the rubber ring; soft wisps on the Big Spanner's shaft; blocky patches on the crate; no holes on the board's back; lamps bloom near-white; HATCH is bitmap lettering; no cable glands.

## Next
- Bolt heads a step brighter than their plates.
- Bolted foot plates on the claws' lugs.
- Lamps held to amber, with sockets.
