--!strict
--[[
	Tutorial remotes

	Client to server:
		DismissTip(stepName)       -- "got it" on a tip step

	Server to client:
		Step(stepName?, kind?, text?)   -- the prompt to show, or nil to hide
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Tutorial"

return {
	DismissTip = Net.event(SYSTEM, "DismissTip"),
	Step = Net.event(SYSTEM, "Step"),
}
