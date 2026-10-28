--!strict
--[[
	InventoryRules

	Reads and changes an inventory table (see InventoryTypes). Used by
	InventoryService for grants and removals, and by TradeSession for the
	trade swap.

	Unique items are keyed by their GUID, so the same item can't be stored
	twice: adding a GUID that's already there is refused, and moving an item
	moves its record (same GUID) rather than making a new one.

	Public API:
		InventoryRules.countOf(inventory, itemId): number
		InventoryRules.addStack(inventory, itemId, count): boolean
		InventoryRules.removeStack(inventory, itemId, count): boolean
		InventoryRules.addUnique(inventory, guid, item): boolean
		InventoryRules.removeUnique(inventory, guid): UniqueItem?
		InventoryRules.emptyOffer(): Offer
		InventoryRules.isValidOffer(offer, maxEntries): boolean
		InventoryRules.hasOffer(inventory, offer): boolean
		InventoryRules.canReceive(inventory, offer, from): boolean
		InventoryRules.describeOffer(inventory, offer): OfferDescription
		InventoryRules.moveOffer(from, to, offer)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)

type Inventory = InventoryTypes.Inventory
type Offer = InventoryTypes.Offer
type UniqueItem = InventoryTypes.UniqueItem

-- GUIDs from HttpService are 36 characters; leave room, refuse junk.
local MAX_GUID_LENGTH = 64

local InventoryRules = {}

function InventoryRules.countOf(inventory: Inventory, itemId: string): number
	local definition = Items.get(itemId)
	if not definition then
		return 0
	end
	if definition.stackable then
		return inventory.stacks[itemId] or 0
	end

	local count = 0
	for _, item in inventory.uniques do
		if item.itemId == itemId then
			count += 1
		end
	end

	return count
end

function InventoryRules.addStack(inventory: Inventory, itemId: string, count: number): boolean
	local definition = Items.get(itemId)
	if not definition or not definition.stackable or not Validate.isPositiveInteger(count) then
		return false
	end

	local current = inventory.stacks[itemId] or 0
	if current + count > Items.MAX_STACK then
		return false
	end

	inventory.stacks[itemId] = current + count
	return true
end

function InventoryRules.removeStack(inventory: Inventory, itemId: string, count: number): boolean
	local current = inventory.stacks[itemId] or 0
	if not Validate.isPositiveInteger(count) or count > current then
		return false
	end

	-- Drop the key at zero so saves don't fill up with empty entries.
	inventory.stacks[itemId] = if current == count then nil else current - count
	return true
end

function InventoryRules.addUnique(inventory: Inventory, guid: string, item: UniqueItem): boolean
	local definition = Items.get(item.itemId)
	if not definition or definition.stackable then
		return false
	end
	-- DUPE-SAFE: a GUID can only exist once in an inventory. If something
	-- tries to add an item that's already here, refuse instead of keeping
	-- two references to it.
	if inventory.uniques[guid] ~= nil then
		return false
	end

	inventory.uniques[guid] = item
	return true
end

function InventoryRules.removeUnique(inventory: Inventory, guid: string): UniqueItem?
	local item = inventory.uniques[guid]
	inventory.uniques[guid] = nil

	return item
end

function InventoryRules.emptyOffer(): Offer
	return { stacks = {}, uniques = {} }
end

-- Checks an offer's shape. Offers arrive from clients, so anything at all
-- could be in them.
function InventoryRules.isValidOffer(offer: any, maxEntries: number): boolean
	if type(offer) ~= "table" or type(offer.stacks) ~= "table" or type(offer.uniques) ~= "table" then
		return false
	end

	local entries = 0
	for itemId, count in offer.stacks do
		local definition = Items.get(itemId)
		if not definition or not definition.stackable or not Validate.isPositiveInteger(count) then
			return false
		end
		entries += 1
	end
	for guid, included in offer.uniques do
		if not Validate.isShortString(guid, MAX_GUID_LENGTH) or included ~= true then
			return false
		end
		entries += 1
	end

	return entries <= maxEntries
end

function InventoryRules.hasOffer(inventory: Inventory, offer: Offer): boolean
	for itemId, count in offer.stacks do
		if (inventory.stacks[itemId] or 0) < count then
			return false
		end
	end
	for guid in offer.uniques do
		if inventory.uniques[guid] == nil then
			return false
		end
	end

	return true
end

-- Whether `inventory` has room for everything `offer` would bring from
-- `from`: no stack over the cap, no GUID already present.
function InventoryRules.canReceive(inventory: Inventory, offer: Offer, from: Inventory): boolean
	for itemId, count in offer.stacks do
		if (inventory.stacks[itemId] or 0) + count > Items.MAX_STACK then
			return false
		end
	end
	for guid in offer.uniques do
		if inventory.uniques[guid] ~= nil or from.uniques[guid] == nil then
			return false
		end
	end

	return true
end

function InventoryRules.describeOffer(inventory: Inventory, offer: Offer): InventoryTypes.OfferDescription
	local uniques = {}
	for guid in offer.uniques do
		local item = inventory.uniques[guid]
		uniques[guid] = if item then item.itemId else "Unknown"
	end

	return { stacks = table.clone(offer.stacks), uniques = uniques }
end

-- Moves an offer's items between inventories. Callers must check hasOffer
-- and canReceive first; TradeSession.swap does both for both sides before
-- moving anything.
function InventoryRules.moveOffer(from: Inventory, to: Inventory, offer: Offer)
	for itemId, count in offer.stacks do
		InventoryRules.removeStack(from, itemId, count)
		InventoryRules.addStack(to, itemId, count)
	end
	for guid in offer.uniques do
		-- DUPE-SAFE: the record is removed from one inventory and the same
		-- record, same GUID, is placed in the other. Nothing is copied.
		local item = InventoryRules.removeUnique(from, guid)
		if item then
			InventoryRules.addUnique(to, guid, item)
		end
	end
end

return InventoryRules
