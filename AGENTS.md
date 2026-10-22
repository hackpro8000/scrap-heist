# AGENTS.md

Coding rules for agents working on Scrap Heist. Read `ROADMAP.md` for what to build; this file covers how to write it.

## Stack
- Roblox Luau with the new type solver, Rojo, luau-lsp, tools via Aftman.
- Shared utilities come from TLib or local modules. No Wally packages.

## Philosophy
- Prefer obvious over clever, and simple and understandable over comprehensive.
- Build mechanisms; compose game meaning on top. A mechanism must not know what it means in the game.
- Prefer composition over inheritance.
- Generalize only when reuse actually recurs. No speculative, hypothetical or empty architecture.
- Names must not hide meaning behind generic terms.
- Prefer explicit wiring over magic. Auto-discovery only when it stays simple and explicit.
- The framework serves the game, never the other way around.

## Architecture
- Layers: Core → Systems → Game. Game sits above Systems, Systems above Core.
- No dependency from Core to Systems or Game, or from Systems to Game, directly or indirectly.
- Core holds foundational code with minimal game knowledge. Systems hold reusable gameplay capabilities. Game holds concrete composition.
- Client and server halves of a system use the same system name.
- Server-only content stays out of replicated services.
- Project folders are CapitalizedCamelCase.

## Lifecycle
- Each module has a `Loaded` phase, a `Started` phase, both, or neither. No universal Init/Start contract.
- Boot is infrastructure only: require every module, await all `Loaded` (they run concurrently and may yield), then dispatch every `Started`.
- `Started` runs async and independently, may yield and may be long-lived. Never await all `Started`.
- A `Loaded` error aborts startup. A `Started` error is surfaced and does not stop unrelated systems.
- A reader must be able to tell from the boot code what loaded, what was ignored and in what order.

## Code style
- `--!strict` at the top of every file.
- Type everything that affects safety, clarity, refactoring or contracts. Avoid theoretical type complexity.
- Shared types live in `<System>Types.luau` modules using `export type`.
- Indent with tabs.
- Naming: PascalCase for module tables and public functions (`Sprint.IsSprinting`), camelCase for locals and local functions, UPPER_SNAKE for constants, `_` prefix for private fields and unused parameters.
- Use guard clauses and early returns. Use `if a then b else c` expressions where they read cleanly.
- Keep dependencies, ownership, state, control flow and cleanup locally traceable.
- Import order: Roblox services, then TLib, then shared modules, then local (`script.Parent`) modules.
- No `WaitForChild` in server module requires.
- Avoid legacy patterns: Matter ECS, DataLib DataContainers, and promise chains like `:andThen`.

## Comments
- Every file starts with a one-line header comment after `--!strict` stating its purpose.
- Comment a function only when its name and types don't make the contract clear. Then cover params, returns, yields, side effects and errors as needed.
- Comment only non-obvious intent, constraints, invariants and edge cases. Keep comments in sync with the code.
- No narration comments and no architectural boilerplate.

## Example

```lua
--!strict
-- Sprint system: owns sprint input state independently from movement and physics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Input = require(ReplicatedStorage.Client.Systems.Input.Input)

local Sprint = {}

local SPRINT_SPEED_MULTIPLIER = 2.5

local sprinting = false

function Sprint.GetSpeedMultiplier(): number
	return if sprinting then SPRINT_SPEED_MULTIPLIER else 1
end

return Sprint
```

## Docs
- Docs live in `Docs/<Topic>/`. No Markdown outside `Docs/` except `AGENTS.md`, `CLAUDE.md` and `ROADMAP.md`.
- Don't duplicate docs. Repo-wide rules live here; module-specific rules live next to the module.
- When unsure, or when something conflicts with existing code, ask Tristen rather than guessing.
