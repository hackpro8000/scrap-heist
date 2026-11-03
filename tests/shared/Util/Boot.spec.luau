--!strict
local Roblox = require("../../Roblox")
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Boot = Source.require("src/shared/Util/Boot")

-- A module that records its init/start calls into a shared log.
local function newModule(name: string, log: { string }): Boot.Entry
	return {
		name = name,
		module = {
			init = function()
				table.insert(log, `init {name}`)
			end,
			start = function()
				table.insert(log, `start {name}`)
			end,
		},
	}
end

describe("Boot", function()
	it("inits every module before starting any, in list order", function()
		local log = {}

		Roblox.captureOutput(function()
			Boot.run("Server", { newModule("DataService", log), newModule("InventoryService", log) })
		end)

		expect(log).toEqual({
			"init DataService",
			"init InventoryService",
			"start DataService",
			"start InventoryService",
		})
	end)

	it("prints each step and a module count", function()
		local output = Roblox.captureOutput(function()
			Boot.run("Server", { newModule("DataService", {}) })
		end)

		expect(output.prints).toEqual({
			"[Server] init DataService",
			"[Server] start DataService",
			"[Server] booted 1 module(s)",
		})
	end)

	it("handles modules without init or start", function()
		local output = Roblox.captureOutput(function()
			Boot.run("Client", { { name = "Empty", module = {} } })
		end)

		expect(output.prints[3]).toBe("[Client] booted 1 module(s)")
	end)

	it("warns on a start error and still starts the rest", function()
		local log = {}
		local broken: Boot.Entry = {
			name = "BrokenService",
			module = {
				start = function()
					error("start failed on purpose")
				end,
			},
		}

		local output = Roblox.captureOutput(function()
			Boot.run("Server", { broken, newModule("RoundService", log) })
		end)

		expect(log).toEqual({ "init RoundService", "start RoundService" })
		expect(#output.warns).toBe(1)
		expect(string.find(output.warns[1], "start BrokenService failed", 1, true) ~= nil).toBe(true)
	end)

	it("stops the boot on an init error", function()
		local log = {}
		local broken: Boot.Entry = {
			name = "BrokenService",
			module = {
				init = function()
					error("init failed on purpose")
				end,
			},
		}

		expect(function()
			Roblox.captureOutput(function()
				Boot.run("Server", { broken, newModule("RoundService", log) })
			end)
		end).toThrow("init failed on purpose")
		expect(log).toEqual({})
	end)
end)
