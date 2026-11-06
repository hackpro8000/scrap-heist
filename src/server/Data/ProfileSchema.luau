--!strict
--[[
	ProfileSchema

	What a player's save looks like, and how old saves are brought up to
	date when they load.

	Two tools keep old saves working:
	- reconcile() fills in any field the template has and the save doesn't.
	  Adding a new field to TEMPLATE is all it takes for existing players to
	  get it, with its default value, without touching anything else.
	- migrate() runs one function per version step for changes reconcile
	  can't express (renaming a field, changing its shape). Each step takes
	  a save at version N and returns it at version N + 1.

	Pad machines are keyed by pad name ("Pad1"), never by number: DataStores
	save tables as JSON, and a table with gaps in its number keys (pad 1 and
	pad 3 owned) doesn't survive that round trip.

	Public API:
		ProfileSchema.VERSION
		ProfileSchema.TEMPLATE
		ProfileSchema.MIGRATIONS
		ProfileSchema.newData(): ProfileData
		ProfileSchema.reconcile(data, template?)
		ProfileSchema.migrate(data, migrations?, targetVersion?)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local YardGrid = require(ReplicatedStorage.Shared.Yard.YardGrid)

local ProfileSchema = {}

export type TradeLogEntry = {
	at: number,
	withUserId: number,
	gave: InventoryTypes.OfferDescription,
	got: InventoryTypes.OfferDescription,
}

export type ProfileData = {
	version: number,
	scrap: number,
	inventory: InventoryTypes.Inventory,
	tradeLog: { TradeLogEntry },
	yard: {
		-- Everything the player has built, and where (Shared/Yard/YardGrid):
		-- pads with the junkrots on them, bays with the capsules in them,
		-- the crate, the mound and the press. Empty until the starter
		-- layout is placed.
		objects: { YardGrid.Object },
		-- The id the next thing built gets; ids are never reused.
		nextObjectId: number,
		-- Scrap waiting in the storage crate (raiders can steal this).
		crateScrap: number,
	},
	-- Rebirth rank ("Scrap the Yard"), 0 to Rebirth.MAX_RANK.
	rank: number,
	-- Parts for junkrot stars, from storms and the junk mound.
	parts: number,
	-- Junkrots hatched at least once, by id.
	logbook: { [string]: boolean },
	stats: {
		raidsWon: number,
		timesRaided: number,
		capsulesHatched: number,
		capsulesStolen: number,
	},
	-- os.time() until which this player's yard can't be raided.
	raidShieldUntil: number,
	-- os.time() when the player last left, for offline earnings.
	lastSeenAt: number,
	-- Player weapons owned, by WeaponConfig name.
	weapons: { [string]: boolean },
	-- os.time() until which each shop boost runs, by boost name.
	boosts: { [string]: number },
	settings: Settings,
	rewards: {
		streakDay: number,
		lastClaimDay: number,
		playDay: number,
		playSeconds: number,
		giftsClaimed: { [string]: boolean },
	},
	-- Developer product receipts already paid out, by PurchaseId, so a
	-- receipt Roblox sends twice pays once.
	purchases: { [string]: number },
}

export type Settings = {
	music: number,
	sounds: number,
	screenShake: boolean,
	damageNumbers: boolean,
	hitPause: boolean,
}

ProfileSchema.VERSION = 2

ProfileSchema.TEMPLATE = {
	version = ProfileSchema.VERSION,
	scrap = Economy.STARTING_SCRAP,
	inventory = {
		stacks = {},
		uniques = {},
	},
	tradeLog = {},
	yard = {
		objects = {},
		nextObjectId = 1,
		crateScrap = 0,
	},
	rank = 0,
	parts = 0,
	logbook = {},
	stats = {
		raidsWon = 0,
		timesRaided = 0,
		capsulesHatched = 0,
		capsulesStolen = 0,
	},
	raidShieldUntil = 0,
	lastSeenAt = 0,
	weapons = { Bat = true },
	boosts = {},
	settings = {
		music = 0.6,
		sounds = 0.85,
		screenShake = true,
		damageNumbers = true,
		hitPause = true,
	},
	rewards = {
		streakDay = 0,
		lastClaimDay = 0,
		playDay = 0,
		playSeconds = 0,
		giftsClaimed = {},
	},
	purchases = {},
} :: ProfileData

-- MIGRATIONS[n] upgrades a save from version n to n + 1.
ProfileSchema.MIGRATIONS = {
	-- Version 2: salvage machines on four fixed pads became junkrots on
	-- pads the player lays out. The old machines are dropped (their yard
	-- starts again from the starter layout); what was in the crate stays.
	[1] = function(data)
		local crate = if type(data.yard) == "table" then tonumber(data.yard.crateParts) else nil
		data.yard = { objects = {}, nextObjectId = 1, crateScrap = crate or 0 }
		data.tutorial = nil
		return data
	end,
} :: { [number]: (any) -> any }

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end

	return copy
end

function ProfileSchema.newData(): ProfileData
	return deepCopy(ProfileSchema.TEMPLATE)
end

-- Fills in missing fields from the template, recursing into nested tables.
-- DUPE-SAFE: only ever adds missing keys; never overwrites or removes
-- anything a save already has, so reconciling twice changes nothing.
function ProfileSchema.reconcile(data: { [any]: any }, template: { [any]: any }?)
	local source = template or (ProfileSchema.TEMPLATE :: any)
	for key, default in source do
		local current = data[key]
		if current == nil then
			data[key] = deepCopy(default)
		elseif type(current) == "table" and type(default) == "table" then
			ProfileSchema.reconcile(current, default)
		end
	end
end

function ProfileSchema.migrate(
	data: { [any]: any },
	migrations: { [number]: (any) -> any }?,
	targetVersion: number?
): any
	local steps = migrations or ProfileSchema.MIGRATIONS
	local target = targetVersion or ProfileSchema.VERSION
	-- Saves from before versioning existed count as version 1.
	local version = data.version or 1

	while version < target do
		local step = steps[version]
		assert(step, `ProfileSchema: no migration from version {version}`)
		data = step(data)
		version += 1
		data.version = version
	end
	data.version = version

	return data
end

return ProfileSchema
