--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local ProfileSchema = Source.require("src/server/Data/ProfileSchema")

describe("ProfileSchema.reconcile", function()
	it("fills a new template field into an old save without touching the rest", function()
		local oldSave = {
			version = 1,
			scrap = 750,
			inventory = {
				stacks = { RustyGear = 3 },
				uniques = { ["guid-1"] = { itemId = "GoldenCog", createdAt = 5 } },
			},
		}

		ProfileSchema.reconcile(oldSave)

		expect(oldSave.scrap).toBe(750)
		expect(oldSave.inventory.stacks).toEqual({ RustyGear = 3 })
		expect(oldSave.inventory.uniques["guid-1"].itemId).toBe("GoldenCog")
		expect(oldSave.yard).toEqual({ objects = {}, nextObjectId = 1, crateScrap = 0 })
		expect(oldSave.stats.raidsWon).toBe(0)
	end)

	it("fills missing fields inside nested tables", function()
		local save = { yard = { crateScrap = 40 } }

		ProfileSchema.reconcile(save)

		expect(save.yard.crateScrap).toBe(40)
		expect(save.yard.objects).toEqual({})
		expect(save.yard.nextObjectId).toBe(1)
	end)

	it("changes nothing when run twice", function()
		local save = ProfileSchema.newData()
		save.scrap = 10
		ProfileSchema.reconcile(save)
		local once = table.clone(save)

		ProfileSchema.reconcile(save)

		expect(save).toEqual(once)
	end)

	it("copies defaults, so saves never share a table with the template", function()
		local first = ProfileSchema.newData()
		local second = ProfileSchema.newData()
		first.inventory.stacks.RustyGear = 1

		expect(second.inventory.stacks.RustyGear).toBe(nil)
		expect(ProfileSchema.TEMPLATE.inventory.stacks.RustyGear).toBe(nil)
	end)
end)

describe("ProfileSchema.migrate", function()
	local migrations = {
		[1] = function(data)
			data.credits = data.scrap
			data.scrap = nil
			return data
		end,
		[2] = function(data)
			data.credits *= 2
			return data
		end,
	}

	it("runs each step from the save's version to the target", function()
		local save = ProfileSchema.migrate({ version = 1, scrap = 5 }, migrations, 3)

		expect(save).toEqual({ version = 3, credits = 10 })
	end)

	it("skips steps a save already has", function()
		local save = ProfileSchema.migrate({ version = 2, credits = 5 }, migrations, 3)

		expect(save.credits).toBe(10)
	end)

	it("treats unversioned saves as version 1", function()
		local save = ProfileSchema.migrate({ scrap = 1 }, migrations, 2)

		expect(save).toEqual({ version = 2, credits = 1 })
	end)

	it("fails loudly on a missing step instead of loading a half-migrated save", function()
		expect(function()
			ProfileSchema.migrate({ version = 1 }, {}, 2)
		end).toThrow("no migration from version 1")
	end)

	it("drops old machines for the new yard but keeps what was in the crate", function()
		local save = ProfileSchema.migrate({
			version = 1,
			scrap = 900,
			yard = { machines = { Pad1 = { level = 2 } }, crateParts = 120 },
			tutorial = { Welcome = true },
		})
		ProfileSchema.reconcile(save)

		expect(save.version).toBe(ProfileSchema.VERSION)
		expect(save.scrap).toBe(900)
		expect(save.yard).toEqual({ objects = {}, nextObjectId = 1, crateScrap = 120 })
		expect(save.tutorial).toBe(nil)
		expect(save.rank).toBe(0)
	end)

	it("has a migration for every version below the current one", function()
		for version = 1, ProfileSchema.VERSION - 1 do
			expect(ProfileSchema.MIGRATIONS[version] ~= nil).toBe(true)
		end
	end)
end)
