# Clip list

One 10-30 second clip per system for the Discord "for hire" post. Record in
Studio with the **Showcase** panel (HUD button, Studio or admins only). Turn
on **Debug overlay** for the clips marked *overlay*: it shows the server's
hitboxes, bot paths and states, and rejected remote calls, which proves the
systems are real.

Before recording: set real asset IDs in `src/shared/Assets.luau` where you
have them; turn off any juice you don't want in `Config/Juice.luau`.

## 1. Combat kit (overlay)

- Showcase: **Training dummy**. Show the three-hit Bat combo with red
  hitbox flashes, then block a dummy swing (blue), then a perfect parry
  (yellow "PARRY" and the dummy stunned).
- Switch to the Big Spanner (press 2) and break a guard.
- End on the overlay's rejection list: "Combat.Busy" climbing as you
  spam-click, so the server is visibly refusing extra swings.

## 2. Dupe-proof data

- Split screen or cut: `/givescrap 500`, leave, rejoin, still 500.
- Show `docs/systems/data.md`'s duplication diagram, or narrate the
  session lock while the second server refuses to load the profile.
- Tight clip: a trade completing, then both players rejoining with the
  traded item on the right side.

## 3. Inventory and trading

- Two clients. Offer a Golden Cog for Copper Coils, both ready, countdown.
- During the countdown, swap the offer: both ready states snap back.
- Complete the trade; open both bags to show the same `#` ID moved across.

## 4. Tycoon and raiding

- Buy a machine, upgrade it, watch the crate fill, collect.
- Showcase: **Fake raid**. The red banner, the raider grabbing from your
  crate, chasing it down, the bundle dropping, picking it back up.
- Optional second take with a real second player banking a raid.

## 5. Storm rounds and bots (overlay)

- Showcase: **Storm now**. Countdown banner, darker sky, teleport to arena.
- Overlay on: bot states above heads (Chase/Attack/Retreat) and blue path
  dots routing around obstacles.
- Parry a Bruiser slam, get zapped by a Zapper, survive.
- End on the results screen with a rare drop announcement.
