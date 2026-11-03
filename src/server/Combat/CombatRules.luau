--!strict
--[[
	CombatRules

	The combat rules with no Roblox objects involved: combos, swing timing,
	blocking, parries, posture, stuns and walk speed. CombatService owns
	the characters, remotes and hitbox queries, and asks this module what
	happens. Keeping the rules here means each one can be unit tested and
	read on its own.

	Every function takes `now` (seconds, from os.clock on the server) rather
	than reading a clock, so tests can step time exactly.

	A Combatant is one fighter's state: a player character, a bot or the
	training dummy all use the same rules.

	Public API:
		CombatRules.newCombatant(weaponName): Combatant
		CombatRules.weaponOf(combatant): Weapon
		CombatRules.isStunned(combatant, now): boolean
		CombatRules.isAttacking(combatant, now): boolean
		CombatRules.tryStartAttack(combatant, now): (AttackStart?, reason?)
		CombatRules.wasInterrupted(combatant, attack): boolean
		CombatRules.setBlocking(combatant, wantsBlock, now): reason?
		CombatRules.equip(combatant, weaponName, now): reason?
		CombatRules.resolveHit(attacker, defender, step, positions..., now): HitResult
		CombatRules.isFacing(look, fromPosition, toPosition, angleDegrees): boolean
		CombatRules.hitbox(position, look, step): (center, size)
		CombatRules.knockbackVelocity(fromPosition, toPosition, speed): Vector3
		CombatRules.walkSpeed(combatant, now): number
		CombatRules.tickPosture(combatant, now)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

type ComboStep = CombatTypes.ComboStep
type Weapon = CombatTypes.Weapon

local SETTINGS = WeaponConfig.Combat

local CombatRules = {}

export type Combatant = {
	weaponName: string,
	-- Index of the last combo step started; 0 before the first swing.
	comboIndex: number,
	-- When the current or last swing ends its recovery.
	busyUntil: number,
	blocking: boolean,
	blockStartedAt: number,
	blockEndedAt: number,
	-- Whether the current block opened with a parry window.
	parryReady: boolean,
	posture: number,
	postureUpdatedAt: number,
	lastPostureHitAt: number,
	stunnedUntil: number,
	-- Scales damage this combatant takes (raid defense buff, for example).
	damageTakenMultiplier: number,
}

export type AttackStart = {
	step: ComboStep,
	index: number,
	startedAt: number,
	-- When the hitbox should be checked.
	hitAt: number,
}

export type HitOutcome = "Hit" | "Blocked" | "Parried" | "GuardBroken"

export type HitResult = {
	outcome: HitOutcome,
	damage: number,
	knockback: number,
}

function CombatRules.newCombatant(weaponName: string): Combatant
	assert(WeaponConfig.Weapons[weaponName], `CombatRules: unknown weapon {weaponName}`)

	return {
		weaponName = weaponName,
		comboIndex = 0,
		busyUntil = 0,
		blocking = false,
		blockStartedAt = -math.huge,
		blockEndedAt = -math.huge,
		parryReady = false,
		posture = SETTINGS.maxPosture,
		postureUpdatedAt = 0,
		lastPostureHitAt = -math.huge,
		stunnedUntil = 0,
		damageTakenMultiplier = 1,
	}
end

function CombatRules.weaponOf(combatant: Combatant): Weapon
	return WeaponConfig.Weapons[combatant.weaponName]
end

function CombatRules.isStunned(combatant: Combatant, now: number): boolean
	return now < combatant.stunnedUntil
end

function CombatRules.isAttacking(combatant: Combatant, now: number): boolean
	return now < combatant.busyUntil
end

function CombatRules.tryStartAttack(combatant: Combatant, now: number): (AttackStart?, string?)
	-- SECURITY: these checks are why spamming the Attack remote does
	-- nothing. A swing can only start once the last one has fully
	-- recovered, whatever rate the client fires at.
	if CombatRules.isStunned(combatant, now) then
		return nil, "Stunned"
	end
	if CombatRules.isAttacking(combatant, now) then
		return nil, "Busy"
	end
	if combatant.blocking then
		return nil, "Blocking"
	end

	local weapon = CombatRules.weaponOf(combatant)
	local continuesCombo = combatant.comboIndex > 0
		and combatant.comboIndex < #weapon.combo
		and now - combatant.busyUntil <= weapon.comboResetTime
	local index = if continuesCombo then combatant.comboIndex + 1 else 1
	local step = weapon.combo[index]

	combatant.comboIndex = index
	combatant.busyUntil = now + step.windup + step.recovery

	return {
		step = step,
		index = index,
		startedAt = now,
		hitAt = now + step.windup,
	},
		nil
end

-- A stun that lands during the windup cancels the swing. Stuns can only
-- start after the swing did (a stunned fighter can't swing), so any stun
-- ending after the start time must have landed during it.
function CombatRules.wasInterrupted(combatant: Combatant, attack: AttackStart): boolean
	return combatant.stunnedUntil > attack.startedAt
end

function CombatRules.setBlocking(combatant: Combatant, wantsBlock: boolean, now: number): string?
	if wantsBlock == combatant.blocking then
		return nil
	end

	if not wantsBlock then
		combatant.blocking = false
		combatant.blockEndedAt = now
		return nil
	end

	if CombatRules.isStunned(combatant, now) then
		return "Stunned"
	end
	if CombatRules.isAttacking(combatant, now) then
		return "Busy"
	end

	combatant.blocking = true
	combatant.blockStartedAt = now
	-- SECURITY: a block raised right after dropping one gets no parry
	-- window, so an exploit (or a fast finger) toggling block every frame
	-- can't parry every hit.
	combatant.parryReady = now - combatant.blockEndedAt >= SETTINGS.parryCooldown

	return nil
end

function CombatRules.equip(combatant: Combatant, weaponName: string, now: number): string?
	if not WeaponConfig.Weapons[weaponName] then
		return "UnknownWeapon"
	end
	if CombatRules.isAttacking(combatant, now) then
		return "Busy"
	end

	combatant.weaponName = weaponName
	combatant.comboIndex = 0

	return nil
end

-- Regenerates posture lazily: called whenever posture is about to be read
-- or changed, instead of on a timer for every fighter.
function CombatRules.tickPosture(combatant: Combatant, now: number)
	local regenStart = math.max(combatant.postureUpdatedAt, combatant.lastPostureHitAt + SETTINGS.postureRegenDelay)
	if now > regenStart then
		combatant.posture =
			math.min(SETTINGS.maxPosture, combatant.posture + (now - regenStart) * SETTINGS.postureRegenPerSecond)
	end
	combatant.postureUpdatedAt = now
end

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- True if `toPosition` lies inside the cone of `angleDegrees` centred on
-- `look`, seen from `fromPosition`. Height is ignored, so jumping over a
-- block doesn't get around it.
function CombatRules.isFacing(look: Vector3, fromPosition: Vector3, toPosition: Vector3, angleDegrees: number): boolean
	local flatLook = flatten(look)
	local toTarget = flatten(toPosition - fromPosition)
	if flatLook.Magnitude < 1e-3 or toTarget.Magnitude < 1e-3 then
		-- Standing inside each other: count as facing rather than letting
		-- hits slip through a block on a technicality.
		return true
	end

	local cosAngle = flatLook.Unit:Dot(toTarget.Unit)
	return cosAngle >= math.cos(math.rad(angleDegrees / 2))
end

function CombatRules.resolveHit(
	attacker: Combatant,
	defender: Combatant,
	step: ComboStep,
	attackerPosition: Vector3,
	defenderPosition: Vector3,
	defenderLook: Vector3,
	now: number
): HitResult
	CombatRules.tickPosture(defender, now)

	local defenderWeapon = CombatRules.weaponOf(defender)
	local blockedFromFront = defender.blocking
		and CombatRules.isFacing(defenderLook, defenderPosition, attackerPosition, defenderWeapon.blockAngle)

	if not blockedFromFront then
		defender.stunnedUntil = math.max(defender.stunnedUntil, now + SETTINGS.hitStun)
		return {
			outcome = "Hit",
			damage = step.damage * defender.damageTakenMultiplier,
			knockback = step.knockback,
		}
	end

	if defender.parryReady and now - defender.blockStartedAt <= defenderWeapon.parryWindow then
		attacker.stunnedUntil = math.max(attacker.stunnedUntil, now + defenderWeapon.parryStun)
		return { outcome = "Parried", damage = 0, knockback = 0 }
	end

	local blockedDamage = step.damage * defenderWeapon.blockDamageMultiplier * defender.damageTakenMultiplier
	defender.posture -= step.postureDamage
	defender.lastPostureHitAt = now

	if defender.posture > 0 then
		return { outcome = "Blocked", damage = blockedDamage, knockback = 0 }
	end

	-- Guard break: the block drops, the defender is stunned, and posture
	-- refills so they aren't broken again the moment the stun ends.
	defender.blocking = false
	defender.blockEndedAt = now
	defender.posture = SETTINGS.maxPosture
	defender.stunnedUntil = math.max(defender.stunnedUntil, now + SETTINGS.guardBreakStun)

	return { outcome = "GuardBroken", damage = blockedDamage, knockback = step.knockback }
end

-- The hitbox is a box in front of the attacker, its back face at the
-- attacker's position. Returns the box centre and size (width, height,
-- depth); CombatService turns them into a CFrame facing `look`.
function CombatRules.hitbox(position: Vector3, look: Vector3, step: ComboStep): (Vector3, Vector3)
	local flatLook = flatten(look)
	local forward = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.new(0, 0, -1)

	return position + forward * (step.range / 2), Vector3.new(step.width, step.height, step.range)
end

function CombatRules.knockbackVelocity(fromPosition: Vector3, toPosition: Vector3, speed: number): Vector3
	local away = flatten(toPosition - fromPosition)
	local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(0, 0, -1)

	return direction * speed + Vector3.new(0, SETTINGS.knockbackLift, 0)
end

function CombatRules.walkSpeed(combatant: Combatant, now: number): number
	local speeds = SETTINGS.walkSpeed
	if CombatRules.isStunned(combatant, now) then
		return speeds.stunned
	elseif combatant.blocking then
		return speeds.blocking
	elseif CombatRules.isAttacking(combatant, now) then
		return speeds.attacking
	end

	return speeds.normal
end

return CombatRules
