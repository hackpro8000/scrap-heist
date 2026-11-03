--!strict
local Roblox = require("../../Roblox")
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Trove = Source.require("src/shared/Util/Trove")

describe("Trove", function()
	it("runs cleanup functions newest first", function()
		local trove = Trove.new()
		local order = {}
		trove:add(function()
			table.insert(order, "first")
		end)
		trove:add(function()
			table.insert(order, "second")
		end)

		trove:clean()

		expect(order).toEqual({ "second", "first" })
	end)

	it("disconnects connections made with connect", function()
		local trove = Trove.new()
		local signal = Roblox.newSignal()
		local calls = 0
		trove:connect(signal :: any, function()
			calls += 1
		end)

		trove:clean()
		signal:Fire()

		expect(calls).toBe(0)
		expect(signal:listenerCount()).toBe(0)
	end)

	it("calls destroy on tracked objects", function()
		local trove = Trove.new()
		local destroyed = false
		trove:add({
			destroy = function()
				destroyed = true
			end,
		})

		trove:clean()

		expect(destroyed).toBe(true)
	end)

	it("cancels tracked threads before they run", function()
		local trove = Trove.new()
		local ran = false
		trove:add(task.delay(0, function()
			ran = true
		end))

		trove:clean()
		task.wait()

		expect(ran).toBe(false)
	end)

	it("cleans a child trove from extend with its parent", function()
		local parent = Trove.new()
		local child = parent:extend()
		local cleaned = false
		child:add(function()
			cleaned = true
		end)

		parent:clean()

		expect(cleaned).toBe(true)
	end)

	it("stays usable after clean", function()
		local trove = Trove.new()
		local calls = 0
		trove:add(function()
			calls += 1
		end)
		trove:clean()
		trove:add(function()
			calls += 1
		end)
		trove:clean()

		expect(calls).toBe(2)
	end)

	it("refuses to add while cleaning", function()
		local trove = Trove.new()
		local addError
		trove:add(function()
			addError = select(2, pcall(trove.add, trove, function() end))
		end)

		trove:clean()

		expect(function()
			error(addError)
		end).toThrow("cannot add while cleaning")
	end)
end)
