# Combat kit

A server-authoritative melee system with combos, directional blocking,
parries, posture and guard breaks. Players, bots and training dummies all
fight through the same code.

## How it works

1. The client sends **intent only**: "attack", "block on/off", "equip
   weapon". It never says who it hit.
2. `CombatService` asks `CombatRules` whether the swing may start. If the
   last swing hasn't recovered, or the fighter is stunned or blocking, the
   request is dropped.
3. After the swing's windup, the server builds a box in front of the
   attacker and asks Roblox which parts are inside it
   (`workspace:GetPartBoundsInBox`). Only fighters in that box are hit.
4. For each target, `CombatRules.resolveHit` decides the outcome: **Hit**,
   **Blocked**, **Parried** or **GuardBroken**. The server applies damage,
   stuns and knockback, then tells every client to show the effect.

## Why it can't be exploited

| Exploit | What stops it |
|---|---|
| Firing Attack 1000 times a second | `RemoteGuard` rate limit, then the swing timer: one swing per windup + recovery |
| "I hit that player from across the map" | The client never names a target; the server's own hitbox decides |
| Hitting while stunned or mid-block | `tryStartAttack` refuses |
| Spamming block to parry everything | A block re-raised within `parryCooldown` gets no parry window |
| Equipping a bot's weapon | `EquipWeapon` only accepts `WeaponConfig.PLAYER_WEAPONS` |
| Bad arguments (`SetBlocking("yes")`) | Type checks in each handler, marked `-- SECURITY:` |

## Data-driven weapons

Every number lives in `src/shared/Combat/WeaponConfig.luau`: per-step damage,
windup, recovery, hitbox size, knockback, posture damage, plus block angle,
parry window and stuns. Adding a weapon is a new table entry; the Big Spanner
and every bot weapon were added with no logic changes. Bots use the same kit:
the Zapper's "bolt" is just a long, narrow hitbox.

## Files

- `src/server/Combat/CombatRules.luau`: the rules, no Roblox objects, unit tested
- `src/server/Services/CombatService.luau`: fighters, remotes, hitbox queries
- `src/shared/Combat/WeaponConfig.luau`: tuning
- `src/client/Controllers/CombatController.luau`: input, animations, effects
- `tests/server/Combat/CombatRules.spec.luau`: specs for every rule above
