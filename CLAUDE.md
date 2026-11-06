# CLAUDE.md

Supplementary rules for agents working on Scrap Heist.

`ROADMAP.md` is the authority. It decides tooling, dependencies, folder layout, lifecycle (`init()`/`start()`), naming, comments, server authority and commit format. This file only adds style rules the roadmap doesn't cover. If anything here conflicts with the roadmap, the roadmap wins.

## Code style
- Indent with tabs.
- Prefix private fields with `_` (`self._connections`), and unused parameters too (`_inputObject`).
- Use guard clauses and early returns instead of deep nesting.
- Use `if a then b else c` expressions where they read cleanly.
- Keep type annotations practical. Avoid theoretical type complexity.
- Shared types live in `<System>Types.luau` modules using `export type`.
- Import order: Roblox services, then packages, then shared modules, then local (`script.Parent`) modules.
- Keep dependencies, ownership, state, control flow and cleanup traceable within the file.
- No `WaitForChild` in server module requires.

## Tooling
- Search with `rg`, never `grep`.
- Edit files with `sd`, never `sed`. Pass `--` before patterns that start with `-`.

## Design
- Prefer obvious over clever, and simple over comprehensive.
- Prefer composition over inheritance.
- Generalize only when reuse actually recurs. No speculative or empty abstractions.
- Names say what things mean in the game. No generic names that hide meaning.
- Dependencies point one way: `shared` never requires `server` or `client`, and reusable systems never require game-specific modules.

## Model work
- After every model change, run `scripts/checkpoint-model.sh` (see `docs/art/pipeline.md`) and send the user the screenshot. Never batch changes or leave progress unpushed.
- Keep model builds cached: layout slabs go through `placeSlab`, prop textures stay at or under 1024×1024, and an unchanged rebuild finishes in seconds. See the caching rules in `docs/art/pipeline.md`.
- Split large meshes (terrain, roads, floors) into cubic chunks via `chunkedPart`: 128 studs, or 1024 texels at the layout's texel density if smaller, with textures at or under 1024×1024.
- Model work routing: the main session does model work itself, editing `art/src`, building and checkpointing, following `docs/art/pipeline.md`. Previews may go to the `model-previewer` subagent (`.claude/agents/model-previewer.md`); relay its screenshot to the user.
- Quick tweaks: for changes to existing settings in a model's `art/src` source (numbers such as sizes, counts, spreads, densities and colours), run `scripts/watch-model.sh <Name>` so the preview re-renders on every save, then checkpoint the result once the user likes it.
- Before a change that grows textures or part counts, estimate the cache size (each paint layer is stored raw at 6 bytes per texel, several layers per part) and keep it within the limit the user sets.
- A character is a capsule 4 studs across and 5.5 tall. Size every space a player uses (gates, doors, walkways, bridges, lifts, interiors, headroom) against it, and state the clearance in sketches and reviews.
- Sketch approval for a new model, one change per checkpoint, screenshot to the user. This applies to every harness, Claude Code and DeepSeek Harness alike.
- If a model task can't be done, stop and report why to the user. Don't fall back to doing it a different way.
- Before a layout build (ServerMap), run `scripts/standby-status.sh`. If build machines are warm for that layout, send the build to them with `scripts/send-build.sh <commit>` (unfinished work: `scripts/push-wip.sh` first) instead of building locally; if none are, build locally. Standby is started with the build-standby workflow (`.github/workflows/build-standby.yml`); keep its defaults, which let machines idle for up to an hour (the countdown restarts with each build; 5 hours at most).
