# Scrap Heist

A Roblox junkyard tycoon with raiding and survival rounds. See `ROADMAP.md`
for the plan.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then from the repo root:

   ```sh
   rokit install
   ```

   This installs the pinned versions of Rojo, Wally, Selene and StyLua from
   `rokit.toml`.

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
stylua --check src
```

`stylua src` fixes formatting.

## Layout

- `src/shared` → `ReplicatedStorage.Shared` (config, types, utilities)
- `src/server` → `ServerScriptService.Server` (services)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (controllers, UI)
- `Packages`, `ServerPackages` → installed by Wally, not committed

## Cloud environment

`scripts/cloud-setup.sh` sets up a Claude Code cloud environment. Paste it
into the environment's **Setup script** setting. It installs Blender 5.2.2
(checksum-verified) to `/opt/blender-5.2.2` and puts `blender` on the PATH.
