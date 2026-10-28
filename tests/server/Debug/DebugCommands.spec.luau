--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local DebugCommands = Source.require("src/server/Debug/DebugCommands")

local function pack(...)
	return { ... }
end

describe("DebugCommands", function()
	it("splits a command into a lowercase name and its arguments", function()
		expect(pack(DebugCommands.parse("/GiveScrap  500 extra"))).toEqual({ "givescrap", { "500", "extra" } })
	end)

	it("ignores normal chat and an empty prefix", function()
		expect(DebugCommands.parse("hello /givescrap")).toBe(nil)
		expect(DebugCommands.parse("/")).toBe(nil)
		expect(DebugCommands.parse(string.rep("/a", 100))).toBe(nil)
	end)

	it("allows everyone in Studio, only admins in live servers", function()
		expect(DebugCommands.isAllowed(1, true, {})).toBe(true)
		expect(DebugCommands.isAllowed(1, false, {})).toBe(false)
		expect(DebugCommands.isAllowed(42, false, { 42 })).toBe(true)
	end)
end)
