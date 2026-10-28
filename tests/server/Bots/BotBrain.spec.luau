--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local BotBrain = Source.require("src/server/Bots/BotBrain")
local BotsConfig = Source.require("src/shared/Config/Bots")

local SCRAPPER = BotsConfig.Types.Scrapper
local ZAPPER = BotsConfig.Types.Zapper

local function see(distance: number?, health: number?)
	return {
		hasTarget = distance ~= nil,
		targetDistance = distance or math.huge,
		healthFraction = health or 1,
	}
end

describe("BotBrain.decide", function()
	it("idles without a target", function()
		expect(BotBrain.decide("Chase", BotBrain.newMemory(), see(nil), SCRAPPER, 0)).toBe("Idle")
	end)

	it("chases out of range and attacks in range", function()
		local memory = BotBrain.newMemory()
		expect(BotBrain.decide("Idle", memory, see(SCRAPPER.attackRange + 1), SCRAPPER, 0)).toBe("Chase")
		expect(BotBrain.decide("Chase", memory, see(SCRAPPER.attackRange), SCRAPPER, 0)).toBe("Attack")
	end)

	it("uses each type's own attack range", function()
		local memory = BotBrain.newMemory()
		expect(BotBrain.decide("Chase", memory, see(20), SCRAPPER, 0)).toBe("Chase")
		expect(BotBrain.decide("Chase", memory, see(20), ZAPPER, 0)).toBe("Attack")
	end)

	it("retreats once when badly hurt, then fights again", function()
		local memory = BotBrain.newMemory()
		local hurt = see(5, ZAPPER.retreatHealthFraction)

		expect(BotBrain.decide("Attack", memory, hurt, ZAPPER, 10)).toBe("Retreat")
		expect(BotBrain.decide("Retreat", memory, hurt, ZAPPER, 10 + BotsConfig.RETREAT_SECONDS - 0.1)).toBe("Retreat")
		expect(BotBrain.decide("Retreat", memory, hurt, ZAPPER, 10 + BotsConfig.RETREAT_SECONDS)).toBe("Attack")
		expect(BotBrain.decide("Attack", memory, hurt, ZAPPER, 100)).toBe("Attack")
	end)

	it("never retreats for types that don't", function()
		expect(BotBrain.decide("Attack", BotBrain.newMemory(), see(3, 0.01), SCRAPPER, 0)).toBe("Attack")
	end)
end)

describe("BotBrain.pickTarget", function()
	it("picks the nearest player", function()
		local candidates = {
			{ id = "far", position = Vector3.new(50, 0, 0), threat = 0 },
			{ id = "near", position = Vector3.new(10, 0, 0), threat = 0 },
		}
		expect(BotBrain.pickTarget(Vector3.zero, candidates)).toBe("near")
	end)

	it("turns on whoever has dealt it damage", function()
		local candidates = {
			{ id = "bystander", position = Vector3.new(10, 0, 0), threat = 0 },
			{ id = "attacker", position = Vector3.new(30, 0, 0), threat = 20 / BotsConfig.THREAT_STUDS_PER_DAMAGE + 1 },
		}
		expect(BotBrain.pickTarget(Vector3.zero, candidates)).toBe("attacker")
	end)

	it("ignores players beyond aggro range", function()
		local candidates = { { id = "far", position = Vector3.new(BotsConfig.AGGRO_RANGE + 1, 0, 0), threat = 0 } }
		expect(BotBrain.pickTarget(Vector3.zero, candidates)).toBe(nil)
	end)
end)

describe("BotBrain.checkStuck", function()
	it("is fine while making progress", function()
		local memory = BotBrain.newMemory()
		BotBrain.checkStuck(memory, Vector3.zero, true, 0)
		expect(BotBrain.checkStuck(memory, Vector3.new(5, 0, 0), true, 10)).toBe("Fine")
	end)

	it("jumps, then hops, when it stops making progress", function()
		local memory = BotBrain.newMemory()
		BotBrain.checkStuck(memory, Vector3.zero, true, 0)

		expect(BotBrain.checkStuck(memory, Vector3.zero, true, BotsConfig.STUCK_SECONDS - 0.1)).toBe("Fine")
		expect(BotBrain.checkStuck(memory, Vector3.zero, true, BotsConfig.STUCK_SECONDS)).toBe("Jump")
		expect(BotBrain.checkStuck(memory, Vector3.zero, true, BotsConfig.UNSTICK_SECONDS)).toBe("Hop")
		-- The hop resets the timer.
		expect(BotBrain.checkStuck(memory, Vector3.zero, true, BotsConfig.UNSTICK_SECONDS + 0.1)).toBe("Fine")
	end)

	it("doesn't count standing still on purpose as stuck", function()
		local memory = BotBrain.newMemory()
		BotBrain.checkStuck(memory, Vector3.zero, false, 0)
		expect(BotBrain.checkStuck(memory, Vector3.zero, false, 100)).toBe("Fine")
	end)
end)
