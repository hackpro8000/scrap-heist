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

The export scale has only been checked inside Blender (the FBX round-trips at
2 × 2 × 2). Before the first real model, import `ReferenceCube.fbx` and check
it matches a default 2 × 2 × 2 Part. If it doesn't, change `FBX_GLOBAL_SCALE`
in `scrapkit.py` and rebuild.

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
