--!strict
--[[
	SettingsService

	Saves each player's settings (volumes and effect switches) in their
	profile, so they follow the player to any server. The client applies
	them; the server only checks their shape and stores them.

	Public API: none (driven by its remotes).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Settings)

local DataService = require(script.Parent.DataService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)

local SYSTEM = "Settings"
-- A slider drag sends a save each time it settles.
local SAVE_RATE = 4
local REQUEST_RATE = 1

local VOLUMES = { "music", "sounds" }
local SWITCHES = { "screenShake", "damageNumbers", "hitPause" }

local SettingsService = {}

local function send(player: Player)
	local data = DataService.getData(player)
	if data then
		Remotes.SettingsLoaded:FireClient(player, data.settings)
	end
end

function SettingsService.init() end

function SettingsService.start()
	RemoteGuard.listen(SYSTEM, Remotes.SaveSettings, SAVE_RATE, function(player: Player, settings: any)
		local data = DataService.getData(player)
		if not data then
			return "NotLoaded"
		end
		-- SECURITY: copy only known fields of the right type, clamped, so a
		-- client can't write anything else into its save.
		if type(settings) ~= "table" then
			return "BadArgument"
		end
		for _, key in VOLUMES do
			local value = settings[key]
			if type(value) == "number" and value == value then
				(data.settings :: any)[key] = math.clamp(value, 0, 1)
			end
		end
		for _, key in SWITCHES do
			if type(settings[key]) == "boolean" then
				(data.settings :: any)[key] = settings[key]
			end
		end
		return nil
	end)
	RemoteGuard.listen(SYSTEM, Remotes.RequestSettings, REQUEST_RATE, function(player: Player)
		send(player)
		return nil
	end)
	DataService.forEachLoaded(send)
end

return SettingsService
