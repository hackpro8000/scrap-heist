# Operation costs

Status: first pass, 2026-11-11. Read from the code, not measured. No constants (seconds per unit) are known yet; those come from a calibration run.

How each cost grows with its input, for the model scripts (`art/src/common.luau`), the baker (`tools/modelkit/src`) and the steps around them. Part of `autonomous-pipeline.md`.

## Symbols

| Symbol | Meaning |
|---|---|
| V, F, T | vertices, faces, triangles of one mesh |
| X | texels of one texture (width × height, at most 1024 × 1024) |
| P | parts in one slab or model (everything finished together) |
| G | chunks of one chunked part |
| V_all, T_all | vertices, triangles of every part in the slab or the whole chunked part |
| S | triangles within shading reach of a part |
| K | triangles near one texel (its grid cell and the 26 round it) |
| N | brush strokes scattered on a part |
| k | strokes that overlap one texel |
| C | UV charts of a mesh |

## Heaviest first

Operations whose cost grows faster than the thing they work on. These are where the time and memory go as the map grows.

| # | Operation | Where | Cost | Why it is heavy |
|---|---|---|---|---|
| 1 | Coat and wear of one chunk scatter strokes over the whole part, then drop the far ones | `bake.rs` `paint_shading`, `coat.rs` `scatter` | O(T_all + N_all) per chunk, O(G × N_all) per part | Quadratic in part size. The island top is one part. |
| 2 | Merging the whole part into one mesh, once per chunk | `bake.rs` `merged_part` | O(V_all + F_all) per chunk, O(G × V_all) per part | Quadratic, and it allocates the whole part each time. |
| 3 | Edge field of every sibling chunk loaded to paint one chunk, then kept | `bake.rs` `sibling_field` | O(G) shade passes per process; memory O(sum of X over the part × 12 bytes) | Memory grows with the whole part, on every machine. |
| 4 | "Is this part near that one" recomputes both bounding boxes every call | `bake.rs` `within_reach`, `bounds` | O(V_a + V_b) per call; O(P × V_all) per part, per layer | Runs for every occluder, for each of four layers, even when the layer is cached. |
| 5 | Building the occluder list for every part | `common.luau` `finishParts` | O(P²) | Every part lists every other part. |
| 6 | Weld | `mesh.rs` `weld` | O(V²) | Each vertex is compared with every kept vertex. Runs on every chunk. |
| 7 | Cache key of a coat or wear layer hashes the whole colour image | `cache.rs` `layer_path` | O(X + V + F) per layer | Paid on every cache hit. |
| 8 | Cache prune | `cache.rs` `prune` | O(files × used files) | Linear search of the used list for every file. |
| 9 | Ear clipping | `common.luau` `earClip` | O(n³) worst case in outline points | Small n today, so cheap in practice. |
| 10 | Octant split re-unwraps a chunk at every level | `common.luau` `chunkedPart` `emit` | O(F_chunk × depth), depth up to 6 | Unwrap repeated per level. |
| 11 | Contact grid files a big triangle in every cell its plane crosses | `bake.rs` `shade_pass` | O(sum over S of cells in the triangle's box inside the chunk) | A large flat neighbour fills a whole layer of cells. |
| 12 | Compiling the baker on a fresh machine | machine start | fixed, about 100 s seen in the 2026-11-10 logs | Paid by all 20 machines on the first task of a run. |

Items 1 to 3 together are the likely reason the island bake filled 16 GB on every machine. That is read from the code and not yet confirmed by measurement.

## Model script helpers (`art/src/common.luau`)

| Operation | Cost | Notes |
|---|---|---|
| `useTexelDensity` | O(1) | |
| `gridFace` | O(nu × nv) | |
| `box` | O(nx·ny + ny·nz + nx·nz), capped at 384 faces | each side is split every 0.4 studs, at most 8 |
| `cylinder` | O(sides) | |
| `sphere` | O(rings × sides) | |
| `ring` | O(sides) | 4 faces per side |
| `bolt` | O(1) | a 6-sided cylinder |
| `strut` | O(1) | 8 vertices, 6 faces |
| `arc` | O(steps) | |
| `earClip` | O(n³) worst, O(n²) typical | n outline points |
| `plate` | O(n) plus `earClip` | |
| `crossFrame` | O(1) | |
| `tube` | O(points × sides) | |
| `roundedPath` | O(points × steps) | |
| `onAxis` | O(1) | |
| `gear` | O(teeth) | 16 vertices and faces per tooth, plus an 8-sided shaft |
| `belt` | O(1) | 19 points, 4 sides |
| `exhaust` | O(points) | 10 sides |
| `engine` | O(1) | 2 boxes, 1 cylinder, 4 rings |
| `stud` | O(1) | |
| `rope` | O(path length ÷ radius) | resampled every 0.8 radius, two 6-sided strands |
| `lashing` | O(perimeter ÷ radius) | via `rope` |
| `sheet` | O(1) | a box and 4 bolts |
| `cornerBracket` | O(1) | 2 boxes and 4 bolts |
| `rusting` | O(1) | |
| `imperfect` set-up | O(name length) | |
| `imperfect` per vertex | O(1) | 9 sines and 2 exponentials on every vertex of every warped part |
| `setLook` | O(1) | |
| `part` | O(build + V + F + unwrap + X) | X for the blank image |
| `chunkedPart` record and bin | O(V + F) | |
| `chunkedPart` per chunk | O(F_chunk × depth) + weld O(V_chunk²) + `part` | see heaviest 6 and 10 |
| `finishParts` | O(P²) + the bake of every part | see heaviest 5 |

## Mesh operations (`mesh.rs`, `bake.rs`)

| Operation | Cost |
|---|---|
| `sub`, `add`, `scale`, `dot`, `cross`, `normalize`, `hash`, `to_linear`, `to_srgb`, `rim` | O(1) each |
| `vertex` | O(1) |
| `face` | O(corners) |
| `face_normal` | O(corners) |
| `weld` | O(V²) |
| `triangles` | O(F × faces per vertex) |
| `solidify` | O(V + F) |
| `indexed` | O(T) |
| `edge_faces` | O(F) |
| `unwrap` | O(F + C log C + C × shrink steps) |
| `bounds` | O(V) |
| `within_reach` | O(V_a + V_b), nothing kept between calls |
| `mesh_triangles` | O(T) |
| `merged_part` | O(V_all + F_all) |
| `hash_mesh` | O(V + F) |

## Texturing, per part (`bake.rs`, `coat.rs`, `hand.rs`, `marks.rs`, `brush.rs`)

| Operation | Cost | Notes |
|---|---|---|
| `texels` / `samples` | O(T + X) | each triangle walks its box of pixels |
| `tangent_frame` | O(1) | per triangle |
| Shade pass: gather neighbours | O(G + P) reach tests, each O(V) | heaviest 4 |
| Shade pass: contact grid | O(sum over S of cells) | heaviest 11 |
| Shade pass: neighbourhood per occupied cell | O(27 + K log K) | |
| Shade pass: paint per texel (`crease_paint`) | O(K), so O(X × K) per texture | on the GPU when there is one |
| `crease_runs` | O(S) | only for moving-hand highlights |
| `closest_on_triangle`, `corner_taper`, `corner_distance`, `edge_frame`, `run_distance`, `to_zero_taper` | O(1) each | called per texel per near surface |
| `soft_wander`, `painted_strokes`, `brush_strokes` | O(1) each | per texel |
| `dilate` | O(passes × X) | copies the whole image each pass |
| `layer_image` | O(X) | |
| `shade_key` | O(1) | |
| `sibling_field` | one shade pass per sibling, kept for the run | heaviest 3 |
| `layer_path` (cache key) | O(V + F + P reach tests + X when colour is keyed) | heaviest 4 and 7 |
| `cached_layer` load or save | O(X) bytes of disk, 12 bytes per texel per image | |
| Coat: `scatter` | O(T_all + N_all) | heaviest 1 |
| Coat: colour callback into the model script | O(N) calls, one thread | cannot run in parallel |
| Coat: `Canvas::add` | O(cells a stroke covers) | per stroke |
| Coat: paint per texel (`Canvas::paint`, `over`) | O(k), so O(X × k) | |
| Crisp coat | O(X) script calls, one thread | |
| Hand coat: `candidates` | O(T_all + N_all) per layer | |
| Hand coat: `prepare` | O(layers × N) | |
| Hand coat: `cover` | O(steps) per stroke per texel | fixed step count |
| Hand coat: `colour` per texel | O(k) | |
| Hand coat: `lost_and_found` | O(E log E) in edges | |
| Wear layer | O(T_all + N_all) scatter, O(X × k) paint | |
| Soft highlight layer | O(S cells) + O(X × K) | |
| Marks (`along_strokes`, `flicks`, `zigzag`, `retrace`, `twist`, `drag_off`, `scrub`, `overshoot`, `crosshatch`, `stipple`, `loops`) | O(search window) each, a small fixed number | per texel |
| Brush (`tone`, `cover`, `sponge`, `stamp_alpha`) | O(1) each | per stroke per texel |
| Normal, roughness, metalness maps | O(X) each | from the stored edge field |
| `ImageSampler::new` | O(X) | |
| `ImageSampler::color` | O(texels in 27 cells) | |

## Storage, export and render

| Operation | Cost | Notes |
|---|---|---|
| Part cache `save` / `load` | O(V + F + X) | 12 bytes per texel colour, plus 4 alpha, 12 normal, 4 roughness, 4 metalness |
| Layer cache `save_layers` / `load_layers` | O(X) | 12 bytes per texel per image; the shade layer holds 2 images |
| `prune` | O(files × used) | heaviest 8 |
| `encode_png` and the map encoders | O(X) | |
| `half` | O(X) | |
| `detail.shrink` | O(T × eyes) | |
| `glb::write` | O(T + X) per part | |
| `write_chunks` | O(P + bytes) | |
| `render` / `draw` | O(T × pixels covered) | per view |
| `fxaa` | O(pixels) | |
| `blur` | O(pixels × radius) | |
| Animation (`sample`, `local`, `skin`, `write_luau`) | O(bones × frames) | |

## Pipeline steps

Seen in logs where a number is given; otherwise read from the scripts at outline level.

| Step | Cost | Seen |
|---|---|---|
| `assemble-model.sh` | O(source bytes) | 0 to 1 s for 308,663 lines |
| Model check (`check-models.sh`) | O(V + F) per model | skipped when nothing changed |
| `push-wip.sh` / `send-build.sh` | O(changed bytes) + one request per machine | |
| Machine start, checkout | fixed per machine | |
| Cache restore and save | O(cache bytes) | 260 to 370 MB per machine |
| Compiling the baker | fixed | about 100 s on a fresh machine |
| Bake, warm | O(P) cache loads, plus heaviest 4 and 7 | 110 to 121 s per machine |
| Bake, cold island | see "Heaviest first" | under 5 minutes per machine on 2026-11-10 |
| `export-objects.py` | O(P + bytes) | |
| Hand-over and upload | O(objects), limited by Roblox rate limits | |
| Placing in Studio | O(objects) | |
| Screenshots | O(shots) | 1084 shots in the last review |
| Critic round | O(images) per critic | |

## Coverage

- Every helper in `common.luau` is listed.
- `mesh.rs`, `cache.rs` and the shade and coat paths of `bake.rs` were read line by line.
- `coat.rs`, `hand.rs`, `marks.rs`, `brush.rs`, `render.rs`, `gpu.rs`, `glb.rs`, `anim.rs`, `detail.rs` and the shell scripts were read at outline level: function lists and loops. Their rows are less certain.
- `layouts/prelude.luau` (placement, `placeSlab`, `placeModel`) and the coordinator are not covered yet.

## Measured, 2026-11-11

Cold ServerMap builds on 20 build machines (4 cores, 16 GB each), no cache, engine time only. Every round was proven byte-identical on the sample models (`scripts/bake-proof.sh`), and the last three map builds match object for object by content hash (182 objects).

| Build | Engine time, 20 machines | Slowest machine | Coat | Shade | CPU in use | Peak memory |
|---|---|---|---|---|---|---|
| First cold build | 6,786 s | 459 s | 3,842 s | 1,696 s | 42% | 10.7 GB |
| Coat strokes that cannot touch the chunk dropped before their colour is asked for | 5,345 s | 387 s | 2,406 s | 1,736 s | 45% | 10.7 GB |
| Shade pass beside the coat's stroke laying, own pass only | 5,203 s | 383 s | 2,384 s | 1,744 s | 46% | 10.8 GB |
| The same, neighbours' shade passes included | 4,747 s | 352 s | 2,607 s | 1,851 s | 52% | 10.9 GB |

Coat and shade overlap in the last two rows, so their sum is more than the wall time.

What the numbers say:
- The island is 88% of the map's bake. Everything else is about 12%.
- The coat's stroke laying runs on one core, because each stroke's colour is one call into the model script. It is still the largest single cost.
- Two machines with the same island texels (33.9 million each) took 134 s and 271 s for them. The island is dealt by texels, and texels are a poor measure of cost.
- Thin LTO and one codegen unit made no measurable difference to the bake.
- Compiling the engine took about 100 s per fresh machine until the compiled engine was shared on the `build-engine` branch.

### Later the same day

| Build | Engine time, 20 machines | Slowest machine | CPU in use |
|---|---|---|---|
| Each dirt chunk handed only the cracks near it | 3,089 s | 243 s | 64% |
| Far surfaces turned away before the nearest-point step; final source | 3,017 s | 237 s | 62% |

From the first cold build: 56% less engine time, 48% off the slowest machine. Every build from the crack fix on matches the one before it object for object by content hash (212 objects).

The crack fix was the largest single gain. Every dirt chunk had been handed the whole island's crack strokes, and the bake read and filed all of them per chunk: a fixed 1.9 s on each of 664 dirt parts.

Where a cold bake goes now (stages overlap, so they sum past the total):

| Stage | Seconds | Share |
|---|---|---|
| Shade, painting each texel (all cores) | 1,661 | 55% |
| Coat, laying strokes (one core: a script call per stroke) | 1,041 | 35% |
| Shade, surfaces, grid and finding texels (one core) | 345 | 11% |
| Shade, spreading over seams | 218 | 7% |
| Wear | 159 | 5% |
| Shade, neighbour lists (one core) | 78 | 3% |
| Coat, painting texels | 71 | 2% |

Tried and dropped, each measured on a cold map build:
- Finding texels on all cores, a triangle at a time or in batches of 256: slower both times (398 s to 513 s, then 341 s to 524 s).
- Gathering neighbour lists on all cores: slower (about 80 s to 135 s).
- Refreshing `ServerMapCosts.txt` from measured times: 6% off the slowest machine, but it regrouped parts into different objects (212 to 196), which breaks the object-for-object check and would re-upload them.
- Thin LTO: no measurable change. Left on.
