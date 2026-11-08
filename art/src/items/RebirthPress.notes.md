# RebirthPress notes

**Goal:** the yard's hydraulic press that flattens its scrap pile into a medal, remade bigger and busier so it says what it does (art/concepts/rebirth-press-sketch.png).

## Decided
- Remake (user: the old yard props were too flat and small, too plain, and didn't say what they do). Same 16 by 8 footprint so the yard layout holds; 15.2 tall against the old 7.6. Front is -y; nothing is walked through, the player stands on the ground at the front, the plinth is a 1.2 step and the platen hangs 5.6 over the bed.
- Style follows the factory and the sky cog: riveted dark steel, bronze caps and name plate, crisp hazard tape (the plinth band, platen rim and button cage are `crisp` parts), orange beacons.
- Baked at the yard kit's 40 px per stud (`useTexelDensity(40)`). The kit is `KIT_DENSITY` in the ServerMap layout, and an item's own call overrides the layout's, so the two must agree. Previews at max detail.
- First build, two critic rounds: plinth with slot and tray; anvil 1.3 thick with dark sides; two riveted box columns a step lighter than the plinth and crown with wide bronze bands; crown with the REBIRTH plate (block letters painted from a 5 by 7 bitmap) and a gauge; cylinder, ram and hazard-rimmed platen; the heap as mounds 2.9 proud of the anvil with small cans and pipe ends pressed in and the big pieces (brass gear, silver hubcap, three painted cans, a spring) as their own part; a brass medal 2.2 across in the tray; console with caged red button, lever, gauge and lamp; grey hoses with brass collars to a pump out past the -x column; beacons on the crown corners.
- Fitted to its cells: the game centres a yard thing's bounding box on its cells, so the flat tray 1.5 past the front edge shifted the whole press 0.65 back and overhung its neighbours. Now a concrete pad exactly 16 by 8, the steel bed set back 1.4 from its front, the pump inside the bed's edges, and a ramp from a dark mouth at the anvil's front edge down to a lip, the medal (its own part, 2.2 across) leaning at its foot and facing whoever walks up. The sketch still shows the flat tray. One review round.

## Open
- Critic, all LOW: the ramp's mouth could be taller and wider than the medal, and its cheeks match the anvil so it can read as a display stand; the concrete apron is plain (an edge line, anchor bolts, a hazard tick at the ramp's foot); the medal reads a little like a coin or gong (an emblem or ribbon loop); the cans and spring are lost at preview scale; the hoses are thin from afar; the pump is hard to see.
- The clipping check flags the intended seating: the mounds' buried halves in the anvil and plinth, the junk pressed into the heap, the ramp's back in the bed.

## Next
- An emblem on the medal and darker cheeks on the ramp.
- The cans and spring about 30% bigger on the heap's front slope.
