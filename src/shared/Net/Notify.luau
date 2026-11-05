--!strict
--[[
	Notify remotes

	Server to client:
		Message(text)   -- a short toast for one player ("Not enough scrap")
		Sound(key)      -- plays Assets.Sounds[key] for one player ("Purchase")
		ScrapBurst(from, amount, fill)
		                -- scrap flies from `from` (a Vector3) into the player,
		                -- with "+amount" floating up;
		                -- `fill` (0-1) is how full the source was, which sets
		                -- how many pieces fly (Juice.collectPieces)
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Notify"

return {
	Message = Net.event(SYSTEM, "Message"),
	Sound = Net.event(SYSTEM, "Sound"),
	ScrapBurst = Net.event(SYSTEM, "ScrapBurst"),
}
