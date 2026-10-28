--!strict
local RateLimiter = require("@shared/Util/RateLimiter")
local Roblox = require("../../Roblox")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- A clock the spec moves by hand, so refill timing is exact and instant.
local function newClock()
	local clock = { now = 0 }
	function clock.read(): number
		return clock.now
	end

	return clock
end

local function newPlayer(name: string): Player
	return { Name = name } :: any
end

describe("RateLimiter", function()
	it("allows a burst, then refuses", function()
		local clock = newClock()
		local limiter = RateLimiter.new(2, 3, clock.read)
		local player = newPlayer("Raider")

		expect(limiter:check(player)).toBe(true)
		expect(limiter:check(player)).toBe(true)
		expect(limiter:check(player)).toBe(true)
		expect(limiter:check(player)).toBe(false)

		limiter:destroy()
	end)

	it("refills at perSecond", function()
		local clock = newClock()
		local limiter = RateLimiter.new(2, 1, clock.read)
		local player = newPlayer("Raider")

		expect(limiter:check(player)).toBe(true)
		expect(limiter:check(player)).toBe(false)

		clock.now += 0.25
		expect(limiter:check(player)).toBe(false)

		clock.now += 0.25
		expect(limiter:check(player)).toBe(true)

		limiter:destroy()
	end)

	it("never refills above burst after a long idle", function()
		local clock = newClock()
		local limiter = RateLimiter.new(10, 2, clock.read)
		local player = newPlayer("Raider")

		limiter:check(player)
		clock.now += 60

		expect(limiter:check(player)).toBe(true)
		expect(limiter:check(player)).toBe(true)
		expect(limiter:check(player)).toBe(false)

		limiter:destroy()
	end)

	it("defaults burst to one second of calls", function()
		local clock = newClock()
		local limiter = RateLimiter.new(3, nil, clock.read)
		local player = newPlayer("Raider")

		for _ = 1, 3 do
			expect(limiter:check(player)).toBe(true)
		end
		expect(limiter:check(player)).toBe(false)

		limiter:destroy()
	end)

	it("tracks each player separately", function()
		local clock = newClock()
		local limiter = RateLimiter.new(1, 1, clock.read)
		local spammer = newPlayer("Spammer")
		local other = newPlayer("Other")

		expect(limiter:check(spammer)).toBe(true)
		expect(limiter:check(spammer)).toBe(false)
		expect(limiter:check(other)).toBe(true)

		limiter:destroy()
	end)

	it("forget gives the player a fresh bucket", function()
		local clock = newClock()
		local limiter = RateLimiter.new(1, 1, clock.read)
		local player = newPlayer("Raider")

		limiter:check(player)
		limiter:forget(player)

		expect(limiter:check(player)).toBe(true)

		limiter:destroy()
	end)

	it("drops a player's state when they leave", function()
		local clock = newClock()
		local limiter = RateLimiter.new(1, 1, clock.read)
		local player = newPlayer("Raider")

		limiter:check(player)
		Roblox.Players.PlayerRemoving:Fire(player)

		expect(limiter:check(player)).toBe(true)

		limiter:destroy()
	end)

	it("destroy stops listening for players leaving", function()
		local listenersBefore = Roblox.Players.PlayerRemoving:listenerCount()
		local limiter = RateLimiter.new(1)

		limiter:destroy()

		expect(Roblox.Players.PlayerRemoving:listenerCount()).toBe(listenersBefore)
	end)

	it("rejects a non-positive rate", function()
		expect(function()
			RateLimiter.new(0)
		end).toThrow("perSecond must be positive")
	end)
end)
