# Model pipeline

Models are built by Python scripts that run in Blender 5.2.2 without a
window, so they can be built and reviewed in a cloud session.

## Layout

```
art/models/<Name>/
├── build.py       # builds the model (the source of truth)
├── <Name>.blend   # generated, safe to open and inspect
├── <Name>.fbx     # generated, import this into Roblox Studio
└── preview.png    # generated 3/4 render for review
tools/blender/scrapkit.py   # shared helpers: new_scene, material, link, finish
scripts/build-model.sh      # runs build.py headless
```

## Building

```sh
scripts/build-model.sh StarterWeapon   # one model
scripts/build-model.sh                 # every model
```

Change `build.py` and rebuild, rather than editing the `.blend` by hand;
hand edits are lost on the next build.

## Conventions

- 1 Blender unit = 1 Roblox stud. Blender is Z-up; the FBX export converts
  to Roblox's Y-up.
- Only meshes inside the `Export` collection are exported.
- Colors are plain Principled materials. Roblox reads the base color.

## Importing into Studio

1. Avatar or Home tab → **Import 3D**, pick `<Name>.fbx`.
2. Upload it, then paste the asset ID into `src/shared/Assets.luau`.

The FBX is exported at `FBX_GLOBAL_SCALE = 0.02` (in `scrapkit.py`), the
scale Tristen's hand-made exports used. The build exports with Apply Scalings
set to "FBX Units Scale", which may differ from those hand exports, so the
scale is not confirmed yet: import `ReferenceCube.fbx` and check it matches a
default 2 × 2 × 2 Part. If it doesn't, change `FBX_GLOBAL_SCALE` and rebuild
every model.

## Virtual desktop

Cloud sessions have a virtual 1920 × 1080 desktop on display `:99`, started
by the setup script (or `scripts/desktop.sh start`). Use it to open Blender's
window and take screenshots:

```sh
scripts/desktop.sh start
DISPLAY=:99 blender --factory-startup art/models/<Name>/<Name>.blend &
scripts/desktop.sh screenshot shot.png
```

Rendering is software OpenGL (Mesa llvmpipe), so the viewport is slower than
on a real GPU. On first launch, press Escape to dismiss the splash screen.

## Saving changes
Every Blender change, however small, ends with a checkpoint so no progress is lost:

```
scripts/checkpoint-model.sh <Name> "phase N: <Name> - <change>"
```

It rebuilds the model (saving the `.blend`, `.fbx` and `preview.png`), takes a screenshot of the virtual desktop into `art/models/<Name>/screenshot.png`, and commits and pushes the `models` branch. Send that screenshot to the user after each change. GUI edits must be saved first (Ctrl+S, or `bpy.ops.wm.save_mainfile()`), and ported back into `build.py` so a rebuild doesn't discard them.

Never leave an edit only in a running Blender session.

### Branches
Model binaries (`.blend`, `.fbx`, `preview.png`) live only on the `models` branch, so the code branch stays free of binary noise. The code branch keeps the tooling (`scrapkit`, build scripts, `build.py` sources) and these docs. Merge the code branch into `models` to pick up tooling changes.

Never leave an edit only in a running Blender session.

## Lessons from past models

### Working with Tristen
- Sketch a new model first and get approval before modeling it.
- One change at a time, each followed by a checkpoint and a screenshot, so Tristen can steer early.
- Keep geometry efficient. Get detail from baked painting (`scrapkit.paint_shading`) rather than extra polygons.
- Send videos as MP4, never GIF. Put any tool installs in `scripts/cloud-setup.sh`.
- If something can't be seen in a screenshot, say so instead of waiting for Tristen to notice.

### Technique
- To compare variants (fill levels, upgrade tiers), render them in a row headless: lay them out in a script and use an orthographic camera. Laying them out with a timer in the GUI didn't work; the variants stayed overlapped.
- Look at the full render before cropping it.
- `paint_shading` writes into the object's material. Give each baked object its own material copy (`material.copy()`) so one bake doesn't overwrite others that share it.
- The shadow bake in `paint_shading` isn't limited to the object, so nearby objects cast contact shadows onto it. Use this to ground parts on a surface: place them first, then bake the surface.
- For parts stacked on each other, settling them with a physics simulation looks more natural than placing them by hand.
- Check that every variant reads from the game camera. A low fill level can hide behind the crate wall.
