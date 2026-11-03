--!strict
--[[
	Inventory remotes

	Client to server:
		RequestInventory()             -- "send me my inventory" (on join)

	Server to client:
		InventoryUpdated(inventory)    -- full snapshot after every change
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Inventory"

return {
	RequestInventory = Net.event(SYSTEM, "RequestInventory"),
	InventoryUpdated = Net.event(SYSTEM, "InventoryUpdated"),
}
