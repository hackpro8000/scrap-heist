# ServerMap shard builds

Each cloud session builds one shard of ServerMap, uploads its chunks to
Roblox and reports here.

- Build: `scripts/assemble-model.sh ServerMap` then
  `scripts/build-model.sh ServerMap -- --chunks --shard <i>/8`
- Upload: `scripts/upload-chunks.sh ServerMap` (needs `ROBLOX_API_KEY` and
  `ROBLOX_CREATOR_ID` in the environment)
- Results: push `art/shards/ServerMap/S<i>/` (the shard's
  `ServerMapAssetIds.txt`, `ServerMapChunks.luau` and `parts.txt`) to branch
  `shard/servermap-s<i>`, then comment on this PR starting `S<i> DONE` or
  `S<i> FAILED`.

The coordinating session merges the shards into `src/shared/Assets.luau`
and `src/shared/Config/MapChunks.luau`.
