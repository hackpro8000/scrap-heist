--!strict
--[[
	Shop remotes

	Client to server:
		BuyWeapon(weaponName)        -- scrap; kept for good
		BuyBoost(boostName)          -- scrap; lasts Shop.BOOSTS[...].seconds
		RequestShop()                -- "send me my shop state" (on join)

	Server to client:
		ShopUpdated(state)           -- see ShopService.stateFor

	Passes and scrap packs are bought through MarketplaceService prompts,
	which the client opens itself; the server hears about them from Roblox.
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Shop"

return {
	BuyWeapon = Net.event(SYSTEM, "BuyWeapon"),
	BuyBoost = Net.event(SYSTEM, "BuyBoost"),
	RequestShop = Net.event(SYSTEM, "RequestShop"),
	ShopUpdated = Net.event(SYSTEM, "ShopUpdated"),
}
