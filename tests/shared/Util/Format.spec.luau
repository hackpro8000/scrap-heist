--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Format = Source.require("src/shared/Util/Format")

describe("Format.short", function()
	it("leaves small numbers alone", function()
		expect(Format.short(0)).toBe("0")
		expect(Format.short(950)).toBe("950")
		expect(Format.short(1.4)).toBe("1.4")
	end)

	it("shortens thousands to trillions", function()
		expect(Format.short(1000)).toBe("1K")
		expect(Format.short(1250)).toBe("1.2K")
		expect(Format.short(34500000)).toBe("34.5M")
		expect(Format.short(425e6)).toBe("425M")
		expect(Format.short(2e9)).toBe("2B")
		expect(Format.short(1.5e12)).toBe("1.5T")
	end)

	it("never rounds up into the next unit", function()
		expect(Format.short(999999)).toBe("999K")
	end)

	it("keeps the sign", function()
		expect(Format.short(-2500)).toBe("-2.5K")
	end)
end)
