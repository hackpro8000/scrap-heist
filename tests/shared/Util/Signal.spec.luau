--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Signal = Source.require("src/shared/Util/Signal")

describe("Signal", function()
	it("passes fired arguments to every listener", function()
		local signal = Signal.new()
		local received = {}
		signal:connect(function(a, b)
			table.insert(received, { a, b })
		end)
		signal:connect(function(a, b)
			table.insert(received, { a, b })
		end)

		signal:fire("scrap", 5)

		expect(received).toEqual({ { "scrap", 5 }, { "scrap", 5 } })
	end)

	it("once runs a listener a single time", function()
		local signal = Signal.new()
		local calls = 0
		local connection = signal:once(function()
			calls += 1
		end)

		signal:fire()
		signal:fire()

		expect(calls).toBe(1)
		expect(connection.connected).toBe(false)
	end)

	it("stops calling a disconnected listener, and disconnecting twice is safe", function()
		local signal = Signal.new()
		local calls = 0
		local connection = signal:connect(function()
			calls += 1
		end)

		connection:disconnect()
		connection:disconnect()
		signal:fire()

		expect(calls).toBe(0)
	end)

	it("skips a listener that an earlier listener disconnects mid-fire", function()
		local signal = Signal.new()
		local laterCalls = 0
		local later: Signal.Connection

		signal:connect(function()
			later:disconnect()
		end)
		later = signal:connect(function()
			laterCalls += 1
		end)

		signal:fire()

		expect(laterCalls).toBe(0)
	end)

	it("keeps calling other listeners when one errors", function()
		local signal = Signal.new()
		local calls = 0
		signal:connect(function()
			error("listener failed on purpose")
		end)
		signal:connect(function()
			calls += 1
		end)

		signal:fire()

		expect(calls).toBe(1)
	end)

	it("wait resumes with the fired arguments", function()
		local signal = Signal.new()
		local result

		task.spawn(function()
			result = { signal:wait() }
		end)
		signal:fire("storm", 3)

		expect(result).toEqual({ "storm", 3 })
	end)

	it("destroy disconnects every listener", function()
		local signal = Signal.new()
		local calls = 0
		local first = signal:connect(function()
			calls += 1
		end)
		local second = signal:connect(function()
			calls += 1
		end)

		signal:destroy()
		signal:fire()

		expect(calls).toBe(0)
		expect(first.connected).toBe(false)
		expect(second.connected).toBe(false)
	end)
end)
