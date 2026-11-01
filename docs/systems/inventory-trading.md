# Inventory and trading

Unique items with their own IDs, and two-player trades that either move
everything or nothing.

## Items

`src/shared/Config/Items.luau` lists every item. Commons and uncommons
(Rusty Gear, Copper Coil, ...) **stack**: a player just has a count.
Rares and legendaries (Circuit Board, Golden Cog, ...) are **unique**: each
copy is a record with its own GUID, made by `HttpService:GenerateGUID` the
moment the server creates it.

- Two Golden Cogs are two records with two IDs. They can't merge.
- No code path copies a record. Trading moves the same record, same GUID,
  from one inventory to the other.
- Adding a GUID that's already in an inventory is refused
  (`InventoryRules.addUnique`).

Only the server creates items (`InventoryService.grant`): loot, debug
commands, nothing else.

## Trade flow

1. **Request**: A asks B. The server checks both are in this server, both
   profiles are loaded and neither is already trading.
2. **Accept**: B accepts within 30 seconds.
3. **Offer**: each side clicks items in. Every offer is validated (shape,
   item IDs, counts) and checked against the player's real inventory.
4. **Ready**: both press Ready. A 3-second countdown starts.
5. **Confirm**: both press Confirm.
6. **Swap**: one atomic step (below).

**Any offer change, by either player, resets both Ready and Confirm.** You
can't swap in a worse item after the other player has agreed.

## The atomic swap

`TradeSession.swap` is verify-then-move, with no yields in between:

1. Re-check A still has everything A offered.
2. Re-check B still has everything B offered.
3. Check each side has room for what it gets (stack caps, no repeat GUIDs).
4. Only then move A's items to B and B's to A.

If any check fails, nothing moves and both players are told the trade
failed. Once all checks pass, the moves can't fail, so the trade is all or
nothing. Before swapping, the session is detached from both players, so
no other remote can reach it mid-swap.

## Saving and duplication

Both profiles are session-locked to this server (see `data.md`), so no
other server can load either copy during the trade. Right after the swap,
both profiles are saved at once. Each player's last 20 trades are logged
in their profile (`tradeLog`: when, with whom, what moved, with item IDs)
for support.

Leaving mid-trade cancels it, with nothing moved.

## Files

- `src/server/Inventory/InventoryRules.luau`: inventory changes, offer checks
- `src/server/Trade/TradeSession.luau`: trade phases and the swap
- `src/server/Services/InventoryService.luau`, `TradeService.luau`
- `src/client/Controllers/InventoryController.luau`, `TradeController.luau`
- Specs: `tests/server/Inventory/`, `tests/server/Trade/`
