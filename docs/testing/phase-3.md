# Phase 3 test checklist: inventory and trading

Unit tests cover inventory rules, offer checks, trade phases and the swap
(`lune run tests/run Trade`, `lune run tests/run Inventory`).

## Inventory (solo)

1. Play. Press **B** (or the **Bag** button): an empty inventory panel.
2. `/giveitem RustyGear 5`, `/giveitem GoldenCog 2`.
3. The panel shows `Rusty Gear x5` and two Golden Cog lines with
   **different** `#` IDs.
4. Stop and play again: the items are still there.

## Trade (Test > Clients and Servers, 2 players)

Give each player items first: Player1 `/giveitem GoldenCog`, Player2
`/giveitem CopperCoil 5`.

1. Player1: **Trade** button, pick Player2. Player2 sees an accept prompt.
2. Player2 accepts. Both see the trade window.
3. Player1 clicks Golden Cog under *Your items*: it moves to *Your offer*
   for Player1 and *Their offer* for Player2.
4. Player2 offers 3 Copper Coils (three clicks).
5. Both press **Ready**: status counts down 3..2..1, then **Confirm**
   appears.
6. Before confirming, Player2 clicks a Copper Coil in *Your offer* to take
   it back: both Ready states reset and the countdown stops.
7. Ready, countdown and Confirm on both sides: "Trade complete!". Both
   inventories updated; Player2's Golden Cog has the same `#` ID it had in
   Player1's bag.

## Cancel paths

1. Start a trade, then have Player2 leave: Player1 sees "Your trade
   partner left"; nothing moved.
2. Start a trade, press **Cancel**: both windows close; nothing moved.
3. Decline a request: the requester sees "declined your trade".

## Mobile

1. In Studio's device emulator (phone), the trade window fits the screen
   and every button is tappable.
