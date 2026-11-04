# Model pipeline

Models are Luau scripts run by `modelkit`, a small Rust engine in
`tools/modelkit` that builds meshes, paints and bakes textures, and writes a
`.glb` with a preview render. No Blender; a model builds in seconds.

The shading bake's per-texel passes (contact creases, coat, wear) run as
compute shaders on the GPU when there is one (`tools/modelkit/src/gpu.rs`,
`crease.wgsl`, `canvas.wgsl`), and on the CPU threads otherwise, such as in
cloud sessions. The build prints which it used. `MODELKIT_GPU=off` forces the
CPU bake. GPU textures match the CPU ones up to f32 rounding (well under 1% of
texels differ), so cached layers from either can be mixed.

## Layout

```
art/models/<Name>/
├── model.luau        # builds the model (the source of truth)
├── <Name>.glb        # generated, import this into Roblox Studio
├── <Part>.png        # generated color texture per part
├── <Part>_Metalness.png, <Part>_Roughness.png   # flat: zero metal, fully rough
├── <Part>_Emissive.png  # glowing parts only: EmissiveMaskContent (set EmissiveStrength to match)
└── preview.png       # generated 3/4 render for review
tools/modelkit/             # the engine (Rust, mlua + Luau)
tools/modelkit/bin/         # prebuilt engine, so sessions need no Rust
scripts/build-model.sh      # runs model.luau with the prebuilt engine
```

## Building

```sh
scripts/build-model.sh StarterWeapon   # one model
scripts/build-model.sh                 # every model
tools/modelkit/bin/modelkit-linux-x64 art/models/<Name> --turntable 60   # MP4 frames
```

Layouts cache each placed model in `art/models/<Name>/.cache` (ignored by
git), keyed on that model's source and stretch. Each is built once at the
origin and moved into place, so moving a prop is free and a rebuild only
re-runs the props whose source changed. A script can cache its own work with
`model.cached(key, build)`, where `build` returns a list of
`{name, mesh, image, preview}` and `key` changes whenever the result would.
Delete `.cache` to force a full rebuild.

Layout pieces built in place (slabs: islands, bridges, the road) are cached
too, in place rather than at the origin, because their paint can read world
position. `scripts/assemble-model.sh` keys each slab on its own body plus
everything around the slab bodies, so editing one slab rebuilds only that
slab and editing a shared helper rebuilds them all. Parts the layout's
`skipPart` leaves out never reach the cache.

Rules that keep rebuilds fast:

- Every piece a layout builds itself goes through `placeSlab` (in ServerMap,
  `slab(label, function() ... end, x, y, turn)`). Start the body on a line
  ending in `function()` and close it with `end` at the same indent, so the
  assembler finds it; `placeSlab` errors on a body it has no key for.
- A slab body may depend only on its own code, code outside the slab
  bodies, and its label and placement. It must not read state another slab
  body changes, since that wouldn't change its key.
- Prop textures are at most 1024×1024. A prop's cache file is a few MB; one
  over 20MB means a texture is oversized or the prop builds parts no layout
  shows. Check with `ls -laS art/models/<Layout>/.cache`.
- Large meshes (terrain, roads, floors) are built with `chunkedPart`, which
  splits them into cubic chunks, each a part with a texture up to 1024×1024
  named `<Part>_<cx>_<cy>_<cz>`. Chunks are 128 studs, or 1024 texels at the
  layout's texel density when that is smaller (64 studs at 16 px/stud). No
  single part spans more than one chunk or uses a texture over 1024.
- `paint` averages a 2×2 grid of samples per texel, so painted stripes and
  edges come out anti-aliased.
- A layout can call `useTexelDensity(pixelsPerStud)` so each of its own parts
  sizes its texture from its UV scale (16 to 1024 px) instead of the fixed
  256 or a per-part override. Props in the layout keep their own sizes.
- After a layout change, a second build with nothing changed should finish
  in seconds (ServerMap: about 15s against 100s cold). If it doesn't, find
  what isn't cached before going on.

## Changing the engine

The cloud setup doesn't install Rust. To change `tools/modelkit/src`, install
it first (`curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal`
and `apt-get install build-essential`). With Rust present,
`scripts/build-model.sh` rebuilds the engine and refreshes
`tools/modelkit/bin/modelkit-linux-x64`; commit that binary with the source
change.

## Script API

Z-up, 1 unit = 1 stud. `art/models/PartBundle/model.luau` is a short
reference.

- `Mesh.new()`, `mesh:vertex(x, y, z)` (returns a 1-based index),
  `mesh:face(verts, uvs?)` with `uvs` as `{u1, v1, u2, v2, ...}`.
- `mesh:setSmooth(true | false | angle)`, `mesh:solidify(thickness)`
  (negative grows inward; drops UVs), `mesh:unwrap(margin?)`.
- `Image.new(w, h, r?, g?, b?)`, `image:set(x, y, r, g, b)` (y = 0 is the
  bottom row).
- `mesh:paint(image, function(x, y, z, nx, ny, nz) return r, g, b end)`.
- `mesh:paintShading(image, {highlight, shadow, bands, sharp, blend, occluders, gradient})`. `blend` 0-1 (default 0) feathers edge highlights and tints them from cream toward the part's own color. `gradient` 0-1 darkens toward the base for a top-lit falloff.
- `model.part(name, mesh, image, {group, preview})`. Parts sharing a group
  are one variant (a fill level, an upgrade tier); `preview` picks what the
  preview shows. `bone` names the bone the part follows.
- `model.bone(name, {at = {x, y, z}, parent = "Name"?})` adds a rig joint
  pivoting at `at`. Add bones before the parts that use them. Once a model
  has bones, every part needs one: each part follows its bone rigidly, and
  Studio imports the joints as Bones for the Animation Editor.

## Importing into Studio

1. Avatar or Home tab → **Import 3D**, pick `<Name>.glb`.
2. Upload it, then paste the asset ID into `src/shared/Assets.luau`.

### Layouts too big for one upload (the Server Map)

Open Cloud takes at most 20 MB per upload, so a layout is exported in
chunks and put back together in Studio:

1. `scripts/build-model.sh ServerMap -- --chunks` writes
   `art/models/ServerMap/chunks/ServerMap_NN.glb`, each under 19 MB, and
   `ServerMapChunks.luau`, which names two anchor parts per chunk and where
   their middles stand.
2. `ROBLOX_API_KEY=... ROBLOX_CREATOR_ID=<user id> scripts/upload-chunks.sh ServerMap`
   uploads each chunk as a Model (the key needs `asset:write`), writes the IDs
   into `Assets.MapChunks` and copies the anchors to
   `src/shared/Config/MapChunks.luau`. Commit both. Re-running skips chunks
   already uploaded.
3. In Studio, with Rojo synced, paste `tools/studio/PlaceMap.luau` into the
   command bar. It loads every chunk, scales, turns and moves it so its
   anchors land in place, anchors the parts, gives the propeller blur discs
   a Transparency of 0.02 so their texture's alpha blends, and files every
   part under
   `workspace.Map` by object: `Map > Pad1 > Plaza > 1_0_0`,
   `Map > Yard1 > Gate > Frame`. Save the place.

Rebuilding the chunks makes new files, so upload them again and commit the new
IDs and anchors together.

## Quick tweaks

To tune settings fast, keep the model building while you edit:

```
scripts/watch-model.sh <Name> [--eye EX,EY,EZ,TX,TY,TZ ...]
```

It re-assembles on every save under `art/src` and re-renders
`art/models/<Name>/preview.png` (and `eye_N.png` per `--eye`) at preview
density, committing nothing. Checkpoint once the result is right.

## Saving changes
Every model change, however small, ends with a checkpoint so no progress is lost:

```
scripts/checkpoint-model.sh <Name> "phase N: <Name> - <change>"
```

The checkpoint also renders four turns round the model into `views.png`, so a
change needs no separate preview pass.

It rebuilds the model, copies `preview.png` to `screenshot.png`, and commits and pushes the `model.luau` source on the current branch (`main`). Send that screenshot to the user after each change.

### Branch
Code, tooling and models all live on `main`; there is no separate models branch. Generated files (`.glb`, textures, `preview.png`, `screenshot.png`) are gitignored; rebuild them with `scripts/build-model.sh <Name>`. Only `model.luau` (and a `sketch.png`, if any) is committed.

## Lessons from past models

### Working with Tristen
- Sketch a new model first and get approval before modeling it.
- One change at a time, each followed by a checkpoint and a screenshot, so Tristen can steer early.
- Keep geometry efficient. Get detail from painted shading (`mesh:paintShading`) rather than extra polygons.
- Send videos as MP4, never GIF. Put any tool installs in `scripts/cloud-setup.sh`.
- If something can't be seen in a screenshot, say so instead of waiting for Tristen to notice.

### Technique
- Look at the full render before cropping it.
- Give each part its own image; `paintShading` writes into the image it is given.
- Pass nearby meshes as `occluders` to `paintShading` so they cast contact shadows. Use this to ground parts on a surface.
- Check that every variant reads from the game camera. A low fill level can hide behind the crate wall.
- For a see-through part (a propeller blur disc, glass), return a fourth value, the opacity, from the `mesh:paint` colour fn. The image gains an alpha channel, the PNG is written as RGBA, the glb material uses `alphaMode` BLEND, and previews blend it over solid parts. In Roblox, give that part a small Transparency (0.02): the importer hands it a plain TextureID, and Roblox only blends a MeshPart texture's alpha once the part is a little transparent. Paint it flat, without `paintShading`.

## Session workflow
Sources live in `art/src`, and `art/models/<Name>/model.luau` is generated from them; never edit it by hand.
- Bots: `art/src/bots/<Name>/{head,body}.luau`, assembled as head + `common.luau` + body.
- Items: `art/src/items/<Name>.luau`, assembled as `rarity.luau` + `common.luau` + item.

Loop for each change:
1. Get the user to approve a sketch before modeling anything new.
2. Edit `art/src`, then `scripts/assemble-model.sh <Name>`.
3. `scripts/view-model.sh <Name> <out.png>` (4 turntable angles). Shrink the render before viewing it to save context.
4. `scripts/checkpoint-model.sh <n> "<msg>"`, which commits and pushes, then send the user the screenshot.

Rules:
- Batch small models into one pass.
- Shading layers: warp, weathering, edge highlights, contact shadows, gradient (`EDGE_HIGHLIGHT` 0.6, `CONTACT_SHADOW` 0.85, `GRADIENT` 0.5, `EDGE_BLEND` 0.7, `WARP` 0.0385). A part with `rust` 0 gets no warp or weathering; use it for glow cores.
- Items carry the rarity accent color from `rarity.luau`. The legendary glow is painted only, with no light objects.
