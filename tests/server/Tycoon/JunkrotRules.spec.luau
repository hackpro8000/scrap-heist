--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Belt = Source.require("src/shared/Config/Belt")
local Economy = Source.require("src/shared/Config/Economy")
local Junkrots = Source.require("src/shared/Config/Junkrots")
local Yard = Source.require("src/shared/Config/Yard")
local JunkrotRules = Source.require("src/server/Tycoon/JunkrotRules")

local CAN = Junkrots.BY_ID.CanettoRustini
local TOASTER = Junkrots.BY_ID.CrumboPoppalot

local function pad(id: number, family: string, junkrot: any?): any
	return { id = id, kind = "Pad", family = family, x = 0, z = 0, turn = 0, junkrot = junkrot }
end

describe("Junkrots config", function()
	it("has the whole cast, each tier in its band", function()
		expect(#Junkrots.LIST).toBe(63)
		local bands = {
			Scrap = { 1, 4 },
			Salvaged = { 12, 30 },
			Refurbished = { 150, 320 },
			Factory = { 2000, 4500 },
			Precision = { 30000, 60000 },
			Prototype = { 400000, 800000 },
			Secret = { 5e6, 1e7 },
		}
		for _, junkrot in Junkrots.LIST do
			local band = bands[junkrot.tier]
			expect(junkrot.rate >= band[1] and junkrot.rate <= band[2]).toBe(true)
			expect(table.find(Junkrots.FAMILIES, junkrot.family) ~= nil).toBe(true)
		end
	end)

	it("lets a new player afford any Scrap capsule", function()
		for _, junkrot in Junkrots.BY_TIER.Scrap do
			expect(JunkrotRules.capsulePrice(junkrot.id) <= Economy.STARTING_SCRAP).toBe(true)
		end
	end)
end)

describe("JunkrotRules capsules", function()
	it("prices a capsule in seconds of its junkrot's output", function()
		expect(JunkrotRules.capsulePrice(CAN.id)).toBe(CAN.rate * Junkrots.TIER_INFO.Scrap.priceSeconds)
		expect(JunkrotRules.capsulePrice(TOASTER.id)).toBe(TOASTER.rate * Junkrots.TIER_INFO.Salvaged.priceSeconds)
	end)

	it("hatches slower when left alone", function()
		expect(JunkrotRules.hatchSeconds(CAN.id)).toBe(Junkrots.TIER_INFO.Scrap.hatchSeconds)
		expect(JunkrotRules.hatchProgress(5, true)).toBe(5)
		expect(JunkrotRules.hatchProgress(5, false)).toBe(5 / Junkrots.UNATTENDED_HATCH_FACTOR)
	end)

	it("refunds a share of the price", function()
		expect(JunkrotRules.refund(TOASTER.id)).toBe(
			math.floor(JunkrotRules.capsulePrice(TOASTER.id) * Junkrots.SCRAP_REFUND)
		)
	end)
end)

describe("JunkrotRules income", function()
	it("doubles with each star", function()
		expect(JunkrotRules.rate({ id = CAN.id, stars = 1 })).toBe(CAN.rate)
		expect(JunkrotRules.rate({ id = CAN.id, stars = 5 })).toBe(CAN.rate * 16)
	end)

	it("pays more on a pad of the junkrot's family, and for a Limited Edition", function()
		expect(JunkrotRules.rate({ id = CAN.id, stars = 1 }, CAN.family)).toBe(CAN.rate * (1 + Junkrots.FAMILY_BONUS))
		expect(JunkrotRules.rate({ id = CAN.id, stars = 1 }, "Garage")).toBe(CAN.rate)
		expect(JunkrotRules.rate({ id = CAN.id, stars = 1, limited = true })).toBe(CAN.rate * Belt.LIMITED_MULTIPLIER)
	end)

	it("earns nothing from a junkrot that no longer exists", function()
		expect(JunkrotRules.rate({ id = "Gone", stars = 3 })).toBe(0)
	end)

	it("sums a yard's junkrots and applies the owner's multiplier", function()
		local objects = {
			pad(1, "Garage", { id = CAN.id, stars = 1 }),
			pad(2, "Garage", { id = TOASTER.id, stars = 2 }),
			pad(3, "Garage"),
			{ id = 4, kind = "Crate", x = 0, z = 0, turn = 0 },
		}
		expect(JunkrotRules.yardIncome(objects, 3)).toBe((CAN.rate + TOASTER.rate * 2) * 3)
	end)

	it("fills the crate and stops at capacity", function()
		expect(JunkrotRules.earn(0, 10, 5, 2000)).toBe(50)
		expect(JunkrotRules.earn(1990, 10, 5, 2000)).toBe(2000)
		-- A crate already over capacity (its yard lost income) keeps what it has.
		expect(JunkrotRules.earn(5000, 10, 5, 2000)).toBe(5000)
	end)

	it("sizes the crate to the yard's income", function()
		expect(JunkrotRules.crateCapacity(0)).toBe(Yard.CRATE_MIN)
		expect(JunkrotRules.crateCapacity(1000)).toBe(1000 * Yard.CRATE_SECONDS)
	end)

	it("pays capped, reduced offline earnings", function()
		expect(JunkrotRules.offlineEarnings(10, 100)).toBe(10 * 100 * Economy.OFFLINE_RATE)
		expect(JunkrotRules.offlineEarnings(10, 1e9)).toBe(10 * Economy.OFFLINE_CAP_SECONDS * Economy.OFFLINE_RATE)
		expect(JunkrotRules.offlineEarnings(10, -50)).toBe(0)
	end)
end)

describe("JunkrotRules stars", function()
	it("costs more parts each star and each tier", function()
		expect(JunkrotRules.starCost(CAN.id, 1)).toBe(10)
		expect(JunkrotRules.starCost(CAN.id, 4)).toBe(270)
		expect(JunkrotRules.starCost(TOASTER.id, 1)).toBe(30)
		expect(JunkrotRules.starCost("UnitZero", 4)).toBe(196830)
	end)

	it("stops at the most stars", function()
		expect(JunkrotRules.starCost(CAN.id, Junkrots.MAX_STARS)).toBe(nil)
	end)
end)

describe("JunkrotRules.choosePad", function()
	it("prefers an empty pad of the junkrot's family", function()
		local objects = { pad(1, "Garage"), pad(2, "Kitchen"), pad(3, "Gadget") }
		local chosen, replaced = JunkrotRules.choosePad(objects, CAN.id)
		expect(chosen.id).toBe(2)
		expect(replaced).toBe(nil)
	end)

	it("takes any empty pad when its family's are full", function()
		local objects = { pad(1, "Kitchen", { id = CAN.id, stars = 1 }), pad(2, "Gadget") }
		local chosen = JunkrotRules.choosePad(objects, CAN.id)
		expect(chosen.id).toBe(2)
	end)

	it("replaces the weakest earner when the yard is full", function()
		local objects = {
			pad(1, "Kitchen", { id = TOASTER.id, stars = 1 }),
			pad(2, "Garage", { id = CAN.id, stars = 1 }),
		}
		local chosen, replaced = JunkrotRules.choosePad(objects, TOASTER.id)
		expect(chosen.id).toBe(2)
		expect(replaced.id).toBe(CAN.id)
	end)

	it("places nothing when the newcomer is the weakest", function()
		local objects = { pad(1, "Kitchen", { id = TOASTER.id, stars = 1 }) }
		local chosen = JunkrotRules.choosePad(objects, CAN.id)
		expect(chosen).toBe(nil)
	end)
end)
