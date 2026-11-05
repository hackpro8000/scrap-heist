### Effects:
- on a successful hit, flash the struck bot or player's body white for one frame.
- on a successful hit, nudge the camera back a few studs and let it settle over 0.2s.
- on a successful hit, play the hit sound at the impact point, not at the attacker.
- on a successful hit, spawn a small burst of sparks where the weapon touched.
- when a machine finishes a cycle, burst a few scrap-colored particles from its output slot.
- when a machine finishes a cycle, play a metallic clink from the machine.
- when a machine finishes a cycle, make its output light pulse once.
- when a player collects loot, arc the pickup toward their character with a sparkle trail.
- when a player collects scrap, show a small "+N" number that floats up and fades.
- when a player collects scrap, play a rising chime that gets higher with each pickup in a row.
- when a player collects scrap from a machine, fly scrap pieces out of the machine into their character, with the number scaling with the machine's fill level: a few when it's nearly empty, a burst when it's nearly full. the machine's visual fill level should drop incrementally with each piece that leaves, not jump to the new total.
- add drifting dust motes over the plaza and yard so the islands feel alive.
- add gull-like flecks that cross the sky above the islands every few minutes.
- add a faint shimmer on the water-line of each island.

### Responsiveness:
- current speed is good. exaggerate feedback instead of speeding it up.
- on a hit, scale up the bot's hit reaction by a bigger knockback distance.
- on a button press, squash the button down further and bounce it back.
- on a heavy hit, add a stronger screen shake that decays over 0.3s.
- on a landed hit, freeze the attacker and target for a few frames of hitstop.
- on a landed hit, play a deeper impact sound with a short low thump.
- on a landed hit, flash the screen edge red for a moment.
- on purchase, scale the bought item's icon up past its normal size and bounce it back.
- on purchase, play a louder confirmation sound than pickups use.
- on purchase, show a brief gold ring around the item's card.

### Atmosphere:
- build the sky as a giant inverted sphere roughly 20,000 studs in radius. use SpecialMesh instances, since Roblox limits Part sizes to 2048 studs.
- all atmospheric elements must be hand-drawn, to give off a stylized anime look.
- add massive 3D special meshes in the distance, starting with a Saturn-like planet. they must be SpecialMesh instances, otherwise they cannot render at a distance. they should also be set to persistent so that they don't stream out.
- use a plain skybox as the base, so the planet and other meshes stand out against it.
- place a few distant floating rock formations in the sky at different heights and sizes.
- add a slow-spinning ringed moon that orbits behind the planet.
- scatter faint, slowly rotating distant structures on the horizon to suggest a larger world.
- give the planet pastel banded colors with a sparkling, glowing ring system.
- add a huge rusted cog with visible teeth in the background, partly hidden behind the planet, as a massive distant mesh.
- add a small red-orange moon and two pale moons at different distances, drifting slowly.
- add a faint spiral galaxy wisp in the sky, drawn as a soft translucent shape.
- add distant floating islands with trees and moss, layered at varying distances so the sky reads as a multi-tier world.
- color the sky a saturated blue with soft cumulus clouds.
