# Dupe-proof player data

Player saves use [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore)
with a session lock, a versioned template and one narrow currency API.

## The duplication problem

The classic Roblox dupe:

1. In server A, give your rare item to a friend in a trade.
2. Immediately join server B, before server A has saved.
3. Server B loads your *old* save, which still has the item.
4. Now the item exists twice.

Any game that loads a profile without checking whether another server still
has it open can be duped this way.

## The fix: session locking

`DataService` opens each profile with `StartSessionAsync`. ProfileStore
writes a lock into the save saying "server A has this". While the lock is
held, server B **can't** load the profile; it waits until A saves and
releases it, so B always gets the newest data.

If A ever loses the lock (another server forced it open after A stopped
responding), ProfileStore fires `OnSessionEnd` and `DataService` kicks the
player straight away. No server keeps playing on a copy that can't save.

If a profile can't be loaded at all, the player is kicked rather than
given a blank save, so a DataStore outage can't wipe anyone.

## Old saves stay valid

- `ProfileSchema.TEMPLATE` lists every field with its default.
  `reconcile()` fills in fields an older save is missing, recursing into
  nested tables, and never overwrites or removes anything. Adding a field
  to the template is all it takes.
- `ProfileSchema.MIGRATIONS` holds one function per version step for shape
  changes (renaming a field, say). Saves are migrated before they're used.

Both are unit tested: `tests/server/Data/ProfileSchema.spec.luau`.

## Currency can't go wrong

Only `DataService.addScrap` and `DataService.trySpend` write scrap. Both use
`Currency`, which refuses zero, negative, fractional, NaN and infinite
amounts, and checks and deducts in one step so two purchases can't both
pass the balance check.

## Trades and saving

After a trade, both profiles are saved at once (`DataService.save`) to keep
the window where only one side has saved as short as possible. See
`docs/systems/inventory-trading.md`.

## Debug commands

`/givescrap <n>` and `/resetdata` work in Studio, or for user IDs in
`Config/Game.ADMIN_USER_IDS`. The check sits in `DebugService.run`, which
every command path goes through.

## Files

- `src/server/Services/DataService.luau`: loading, locking, releasing
- `src/server/Data/ProfileSchema.luau`: template, reconcile, migrations
- `src/server/Data/Currency.luau`: balance rules
- `src/server/Services/DebugService.luau`: gated debug commands
