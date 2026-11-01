--!strict
--[[
	InventoryService

	Grants and removes items. Only the server creates items, and only
	through grant(): loot, debug commands and trades all come through here
	or through InventoryRules on the saved inventory.

	Every unique item gets a GUID from HttpService when it is created. Two
	Golden Cogs are two records with two IDs; nothing in the game copies a
	record, so a unique item can be traced from the drop that made it.

	After each change the owner's client gets a full inventory snapshot.
	Inventories are small, and a full snapshot can't drift out of sync the
	way a stream of "add 1, remove 2" messages can.

	Public API:
		InventoryService.getInventory(player): Inventory?
		InventoryService.grant(player, itemId, count?): boolean
		InventoryService.remove(player, itemId, count): boolean   -- stackables
		InventoryService.removeUnique(player, guid): UniqueItem?
		InventoryService.notifyChanged(player)
		InventoryService.changed: Signal(player)
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Remotes = require(ReplicatedStorage.Shared.Net.Inventory)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local InventoryRules = require(script.Parent.Parent.Inventory.InventoryRules)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)

local SYSTEM = "Inventory"
local REQUEST_RATE = 2
-- Most unique items one grant can create, so a typo in a debug command
-- can't flood a save with thousands of records.
local MAX_UNIQUES_PER_GRANT = 20

local InventoryService = {}

InventoryService.changed = Signal.new()

function InventoryService.getInventory(player: Player): InventoryTypes.Inventory?
	local data = DataService.getData(player)
	return if data then data.inventory else nil
end

function InventoryService.notifyChanged(player: Player)
	local inventory = InventoryService.getInventory(player)
	if not inventory then
		return
	end

	Remotes.InventoryUpdated:FireClient(player, inventory)
	InventoryService.changed:fire(player)
end

function InventoryService.grant(player: Player, itemId: string, count: number?): boolean
	local inventory = InventoryService.getInventory(player)
	local definition = Items.get(itemId)
	local amount = count or 1
	if not inventory or not definition or not Validate.isPositiveInteger(amount) then
		return false
	end

	if definition.stackable then
		if not InventoryRules.addStack(inventory, itemId, amount) then
			return false
		end
	else
		if amount > MAX_UNIQUES_PER_GRANT then
			return false
		end
		for _ = 1, amount do
			-- DUPE-SAFE: every unique item is born with its own GUID, so two
			-- copies of the same item can never be confused or merged.
			local guid = HttpService:GenerateGUID(false)
			InventoryRules.addUnique(inventory, guid, { itemId = itemId, createdAt = os.time() })
		end
	end

	InventoryService.notifyChanged(player)
	return true
end

function InventoryService.remove(player: Player, itemId: string, count: number): boolean
	local inventory = InventoryService.getInventory(player)
	if not inventory or not InventoryRules.removeStack(inventory, itemId, count) then
		return false
	end

	InventoryService.notifyChanged(player)
	return true
end

function InventoryService.removeUnique(player: Player, guid: string): InventoryTypes.UniqueItem?
	local inventory = InventoryService.getInventory(player)
	local item = if inventory then InventoryRules.removeUnique(inventory, guid) else nil
	if item then
		InventoryService.notifyChanged(player)
	end

	return item
end

function InventoryService.init()
	DebugService.register("giveitem", "/giveitem <ItemId> [count]", function(player, args)
		local itemId = args[1]
		local count = tonumber(args[2] or "1")
		if not Items.get(itemId) or not count then
			return "Usage: /giveitem <ItemId> [count], e.g. /giveitem GoldenCog"
		end
		if not InventoryService.grant(player, itemId, math.floor(count)) then
			return "Couldn't give that"
		end
		return `Gave {math.floor(count)} {itemId}`
	end)
end

function InventoryService.start()
	RemoteGuard.listen(SYSTEM, Remotes.RequestInventory, REQUEST_RATE, function(player: Player)
		if not DataService.isLoaded(player) then
			return "NotLoaded"
		end

		InventoryService.notifyChanged(player)
		return nil
	end)

	DataService.forEachLoaded(function(player)
		InventoryService.notifyChanged(player)
	end)
end

return InventoryService
