--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Belt = Source.require("src/shared/Config/Belt")
local Junkrots = Source.require("src/shared/Config/Junkrots")
local BeltRules = Source.require("src/server/Tycoon/BeltRules")

local function rollsOf(values: { number }): () -> number
	local index = 0
	return function()
		index += 1
		return values[index]
	end
end

describe("BeltRules timing", function()
	it("drops capsules faster on busier servers and in storms", function()
		expect(BeltRules.spawnSeconds(1, false)).toBe(Belt.SPAWN_SECONDS_SOLO)
		expect(BeltRules.spawnSeconds(2, false)).toBe(Belt.SPAWN_SECONDS_PAIR)
		expect(BeltRules.spawnSeconds(8, false)).toBe(Belt.SPAWN_SECONDS_CROWD)
		expect(BeltRules.spawnSeconds(8, true)).toBe(Belt.SPAWN_SECONDS_CROWD / Belt.STORM_SPEED)
	end)

	it("takes one lap in the lap time, half that in a storm", function()
		expect(math.abs(BeltRules.lapLength() / BeltRules.speed(false) - Belt.LAP_SECONDS) < 1e-6).toBe(true)
		expect(math.abs(BeltRules.lapLength() / BeltRules.speed(true) - Belt.LAP_SECONDS / 2) < 1e-6).toBe(true)
	end)
end)

describe("BeltRules.pointAt", function()
	it("is one unbroken loop", function()
		local length = BeltRules.lapLength()
		local lastX, lastZ = BeltRules.pointAt(0)
		for step = 1, 2000 do
			local x, z, headingX, headingZ = BeltRules.pointAt(step / 2000 * length)
			local moved = math.sqrt((x - lastX) ^ 2 + (z - lastZ) ^ 2)
			expect(moved < length / 2000 * 1.01).toBe(true)
			expect(math.abs(math.sqrt(headingX ^ 2 + headingZ ^ 2) - 1) < 1e-6).toBe(true)
			lastX, lastZ = x, z
		end
		local startX, startZ = BeltRules.pointAt(0)
		expect(math.abs(lastX - startX) < 1e-6 and math.abs(lastZ - startZ) < 1e-6).toBe(true)
	end)

	it("stays inside the belt's stadium", function()
		for step = 0, 200 do
			local x, z = BeltRules.pointAt(step / 200 * BeltRules.lapLength())
			expect(math.abs(x) <= Belt.STRAIGHT_HALF_LENGTH + Belt.TURN_RADIUS + 1e-6).toBe(true)
			expect(math.abs(z) <= Belt.TURN_RADIUS + 1e-6).toBe(true)
		end
	end)
end)

describe("BeltRules.rollTier", function()
	it("gives the commonest tier to low rolls and the rarest to the highest", function()
		expect(BeltRules.rollTier(0, 1, 0, false)).toBe("Scrap")
		expect(BeltRules.rollTier(0.5, 1, 0, false)).toBe("Scrap")
		expect(BeltRules.rollTier(0.8, 1, 0, false)).toBe("Salvaged")
		expect(BeltRules.rollTier(1, 1, 0, false)).toBe("Secret")
	end)

	it("never gives a tier with no odds", function()
		for step = 0, 1000 do
			expect(BeltRules.rollTier(step / 1000, 1, 0, false) ~= "Prototype").toBe(true)
		end
	end)

	it("makes rarer tiers likelier with rank", function()
		-- 0.71 is a Scrap roll at rank 0; luck shrinks Scrap's share.
		expect(BeltRules.rollTier(0.71, 1, 0, false)).toBe("Scrap")
		expect(BeltRules.rollTier(0.71, 1, 20, false)).toBe("Salvaged")
	end)

	it("lifts a storm capsule one tier, but not into the chase tiers", function()
		expect(BeltRules.rollTier(0, 1, 0, true)).toBe("Salvaged")
		expect(BeltRules.rollTier(0.8, 1, 0, true)).toBe("Refurbished")
		expect(BeltRules.rollTier(1, 1, 0, true)).toBe("Secret")
		expect(BeltRules.rollTier(0.9999, 3, 0, true)).toBe("Prototype")
	end)
end)

describe("BeltRules.rollCapsule", function()
	it("holds a junkrot of its tier", function()
		local capsule = BeltRules.rollCapsule(rollsOf({ 0, 0.999, 0.5 }), 1, 0, false)
		expect(capsule.tier).toBe("Scrap")
		expect(Junkrots.BY_ID[capsule.junkrot].tier).toBe("Scrap")
		expect(capsule.limited).toBe(false)
		expect(capsule.storm).toBe(false)
	end)

	it("is a Limited Edition on a lucky roll", function()
		local capsule = BeltRules.rollCapsule(rollsOf({ 0, 0, 0 }), 1, 0, true)
		expect(capsule.limited).toBe(true)
		expect(capsule.storm).toBe(true)
	end)
end)
