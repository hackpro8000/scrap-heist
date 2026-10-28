--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local TradeConfig = Source.require("src/shared/Config/Trade")
local TradeSession = Source.require("src/server/Trade/TradeSession")

local COUNTDOWN = TradeConfig.COUNTDOWN_SECONDS

local function offerOf(stacks, uniques)
	return { stacks = stacks or {}, uniques = uniques or {} }
end

-- Runs a session from open to "both confirmed".
local function agree(session, now: number): boolean
	TradeSession.setReady(session, "ana", true, now)
	TradeSession.setReady(session, "ben", true, now)
	TradeSession.advance(session, now + COUNTDOWN)
	TradeSession.confirm(session, "ana")
	local _, both = TradeSession.confirm(session, "ben")
	return both
end

describe("TradeSession phases", function()
	it("starts open with empty offers", function()
		local session = TradeSession.new("ana", "ben")

		expect(session.phase).toBe("Open")
		expect(session.offers.ana).toEqual(offerOf())
		expect(TradeSession.partnerOf(session, "ana")).toBe("ben")
		expect(TradeSession.partnerOf(session, "cat")).toBe(nil)
	end)

	it("counts down once both are ready, then asks for confirmation", function()
		local session = TradeSession.new("ana", "ben")
		TradeSession.setReady(session, "ana", true, 10)
		expect(session.phase).toBe("Open")

		TradeSession.setReady(session, "ben", true, 11)
		expect(session.phase).toBe("Countdown")

		expect(TradeSession.advance(session, 11 + COUNTDOWN - 0.1)).toBe(false)
		expect(TradeSession.advance(session, 11 + COUNTDOWN)).toBe(true)
		expect(session.phase).toBe("Confirm")
	end)

	it("only finishes when both confirm", function()
		local session = TradeSession.new("ana", "ben")

		expect(agree(session, 10)).toBe(true)
	end)

	it("refuses to confirm before the countdown ends", function()
		local session = TradeSession.new("ana", "ben")
		TradeSession.setReady(session, "ana", true, 10)
		TradeSession.setReady(session, "ben", true, 10)

		expect(select(1, TradeSession.confirm(session, "ana"))).toBe("NotConfirming")
	end)

	it("resets both ready states when either offer changes", function()
		local session = TradeSession.new("ana", "ben")
		TradeSession.setReady(session, "ana", true, 10)
		TradeSession.setReady(session, "ben", true, 10)

		TradeSession.setOffer(session, "ben", offerOf({ RustyGear = 1 }))

		expect(session.phase).toBe("Open")
		expect(session.ready).toEqual({ ana = false, ben = false })
	end)

	it("resets confirmations when an offer changes during confirm", function()
		local session = TradeSession.new("ana", "ben")
		TradeSession.setReady(session, "ana", true, 10)
		TradeSession.setReady(session, "ben", true, 10)
		TradeSession.advance(session, 10 + COUNTDOWN)
		TradeSession.confirm(session, "ana")

		TradeSession.setOffer(session, "ana", offerOf({ BentBolt = 1 }))
		local reason = TradeSession.confirm(session, "ben")

		expect(reason).toBe("NotConfirming")
		expect(session.confirmed.ana).toBe(false)
	end)

	it("cancels the countdown when someone un-readies", function()
		local session = TradeSession.new("ana", "ben")
		TradeSession.setReady(session, "ana", true, 10)
		TradeSession.setReady(session, "ben", true, 10)
		TradeSession.setReady(session, "ana", false, 11)

		expect(session.phase).toBe("Open")
		expect(TradeSession.advance(session, 100)).toBe(false)
	end)

	it("ignores players outside the trade", function()
		local session = TradeSession.new("ana", "ben")

		expect(TradeSession.setOffer(session, "cat", offerOf())).toBe("NotInTrade")
		expect(TradeSession.setReady(session, "cat", true, 0)).toBe("NotInTrade")
	end)
end)

describe("TradeSession.swap", function()
	local function inventories()
		local ana = {
			stacks = { RustyGear = 10 },
			uniques = { ["cog-1"] = { itemId = "GoldenCog", createdAt = 1 } },
		}
		local ben = {
			stacks = { CopperCoil = 3 },
			uniques = { ["core-1"] = { itemId = "ReactorCore", createdAt = 2 } },
		}
		return ana, ben
	end

	it("moves both offers, keeping unique items' GUIDs", function()
		local ana, ben = inventories()
		local cogRecord = ana.uniques["cog-1"]

		local ok = TradeSession.swap(
			ana,
			ben,
			offerOf({ RustyGear = 4 }, { ["cog-1"] = true }),
			offerOf({ CopperCoil = 3 }, { ["core-1"] = true })
		)

		expect(ok).toBe(true)
		expect(ana.stacks).toEqual({ RustyGear = 6, CopperCoil = 3 })
		expect(ben.stacks).toEqual({ RustyGear = 4 })
		expect(ben.uniques["cog-1"]).toBe(cogRecord)
		expect(ana.uniques["cog-1"]).toBe(nil)
		expect(ana.uniques["core-1"].itemId).toBe("ReactorCore")
	end)

	it("moves nothing when one side no longer has an offered item", function()
		local ana, ben = inventories()
		local anaBefore, benBefore = table.clone(ana.stacks), table.clone(ben.stacks)

		local ok, reason = TradeSession.swap(
			ana,
			ben,
			offerOf({ RustyGear = 4 }),
			offerOf({}, { ["already-traded"] = true })
		)

		expect(ok).toBe(false)
		expect(reason).toBe("SecondPlayerMissingItems")
		expect(ana.stacks).toEqual(anaBefore)
		expect(ben.stacks).toEqual(benBefore)
		expect(ana.uniques["cog-1"] ~= nil).toBe(true)
	end)

	it("moves nothing when the receiver's stack would overflow", function()
		local ana, ben = inventories()
		ben.stacks.RustyGear = 9999

		local ok = TradeSession.swap(ana, ben, offerOf({ RustyGear = 1 }), offerOf())

		expect(ok).toBe(false)
		expect(ana.stacks.RustyGear).toBe(10)
	end)

	it("never leaves an item in both inventories", function()
		local ana, ben = inventories()
		TradeSession.swap(ana, ben, offerOf({}, { ["cog-1"] = true }), offerOf())

		local copies = 0
		for _, inventory in { ana, ben } do
			if inventory.uniques["cog-1"] then
				copies += 1
			end
		end
		expect(copies).toBe(1)
	end)
end)
