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
- `mesh:paintShading(image, {highlight, shadow, bands, sharp, blend, occluders})`. `blend` 0-1 (default 0) feathers edge highlights and tints them from cream toward the part's own color.
- `model.part(name, mesh, image, {group, preview})`. Parts sharing a group
  are one variant (a fill level, an upgrade tier); `preview` picks what the
  preview shows.

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
