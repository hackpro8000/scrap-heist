# Phase 7 test checklist: polish and showcase

## Juice (Config/Juice.luau)

1. Hit the dummy: a damage number floats up, the camera shakes slightly,
   and your swing freezes for a split second on contact.
2. Get hit: a bigger shake.
3. Open the Bag, trade window and storm results: each pops open.
4. Set each switch in `Config/Juice.luau` to `false` in turn: that effect
   stops, nothing else changes, no errors.

## Showcase mode

1. In Studio, a **Showcase** button is on the HUD. Every panel button
   works and shows a toast with the result.
2. In a live server with your user ID not in `Config/Game.ADMIN_USER_IDS`,
   no Showcase button appears and firing the remote does nothing (the
   overlay's rejection list on an admin shows `Showcase.NotAllowed`).
3. **Fake raid**: a red NPC walks to your crate, takes parts and runs for
   the gate. Kill it: the bundle drops and you can recover it. Let it go:
   "got away (parts returned)".

## Debug overlay

1. Showcase > **Debug overlay**. A "Rejected remote calls" list appears.
2. Swing at the dummy: red boxes show each server hitbox.
3. `/storm` or spawn bots: every bot shows its state; blue dots show paths.
4. Spam-click: `Combat.Busy` climbs in the rejection list.
5. Toggle it off: everything it drew disappears.

## Performance pass

1. Start a storm and `/spawnbots Scrapper 25`.
2. Open the MicroProfiler (Ctrl+F6) on the server view: no long frames
   from BotService or CombatService.
3. Developer Console > Memory: note the server total, run three full storm
   cycles (about 20 minutes), check it again. It should be roughly flat
   (bots are pooled, troves clean up connections).
4. Developer Console > Server Stats: the Heartbeat rate stays near 60.
