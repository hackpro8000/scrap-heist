--!strict
local Roblox = require("../../Roblox")
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local RemoteGuard = Source.require("src/server/Security/RemoteGuard")

local function newRemote()
	return { OnServerEvent = Roblox.newSignal() }
end

describe("RemoteGuard", function()
	it("passes the player and arguments to the handler", function()
		local remote = newRemote()
		local received
		RemoteGuard.listen("Spec", remote :: any, 10, function(player, a, b)
			received = { player, a, b }
			return nil
		end)

		remote.OnServerEvent:Fire("player", 1, "two")

		expect(received).toEqual({ "player", 1, "two" })
	end)

	it("counts reasons a handler returns", function()
		local remote = newRemote()
		RemoteGuard.listen("Counted", remote :: any, 10, function()
			return "NotOwner"
		end)

		remote.OnServerEvent:Fire("player")
		remote.OnServerEvent:Fire("player")

		expect(RemoteGuard.rejectionCounts()["Counted.NotOwner"]).toBe(2)
	end)

	it("drops spam past the burst before the handler runs", function()
		local remote = newRemote()
		local calls = 0
		RemoteGuard.listen("Spammed", remote :: any, 2, function()
			calls += 1
			return nil
		end)

		for _ = 1, 20 do
			remote.OnServerEvent:Fire("spammer")
		end

		-- Burst is twice the per-second rate.
		expect(calls).toBe(4)
		expect(RemoteGuard.rejectionCounts()["Spammed.RateLimited"]).toBe(16)
	end)
end)
