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
  Studio imports the joints as Bones for the Animation Editor, each named
  `<name>Bone`: Studio turns a bone that shares a part's name into a Motor6D
  and drops the parts skinned to it.
- `model.clip(name, {length, keys = {Bone = {{t, rot?, pos?}, ...}}})` adds
  an animation. The bots use `Idle`, `Move` and `Attack`. Besides going into
  the GLB, a rigged model's clips are written to `<Name>Clips.luau`, and
  `scripts/build-model.sh` copies that to `src/shared/Animations/<Name>.luau`:
  every frame of each moving bone's `Bone.Transform`, which
  `BotAnimationController` plays in game. No Animation assets are uploaded.

## Importing into Studio

1. Avatar or Home tab → **Import 3D**, pick `<Name>.glb`.
2. Upload it, then paste the asset ID into `src/shared/Assets.luau`.

### Bots, machines, crates and weapons

1. `scripts/build-model.sh Scrapper Bruiser Zapper SalvageMachine StorageCrate PartBundle StarterWeapon BigSpanner`
   (for the bots this also refreshes their clip modules in
   `src/shared/Animations`).
2. `ROBLOX_API_KEY=... ROBLOX_CREATOR_ID=<user id> scripts/upload-model.sh <Name>...`
   uploads each GLB as a Model and writes its ID into `Assets.Models`.
3. In Studio (edit mode, Rojo synced) run `tools/studio/PlaceModels.luau` in
   the command bar, then save the place. It loads:
   - each bot into `ServerStorage.NpcModels`, with a HumanoidRootPart,
     Humanoid and Head built round the imported rig, for `NpcRig`;
   - the salvage machine's tiers into `ServerStorage.MachineModels` as
     `SalvageMachine1`-`3`, pivoted at their art centre, for `MachineService`;
   - the storage crate's six heaps into `ServerStorage.CrateFills`, lined up
     on Yard1's crate in the placed map (so run `PlaceMap` first), for
     `PlotService`;
   - the part bundle's fill levels into `ServerStorage.PartBundle`, for
     `RaidService`;
   - the weapons into `ServerStorage.WeaponModels`, named after their
     WeaponConfig weapon (StarterWeapon is the Bat, BigSpanner the Spanner)
     with a `Grip` attachment, for `HeldWeaponService`.

### Layouts (the Server Map)

A layout is uploaded one object at a time, and only the objects that changed:

1. The build machines (`docs/builds/workers.md`, `scripts/standby.sh`) each
   build their shard, then `scripts/export-objects.py ServerMap` cuts the
   built map into `art/models/ServerMap/objects/<id>.glb`, one per object,
   with a `manifest.json` of every placement. An object is a placed model or
   a slab, known by the key its build is cached under, so copies of a model
   (the eight yard islands, every fence panel) are one object. An object over
   Open Cloud's 20 MB limit is cut into several. An object's id comes from
   its cache key, and the ledger `art/src/layouts/ServerMapUploads.tsv` says
   which ids already have an asset; each machine hands over only the objects
   that don't (`scripts/standby-task.sh`).
2. The uploads overlap the builds. With a coordinator running in the session
   (`scripts/coordinator.sh start`, then `scripts/standby-start.sh 20`), every
   machine keeps a live connection to it (`scripts/standby-agent.py`, over
   Tailscale or a Cloudflare quick tunnel; each proves it is one of this
   repo's standby machines with its GitHub identity token, so no secret rides
   in the public workflow inputs). `scripts/send-build.sh` hands the task to
   them all at once, each machine's results and objects come straight back
   into `.standby-results/<task>/S<i>/`, and the session's one uploader
   (`tools/coordinator/uploader.py`) sends each object the moment it lands.
   Objects landing within a second of each other go up as one bundle, a
   Model of up to 18 MB with each object as a child named by its id
   (`tools/coordinator/bundle.py`); they all get the bundle's asset id, and
   `tools/studio/PlaceMap.luau` loads each bundle once and takes every
   object out by its id.
   The machines also render previews with modelkit's own renderer, no
   Studio and no upload needed: `send-build.sh` lists the layout's models
   whose script changed since their last preview (`PREVIEW=Name,Name` or
   `PREVIEW=all` to choose), and each machine renders its share once its
   build result has gone (`scripts/standby-previews.sh`), so renders never
   hold a build or its uploads back. Each lands in
   `art/models/<Name>/preview.png` and `views.png` as it arrives, and the
   client waits for the last. Finished pictures come back through GitHub
   (`preview-results/` branches), not the tunnel, which only carries short
   messages for previews. When a model is shared between machines, each
   claims texture chunks from one queue until none are left (`modelkit
   --share-bakes --work-port`), so a machine that finishes early takes more,
   pushes those paint layers to its `build-bakes/<Name>-<i>-<n>` branch and
   fetches everyone else's, so no two machines bake the same texture. Then
   they claim the views from a queue the same way. A layer that doesn't arrive is baked
   by the render, so a failed swap costs time, never a wrong picture.
   Its width grows by 0.5 per round of successes up to 64, halves when Roblox
   turns a request away (waiting out `Retry-After`), and is kept in
   `art/models/ServerMap/upload-width.txt` for the next run. Nothing polls.
   The session needs the Roblox key (`ROBLOX_API_KEY`, or
   `~/.config/scrap-heist/roblox-api-key`); `--dry-upload` fakes uploads for
   tests (never merge a dry run's results).
   While a job runs, each machine reports its stage and last log line every
   10 s. `send-build.sh` prints a summary every 30 s and a `STALL S<i>` line
   naming any machine with no new log line for 3 minutes or no report for
   60 s (`RECOVERED S<i>` when it comes back);
   `scripts/coordinator.sh machines` shows each machine. Agents redirect
   `send-build.sh` to a file and watch it with Monitor, never through `tail`,
   so progress and stalls reach the session unprompted. A machine whose
   connection drops mid-job sends its result on the new connection.
   A session that can't connect out starts standby with `--on-machine`:
   machine 1 runs the coordinator and does the uploads, the others reach it
   over the tailnet (the repo's `TS_AUTHKEY` secret), and the session posts
   tasks to the build-queue branch and gets each task's results back as one
   commit on `build-results/coordinator`, checked every 10 s. Without either,
   machines fall back to the build-queue branch and shard 1 uploads at the end
   (`scripts/standby.sh`, `scripts/upload-objects.py`).
3. `scripts/merge-shards.sh ServerMap .standby-results/<task>/S*` adds the new
   uploads to the ledger and writes `Assets.MapChunks` (each object's asset
   ID) and `src/shared/Config/MapChunks.luau` (every placement). Commit all
   three. It prints the new asset IDs: the game is owned by a group and the
   uploads by a user, so each new asset needs the game's permission to use
   it (Open Cloud `asset-permissions-api`, at most 50 per request) before
   Studio can load it.
4. In Studio, with Rojo synced, paste `tools/studio/PlaceMap.luau` into the
   command bar. It loads every object once, copies it to each of its
   placements, lines each copy up by its anchors, anchors the parts, and
   files every part under `workspace.Map` by object: `Map > Line > Walk > 1_0_0`,
   `Map > Yard1 > Gate > Frame`. It turns collision off on the yard gates,
   then hooks the map up to the game: `YardSpots`, a SpawnLocation, and the
   kit. Save the place.

**The kit.** Models the game places itself (pads, the build bay, the crate,
the mound, the press, each tier's capsule and each junkrot) are built in the
layout too, one of each under the label `Kit_<Name>`, out of sight under the
hub (`KIT` at the end of `ServerMap.luau`). They upload with the map, and
`PlaceMap` takes them out of `workspace.Map` and files them where the game
clones them from: `Capsule<Tier>` in `ServerStorage.Capsules` as `<Tier>`,
`Junkrot<Id>` in `ServerStorage.Junkrots` as `<Id>`, and the rest in
`ServerStorage.YardKit`. Where a model is missing the game shows a plain
block, so a junkrot can ship before its art. To add one: write its item,
add it to the layout's `-- uses:` line and to `KIT`, build, upload, merge,
grant, and run `PlaceMap`.

The older whole-map path (`modelkit --chunks`, `scripts/upload-chunks.sh`,
`scripts/worker-job.sh`, the build-map-shards workflow) packs parts into
chunks by size and uploads all of them every time. `scripts/merge-shards.sh`
no longer reads its output.

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

It rebuilds the model, copies `preview.png` to `screenshot.png`, and commits and pushes the `model.luau` source and the model's `art/src` files (source, plan, notes, preview flags) on the current branch (`main`). It also writes `screenshot-grid.png`: the screenshot with a labelled 6×6 grid over the model (A1 top left), beside the model's sketch. `cells.txt` names the parts in each cell. Send `screenshot-grid.png` and `views.png` to the user after each change. Each screenshot is also kept as `history/<commit>.png`. `scripts/model-history.sh <Name> [count]` lays the last ones side by side.

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

A new item or bot goes through the first build below. After that, the loop for each change is:
1. Edit `art/src`, then `scripts/assemble-model.sh <Name>`.
2. `scripts/view-model.sh <Name> <out.png>` (4 turntable angles). Shrink the render before viewing it to save context.
3. `scripts/checkpoint-model.sh <n> "<msg>"`, which commits and pushes. Update the notes file (below) in the same checkpoint. Send the user the gridded screenshot, then end with "Where we are": the goal, what's done, and 2–3 suggested next changes to pick from.

### First build
The aim is a first screenshot that is already good. The steps follow what
worked in agentic modelling research: Procedura (planning was its biggest
single gain), ShapeCraft (parts with explicit boxes, about 3 refine rounds),
and LL3M (geometric checks catch what eyes miss, and edit in place).

1. **Sketch and part plan, approved together.** Write
   `art/src/items/<Name>.plan.luau` (bots: `art/src/bots/<Name>/plan.luau`).
   It is a flat list of the parts the game camera sees, with these rules:
   - The core part comes first, and every later part `attaches` to an earlier one.
   - Each part gets a centre `at` and `size` in studs.
   - Mirrors (`mirror = "DoorLeft"`) and repeats (`count = 6`) are declared once.
   - Names match `model.part` names.
   - Spaces a player uses get a `clearance` entry against the 4×5.5 capsule.

   ```luau
   return {
   	parts = {
   		{ name = "Frame", level = "core", at = { 0, 0, 6 }, size = { 8, 6, 12 }, note = "upright arch the rest hangs on" },
   		{ name = "DoorLeft", level = "major", attaches = "Frame", at = { -2, -3, 3 }, size = { 2, 0.5, 6 } },
   		{ name = "DoorRight", mirror = "DoorLeft" },
   		{ name = "Rivet", level = "detail", attaches = "Frame", count = 6 },
   	},
   	clearance = { { part = "Frame", width = 5, height = 6.5 } },
   }
   ```

   Send the sketch and the plan as a short table (part, attaches to, size,
   note) for approval.
2. **Draft** the parts in plan order, core first, from the shapes in
   `docs/art/shapes.md`. Small detail is painted. Run
   `lune run tools/modelcheck/check <Name>` until the plan check passes.
3. **Critique, at most 3 rounds, stopping early once nothing is HIGH or MED.** Each round:
   - Run `scripts/review-model.sh <Name>`. It writes `review.png` (sketch, preview, part colours, front/right/top on a 1-stud grid) and prints the part legend and check output.
   - Send the `model-critic` agent the paths of `review.png`, the sketch and the plan, plus the legend and check output. From round 2, also send its previous list. Reuse the same agent across rounds with SendMessage. Run `scripts/critic-atlas.sh <Name>` and send it the atlases it prints, not separate images, so it can review in a couple of tool calls.
   - If its reply has `VIEW:` lines, run `scripts/critic-views.sh <Name> "<flags>" ...` with what it asked for and send it the one atlas it prints. The round isn't done until it stops asking.
   - Fix only what it listed, editing in place. Don't regenerate parts it didn't flag.
4. **Checkpoint once** with `checkpoint-model.sh`. Write the notes file, then send the gridded screenshot and anything the critic still lists. From here it's one change per checkpoint.

### When the feedback is vague
"Something's off", "meh", "not quite": don't guess and edit. People find
problems more easily than they describe them, and criticise more freely
when shown alternatives.
1. If they point ("C4", "that thing at B2"), look the cell up in `cells.txt`.
2. Otherwise, run the critic on the current build. Turn its top 3–4 issues
   into a multi-select question in plain words (`docs/art/feedback-words.md`),
   plus "none of these".
3. For what they pick, or for "none", build 2–3 variants with
   `--preview` in fixed scratch folders (the `model-previewer` agent), nothing
   committed. Lay them out as A/B/C beside the current version and send the
   sheet.
4. Checkpoint only the pick. "Closer to B but more" gets a second set
   around B.

### When the critic misses something
When the user points out a defect in a model and the critic's last list doesn't have it, the critic's rules grow, in that same turn and without being asked:
1. Add a rule to `docs/art/critic-rules.md` for the kind of defect, not the one instance, so it applies to any model. Don't name the model or the instance. If a rule nearly covers it, sharpen that rule instead.
2. Prove it works: a fresh `model-critic`, given the same render and none of the user's words, has to list the defect. If it doesn't, sharpen the rule and try once more, then tell the user how that went.
3. Fix the defect the usual way, commit the rule with the model's checkpoint, and tell the user the new rule in one line.

A matter of taste or a change of mind ("make it bluer") isn't a miss and makes no rule.

### Keeping the direction
`art/src/items/<Name>.notes.md` (bots: `art/src/bots/<Name>/notes.md`) is
committed with each checkpoint and holds:
- **Goal:** one line from the approved sketch.
- **Decided:** what was settled and why, newest last.
- **Open:** the critic's last list and anything the user raised.
- **Next:** 2–3 suggested changes.

Read it first when resuming a model. If the user is lost, send the "Where
we are" from it and the strip from `scripts/model-history.sh <Name>`. If they
pick an older checkpoint, restore its sources (`git checkout <commit> --
<paths>`) and checkpoint that as a new commit.

Rules:
- Batch small models into one pass.
- Shading layers: warp, weathering, edge highlights, contact shadows, gradient (`EDGE_HIGHLIGHT` 0.6, `CONTACT_SHADOW` 0.85, `GRADIENT` 0.5, `EDGE_BLEND` 0.7, `WARP` 0.0385). A part with `rust` 0 gets no warp or weathering; use it for glow cores.
- Items carry the rarity accent color from `rarity.luau`. The legendary glow is painted only, with no light objects.
