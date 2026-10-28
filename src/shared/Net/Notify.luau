--!strict
--[[
	Notify remotes

	Server to client:
		Message(text)   -- a short toast for one player ("Not enough scrap")
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Notify"

return {
	Message = Net.event(SYSTEM, "Message"),
}
