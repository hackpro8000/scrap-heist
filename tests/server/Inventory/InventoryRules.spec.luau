--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local InventoryRules = Source.require("src/server/Inventory/InventoryRules")
local Items = Source.require("src/shared/Config/Items")

local function newInventory()
	return { stacks = {}, uniques = {} }
end

describe("InventoryRules stacks", function()
	it("adds and removes stackable counts", function()
		local inventory = newInventory()
		expect(InventoryRules.addStack(inventory, "RustyGear", 5)).toBe(true)
		expect(InventoryRules.removeStack(inventory, "RustyGear", 2)).toBe(true)

		expect(InventoryRules.countOf(inventory, "RustyGear")).toBe(3)
	end)

	it("drops the entry when a stack hits zero", function()
		local inventory = newInventory()
		InventoryRules.addStack(inventory, "RustyGear", 2)
		InventoryRules.removeStack(inventory, "RustyGear", 2)

		expect(inventory.stacks).toEqual({})
	end)

	it("refuses removing more than held, bad counts and unique items", function()
		local inventory = newInventory()
		InventoryRules.addStack(inventory, "RustyGear", 2)

		expect(InventoryRules.removeStack(inventory, "RustyGear", 3)).toBe(false)
		expect(InventoryRules.addStack(inventory, "RustyGear", -1)).toBe(false)
		expect(InventoryRules.addStack(inventory, "RustyGear", 0 / 0)).toBe(false)
		expect(InventoryRules.addStack(inventory, "GoldenCog", 1)).toBe(false)
		expect(InventoryRules.addStack(inventory, "MadeUp", 1)).toBe(false)
		expect(InventoryRules.countOf(inventory, "RustyGear")).toBe(2)
	end)

	it("caps stacks", function()
		local inventory = newInventory()
		InventoryRules.addStack(inventory, "RustyGear", Items.MAX_STACK)

		expect(InventoryRules.addStack(inventory, "RustyGear", 1)).toBe(false)
	end)
end)

describe("InventoryRules uniques", function()
	it("keeps two copies of a rare item as separate entries", function()
		local inventory = newInventory()
		InventoryRules.addUnique(inventory, "guid-a", { itemId = "GoldenCog", createdAt = 1 })
		InventoryRules.addUnique(inventory, "guid-b", { itemId = "GoldenCog", createdAt = 2 })

		expect(InventoryRules.countOf(inventory, "GoldenCog")).toBe(2)
		expect(inventory.uniques["guid-a"] ~= inventory.uniques["guid-b"]).toBe(true)
	end)

	it("refuses a GUID that's already present", function()
		local inventory = newInventory()
		InventoryRules.addUnique(inventory, "guid-a", { itemId = "GoldenCog", createdAt = 1 })

		expect(InventoryRules.addUnique(inventory, "guid-a", { itemId = "ReactorCore", createdAt = 2 })).toBe(false)
		expect(inventory.uniques["guid-a"].itemId).toBe("GoldenCog")
	end)

	it("refuses stackable items as uniques", function()
		expect(InventoryRules.addUnique(newInventory(), "guid-a", { itemId = "RustyGear", createdAt = 1 })).toBe(false)
	end)
end)

describe("InventoryRules offers", function()
	it("accepts a well-formed offer", function()
		local offer = { stacks = { RustyGear = 2 }, uniques = { ["guid-a"] = true } }
		expect(InventoryRules.isValidOffer(offer, 12)).toBe(true)
	end)

	it("rejects malformed offers from clients", function()
		local bad = {
			"offer",
			{ stacks = {} },
			{ stacks = { RustyGear = -1 }, uniques = {} },
			{ stacks = { RustyGear = 1.5 }, uniques = {} },
			{ stacks = { GoldenCog = 1 }, uniques = {} },
			{ stacks = { NotAnItem = 1 }, uniques = {} },
			{ stacks = {}, uniques = { ["guid-a"] = "yes" } },
			{ stacks = {}, uniques = { [123] = true } },
			{ stacks = {}, uniques = { [string.rep("x", 100)] = true } },
		}
		for _, offer in bad do
			expect(InventoryRules.isValidOffer(offer, 12)).toBe(false)
		end
	end)

	it("rejects offers with too many entries", function()
		local offer = { stacks = { RustyGear = 1, BentBolt = 1 }, uniques = { a = true } }
		expect(InventoryRules.isValidOffer(offer, 2)).toBe(false)
	end)

	it("checks the inventory holds everything offered", function()
		local inventory = newInventory()
		InventoryRules.addStack(inventory, "RustyGear", 2)
		InventoryRules.addUnique(inventory, "guid-a", { itemId = "GoldenCog", createdAt = 1 })

		local held = { stacks = { RustyGear = 2 }, uniques = { ["guid-a"] = true } }
		expect(InventoryRules.hasOffer(inventory, held)).toBe(true)
		expect(InventoryRules.hasOffer(inventory, { stacks = { RustyGear = 3 }, uniques = {} })).toBe(false)
		expect(InventoryRules.hasOffer(inventory, { stacks = {}, uniques = { ["guid-z"] = true } })).toBe(false)
	end)

	it("describes unique items by item ID", function()
		local inventory = newInventory()
		InventoryRules.addUnique(inventory, "guid-a", { itemId = "GoldenCog", createdAt = 1 })

		local offer = { stacks = { BentBolt = 1 }, uniques = { ["guid-a"] = true } }
		local description = InventoryRules.describeOffer(inventory, offer)

		expect(description).toEqual({ stacks = { BentBolt = 1 }, uniques = { ["guid-a"] = "GoldenCog" } })
	end)
end)
