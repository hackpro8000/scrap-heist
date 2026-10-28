--!strict
--[[
	InventoryTypes

	Shapes of inventory data. Shared because the server saves it in the
	profile and sends snapshots of it to the client for the inventory and
	trade UI.
]]

-- One unique (non-stackable) item. Its ID is the key it's stored under in
-- Inventory.uniques; the record itself only says what it is.
export type UniqueItem = {
	itemId: string,
	-- os.time() when the item was created, for support and trade logs.
	createdAt: number,
}

export type Inventory = {
	-- Stackable items by item ID: { CopperCoil = 12 }.
	stacks: { [string]: number },
	-- Unique items by their GUID.
	uniques: { [string]: UniqueItem },
}

-- What one side puts into a trade: counts of stackables and a set of
-- unique item GUIDs.
export type Offer = {
	stacks: { [string]: number },
	uniques: { [string]: boolean },
}

-- An offer with each unique item's item ID filled in, so the other player
-- can see what they'd get and trade logs say what moved.
export type OfferDescription = {
	stacks: { [string]: number },
	uniques: { [string]: string },
}

return {}
