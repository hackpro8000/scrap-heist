# Scrap Heist: Build Roadmap

> **For the coding agent:** Read this whole file before writing anything. Work
> phase by phase, top to bottom. Tick a checkbox (`- [x]`) only when the task's
> acceptance criteria pass. Commit after every finished task. If something here
> is unclear or conflicts with existing code, stop and ask Tristen rather than
> guessing.

---

## 1. What we're building

**Scrap Heist** is a Roblox junkyard tycoon with raiding and survival rounds.

- Each player claims a **yard** (plot) and builds **salvage machines** that turn
  junk into **parts** over time.
- Other players can **raid** your yard and carry parts out of your storage. You
  defend with combat and upgrades.
- Every few minutes a **storm round** hits the whole server. **Scrap bots**
  spawn, everyone fights to survive, and survivors earn **rare loot**.
- Rare loot can be **traded** between players.

### Why it exists

This game is a **scripting portfolio piece**. It has to show clients five
systems they hire for, each one clean enough to clip, explain, and sell:

| # | System | What it proves to a client |
|---|--------|----------------------------|
| 1 | Server-authoritative combat kit | Combos, block, parry, hit validation the client can't exploit |
| 2 | Dupe-proof player data | Session locking, safe saves, no item duplication |
| 3 | Inventory and trading | Unique items, atomic two-player trades |
| 4 | Tycoon loop with steal mechanic | Plots, machines, income, raiding, anti-grief rules |
| 5 | Survival rounds with NPC AI | Round state machine, pathfinding bots, loot tables |

### Final deliverables

1. A **playable showcase place** published on Roblox.
2. **Short clips** of each system (10 to 30 seconds each) for a Discord "for
   hire" post.
3. Clean, commented source that Tristen can walk a client through.

---

## 2. Who does what

| Claude Code (agent) | Tristen |
|---------------------|---------|
| All Luau code, Rojo project, tooling config | Models, maps, UI art, animations, sounds |
| Placeholder asset IDs in **one** config file | Uploading assets and pasting real IDs into that file |
| Test checklists for each phase | Playtesting in Studio, reporting bugs |
| Comments that explain the *why* | Recording clips, writing the Discord post |

The agent never blocks on art. Every system must run with placeholder parts
(plain gray blocks, no animations, no sounds) and must not error or spam
warnings when an asset ID is still a placeholder.

---

## 3. Timeline

| When | Goal |
|------|------|
| Day 1 | Phase 0 (audit and setup) and Phase 1 (combat) |
| Day 2 | Phase 2 (data) and Phase 3 (inventory and trading) |
| Day 3 | Phase 4 (tycoon and raiding) |
| Day 4 | Phase 5 (storm rounds and bots) and Phase 6 (game flow glue) |
| Days 5 to 7 | Tristen drops in assets, playtests; agent fixes bugs. **Playable by end of week 1.** |
| Week 2 | Phase 7 (polish, showcase mode, clips, post) |

Code-complete target is about 2 to 4 days. If a phase runs long, finish it
properly before moving on. A half-working system is worse for a portfolio
than a missing one.

---

## 4. Tech stack and tooling

- **Language:** Luau, `--!strict` at the top of every module.
- **Project sync:** [Rojo](https://rojo.space) (`default.project.json`).
- **Packages:** [Wally](https://wally.run) for dependencies.
- **Data library:** ProfileStore (by loleris) for session-locked saves. If it
  can't be installed, ask before writing a custom DataStore wrapper.
- **Formatting and linting:** StyLua and Selene, with config files committed.
- **Unit tests:** [Lune](https://lune-org.github.io/docs) runs specs in
  `tests/` outside Studio, with our own small runner (`tests/run.luau`), no
  test framework package. Approved by Tristen.
- **Toolchain manager:** Rokit (or Aftman) with a `rokit.toml` pinning Rojo,
  Wally, StyLua, Selene, and Lune versions.
- **No other frameworks** (no Knit, no full networking libraries) unless
  Tristen approves. Plain modules are easier to explain to clients.

---

## 5. Existing code

None. The project is built from the ground up: there is no starter combat kit
and no older code to reuse. Every file, including `default.project.json`,
`src/shared/Assets.luau` and the combat config, is created by the phases
below.

---

## 6. Folder structure

Target layout. Create folders as phases need them, not all up front.

```
scrap-heist/
├── ROADMAP.md                 # this file
├── README.md                  # how to build, sync, and test
├── default.project.json       # Rojo tree
├── wally.toml
├── rokit.toml
├── selene.toml
├── stylua.toml
├── .gitignore
├── docs/
│   ├── systems/               # one short explainer per system (for clients)
│   └── testing/               # Studio test checklists per phase
├── tests/                     # Lune unit tests, never synced into Studio
│   ├── run.luau               # runner: `lune run tests/run`
│   ├── Test.luau              # describe / it / expect
│   ├── Roblox.luau            # fakes for the engine bits modules touch
│   └── shared/ server/ ...    # *.spec.luau, mirroring src/
└── src/
    ├── shared/                # ReplicatedStorage.Shared
    │   ├── Assets.luau        # EVERY asset ID lives here
    │   ├── Config/            # all tuning tables (economy, rounds, bots, loot)
    │   ├── Net/               # remote definitions, one module per system
    │   ├── Types.luau         # shared type definitions
    │   ├── Util/              # small pure helpers (Signal, Maid/Trove, etc.)
    │   └── Combat/            # WeaponConfig, Remotes
    ├── server/                # ServerScriptService.Server
    │   ├── init.server.luau   # single entry point, boots services in order
    │   ├── Services/
    │   │   ├── DataService.luau
    │   │   ├── InventoryService.luau
    │   │   ├── TradeService.luau
    │   │   ├── CombatService.luau
    │   │   ├── PlotService.luau
    │   │   ├── MachineService.luau
    │   │   ├── RaidService.luau
    │   │   ├── RoundService.luau
    │   │   ├── BotService.luau
    │   │   └── LootService.luau
    │   └── Bots/              # bot state machine and behaviors
    └── client/                # StarterPlayerScripts.Client
        ├── init.client.luau   # single entry point, boots controllers
        ├── Controllers/
        │   ├── CombatController.luau
        │   ├── InventoryController.luau
        │   ├── TradeController.luau
        │   ├── PlotController.luau
        │   └── RoundController.luau
        └── UI/                # UI built in code, styled from Config/Theme
```

---

## 7. Conventions (apply everywhere)

### Server authority
- The **server decides everything that matters**: damage, hits, currency,
  item grants, trades, steals, loot. Clients only send *intent* ("I want to
  attack", "I want to buy machine X").
- Every remote handler validates: argument types, player state (alive, not
  stunned, in the right place), distance, cooldowns, and ownership.
- Rate-limit every client-to-server remote.

### Code style
- `--!strict` and typed function signatures everywhere.
- One service or controller per file. Each exposes `init()` and `start()`;
  the entry script calls all `init()`s, then all `start()`s.
- `PascalCase` for modules and types, `camelCase` for functions and locals,
  `UPPER_SNAKE` for constants.
- No magic numbers in logic. Tuning goes in `src/shared/Config/`.
- No asset IDs outside `src/shared/Assets.luau`. Code checks
  `Assets.isSet(id)` and skips the effect when it's a placeholder.
- Clean up connections on player leave and object destroy (use a Trove/Maid
  style helper).

### Testing
- Split each system into a **rules module** (plain tables in, results out;
  time passed in as `now` or an injected clock) and a **service** (remotes,
  instances, `Players` events) that calls it. Rules modules get Lune specs;
  service glue gets Studio checklist steps.
- Write the spec with the code, not after. A task is ticked only when its
  specs pass (`lune run tests/run`) and its Studio test passes.
- Specs mirror `src/` (`tests/shared/Util/Signal.spec.luau` tests
  `src/shared/Util/Signal.luau`) and load source with
  `Source.require("src/...")`, which resolves normal Roblox requires
  (`script.Parent.X`, `ReplicatedStorage.Shared.X`) to files. Game code
  needs no test-only require style.
- Only fake engine pieces in `tests/Roblox.luau`, and only what code under
  test actually touches.

### Comments (important)
Tristen will explain this code to clients on calls, so comments must teach.

- Every file starts with a header block: what the module does, how it fits
  with other modules, and its public API.
- Comment the **why**, not the what. Example: "We re-check distance on the
  server because exploiters can fire this remote from anywhere."
- Mark every anti-exploit check with `-- SECURITY:` and every anti-dupe step
  with `-- DUPE-SAFE:` so they're easy to point at in a walkthrough.
- Keep comments plain English. No jargon without a one-line explanation.

### Git
- Small commits, one task per commit, message format: `phase N: short summary`.
- Never commit `.rbxl` / `.rbxlx` place files (ignored in `.gitignore`).

---

## 8. Phases

Each task lists its acceptance criteria. "Studio test" means a step Tristen
runs; the agent writes the steps into `docs/testing/phase-N.md`.

### Phase 0: Audit and setup

- [x] Create `default.project.json` (Rojo tree mapping `src/shared`,
      `src/server`, `src/client`) and `.gitignore` (ignores `.rbxl`/`.rbxlx`,
      `Packages/` and other build output).
  - *Done when:* `rojo build -o test.rbxl` succeeds on the empty tree.
- [ ] Add `rokit.toml`, `wally.toml`, `selene.toml`, `stylua.toml`; install
      ProfileStore via Wally and add `Packages` to the Rojo tree.
  - *Done when:* `rojo build -o test.rbxl` succeeds and `selene src` plus
    `stylua --check src` pass.
  - *Note:* Rojo build and StyLua pass. Selene still needs a local run:
    it couldn't download Roblox's API data in the cloud sandbox.
- [ ] Create server and client entry scripts with the `init()`/`start()`
      boot order, plus `Util/` helpers (Signal, Trove, rate limiter).
  - *Done when:* Studio test: play solo, output shows each service booting in
    order with no errors.
  - *Note:* boot lives in `src/shared/Util/Boot.luau`. No services exist
    yet, so the test checks for `booted 0 module(s)` (`docs/testing/phase-0.md`).
  - *Note:* Signal, Trove, RateLimiter and Boot now have Lune specs.
    RateLimiter takes an optional clock so specs can step time.
  - *Note:* `tests/Source.luau` loads src/ files with Roblox-style requires,
    so rules modules can require config normally and still run in Lune.
- [x] Unit test setup: Lune pinned in `rokit.toml`, own runner in `tests/`,
      specs for the existing `Util/` modules. Added because Studio access
      isn't available yet; Tristen approved Lune and an in-repo runner.
  - *Done when:* `lune run tests/run` passes and exits non-zero on a failure.
- [ ] Write `README.md` (install tools, `rojo serve`, connect in Studio).
  - *Done when:* Tristen can follow it from a fresh clone.

### Phase 1: Combat kit

- [ ] `src/shared/Assets.luau` (single asset ID file with `PLACEHOLDER` and
      `Assets.isSet()`), `src/shared/Combat/WeaponConfig.luau` (combo steps,
      block, parry, posture, stun tuning) and `src/shared/Combat/Remotes.luau`
      (`Attack`, `SetBlocking`, `PlaySwing`, `HitEffect`, `Knockback`).
  - *Done when:* the modules require cleanly in Studio and every combat number
    lives in `WeaponConfig`.
  - *Note:* code done; `WeaponConfig.spec` checks every step's numbers and
    animation keys. Waiting on the Studio require check.

- [ ] `CombatService`: combo tracking, windup/recovery timing, server-side
      hitbox (spatial query in front of the attacker), damage, knockback.
  - *Done when:* hits only land when the server's hitbox overlaps; spamming
    the `Attack` remote faster than the combo allows does nothing.
  - *Note:* code and specs done (`CombatRules.spec`: spam is refused until
    recovery). Rules live in `src/server/Combat/CombatRules.luau`. Waiting
    on Studio test (`docs/testing/phase-1.md`).
- [ ] Blocking, directional block angle, parry window, posture and guard
      break, stun states and walk speed changes.
  - *Done when:* Studio test: blocked hits deal reduced damage, a well-timed
    block parries and stuns the attacker, draining posture breaks guard.
  - *Note:* code and specs done. Waiting on Studio test.
- [ ] `CombatController`: input (click to attack, F or right-click to block),
      animations and sounds via `Assets`, hit effects from `HitEffect`.
  - *Done when:* combat works with all assets still placeholders, no errors.
  - *Note:* code done. Mobile gets touch buttons through
    ContextActionService. Waiting on Studio test.
- [ ] Combat works against NPC humanoids too (needed for bots in Phase 5).
  - *Done when:* a test dummy can be hit, blocked against, and killed.
  - *Note:* `DummyService` spawns a training dummy in Studio; NPC models
    come from `NpcRig` (gray blocks until `ServerStorage.NpcModels` has art).
    Waiting on Studio test.
- [x] Add a second weapon in `WeaponConfig` (for example `Wrench`) to prove
      the kit is data-driven.
  - *Done when:* switching weapons needs zero logic changes.
  - *Note:* `Spanner` (the Big Spanner art) plus the bot weapons, all data
    only. `CombatRules.spec` switches weapons with no logic change.
- [x] `docs/systems/combat.md`: one-page client-facing explainer.

### Phase 2: Dupe-proof data

- [ ] `DataService` on ProfileStore: session lock, profile template, load on
      join, release on leave, kick if the profile can't load.
  - *Done when:* data persists across rejoins; joining a second server while
    still in the first can't load a second copy.
  - *Note:* code done. Needs `wally install` and Studio API access to
    test (`docs/testing/phase-2.md`).
- [ ] Template versioning and a migration function for old saves.
  - *Done when:* adding a new field to the template fills it in for existing
    profiles without wiping anything.
  - *Note:* `ProfileSchema.reconcile` and `migrate`, covered by
    `ProfileSchema.spec`. Waiting on a Studio rejoin check.
- [x] Safe currency API (`addScrap`, `trySpend`) that refuses negatives and
      overspending.
  - *Done when:* no code path outside `DataService` writes currency directly.
  - *Note:* rules in `src/server/Data/Currency.luau` (`Currency.spec`).
    `rg 'scrap ='` finds the only write in `DataService.setScrap`.
- [ ] Studio-only debug commands (give scrap, reset data) gated to Studio or
      an admin user ID list in Config.
  - *Note:* `/givescrap`, `/resetdata`, `/help` via `DebugService`, gated in
    `DebugService.run`. Waiting on Studio test.
- [x] `docs/systems/data.md`: explain session locking and why it stops dupes.

### Phase 3: Inventory and trading

- [x] Item definitions in `Config/Items.luau` (common parts, rare loot,
      rarity tiers).
  - *Note:* item IDs match the art loot models; commons/uncommons stack,
    rares/legendaries are unique.
- [ ] `InventoryService`: every non-stackable item gets a unique ID (GUID)
      when created; stackables are counts. Server-only grant and remove.
  - *Done when:* two of the same rare item have different IDs and can't be
    merged or cloned.
  - *Note:* code and specs done (`InventoryRules.spec`). `/giveitem` for
    testing. Waiting on Studio test (`docs/testing/phase-3.md`).
- [ ] `TradeService`: request, accept, add/remove items, both players ready,
      short countdown, both confirm, then **one atomic swap** that re-verifies
      both inventories right before moving anything.
  - *Done when:* changing an offer resets both ready states; leaving
    mid-trade cancels cleanly; a failed check moves nothing; trades only
    happen between players in the same server who both have loaded profiles.
  - *Note:* rules and swap in `src/server/Trade/TradeSession.luau`
    (`TradeSession.spec` covers resets, failed checks moving nothing, and
    GUIDs surviving the swap). Waiting on 2-player Studio test.
- [x] Trade log (last N trades per player stored in profile) for support.
  - *Note:* `profile.tradeLog`, newest first, `Config/Trade.LOG_SIZE` entries.
- [ ] Inventory and trade UI (placeholder styling, readable on mobile).
  - *Done when:* Studio test with 2 players completes a trade end to end.
  - *Note:* `InventoryController`, `TradeController`, HUD buttons. Waiting
    on Studio test.
- [x] `docs/systems/inventory-trading.md`.

### Phase 4: Tycoon loop and raiding

- [ ] `PlotService`: N yards per server, auto-assign on join, release and
      reset on leave. Yard layout comes from a template model Tristen builds
      (agent uses gray-block placeholders until then).
  - *Note:* code done; yard geometry in `Tycoon/YardLayout.luau`
    (`YardLayout.spec`). Uses `ServerStorage.YardTemplate` and
    `workspace.YardSpots` when present. Waiting on Studio test
    (`docs/testing/phase-4.md`).
- [ ] `MachineService`: buy and place salvage machines on fixed pads, upgrade
      levels, each produces parts into the yard's **storage crate** on a tick.
      Costs, rates, and upgrade curves in `Config/Economy.luau`.
  - *Done when:* income is calculated on the server from owned machines;
    buying with insufficient scrap fails cleanly.
  - *Note:* one machine type with 3 tiers on 4 pads (matches the art).
    Rules in `Tycoon/MachineRules.luau` (`MachineRules.spec`). Prompts, not
    remotes, with server-side owner and distance checks. Waiting on Studio test.
- [ ] Offline earnings (capped) granted on join, based on saved machines.
  - *Note:* `MachineRules.offlineEarnings` (specced): half rate, 2 h cap,
    paid as scrap. Waiting on Studio test.
- [ ] `RaidService`: other players can enter your yard, grab a part bundle
      from your storage crate, and carry it back to their own yard to bank it.
      Carrier is slowed and drops the bundle on death.
  - *Done when:* the server validates every step (in yard, near crate,
    carrying limit, reached own yard); a dropped bundle can be recovered.
  - *Note:* every check in `Tycoon/RaidRules.canGrab` (`RaidRules.spec`).
    Waiting on 2-player Studio test.
- [ ] Anti-grief rules in Config: raid shield after being raided, can't raid
      players far below your level, owner gets an alert and a defense buff
      while raided.
  - *Note:* `Config/Raid.luau`; shield, level gap and defense buff wired in
    `RaidService`. Waiting on Studio test.
- [ ] Plot UI: scrap counter, buy/upgrade prompts, raid alert.
  - *Note:* HUD scrap counter, ProximityPrompts, raid banner and carry
    bar in `PlotController`. Waiting on Studio test.
- [x] `docs/systems/tycoon-raiding.md`.

### Phase 5: Storm rounds and scrap bots

- [ ] `RoundService` state machine: `Calm -> Warning -> Storm -> Results ->
      Calm`, durations in `Config/Rounds.luau`. Broadcast state and timer to
      clients.
  - *Done when:* the cycle runs forever without drift or overlapping rounds;
    players who join mid-round get the current state.
- [ ] During a storm: raiding is paused, yards are safe, players fight bots in
      the shared arena (or the whole map, per Config).
- [ ] `BotService` and `Bots/`: pooled bot spawning with a cap, simple state
      machine (`Idle -> Chase -> Attack -> Retreat`), `PathfindingService`
      with path recompute throttling, target selection by distance and threat.
      Bots use the Phase 1 combat kit for their attacks.
  - *Done when:* 20+ bots run without noticeable server lag; bots don't get
    stuck on corners for more than a few seconds; bots clean up at round end.
- [ ] Bot types in `Config/Bots.luau` (at least: fast weak scrapper, slow
      tank, ranged zapper) with waves that scale by round number.
- [ ] `LootService`: weighted loot tables, survivors and top damage dealers
      get rewards, rare drops create unique items through `InventoryService`.
  - *Done when:* loot is granted only by the server and only once per round
    per player.
- [ ] Round UI: phase banner, countdown, survivors left, results screen.
- [ ] `docs/systems/rounds-ai.md`.

### Phase 6: Game flow glue

- [ ] New player flow: spawn, get a yard, short tutorial prompts (first
      machine, first collect, what storms are).
- [ ] Leaderboard (scrap and raids won) via leaderstats.
- [ ] Settings in one `Config/Game.luau`: yard count, round timing, economy
      multipliers.
- [ ] Full playtest checklist in `docs/testing/full-game.md`.
  - *Done when:* Tristen can play a full 20-minute session with 2+ players
    (build, raid, storm, trade) with no errors in output.

**End of week 1 checkpoint:** game is playable start to finish with Tristen's
assets swapped in through `Assets.luau`.

### Phase 7: Polish, showcase, and clips (week 2)

- [ ] Bug fixes from Tristen's playtests (track them in `docs/bugs.md`).
- [ ] Juice: screen shake, hit pause, damage numbers, UI tweens. All toggleable
      in Config.
- [ ] **Showcase mode** (Studio or admin only): buttons to trigger a storm
      now, spawn bots, give items, start a fake raid. Makes recording clips
      fast.
- [ ] Debug overlay for clips: show server hitboxes, bot paths and states,
      remote rejection counts. Shows clients the systems are real.
- [ ] Performance pass: microprofiler check with full bots, no memory growth
      over a 30-minute session.
- [ ] Publish the showcase place (Tristen).
- [ ] Clip list for Tristen (one clip per system, what to show in each).
- [ ] Final pass on `docs/systems/` so each explainer works as a client
      handout.

---

## 9. Definition of done (whole project)

- [ ] All five systems work in a published place with 2+ players.
- [ ] No errors or warnings in a clean 30-minute session.
- [ ] Every asset ID is in `src/shared/Assets.luau`; none are hardcoded.
- [ ] Every client-to-server remote is validated and rate-limited.
- [ ] Every module has a header comment and `SECURITY:` / `DUPE-SAFE:` tags
      where relevant.
- [ ] `selene` and `stylua --check` pass.
- [ ] `lune run tests/run` passes.
- [ ] One clip per system recorded.

---

## 10. Rules for the agent

1. Read this file and the current code before each session.
2. Don't skip ahead. Finish a phase's acceptance criteria first.
3. Don't add frameworks or libraries beyond those in section 4 without asking.
4. Don't wait on art. Placeholders always.
5. When a task needs a Studio check, write the test steps and tell Tristen
   exactly what to try.
6. Keep this file updated: tick boxes, and add a short note under a task if
   the plan changed.
