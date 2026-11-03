--!strict
--[[
	DataService

	Loads, holds and saves every player's profile using ProfileStore.

	ProfileStore gives each profile a **session lock**: while one server
	has a player's profile open, no other server can open it. That is what
	stops the classic duplication trick: join server A, trade away an item,
	quickly join server B before A saves, and load the old copy that still
	has the item. Server B simply can't load the profile until A releases it
	(see docs/systems/data.md).

	If a profile can't be loaded, the player is kicked rather than playing
	on a blank save that could later overwrite their real one.

	Other services read and change their own part of the profile through
	getData(). Scrap is the exception: only addScrap and trySpend write it,
	so every scrap change goes through the same checks.

	Public API:
		DataService.getData(player): ProfileData?
		DataService.isLoaded(player): boolean
		DataService.forEachLoaded(callback)       -- now and for every future load
		DataService.getScrap(player): number
		DataService.addScrap(player, amount): boolean
		DataService.trySpend(player, amount): boolean
		DataService.save(player)                  -- save now, after trades
		DataService.resetData(player)             -- debug only
		DataService.profileLoaded: Signal(player, data)
		DataService.profileReleasing: Signal(player, data)   -- last chance to write
		DataService.scrapChanged: Signal(player, balance)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Currency = require(script.Parent.Parent.Data.Currency)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)

-- Changing the store name starts every player from scratch, so it only
-- changes for a deliberate full wipe.
local STORE_NAME = "PlayerProfiles"
local KICK_LOAD_FAILED = "Your data couldn't be loaded. Please rejoin in a moment."
local KICK_SESSION_ENDED = "Your data was opened on another server. Please rejoin."
local KICK_DATA_RESET = "Your data was reset. Rejoin to start fresh."

local DataService = {}

DataService.profileLoaded = Signal.new()
DataService.profileReleasing = Signal.new()
DataService.scrapChanged = Signal.new()

local playerStore = ProfileStore.New(STORE_NAME, ProfileSchema.TEMPLATE)
local profiles: { [Player]: any } = {}

local function profileKey(player: Player): string
	return `Player_{player.UserId}`
end

local function setScrap(player: Player, data: ProfileSchema.ProfileData, balance: number)
	data.scrap = balance
	-- The attribute replicates to the client for the scrap counter.
	player:SetAttribute("Scrap", balance)
	DataService.scrapChanged:fire(player, balance)
end

local function loadProfile(player: Player)
	local profile = playerStore:StartSessionAsync(profileKey(player), {
		-- Stop waiting for the session lock if the player leaves first.
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick(KICK_LOAD_FAILED)
		return
	end

	-- Ties the profile to the player's user ID for data removal requests.
	profile:AddUserId(player.UserId)
	profile.Data = ProfileSchema.migrate(profile.Data)
	ProfileSchema.reconcile(profile.Data)

	-- DUPE-SAFE: if another server takes the session (or ProfileStore loses
	-- the lock), this server must stop using the profile at once, so the
	-- player is removed instead of playing on a copy that can't save.
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick(KICK_SESSION_ENDED)
	end)

	if player.Parent ~= Players then
		-- Left while loading.
		profile:EndSession()
		return
	end

	profiles[player] = profile
	player:SetAttribute("Scrap", profile.Data.scrap)
	player:SetAttribute("DataLoaded", true)
	DataService.profileLoaded:fire(player, profile.Data)
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end

	-- Listeners write their last state (lastSeenAt, yard state) here. Signal
	-- listeners run immediately, so this finishes before the session ends.
	DataService.profileReleasing:fire(player, profile.Data)
	profiles[player] = nil
	profile:EndSession()
end

function DataService.getData(player: Player): ProfileSchema.ProfileData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.forEachLoaded(callback: (Player, ProfileSchema.ProfileData) -> ())
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
	DataService.profileLoaded:connect(callback)
end

function DataService.getScrap(player: Player): number
	local data = DataService.getData(player)
	return if data then data.scrap else 0
end

function DataService.addScrap(player: Player, amount: number): boolean
	local data = DataService.getData(player)
	if not data then
		return false
	end

	local ok, balance = Currency.add(data.scrap, amount)
	if ok then
		setScrap(player, data, balance)
	end

	return ok
end

function DataService.trySpend(player: Player, amount: number): boolean
	local data = DataService.getData(player)
	if not data then
		return false
	end

	local ok, balance = Currency.spend(data.scrap, amount)
	if ok then
		setScrap(player, data, balance)
	end

	return ok
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

function DataService.resetData(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end

	profile.Data = ProfileSchema.newData()
	-- Rejoining reloads every system from the fresh save, which is simpler
	-- and safer than resetting each service's in-memory state by hand.
	player:Kick(KICK_DATA_RESET)
end

function DataService.init() end

function DataService.start()
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	Players.PlayerRemoving:Connect(releaseProfile)
end

return DataService
