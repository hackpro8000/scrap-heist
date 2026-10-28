# Scrap Heist

A Roblox junkyard tycoon with raiding and survival rounds. See `ROADMAP.md`
for the plan.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then from the repo root:

   ```sh
   rokit install
   ```

   This installs the pinned versions of Rojo, Wally, Selene, StyLua and
   Lune from `rokit.toml`.

2. Install packages (ProfileStore):

   ```sh
   wally install
   ```

3. Install the Rojo plugin in Roblox Studio (once):

   ```sh
   rojo plugin install
   ```

## Working in Studio

1. Start the sync server:

   ```sh
   rojo serve
   ```

2. Open a place in Roblox Studio, open the Rojo plugin and click **Connect**.
   Code from `src/` now syncs live into the place.

3. Press **Play**. The Output window should show each service and controller
   booting (see `docs/testing/`).

## Building a place file

```sh
rojo build -o ScrapHeist.rbxl
```

Place files are build output and are not committed.

## Checks

Run before every commit:

```sh
selene src
stylua --check src tests
lune run tests/run
```

`stylua src tests` fixes formatting.

## Unit tests

`lune run tests/run` runs every `*.spec.luau` under `tests/` with
[Lune](https://lune-org.github.io/docs), outside Studio. Pass a word to run
only matching specs: `lune run tests/run RateLimiter`. It exits non-zero if
anything fails.

Specs mirror `src/` and cover logic that doesn't need the engine. Physics,
replication, saves and UI are checked in Studio with `docs/testing/`.
`tests/Roblox.luau` fakes the few engine pieces modules touch (`task`,
`game:GetService("Players")`).

For editor autocomplete of `@lune/*` modules, run `lune setup` once.

## Layout

- `src/shared` → `ReplicatedStorage.Shared` (config, types, utilities)
- `src/server` → `ServerScriptService.Server` (services)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (controllers, UI)
- `Packages`, `ServerPackages` → installed by Wally, not committed

## Cloud environment

`scripts/cloud-setup.sh` sets up a Claude Code cloud environment. Paste it
into the environment's **Setup script** setting. It installs ffmpeg and
starts a virtual 1920 × 1080 desktop on `:99` for GUI apps.
