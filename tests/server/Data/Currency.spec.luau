--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Currency = Source.require("src/server/Data/Currency")

local function pack(...)
	return { ... }
end

describe("Currency", function()
	it("adds positive whole amounts", function()
		expect(pack(Currency.add(100, 50))).toEqual({ true, 150 })
	end)

	it("spends when the balance covers it", function()
		expect(pack(Currency.spend(100, 100))).toEqual({ true, 0 })
	end)

	it("refuses to overspend", function()
		expect(pack(Currency.spend(100, 101))).toEqual({ false, 100 })
	end)

	it("refuses negative, zero, fractional and non-number amounts", function()
		for _, bad in { -500, 0, 2.5, 0 / 0, math.huge, "50", nil } do
			expect(pack(Currency.add(100, bad :: any))).toEqual({ false, 100 })
			expect(pack(Currency.spend(100, bad :: any))).toEqual({ false, 100 })
		end
	end)

	it("caps the balance", function()
		local _, balance = Currency.add(Currency.MAX_BALANCE - 1, 10)
		expect(balance).toBe(Currency.MAX_BALANCE)
	end)
end)
