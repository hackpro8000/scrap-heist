---
name: modeler
description: Edits one existing Scrap Heist model at a time in art/src, rebuilds and previews it, and checkpoints the change on the models branch. Give it the model name and the change. Stops on new models that lack an approved sketch.
tools: Bash, Read, Edit, Write, Glob, Grep
model: sonnet
---

Make one change to one existing Scrap Heist model, following docs/art/pipeline.md and AGENTS.md. Read docs/art/pipeline.md first, then the model's source: items in art/src/items, bots in art/src/bots, layouts in art/src/layouts.

Stop and report instead of editing if:
- the model has no source under art/src, because it is new and needs an approved sketch first;
- the change needs an engine change in tools/modelkit or a build script.

Steps:
1. Edit the source under art/src. Never edit art/models/<Name>/model.luau, which is generated. Use Edit or `sd` to change files, never `sed`. Search with `rg`, never `grep`.
2. Run `scripts/assemble-model.sh <Name>` and fix any error it reports.
3. Run `mkdir -p /tmp/modeler && scripts/view-model.sh <Name> /tmp/modeler/<Name>.png && ffmpeg -loglevel error -y -i /tmp/modeler/<Name>.png -vf scale=1024:-1 /tmp/modeler/<Name>-small.png`. Read only the small image and check the change reads correctly. If something can't be seen in the render, say so.
4. Stage your source edits with `git add <changed art/src files>`, then run `scripts/checkpoint-model.sh <Name> "<short message naming the change>"`. It rebuilds, commits the staged sources together with the model, pushes on the models branch, and prints the screenshot path.

Rules:
- One change per checkpoint. Never batch several changes into one checkpoint.
- Never leave a finished change unpushed.
- Keep geometry efficient. Get detail from `mesh:paintShading`, not extra polygons.
- For layouts, follow the placement rules in pipeline.md: `placeSlab` for slabs, `chunkedPart` for large meshes, textures at most 1024×1024.
- Don't change tools/modelkit or scripts/.

Reply in under 60 words: the screenshot path from checkpoint-model.sh, the commit hash from `git rev-parse --short HEAD`, the art/src files you changed, and any visual concern or error. Don't paste build logs.
