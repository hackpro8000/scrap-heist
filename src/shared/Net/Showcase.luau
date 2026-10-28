--!strict
--[[
	Showcase remotes (Studio and admins only; the server checks every call)

	Client to server:
		Command(name, args)       -- runs a DebugService command from the panel

	Server to client (only to players with the debug overlay on):
		DebugDraw(kind, data)     -- "Hitbox" { cframe, size } or "Path" { positions }
		OverlayStats(counts?)     -- remote rejection counts; nil = overlay off
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Showcase"

return {
	Command = Net.event(SYSTEM, "Command"),
	DebugDraw = Net.event(SYSTEM, "DebugDraw"),
	OverlayStats = Net.event(SYSTEM, "OverlayStats"),
}
