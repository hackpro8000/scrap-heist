# RebirthPress notes

**Goal:** the yard's hydraulic press that flattens its scrap pile into a medal, remade bigger and busier so it says what it does (art/concepts/rebirth-press-sketch.png).

## Decided
- Remake (user: the old yard props were too flat and small, too plain, and didn't say what they do). Same 16 by 8 footprint so the yard layout holds; 15.2 tall against the old 7.6. Front is -y; nothing is walked through, the player stands on the ground at the front, the plinth is a 1.2 step and the platen hangs 5.6 over the bed.
- Style follows the factory and the sky cog: riveted dark steel, bronze caps and name plate, crisp hazard tape (the plinth band, platen rim and button cage are `crisp` parts), orange beacons.
- Baked at the map's 16 px per stud (`useTexelDensity(16)`), as it is in game; previews at max detail.
- First build, two critic rounds: plinth with slot and tray; anvil 1.3 thick with dark sides; two riveted box columns a step lighter than the plinth and crown with wide bronze bands; crown with the REBIRTH plate (block letters painted from a 5 by 7 bitmap) and a gauge; cylinder, ram and hazard-rimmed platen; the heap as mounds 2.9 proud of the anvil with small cans and pipe ends pressed in and the big pieces (brass gear, silver hubcap, three painted cans, a spring) as their own part; a brass medal 2.2 across in the tray; console with caged red button, lever, gauge and lamp; grey hoses with brass collars to a pump out past the -x column; beacons on the crown corners.

## Open
- Critic, all LOW: the cans and spring are lost at preview scale (make them about 30% bigger on the front slope, more saturated); the crest is flatter and wider than the sketch; the hoses are thin lines from afar; a drop chute from the slot to the tray would show the medal's path.
- The clipping check flags the intended seating: the mounds' buried halves in the anvil and plinth, the junk pressed into the heap.

## Next
- Place it in the island's yards (one per yard) and re-render the island.
