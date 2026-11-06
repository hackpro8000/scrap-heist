--!strict
--[[
	Build remotes (build mode)

	Client to server:
		Move(objectId, x, z, turn)        -- move a thing in your yard
		Add(kind, family, x, z, turn)     -- place a new thing you're owed;
		                                  -- family is for pads, nil otherwise

	x and z are the thing's corner cell on the plot's grid and turn counts
	quarter turns (Shared/Yard/YardGrid). The server answers a refused
	request with a Notify message; an allowed one shows as the thing
	rebuilt in its new place.
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Build"

return {
	Move = Net.event(SYSTEM, "Move"),
	Add = Net.event(SYSTEM, "Add"),
}
