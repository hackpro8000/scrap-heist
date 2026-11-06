--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Junkrots = Source.require("src/shared/Config/Junkrots")
local Rebirth = Source.require("src/shared/Config/Rebirth")
local RebirthRules = Source.require("src/server/Tycoon/RebirthRules")

local function pads(junkrots: { any }): { any }
	local objects = {}
	for id, junkrot in junkrots do
		table.insert(objects, { id = id, kind = "Pad", family = "Kitchen", x = 0, z = 0, turn = 0, junkrot = junkrot })
	end
	return objects
end

local RANK_ONE = pads({
	{ id = "CanettoRustini", stars = 1 },
	{ id = "TyroFlattino", stars = 1 },
	{ id = "RemotinoMuto", stars = 2 },
})

describe("Rebirth config", function()
	it("names only junkrots and tiers that exist, and costs more each rank", function()
		expect(Rebirth.MAX_RANK).toBe(20)
		local last = 0
		for _, step in Rebirth.LADDER do
			expect(step.cost > last).toBe(true)
			last = step.cost
			for _, need in step.needs do
				if need.id then
					expect(Junkrots.BY_ID[need.id] ~= nil).toBe(true)
				else
					expect(Junkrots.TIER_INFO[need.tier] ~= nil).toBe(true)
				end
			end
		end
	end)

	it("never asks for a Prototype or a Secret", function()
		for _, step in Rebirth.LADDER do
			for _, need in step.needs do
				local tier = if need.id then Junkrots.BY_ID[need.id].tier else need.tier
				expect(tier ~= "Prototype" and tier ~= "Secret").toBe(true)
			end
		end
	end)
end)

describe("RebirthRules", function()
	it("adds half again to income each rank", function()
		expect(RebirthRules.incomeMultiplier(0)).toBe(1)
		expect(RebirthRules.incomeMultiplier(20)).toBe(11)
	end)

	it("allows a rank when its junkrots stand in the yard and the scrap is there", function()
		expect(RebirthRules.canRebirth(0, Rebirth.LADDER[1].cost, RANK_ONE)).toBe(nil)
	end)

	it("refuses without the scrap", function()
		expect(RebirthRules.canRebirth(0, Rebirth.LADDER[1].cost - 1, RANK_ONE)).toBe("NotEnoughScrap")
	end)

	it("lists the junkrots still missing", function()
		local objects = pads({ { id = "CanettoRustini", stars = 1 } })
		local missing = RebirthRules.missing(0, objects)
		expect(#missing).toBe(2)
		expect(RebirthRules.describe(missing[1])).toBe("Tyro Flattino")
		expect(RebirthRules.canRebirth(0, 1e15, objects)).toBe("MissingJunkrots")
	end)

	it("asks for stars where the rank does", function()
		local needed = { "FrostboxGelatone", "DrilloTrapanino", "TypewrittoClackini" }
		local low, high = {}, {}
		for _, id in needed do
			table.insert(low, { id = id, stars = 2 })
			table.insert(high, { id = id, stars = 3 })
		end
		expect(#RebirthRules.missing(7, pads(low))).toBe(3)
		expect(#RebirthRules.missing(7, pads(high))).toBe(0)
		expect(RebirthRules.describe(RebirthRules.missing(7, pads(low))[1])).toBe("Frostbox Gelatone ★3")
	end)

	it("counts any junkrot of a tier, each one once", function()
		local two = pads({ { id = "GrindoBeanbasher", stars = 5 }, { id = "AirfryoCroccante", stars = 5 } })
		local missing = RebirthRules.missing(14, two)
		expect(#missing).toBe(1)
		expect(missing[1].count).toBe(1)
		expect(RebirthRules.describe(Rebirth.LADDER[15].needs[1])).toBe("3 x any Factory ★5")
	end)

	it("keeps high-starred junkrots for the needs that ask for stars", function()
		-- Rank 20: a Limited Edition Precision, and two Precision at 5 stars.
		local objects = pads({
			{ id = "ChefbotPrecisio", stars = 5, limited = true },
			{ id = "DronettoBuzzatti", stars = 5 },
			{ id = "TorquoWrenchelli", stars = 1, limited = true },
		})
		expect(#RebirthRules.missing(19, objects)).toBe(0)
	end)

	it("stops at the top rank", function()
		expect(RebirthRules.next(Rebirth.MAX_RANK)).toBe(nil)
		expect(RebirthRules.canRebirth(Rebirth.MAX_RANK, 1e18, RANK_ONE)).toBe("TopRank")
	end)
end)
