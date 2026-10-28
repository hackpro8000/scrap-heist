--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local BotsConfig = Source.require("src/shared/Config/Bots")
local WaveRules = Source.require("src/server/Bots/WaveRules")

describe("WaveRules", function()
	it("grows waves with the round number", function()
		local early = WaveRules.total(WaveRules.composition(1, 1, 1000))
		local late = WaveRules.total(WaveRules.composition(6, 1, 1000))

		expect(late > early).toBe(true)
	end)

	it("grows waves within a storm", function()
		local first = WaveRules.total(WaveRules.composition(2, 1, 1000))
		local third = WaveRules.total(WaveRules.composition(2, 3, 1000))

		expect(third > first).toBe(true)
	end)

	it("follows the configured growth", function()
		local growth = BotsConfig.WAVE_GROWTH.Scrapper
		local wave = WaveRules.composition(3, 2, 1000)

		expect(wave.Scrapper).toBe(math.floor(growth.base + growth.perRound * 2 + growth.perWave))
	end)

	it("never goes past the room left, and keeps a capped wave mixed", function()
		local wave = WaveRules.composition(10, 5, 3)

		expect(WaveRules.total(wave)).toBe(3)
		expect(wave.Scrapper).toBe(1)
		expect(wave.Zapper).toBe(1)
		expect(wave.Bruiser).toBe(1)
	end)

	it("spawns nothing when full", function()
		expect(WaveRules.total(WaveRules.composition(5, 1, 0))).toBe(0)
	end)

	it("starts round one with only weaker bots", function()
		expect(WaveRules.composition(1, 1, 1000).Bruiser).toBe(nil)
	end)
end)
