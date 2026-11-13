# Render from saved GLBs, with game-renderer speedups

State file for this task (shape: long, two parallel lanes). Any session can
pick it up from here. Goal and design: build each object once to a `.glb`,
then render every review view from the saved files, never re-baking
(`docs/art/review-views.md`). The renderer is our own
`tools/modelkit/src/render.rs`.

Hard rule: nothing is compiled, built or rendered on the user's computer, and
no build cache is kept there. Code is edited locally; the Lead pushes a
snapshot (`scripts/push-wip.sh`) and runs it on the build machines. Subagents
never push or commit.

## Lanes

**Lane A, GLB in** (`tools/modelkit/src/glb.rs`, `tools/modelkit/src/main.rs`,
new `tools/modelkit/src/scene.rs` if wanted):
1. Read a `.glb` that `glb::write` made back into `Part`s: meshes, texture
   coordinates, normals, textures, emissive, see-through, bones posed at rest.
2. Render-only mode: `modelkit --render <a.glb> [<b.glb> ...] --out <dir>`
   with the same view flags as a build (`--size`, `--turntable`, `--eye`,
   `--closeup`, `--view`, `--parts`, `--grid`), or `--views <file>` with one
   view per line (flags, then an output name). Every file is loaded once and
   every view rendered from memory.
3. Lazy textures: a part's texture is decoded only if its bounds fall in at
   least one view.
4. `--glb-check` on a normal build: after writing the `.glb`, load it back,
   render each of the build's views both ways and log
   `GLB_CHECK <view> max=<0-255> mean=<x> direct=<s> glb=<s>`.

**Lane B, faster drawing** (`tools/modelkit/src/render.rs` only):
1. Screen tiles drawn on every core (`std::thread::scope`, no new crate).
2. Frustum culling: whole parts outside the view are skipped before their
   triangles are walked (bounding spheres; `in_view` exists for eyes).
3. Visibility buffer: the first pass keeps only the nearest triangle per
   sample; textures are looked up once per sample after it. See-through
   parts still blend after, as now.
4. Back-face culling as an option on `View` (`cull_back`, off by default),
   since Roblox culls back faces.
5. `--render-check` (passed to `View` or an env var, the worker's choice): every
   render is also drawn by the current code, kept as a reference function,
   and the log gets `RENDER_CHECK <view> max=<0-255> reference=<s> new=<s>`.

## Pass bars (fixed before work started)

Run on the build machines on BuildBay and HubShop with their usual review
views plus `--glb-check --render-check`:
- Lane A: every `GLB_CHECK` line has max_f32 ≤ 2 and mean ≤ 0.2; `--render`
  on the saved `.glb` writes the same set of images as the build. max_f32
  compares against the build's parts rounded as the file stores them (f32
  corners, 8-bit PNG textures). The user chose this on 2026-11-13 over the
  first bar (max ≤ 2 against the unrounded build), which no .glb can meet.
- Lane B: every `RENDER_CHECK` line has max = 0 with `cull_back` off, and
  HubShop's preview draws at least 3× faster than the reference.
- Both: the build itself still passes; `lune run tests/run` still passes.

## Later milestones (not started)

- Mip levels stored beside each `.glb` and loaded per view (streaming).
- Saved GLBs keyed by source fingerprint on the machines; in-map views load
  only neighbours in range.
- The review view generator (`docs/art/review-views.md`).
- Instancing of repeated props; occlusion culling.

## Progress

- 2026-11-12: plan written; machines starting (run 43199196719).
- Round 1 (snapshots `wip/render-b` d11191cd, `wip/render-ab` cd819d3c, built
  from 017dcf71 plus the lane files): both compile first time.
  - Lane B: all 40 RENDER_CHECK lines max=0, owner_mismatch=0. Speed 1.36×
    in total (33.2 s → 24.4 s), median 1.35×, best 3.97×, some views slower.
    Fails 3×. Next: stage timers, mip chains cached across renders, parallel
    bloom/downsample/fxaa.
  - Lane A: GLB_CHECK mean ≤ 0.191 (passes), glb time ≈ direct. max up to 63
    (fails ≤ 2), also on untextured parts views, so likely f32 positions.
    Next: per-corner normals on Mesh instead of pull faces; over2 and
    over2_f32 counts to separate reader errors from file precision.
- Round 2 (`wip/render-a2`, `wip/render-ab2`):
  - Lane B passes: 120 RENDER_CHECK lines all max=0, owner_mismatch=0;
    reference 109.2 s vs new 26.8 s = 4.08×. Stage totals: bloom 9.9 s,
    raster 7.3 s, shade 3.9 s, mips 2.2 s, finish 1.9 s.
  - Lane A: on every untextured parts view over2_f32 = 0, so the reader
    rebuilds geometry exactly; the max spikes (up to 63, at most 329 of
    ~1M pixels) are the glb's f32 positions. Textured views keep at most 22
    pixels over 2 against f32-rounded parts (8-bit textures). This fails the
    written max ≤ 2 bar for a format reason; the bar stays as written and
    the call goes to the user.
  - `lune run tests/run`: 481 passed.
- Round 3 (`wip/render-ab5` 602f9037, GitHub machines only, `client.py
  build --no-seat`): `modelkit --render` on the saved .glb wrote all 19
  views on every share, exit 0, 5.5-8.2 s, peak 650-667 MB. Against the
  build's own images of the same views (40 pairs) the differences equal the
  in-build GLB_CHECK counts exactly, so render-only reproduces the reloaded
  render; worst max 63, from f32 positions as above.
  - The "hangs" were not modelkit: earlier runs were handed to cloud
    machines that `client.py build` seated and that then paused, and the
    test step sent ~19 large PNGs a share home through the tunnel, which
    blocked heartbeats. `--no-seat` added to `client.py build`.
- Open: the user's call on lane A's max ≤ 2 bar (compare against
  f32-rounded parts instead?). Not started: `--views` batch files tested on
  the machines, mip streaming, spatial index for in-map views, the review
  view generator. Nothing committed.
- Round 4 (`wip/render-ab6` 26b2631d, GitHub machines, `--no-seat`), after
  the user's call: the check now compares against parts rounded as the file
  stores them (f32 corners and 8-bit PNG textures). All 40 GLB_CHECK lines
  max_f32=0, over2_f32=0 (the reader is bit-exact against the file); mean
  ≤ 0.198 against the unrounded build (bar 0.2, close); render-only ok on all
  19 shares that reported. **Lane A passes.** The run's last share (S20) hung
  in the bake swap after its peers stalled sending ~19 PNGs each through the
  tunnel; the same transport issue as round 3, not modelkit.
