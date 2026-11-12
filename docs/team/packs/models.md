# Pack: model work

`docs/art/pipeline.md` and the "Model work" section of `CLAUDE.md` are the rules; this pack only points at them.

- The main session does model edits, builds and checkpoints itself. Previews may go to `model-previewer`; reviews go to `model-critic` with a neutral prompt.
- One change per checkpoint (`scripts/checkpoint-model.sh`), screenshot to the user.
- Builds and renders go to the build machines, spread across all of them (`scripts/send-build.sh`), never the user's computer.
- Sources are in `art/src`; `art/models` holds generated copies. Never edit or quote the copies.
- Layout slabs go through `placeSlab` (`art/src/layouts/prelude.luau`); large meshes through `chunkedPart` (`art/src/common.luau`). Textures stay at or under 1024×1024.
- Flat PBR maps and hand-painted metal wear are deliberate. Do not flag or "fix" them.
