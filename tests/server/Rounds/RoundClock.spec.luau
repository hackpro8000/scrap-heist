--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local RoundClock = Source.require("src/server/Rounds/RoundClock")

local ORDER = { "Calm", "Warning", "Storm", "Results" }
local DURATIONS = { Calm = 60, Warning = 10, Storm = 90, Results = 15 }
local CYCLE = 175

describe("RoundClock", function()
	it("adds up the cycle", function()
		expect(RoundClock.cycleLength(DURATIONS, ORDER)).toBe(CYCLE)
	end)

	it("walks the phases in order with exact boundaries", function()
		local start = 1000
		local expected = {
			{ 0, "Calm" },
			{ 59.999, "Calm" },
			{ 60, "Warning" },
			{ 70, "Storm" },
			{ 160, "Results" },
			{ 174.999, "Results" },
			{ 175, "Calm" },
		}
		for _, case in expected do
			expect(RoundClock.stateAt(start, start + case[1], DURATIONS, ORDER).phase).toBe(case[2])
		end
	end)

	it("reports when the current phase ends", function()
		local state = RoundClock.stateAt(0, 75, DURATIONS, ORDER)

		expect(state.phase).toBe("Storm")
		expect(state.phaseStartedAt).toBe(70)
		expect(state.phaseEndsAt).toBe(160)
	end)

	it("doesn't drift after thousands of cycles", function()
		local cycles = 10000
		local state = RoundClock.stateAt(0, cycles * CYCLE + 70, DURATIONS, ORDER)

		expect(state.phase).toBe("Storm")
		expect(state.cycle).toBe(cycles + 1)
		expect(state.phaseStartedAt).toBe(cycles * CYCLE + 70)
	end)

	it("never has two phases at once: every instant maps to one phase", function()
		local previousEnd = 0
		local time = 0
		while time < CYCLE * 3 do
			local state = RoundClock.stateAt(0, time, DURATIONS, ORDER)
			expect(state.phaseStartedAt <= time and time < state.phaseEndsAt).toBe(true)
			expect(state.phaseStartedAt >= previousEnd - DURATIONS.Storm).toBe(true)
			previousEnd = state.phaseEndsAt
			time += 7.3
		end
	end)

	it("treats times before the start as the start", function()
		expect(RoundClock.stateAt(100, 50, DURATIONS, ORDER).phase).toBe("Calm")
	end)

	it("can jump straight to a phase", function()
		local now = 5000
		local start = RoundClock.startForPhase("Storm", now, DURATIONS, ORDER)
		local state = RoundClock.stateAt(start, now, DURATIONS, ORDER)

		expect(state.phase).toBe("Storm")
		expect(state.phaseEndsAt).toBe(now + DURATIONS.Storm)
	end)
end)
