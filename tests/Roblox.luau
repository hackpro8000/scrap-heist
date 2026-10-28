--!strict
--[[
	Roblox

	Fakes the few Roblox engine pieces our modules touch, so they can be
	required under Lune. Only what our code actually uses is faked; when a
	module under test needs more, add it here and nowhere else.

	- task: Lune ships the same scheduler, but as a library, not a global.
	- Vector3, Color3: Lune's own, which match Roblox's. CFrame is left out on
	  purpose: Lune's CFrame.lookAt faces the opposite way to Roblox's, so
	  rules modules do their maths with positions and facing vectors.
	- game:GetService("Players"): a fake Players with a PlayerRemoving
	  signal that specs fire by hand to simulate a player leaving.
	- ReplicatedStorage.Shared and ServerScriptService.Server: the src/
	  folders, loaded through tests/Source.luau as default.project.json maps
	  them.

	Lune already provides print, warn and typeof as globals.

	Public API:
		Roblox.install()             -- set the globals; the runner calls this once
		Roblox.Players               -- the fake Players service
		Roblox.newSignal(): FakeSignal
		Roblox.captureOutput(body): { prints, warns }
]]

local Source = require("./Source")

local Roblox = {}

export type FakeConnection = {
	Connected: boolean,
	Disconnect: (self: FakeConnection) -> (),
}

-- Matches the slice of RBXScriptSignal our code uses, plus Fire so specs
-- can trigger engine events.
export type FakeSignal = {
	Connect: (self: FakeSignal, callback: (...any) -> ()) -> FakeConnection,
	Fire: (self: FakeSignal, ...any) -> (),
	listenerCount: (self: FakeSignal) -> number,
}

export type Output = {
	prints: { string },
	warns: { string },
}

function Roblox.newSignal(): FakeSignal
	local connections: { FakeConnection } = {}
	local callbacks: { [FakeConnection]: (...any) -> () } = {}

	local signal = {}

	function signal.Connect(_self: FakeSignal, callback: (...any) -> ()): FakeConnection
		local connection = {
			Connected = true,
		}

		function connection.Disconnect(self: FakeConnection)
			self.Connected = false
			callbacks[self] = nil
			local index = table.find(connections, self)
			if index then
				table.remove(connections, index)
			end
		end

		table.insert(connections, connection)
		callbacks[connection] = callback

		return connection
	end

	function signal.Fire(_self: FakeSignal, ...: any)
		for _, connection in table.clone(connections) do
			local callback = callbacks[connection]
			if callback then
				callback(...)
			end
		end
	end

	function signal.listenerCount(_self: FakeSignal): number
		return #connections
	end

	return signal :: any
end

Roblox.Players = {
	PlayerRemoving = Roblox.newSignal(),
}

local services: { [string]: any } = {
	Players = Roblox.Players,
	ReplicatedStorage = {
		Shared = Source.instance("src/shared"),
	},
	ServerScriptService = {
		Server = Source.instance("src/server"),
	},
}

-- Where print and warn go while captureOutput runs; nil means the console.
local capture: Output? = nil

local fakeGame = {}

function fakeGame.GetService(_self: any, name: string): any
	local service = services[name]
	if not service then
		error(`Roblox fake: no fake for service {name}, add one in tests/Roblox.luau`, 2)
	end

	return service
end

function Roblox.install()
	-- Plain assignment, not _G: Lune shares globals between the runner and
	-- every module it requires, but keeps _G as a separate table.
	task = require("@lune/task") :: any
	local lune = require("@lune/roblox")
	Vector3 = lune.Vector3 :: any
	Color3 = lune.Color3 :: any
	game = fakeGame :: any

	-- Luau caches built-in globals like print when a module loads, so
	-- swapping print later wouldn't reach modules already required. Instead
	-- print and warn are replaced once, here, before any module loads, and
	-- forward to whatever captureOutput has set.
	local consolePrint, consoleWarn = print, warn
	print = function(...)
		if capture then
			table.insert(capture.prints, table.concat({ ... }, " "))
		else
			consolePrint(...)
		end
	end :: any
	warn = function(...)
		if capture then
			table.insert(capture.warns, table.concat({ ... }, " "))
		else
			consoleWarn(...)
		end
	end :: any
end

-- Runs body with print and warn redirected into lists, so specs can check
-- log lines and keep the test output clean.
function Roblox.captureOutput(body: () -> ()): Output
	local output: Output = { prints = {}, warns = {} }

	capture = output
	local ok, message = pcall(body)
	capture = nil

	if not ok then
		error(message, 0)
	end

	return output
end

return Roblox
