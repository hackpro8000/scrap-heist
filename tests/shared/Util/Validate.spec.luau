--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Validate = Source.require("src/shared/Util/Validate")

local NAN = 0 / 0

describe("Validate", function()
	it("rejects NaN and infinities as numbers", function()
		expect(Validate.isFiniteNumber(1.5)).toBe(true)
		expect(Validate.isFiniteNumber(NAN)).toBe(false)
		expect(Validate.isFiniteNumber(math.huge)).toBe(false)
		expect(Validate.isFiniteNumber(-math.huge)).toBe(false)
		expect(Validate.isFiniteNumber("5")).toBe(false)
	end)

	it("checks integers", function()
		expect(Validate.isPositiveInteger(3)).toBe(true)
		expect(Validate.isPositiveInteger(0)).toBe(false)
		expect(Validate.isPositiveInteger(2.5)).toBe(false)
		expect(Validate.isPositiveInteger(NAN)).toBe(false)
		expect(Validate.isNonNegativeInteger(0)).toBe(true)
		expect(Validate.isNonNegativeInteger(-1)).toBe(false)
	end)

	it("checks string length", function()
		expect(Validate.isShortString("Bat", 10)).toBe(true)
		expect(Validate.isShortString("", 10)).toBe(false)
		expect(Validate.isShortString(string.rep("a", 11), 10)).toBe(false)
		expect(Validate.isShortString({}, 10)).toBe(false)
	end)

	it("checks membership by key", function()
		local allowed = { Bat = true }
		expect(Validate.isOneOf("Bat", allowed)).toBe(true)
		expect(Validate.isOneOf("Zap", allowed)).toBe(false)
		expect(Validate.isOneOf(nil, allowed)).toBe(false)
	end)
end)
