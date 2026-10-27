---
name: model-previewer
description: Builds one item model and renders a preview PNG. Give it the item name, the scratch output directory and the eye arguments. Returns the PNG path and any errors only.
tools: Bash, Read
model: haiku
---

Run these steps in order and do not open the rendered images.

1. Run `scripts/assemble-model.sh <Name>` from the repo root.
2. Copy `art/models/<Name>/model.luau` into the output directory you were given, creating it if needed.
3. Run `tools/modelkit/target/release/modelkit <output directory> --preview --size <size> --eye <eye arguments>`, using the size and eye arguments you were given.

Reply in under 40 words: the PNG path of the first eye, and the error lines if any step failed. Do not paste build logs.
