# AGENTS.md

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

## Design
- Prefer obvious over clever, and simple over comprehensive.
- Prefer composition over inheritance.
- Generalize only when reuse actually recurs. No speculative or empty abstractions.
- Names say what things mean in the game. No generic names that hide meaning.
- Dependencies point one way: `shared` never requires `server` or `client`, and reusable systems never require game-specific modules.
