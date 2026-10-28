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

3. In **Game Settings > Security**, turn on **Enable Studio Access to API
   Services** so player data saves (otherwise ProfileStore uses a mock).

4. Press **Play**. The Output window shows each service and controller
   booting. Per-phase test steps are in `docs/testing/`, and the full
   playtest is `docs/testing/full-game.md`.

## Debug commands

In Studio (or for user IDs in `src/shared/Config/Game.luau`
`ADMIN_USER_IDS`), type in chat:

| Command | Does |
|---|---|
| `/help` | list every command |
| `/givescrap <n>` | add scrap |
| `/giveitem <ItemId> [n]` | add items, e.g. `/giveitem GoldenCog` |
| `/fillcrate [n]` | fill your storage crate |
| `/storm`, `/phase <name>` | jump to a storm or any round phase |
| `/spawnbots <type> [n]`, `/clearbots` | bots near you (Scrapper, Bruiser, Zapper) |
| `/dummy` | a training dummy in front of you |
| `/fakeraid` | an NPC raids your crate |
| `/overlay` | debug overlay: hitboxes, bot paths and states, rejections |
| `/resetdata` | wipe your save (you're kicked to reload) |

The **Showcase** button on the HUD runs the same commands with one tap.

## Dropping in art

Everything runs on gray-block placeholders. To swap in real assets:

- **Animations and sounds:** paste IDs into `src/shared/Assets.luau`.
- **Yard:** a Model named `YardTemplate` in ServerStorage, with parts (or
  models) named `Pad1`-`Pad4`, `Crate` and `PlotMarker`.
- **Yard positions on the map:** parts named `Yard1`..`Yard8` in a
  workspace folder `YardSpots` (each part's position and facing).
- **Arena:** a part named `Arena` in workspace.
- **Machines:** `ServerStorage.MachineModels.SalvageMachine1`..`3`.
- **Bots and dummy:** models in `ServerStorage.NpcModels` named `Scrapper`,
  `Bruiser`, `Zapper`, `TrainingDummy`, `FakeRaider` (each needs a Humanoid
  and HumanoidRootPart).
- **Part bundle:** a MeshPart named `PartBundle` in ServerStorage.

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

- `src/shared` → `ReplicatedStorage.Shared` (config, types, remotes, utilities)
- `src/server` → `ServerScriptService.Server` (services)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (controllers, UI)
- `Packages`, `ServerPackages` → installed by Wally, not committed
- `tests/` → Lune unit tests (never synced into Studio)
- `docs/systems/` → client-facing explainers, `docs/testing/` → Studio checklists

## Cloud environment

`scripts/cloud-setup.sh` sets up a Claude Code cloud environment. Paste it
into the environment's **Setup script** setting. It installs ffmpeg and
starts a virtual 1920 × 1080 desktop on `:99` for GUI apps.
