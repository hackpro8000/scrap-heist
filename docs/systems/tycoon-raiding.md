# Capsules, junkrots, yards and raiding

Buy a mystery capsule off the belt, carry it home, hatch it into a junkrot
that earns scrap, lay your yard out the way you like, and steal from
everyone else while defending your own. The full design and its numbers
are in `docs/plans/gameplay-content.md`.

## The loop

1. Every player gets a **yard** when their profile loads (8 per server). A
   new player's yard comes laid out: six pads, a build bay, the crate, the
   junk mound and the rebirth press.
2. Capsules ride the **belt** round the Line (`BeltService`). Each holds a
   junkrot rolled when it dropped; its tier shows, the junkrot doesn't.
   Nobody buys it in one lap and it's crushed.
3. **Buy** one with scrap and you carry it, slowed. A landed blow, death or
   lightning knocks it out of your hands; anyone can pick it up
   (`CapsuleService`).
4. Walk up to an empty **build bay** in your own yard and the capsule loads.
   It hatches over time, faster while you whack it. Until it hatches, a
   raider in your yard can steal it out of the bay.
5. The **junkrot** goes on a pad: an empty one of its family first, then any
   empty one, else it replaces your weakest earner (which is scrapped for a
   quarter of its price) or is scrapped itself if it is the weakest
   (`JunkrotRules.choosePad`).
6. Junkrots earn **scrap** into the yard's **crate** every second, up to its
   capacity (ten minutes of the yard's income). **Collect** the crate to
   bank it. Parts add **stars** to a junkrot; each star doubles it.
7. The **rebirth press** takes the next rank when the junkrots it asks for
   stand on your pads and you have the scrap (`RebirthRules`). Your scrap
   goes to 0; income rises, land is cleared and another pad is allowed.
8. Coming back after time away pays **offline earnings**: half rate, capped
   at two hours, straight into your scrap (so it can't be raided).

All income is calculated on the server from the junkrots saved in the
profile (`JunkrotRules.yardIncome`). The client never says how much it
earned or what a capsule holds.

## Yards and build mode

A yard is a 96 x 112 stud plot inside a fixed fence, laid out on a 2-stud
grid (`Shared/Config/Yard`, `Shared/Yard/YardGrid`). Everything in it is
saved in the profile as a list of things and where they stand
(`yard.objects`); `PlotService` builds them, from `ServerStorage.YardKit`
when the art is there and as plain blocks when it isn't.

In **build mode** (the HUD's Build button, `BuildController`) the owner
moves things and places the pads and bays their rank has earned. The rules
(`Shared/Yard/BuildRules`), checked by the client for the ghost and again
by the server (`BuildService`):

- everything stands on the plot, on cleared land, and nothing overlaps
- the doorstep inside the gate stays clear
- every pad, bay, crate, mound and press can be walked to from the gate
  along a way 4 studs wide, so nothing can be walled in
- no building in a storm, with a raider in the yard, or with a capsule in
  hand

Land: the plot is 12 parcels. The front row is clear from the start; ranks
1, 2, 3, 4, 6, 8, 10, 12 and 14 each clear one more, in a fixed order for
now. Uncleared parcels lie under rubble that can be walked over.

## Raiding

1. Walk into another player's yard and hold **Grab scrap** at their crate.
2. You take a bundle (a quarter of the crate; half in a blackout) and carry
   it on your back, slowed.
3. Reach **your own** yard to bank it.
4. Die on the way and the bundle drops. The owner can pick it up to put it
   straight back in their crate. Another raider can carry it on. Left
   alone, it returns to the crate after 30 seconds.

`RaidRules.canGrab` checks every grab on the server: not the owner, has a
yard, inside that yard and near the crate, hands free, the yard not
shielded, and the crate worth raiding (1% full or more).

Defences: a raided yard is **shielded** for five minutes; the owner is
alerted and takes less damage while raiders are inside; and the owner can
**lock the gate** for 30 seconds (then waits a minute to lock it again). A
locked gate stops everyone but its owner. The blackout drops every gate.

## Where things live

| | |
|---|---|
| Numbers | `src/shared/Config/`: `Junkrots`, `Belt`, `Yard`, `Rebirth`, `Raid`, `Economy` |
| Rules (pure, unit tested) | `src/server/Tycoon/`: `JunkrotRules`, `RebirthRules`, `RaidRules`; `src/shared/Belt/BeltRules`; `src/shared/Yard/BuildRules` |
| Services | `PlotService` (yards, things, crate), `JunkrotService` (income, stars, collect, mound), `BeltService`, `CapsuleService`, `BuildService`, `RebirthService`, `RaidService` (crate grabs, gates) |
| Client | `BuildController`, `BeltController` (smooth capsules), `PlotController` (owner-only prompts, alerts, own gate), `HudController` |
| Debug commands | `/drop [id]`, `/capsule [id]`, `/junkrot <id> [limited]`, `/parts <n>`, `/rank <n>`, `/fillcrate`, `/givescrap <n>` |
