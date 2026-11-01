--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local CombatRules = Source.require("src/server/Combat/CombatRules")
local WeaponConfig = Source.require("src/shared/Combat/WeaponConfig")

local SETTINGS = WeaponConfig.Combat
local BAT = WeaponConfig.Weapons.Bat

-- Attacker at the origin facing -Z, defender 4 studs in front facing back.
local ATTACKER_POSITION = Vector3.new(0, 0, 0)
local DEFENDER_POSITION = Vector3.new(0, 0, -4)
local FACING_ATTACKER = Vector3.new(0, 0, 1)
local FACING_AWAY = Vector3.new(0, 0, -1)

local function hit(attacker, defender, defenderLook: Vector3, now: number)
	return CombatRules.resolveHit(
		attacker,
		defender,
		BAT.combo[1],
		ATTACKER_POSITION,
		DEFENDER_POSITION,
		defenderLook,
		now
	)
end

-- Time when a swing started at `startedAt` has fully recovered.
local function recovered(step, startedAt: number): number
	return startedAt + step.windup + step.recovery
end

describe("CombatRules attacks", function()
	it("walks through the combo in order, then starts over", function()
		local fighter = CombatRules.newCombatant("Bat")
		local now = 10
		local indexes = {}

		for _ = 1, #BAT.combo + 1 do
			local attack = CombatRules.tryStartAttack(fighter, now)
			table.insert(indexes, attack.index)
			now = recovered(attack.step, now)
		end

		expect(indexes).toEqual({ 1, 2, 3, 1 })
	end)

	it("ignores attacks during windup and recovery", function()
		local fighter = CombatRules.newCombatant("Bat")
		local first = CombatRules.tryStartAttack(fighter, 10)

		local spam, reason = CombatRules.tryStartAttack(fighter, 10 + first.step.windup)
		expect(spam).toBe(nil)
		expect(reason).toBe("Busy")

		local almost = CombatRules.tryStartAttack(fighter, recovered(first.step, 10) - 0.01)
		expect(almost).toBe(nil)

		local next = CombatRules.tryStartAttack(fighter, recovered(first.step, 10))
		expect(next.index).toBe(2)
	end)

	it("restarts the combo after the reset time", function()
		local fighter = CombatRules.newCombatant("Bat")
		local first = CombatRules.tryStartAttack(fighter, 10)
		local late = recovered(first.step, 10) + BAT.comboResetTime + 0.01

		expect(CombatRules.tryStartAttack(fighter, late).index).toBe(1)
	end)

	it("schedules the hit check after the windup", function()
		local fighter = CombatRules.newCombatant("Bat")
		local attack = CombatRules.tryStartAttack(fighter, 10)

		expect(attack.hitAt).toBe(10 + BAT.combo[1].windup)
	end)

	it("refuses to attack while stunned or blocking", function()
		local stunned = CombatRules.newCombatant("Bat")
		stunned.stunnedUntil = 11
		expect(select(2, CombatRules.tryStartAttack(stunned, 10))).toBe("Stunned")

		local blocking = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(blocking, true, 10)
		expect(select(2, CombatRules.tryStartAttack(blocking, 10))).toBe("Blocking")
	end)

	it("treats a stun during windup as an interrupt", function()
		local fighter = CombatRules.newCombatant("Bat")
		local attack = CombatRules.tryStartAttack(fighter, 10)
		expect(CombatRules.wasInterrupted(fighter, attack)).toBe(false)

		fighter.stunnedUntil = 10.05 + SETTINGS.hitStun
		expect(CombatRules.wasInterrupted(fighter, attack)).toBe(true)
	end)
end)

describe("CombatRules hits and blocks", function()
	it("deals full damage and a hit stun when not blocking", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")

		local result = hit(attacker, defender, FACING_ATTACKER, 10)

		expect(result.outcome).toBe("Hit")
		expect(result.damage).toBe(BAT.combo[1].damage)
		expect(CombatRules.isStunned(defender, 10 + SETTINGS.hitStun - 0.01)).toBe(true)
	end)

	it("reduces damage and drains posture on a block", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(defender, true, 10)

		local result = hit(attacker, defender, FACING_ATTACKER, 10 + BAT.parryWindow + 0.1)

		expect(result.outcome).toBe("Blocked")
		expect(result.damage).toBe(BAT.combo[1].damage * BAT.blockDamageMultiplier)
		expect(defender.posture).toBe(SETTINGS.maxPosture - BAT.combo[1].postureDamage)
		expect(CombatRules.isStunned(defender, 10.5)).toBe(false)
	end)

	it("doesn't block hits from behind", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(defender, true, 10)

		expect(hit(attacker, defender, FACING_AWAY, 11).outcome).toBe("Hit")
	end)

	it("only blocks inside the block angle", function()
		local look = Vector3.new(0, 0, -1)
		local halfAngle = BAT.blockAngle / 2
		local function pointAt(degrees: number): Vector3
			local radians = math.rad(degrees)
			return Vector3.new(math.sin(radians), 0, -math.cos(radians)) * 5
		end

		expect(CombatRules.isFacing(look, Vector3.zero, pointAt(halfAngle - 1), BAT.blockAngle)).toBe(true)
		expect(CombatRules.isFacing(look, Vector3.zero, pointAt(halfAngle + 1), BAT.blockAngle)).toBe(false)
		expect(CombatRules.isFacing(look, Vector3.zero, Vector3.new(0, 50, -1), BAT.blockAngle)).toBe(true)
	end)

	it("parries a hit just after raising block and stuns the attacker", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(defender, true, 10)

		local result = hit(attacker, defender, FACING_ATTACKER, 10 + BAT.parryWindow)

		expect(result.outcome).toBe("Parried")
		expect(result.damage).toBe(0)
		expect(CombatRules.isStunned(attacker, 10 + BAT.parryWindow + BAT.parryStun - 0.01)).toBe(true)
		expect(defender.posture).toBe(SETTINGS.maxPosture)
	end)

	it("gives no parry window to a block re-raised too quickly", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(defender, true, 10)
		CombatRules.setBlocking(defender, false, 10.1)
		CombatRules.setBlocking(defender, true, 10.1 + SETTINGS.parryCooldown / 2)

		local result = hit(attacker, defender, FACING_ATTACKER, 10.1 + SETTINGS.parryCooldown / 2)

		expect(result.outcome).toBe("Blocked")
	end)

	it("breaks guard when posture runs out", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(defender, true, 0)

		local now = 1
		local outcome
		local hitsTaken = 0
		repeat
			outcome = hit(attacker, defender, FACING_ATTACKER, now).outcome
			hitsTaken += 1
			now += 0.1
		until outcome ~= "Blocked" or hitsTaken > 50

		expect(outcome).toBe("GuardBroken")
		expect(hitsTaken).toBe(math.ceil(SETTINGS.maxPosture / BAT.combo[1].postureDamage))
		expect(defender.blocking).toBe(false)
		expect(CombatRules.isStunned(defender, now + SETTINGS.guardBreakStun - 0.2)).toBe(true)
	end)

	it("regenerates posture only after the delay", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(defender, true, 0)
		hit(attacker, defender, FACING_ATTACKER, 1)
		local afterHit = defender.posture

		CombatRules.tickPosture(defender, 1 + SETTINGS.postureRegenDelay)
		expect(defender.posture).toBe(afterHit)

		CombatRules.tickPosture(defender, 1 + SETTINGS.postureRegenDelay + 0.5)
		expect(defender.posture).toBe(math.min(SETTINGS.maxPosture, afterHit + 0.5 * SETTINGS.postureRegenPerSecond))

		CombatRules.tickPosture(defender, 1000)
		expect(defender.posture).toBe(SETTINGS.maxPosture)
	end)

	it("scales damage taken by the defender's multiplier", function()
		local attacker = CombatRules.newCombatant("Bat")
		local defender = CombatRules.newCombatant("Bat")
		defender.damageTakenMultiplier = 0.5

		expect(hit(attacker, defender, FACING_ATTACKER, 10).damage).toBe(BAT.combo[1].damage * 0.5)
	end)

	it("can't raise a block while stunned or mid-swing", function()
		local stunned = CombatRules.newCombatant("Bat")
		stunned.stunnedUntil = 11
		expect(CombatRules.setBlocking(stunned, true, 10)).toBe("Stunned")

		local swinging = CombatRules.newCombatant("Bat")
		CombatRules.tryStartAttack(swinging, 10)
		expect(CombatRules.setBlocking(swinging, true, 10.05)).toBe("Busy")
	end)
end)

describe("CombatRules geometry and movement", function()
	it("puts the hitbox in front of the attacker", function()
		local step = BAT.combo[1]
		local center, size = CombatRules.hitbox(Vector3.new(10, 3, 10), Vector3.new(1, 0.5, 0), step)

		expect(center).toEqual(Vector3.new(10 + step.range / 2, 3, 10))
		expect(size).toEqual(Vector3.new(step.width, step.height, step.range))
	end)

	it("knocks targets away from the attacker with a little lift", function()
		local velocity = CombatRules.knockbackVelocity(Vector3.zero, Vector3.new(0, 0, -4), 40)

		expect(velocity).toEqual(Vector3.new(0, SETTINGS.knockbackLift, -40))
	end)

	it("picks walk speed from state, stun first", function()
		local fighter = CombatRules.newCombatant("Bat")
		expect(CombatRules.walkSpeed(fighter, 10)).toBe(SETTINGS.walkSpeed.normal)

		CombatRules.tryStartAttack(fighter, 10)
		expect(CombatRules.walkSpeed(fighter, 10.05)).toBe(SETTINGS.walkSpeed.attacking)

		local blocker = CombatRules.newCombatant("Bat")
		CombatRules.setBlocking(blocker, true, 10)
		expect(CombatRules.walkSpeed(blocker, 10)).toBe(SETTINGS.walkSpeed.blocking)

		blocker.stunnedUntil = 11
		expect(CombatRules.walkSpeed(blocker, 10)).toBe(SETTINGS.walkSpeed.stunned)
	end)
end)

describe("CombatRules weapons", function()
	it("switches weapon with no logic change and restarts the combo", function()
		local fighter = CombatRules.newCombatant("Bat")
		CombatRules.tryStartAttack(fighter, 10)

		expect(CombatRules.equip(fighter, "Spanner", 10.05)).toBe("Busy")
		expect(CombatRules.equip(fighter, "Spanner", 20)).toBe(nil)

		local attack = CombatRules.tryStartAttack(fighter, 20)
		expect(attack.step).toBe(WeaponConfig.Weapons.Spanner.combo[1])
	end)

	it("rejects unknown weapons", function()
		local fighter = CombatRules.newCombatant("Bat")
		expect(CombatRules.equip(fighter, "Bazooka", 10)).toBe("UnknownWeapon")
	end)
end)
