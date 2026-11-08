# Shapes to build from

Read this before drafting a model (`docs/art/pipeline.md`, "First build"). Reach
for an existing shape before writing vertices by hand, and open the example
model to see it in use. Counts are how many sources use each one today.

## Shared helpers (`art/src/common.luau`, in every item and bot)

| Helper | Makes | Examples |
| --- | --- | --- |
| `box(mesh, cx, cy, cz, sx, sy, sz)` | axis-aligned box [72] | ArenaDrone, BigSpanner, BillboardFrame |
| `cylinder(mesh, cx, cy, cz, r, length, axis, sides)` | cylinder along x, y or z [57] | Barrels, BentBolt |
| `sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)` | squashable UV sphere [21] | Zapper, BuildBay |
| `ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)` | washer: rims, hubs, clamps [42] | ArenaDrone, Barrels |
| `bolt(mesh, cx, cy, cz, axis, size)` | hex bolt head on a flat face [23] | Bruiser, CapsuleRefurbished |
| `stud(mesh, x, y, z, nx, ny, nz, size)` | bolt head on a curved face | Zapper, GearPanel |
| `strut(mesh, x0, y0, z0, x1, y1, z1, thick)` | square beam between two points: limbs, antennae [42] | BillboardFrame, all bots |
| `tube(mesh, points, radius, sides)` | round tube along points, capped [37] | BentBolt, all bots |
| `arc(cx, cz, radius, a0, a1, steps)` | points on an arc, for `plate` outlines | SimpleCar |
| `plate(mesh, outline, y, depth, bevel)` | any flat silhouette, bevelled: signs, blades, brackets | BigSpanner, SimpleCar |
| `sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)` | bolted panel on a box side | Bruiser, JunkrotDingDingDingDongo |
| `cornerBracket(mesh, x, y, sx, sy, z, height, size)` | angle bracket round a box corner | Bruiser, Scrapper |
| `gear(mesh, cx, cy, cz, radius, thick, teeth, axis)` | spur gear with shaft hole [10] | GearPanel, GoldenCog |
| `belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)` | drive belt round two pulleys | bots |
| `engine(mesh, cx, cy, cz, size)` | small finned engine block | bots |
| `exhaust(mesh, points, radius)` | pipe ending in a sooty flared lip | bots, ScrapTreeExhaust |
| `rope(mesh, points, radius)` / `lashing(...)` | twisted rope / rope round a box | Zapper / Bruiser |
| `part(name, bone, color, build, ...)` | adds a part with its look | everything |
| `chunkedPart(...)` | large meshes split into texture-sized chunks | IslandStudy, ShopConceptContainer |
| `finishParts()` | shades parts with each other as occluders, then adds them | everything |

## Edit Mesh (`art/src/shared/EditMesh.luau` + `EditShapes.luau` + `EditOps.luau`, by `-- include:`)

Quad meshes you can select from and reshape. Use them for organic or
sculpted forms (the junkrots are built this way).

Shapes: `lattice`, `box`, `grid`, `disk`, `circle`, `cylinder`, `cone`,
`sphere`, `capsule`, `torus`, `tube`, `prism`, `wedge`, `arch`, `spin`
(lathe a profile), `sweep` (profile along a path, with scale and twist),
`coil`. Examples: JunkrotKit and JunkrotScrap (`spin`, `sweep`),
JunkrotRusteliRustela (`arch`, `tube`), JunkrotPressurwashoSprizzo (`coil`,
`torus`), JunkrotHolofonoShimmerra (`sphere`, `capsule`).

Operations (`EditOps.luau`, header lists them all): `extrude`, `inset`,
`loopCut`, `subdivide`, `smoothSubdivide`, `bridge`, `bridgeFaces`, `bevel`,
`poke`, `bend`/`taper`/`twist`, `smooth`, `push`, `toCircle`, `toSphere`,
`dissolve`, `weld`, `fill`, `mirror`, `solidify`, `array`, `transform`.

## Picking one

- A flat outline (blade, sign, bracket): `plate`, not stacked boxes.
- Mirrored halves: build one side, `mirror` it (Edit Mesh), or loop over `{-1, 1}`.
- Repeats (rivets, slats, teeth): one helper call in a loop, or `array`.
- A rounded or organic body: Edit Mesh `sphere`/`capsule`/`spin`, then
  `smoothSubdivide` and `push`.
- Small detail (seams, scratches, rivet rows on a flat panel): paint it with
  `paintShading` rather than modelling it.
- No helper cuts one shape out of another yet. Make holes with `inset` and
  `extrude` inward, or with `ring`/`tube` walls.
