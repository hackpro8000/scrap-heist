--!strict
--[[
	Raid remotes

	Server to client:
		Alert(kind, text)   -- yard owner: "Intruder", "Grabbed", "Clear"
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Raid"

return {
	Alert = Net.event(SYSTEM, "Alert"),
}
