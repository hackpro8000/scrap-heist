--!strict
--[[
	Settings remotes

	Client to server:
		SaveSettings(settings)       -- the whole settings table, see SettingsService
		RequestSettings()            -- "send me my saved settings" (on join)

	Server to client:
		SettingsLoaded(settings)
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Settings"

return {
	SaveSettings = Net.event(SYSTEM, "SaveSettings"),
	RequestSettings = Net.event(SYSTEM, "RequestSettings"),
	SettingsLoaded = Net.event(SYSTEM, "SettingsLoaded"),
}
