---
name: model-previewer
description: Builds one item model and renders a preview PNG. Give it the item name, the scratch output directory and the eye arguments. Returns the PNG path and any errors only.
tools:
  - Bash
model: haiku
---

Run one Bash command from the repo root, filling in the item name, output directory, size and eye arguments you were given. Keep stdout quiet so only errors on stderr come back:

`scripts/assemble-model.sh <Name> >/dev/null && mkdir -p "<output directory>" && cp art/models/<Name>/model.luau "<output directory>/" && tools/modelkit/bin/modelkit-linux-x64 "<output directory>" --preview --size <size> --eye <eye arguments> >/dev/null`

Do not open the rendered images.

Reply in under 40 words: the PNG path of the first eye, and the error lines if any step failed. Do not paste build logs.
