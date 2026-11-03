--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Assets = Source.require("src/shared/Assets")
local WeaponConfig = Source.require("src/shared/Combat/WeaponConfig")

local STEP_NUMBERS = { "damage", "postureDamage", "windup", "recovery", "range", "width", "height", "knockback" }

describe("WeaponConfig", function()
	it("gives every combo step valid numbers and a known animation", function()
		for weaponName, weapon in WeaponConfig.Weapons do
			expect(#weapon.combo > 0).toBe(true)
			for index, step in weapon.combo do
				for _, field in STEP_NUMBERS do
					local value = step[field]
					if type(value) ~= "number" or value < 0 then
						error(`{weaponName} step {index}: {field} must be a non-negative number`)
					end
				end
				if step.windup <= 0 then
					error(`{weaponName} step {index}: windup must be positive so spam can't skip it`)
				end
				if Assets.Animations[step.animation] == nil then
					error(`{weaponName} step {index}: animation {step.animation} missing from Assets`)
				end
			end
		end
	end)

	it("lists only real weapons as player weapons", function()
		for _, name in WeaponConfig.PLAYER_WEAPONS do
			expect(WeaponConfig.Weapons[name] ~= nil).toBe(true)
		end
		expect(WeaponConfig.isPlayerWeapon(WeaponConfig.DEFAULT_PLAYER_WEAPON)).toBe(true)
	end)

	it("keeps bot weapons out of players' hands", function()
		expect(WeaponConfig.isPlayerWeapon("Zap")).toBe(false)
		expect(WeaponConfig.isPlayerWeapon(42)).toBe(false)
	end)

	it("gives player weapons a real parry window", function()
		for _, name in WeaponConfig.PLAYER_WEAPONS do
			local weapon = WeaponConfig.Weapons[name]
			expect(weapon.parryWindow > 0 and weapon.blockAngle > 0).toBe(true)
		end
	end)
end)
