# Model pipeline

Models are Luau scripts run by `modelkit`, a small Rust engine in
`tools/modelkit` that builds meshes, paints and bakes textures, and writes a
`.glb` with a preview render. No Blender, no GPU; a model builds in seconds.

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
git), keyed on that model's source and its placement, so a rebuild only
re-runs the props that changed. A script can cache its own work with
`model.cached(key, build)`, where `build` returns a list of
`{name, mesh, image, preview}` and `key` changes whenever the result would.
Delete `.cache` to force a full rebuild.

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

## Saving changes
Every model change, however small, ends with a checkpoint so no progress is lost:

```
scripts/checkpoint-model.sh <Name> "phase N: <Name> - <change>"
```

It rebuilds the model, copies `preview.png` to `screenshot.png`, and commits and pushes the `models` branch. Send that screenshot to the user after each change.

### Branches
Generated files (`.glb`, textures, `preview.png`) live only on the `models` branch, so the code branch stays free of binary noise. The code branch keeps the tooling (`modelkit`, build scripts, `model.luau` sources) and these docs. Merge the code branch into `models` to pick up tooling changes.

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

## Session workflow
Sources live in `art/src`, and `art/models/<Name>/model.luau` is generated from them; never edit it by hand.
- Bots: `art/src/bots/<Name>/{head,body}.luau`, assembled as head + `common.luau` + body.
- Items: `art/src/items/<Name>.luau`, assembled as `rarity.luau` + `common.luau` + item.

Loop for each change:
1. Get the user to approve a sketch before modeling anything new.
2. Edit `art/src`, then `scripts/assemble-model.sh <Name>`.
3. `scripts/view-model.sh <Name> <out.png>` (4 turntable angles). Shrink the render before viewing it to save context.
4. `scripts/checkpoint-model.sh <n> "<msg>"` on `models`, bring the changed paths onto the code branch with `git checkout origin/models -- <paths>`, commit, push, and send the user the screenshot.

Rules:
- Batch small models into one pass.
- Shading layers: warp, weathering, edge highlights, contact shadows, gradient (`EDGE_HIGHLIGHT` 0.6, `CONTACT_SHADOW` 0.85, `GRADIENT` 0.5, `EDGE_BLEND` 0.7, `WARP` 0.0385). A part with `rust` 0 gets no warp or weathering; use it for glow cores.
- Items carry the rarity accent color from `rarity.luau`. The legendary glow is painted only, with no light objects.
