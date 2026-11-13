# Review views and object lists

How a model is shown to the `model-critic` agent. Every review sees each
object it judges from the same fixed set of views, both alone and, when the
object belongs to a map, standing in that map. The critic also gets a list
of every object with what it is and what it is for. It checks that each
object looks like its description and runs every rule in
`docs/art/critic-rules.md` on it.

## The object list

Every object a critic judges has an entry. For an item or bot, that is each
part in its plan (`art/src/items/<Name>.plan.luau`). For a map, it is each
placed object in the layout, one entry per model or slab label. Two fields
join the plan's `name`, `at`, `size` and `note`:

- `looks`: what it objectively looks like, in plain words a stranger could
  check against a picture. Material, shape, condition, colour. "A rusted
  steel oil drum, ribbed, standing upright, lid on."
- `purpose`: what it is for in the game or the scene. "Clutter by the shop
  door: says the shop sells supplies."

The critic answers every entry, so none is skipped: does the object match
`looks`, does its look serve `purpose`, and which rules does it break.

## Views of an object alone

Each object is rendered by itself, framed to its own bounds `B` (centre `C`,
half-size `H`, the largest of `H` is `R`). Z is up and the front faces -Y,
as everywhere in the pipeline. Isolation views stand the object on a plain
ground sheet at its base, so contact and floating still show.

| # | View | Camera | Catches |
|---|---|---|---|
| 1-6 | **Square-on sides**: front, back, left, right, top, bottom | Orthographic, fitted to `B`, 1-stud grid | Sizes and ratios, alignment, symmetry, holes and missing caps underneath |
| 7-10 | **Three-quarter**: the four corners | 45° round from each side, 30° above level, framing `B` | How the form reads, silhouette, primitives, detail hierarchy |
| 11-12 | **Parts**: two three-quarter corners (front-left, back-right) | As 7-10, each part a flat colour | Which part is which, parts fused or split |
| 13-16 | **Game camera, near**: front, back, left, right | A player standing 3 studs from the object's face, the camera 12.5 studs behind the player's head and looking at it (Roblox's default third-person camera; head at 5 studs) | What a player sees up close: wear, brushwork, scale against the capsule |
| 17-18 | **Game camera, far**: the two front corners | The player 25 studs away | Silhouette and readability from across a space |
| 19-22 | **Ground level**: front, back, left, right | 0.3 studs above the ground, at a distance of `R` + 4, looking level along the base | Floating, sinking, gaps under feet, contact shadows lifted off the ground |
| 23+ | **Every part close**: one per object-list entry | A close-up framing that part (radius 1.3 × its own largest half-size), from the side that faces most toward the front | Each part judged at full detail, so nothing is missed in a crowded view |
| 23+ | **Every join close**: one per `attaches` pair | A close-up at the point where the part meets what it attaches to, radius 1 stud or 1.5 × the smaller part, whichever is larger | Gaps between parts, parts sunk into each other, colour bleed along the seam, missing flanges |
| 23+ | **Every moving part**: at each end of its movement | Close-up as for its part, posed by its animation clip | Clearance through the movement |

Views 1–22 are the fixed set every object gets. The close-ups come from
the object list and the plan, so they grow with the model and none is
chosen by hand.

## Views of an object in its map

When the object belongs to a map, the same object is rendered again with
the whole map around it. These views are framed on the object but show
everything nearby.

| # | View | Camera | Catches |
|---|---|---|---|
| M1 | **Plan from above** | Orthographic straight down, framing a circle of 3 × `R` + 10 round `C` | Orientation against the layout (a ring, a path, a fence), duplicates and overlaps, blocked routes |
| M2-M3 | **Neighbours**: the two front corners | Three-quarter as views 7–10, framing everything within 10 studs of `B` | Scale against neighbours, colour leaks between neighbours, clutter by rule |
| M4 | **The approach** | The game camera from the nearest walkable path, at the distance a player first sees it, up to 40 studs | First impression; whether it faces the way players come |
| M5-M8 | **Ground level in place**: front, back, left, right | As views 19–22, on the map's real ground | Contact with the real terrain, shade sheets lifted or sunk, things to trip over |
| M9 | **From afar** | The game camera from the farthest spot players normally see it from (the hub centre or a yard gate, whichever is farther), when that is over 60 studs | Silhouette and landmark readability at distance |

## A whole map

A map is reviewed in two layers.

1. **Object critics.** The object list is split into scopes: a hub, each
   yard, each rough-edge sector, or about 15 objects each, whichever is
   smaller. Each scope gets its own fresh critic, its slice of the object
   list, and views 1–22, the close-ups and M1–M9 for every object in it.
   A critic judges only its scope, but names a defect it sees outside it in
   one line, for the scope that owns it.
2. **One map critic** for the whole layout, with these views:
   - **Overview**: straight down over the whole map, orthographic, with a
     10-stud grid.
   - **Compass aerials**: eight three-quarter views from the eight compass
     points, 35° above level, framing the whole map.
   - **Spawn look-round**: the game camera at the spawn point, turned to
     each of the eight compass points.
   - **Walked routes**: the game camera every 20 studs along each main route
     (spawn to every yard gate, the shop, the stage, the tinkerer), facing
     along the route.
   - **Edges**: the game camera at each yard gate and every 45° round the
     island's rim, looking outward and back inward.

   The map critic judges what no single object critic can see: layout,
   paths and clearances for the 4 × 5.5 capsule, repetition across the map,
   orientation to the map's shape, sightlines and landmarks, and the rough
   edge.

## Size and cost

At about 24 views per object plus close-ups, a review renders hundreds of
images for a map. Renders are spread over every build machine with
`--renders i/n`, and each critic's views are laid out in atlases
(`scripts/critic-atlas.sh`) under 1560 pixels a side, about 16 tiles each.
An object critic reads its scope in a few atlases, not one image at a time.
