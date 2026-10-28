# Phase 4 test checklist: tycoon and raiding

Unit tests cover costs, production, offline earnings, raid rules and yard
geometry (`lune run tests/run Tycoon`).

## Yard and machines (solo)

1. Play. You spawn in a gray yard facing the green crate. The yellow post
   says "<your name>'s Yard".
2. The HUD shows `Scrap: 50` for a new profile.
3. Walk onto Pad1: prompt "Buy salvage machine - 50 scrap". Hold it: a
   block appears on the pad, scrap drops to 0.
4. Pad2's prompt asks 300. Holding it says "You need 300 scrap".
5. Watch the crate label count up (1 part per second at level 1).
6. Hold **Collect** at the crate: "Collected N scrap", crate back to 0.
7. `/givescrap 1000`, upgrade Pad1: the block grows and changes color.
   The crate fills faster.
8. Upgrade to level 3: the prompt then reads "Max level" and can't be used.

## Offline earnings

1. With at least one machine, stop and wait a minute, then play again.
2. A toast says "While you were away your machines made N scrap".

## Raiding (Test > Clients and Servers, 2 players)

1. Player1: `/fillcrate 400`.
2. Player2 walks into Player1's yard. Player1 sees a red "is in your yard"
   banner.
3. Player2 holds **Grab parts** at Player1's crate: Player2 gets a brown
   ball on their back, a "Carrying 100 parts" bar, and walks slower.
   Player1 sees "stole 100 parts" and the crate drops to 300.
4. Player2 tries to grab again: "already carrying".
5. Player2 walks home: "Banked 100 scrap", speed back to normal.
6. Player2 goes back for more: "shielded" (5 minute shield).

## Drops

1. Clear the shield (rejoin as Player1), `/fillcrate 400`, raid again.
2. Player1 kills Player2 on the way out: the bundle drops.
3. Player1 holds **Pick up**: "Recovered 100 parts", crate back up.
4. Repeat, but leave the bundle 30 s: it returns to Player1's crate.

## Prompts

1. Player2 never sees buy/upgrade/collect prompts in Player1's yard.
2. Player1 never sees "Grab parts" on their own crate.

## Level gap

1. Player1 maxes three machines (`/givescrap 50000`), Player2 has none.
2. Player1 can't raid Player2 ("too far below your level"); Player2 can
   raid Player1.
