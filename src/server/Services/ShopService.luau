--!strict
--[[
	ShopService

	Sells what Config/Shop lists and answers what each player owns:
	- Weapons: bought once with scrap, saved in profile.weapons. The
	  player's "Weapons" attribute lists them for the hotbar.
	- Boosts: bought with scrap, each running until a saved os.time()
	  (profile.boosts). The Shield boost lengthens the raid shield.
	- Passes: Robux game passes. Ownership is asked of Roblox when the
	  player joins and updated when they buy one in game.
	- Scrap packs: Robux developer products, paid out in ProcessReceipt.

	Other services ask for perks through the functions below, so the perks'
	numbers live in one place (Config/Shop).

	The player's "ShieldUntil" attribute mirrors profile.raidShieldUntil for
	the HUD's shield plank; anything that changes the shield calls
	syncShield.

	Public API:
		ShopService.hasPass(player, passName): boolean
		ShopService.boostActive(player, boostName): boolean
		ShopService.ownsWeapon(player, weaponName): boolean
		ShopService.scrapMultiplier(player): number
		ShopService.crateCapacity(player): number
		ShopService.productionMultiplier(player): number
		ShopService.syncShield(player)
		ShopService.weaponsChanged: Signal(player)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Remotes = require(ReplicatedStorage.Shared.Net.Shop)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local DataService = require(script.Parent.DataService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)

local SYSTEM = "Shop"
local BUY_RATE = 2
local REQUEST_RATE = 1
-- Receipts older than this are dropped from the save; Roblox stops
-- retrying a receipt long before.
local RECEIPT_KEEP_SECONDS = 30 * 24 * 60 * 60

local ShopService = {}

ShopService.weaponsChanged = Signal.new()

-- Passes each player owns, filled when they join.
local ownedPasses: { [Player]: { [string]: boolean } } = {}

function ShopService.hasPass(player: Player, passName: string): boolean
	local owned = ownedPasses[player]
	return owned ~= nil and owned[passName] == true
end

function ShopService.boostActive(player: Player, boostName: string): boolean
	local data = DataService.getData(player)
	return data ~= nil and (data.boosts[boostName] or 0) > os.time()
end

function ShopService.ownsWeapon(player: Player, weaponName: string): boolean
	if Shop.weaponPrice(weaponName) == 0 then
		return true
	end
	local data = DataService.getData(player)
	return data ~= nil and data.weapons[weaponName] == true
end

function ShopService.scrapMultiplier(player: Player): number
	local multiplier = 1
	if ShopService.hasPass(player, "DoubleScrap") then
		multiplier *= Shop.DOUBLE_SCRAP
	end
	if ShopService.hasPass(player, "VIP") then
		multiplier *= Shop.VIP_SCRAP
	end
	return multiplier
end

function ShopService.crateCapacity(player: Player): number
	local capacity = Economy.CRATE_CAPACITY
	return if ShopService.hasPass(player, "BigCrate") then math.floor(capacity * Shop.BIG_CRATE) else capacity
end

function ShopService.productionMultiplier(player: Player): number
	return if ShopService.boostActive(player, "Overdrive") then Shop.OVERDRIVE else 1
end

function ShopService.syncShield(player: Player)
	local data = DataService.getData(player)
	player:SetAttribute("ShieldUntil", if data then data.raidShieldUntil else nil)
end

local function syncWeapons(player: Player)
	local names = {}
	for _, weapon in WeaponConfig.PLAYER_WEAPONS do
		if ShopService.ownsWeapon(player, weapon) then
			table.insert(names, weapon)
		end
	end
	player:SetAttribute("Weapons", table.concat(names, ","))
end

-- What the shop window shows: owned weapons and passes, and when each
-- boost ends (in os.time(), which matches the client's server clock).
local function stateFor(player: Player): { [string]: any }?
	local data = DataService.getData(player)
	if not data then
		return nil
	end
	local weapons = {}
	for _, entry in Shop.WEAPONS do
		weapons[entry.weapon] = ShopService.ownsWeapon(player, entry.weapon)
	end
	local passes = {}
	for _, pass in Shop.PASSES do
		passes[pass.name] = ShopService.hasPass(player, pass.name)
	end
	return { weapons = weapons, boosts = table.clone(data.boosts), passes = passes }
end

local function sendState(player: Player)
	local state = stateFor(player)
	if state then
		Remotes.ShopUpdated:FireClient(player, state)
	end
end

local function setPassOwned(player: Player, passName: string)
	local owned = ownedPasses[player]
	if not owned then
		return
	end
	owned[passName] = true
	if passName == "VIP" then
		player:SetAttribute("VIP", true)
	end
end

local function loadPasses(player: Player)
	ownedPasses[player] = {}
	for _, pass in Shop.PASSES do
		if pass.gamePassId ~= 0 then
			local ok, owns =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.gamePassId)
			if ok and owns then
				setPassOwned(player, pass.name)
			end
		end
	end
end

local function onBuyWeapon(player: Player, weaponName: any): string?
	local price = type(weaponName) == "string" and Shop.weaponPrice(weaponName)
	if not price then
		return "UnknownWeapon"
	end
	local data = DataService.getData(player)
	if not data then
		return "NotLoaded"
	end
	if ShopService.ownsWeapon(player, weaponName) then
		return "AlreadyOwned"
	end
	if not DataService.trySpend(player, price) then
		Notify.Message:FireClient(player, `You need {price} scrap`)
		return nil
	end
	data.weapons[weaponName] = true
	syncWeapons(player)
	ShopService.weaponsChanged:fire(player)
	Notify.Sound:FireClient(player, "Purchase")
	Notify.Message:FireClient(
		player,
		`{WeaponConfig.Weapons[weaponName].displayName} is yours! Press its number to equip it.`
	)
	sendState(player)
	return nil
end

local function onBuyBoost(player: Player, boostName: any): string?
	local boost = type(boostName) == "string" and Shop.boost(boostName)
	if not boost then
		return "UnknownBoost"
	end
	local data = DataService.getData(player)
	if not data then
		return "NotLoaded"
	end
	if not DataService.trySpend(player, boost.price) then
		Notify.Message:FireClient(player, `You need {boost.price} scrap`)
		return nil
	end
	-- Buying again while one runs adds its time on the end.
	local now = os.time()
	local endsAt = math.max(data.boosts[boost.name] or 0, now) + boost.seconds
	data.boosts[boost.name] = endsAt
	if boost.name == "Shield" then
		data.raidShieldUntil = math.max(data.raidShieldUntil, endsAt)
		ShopService.syncShield(player)
	end
	Notify.Sound:FireClient(player, "Purchase")
	Notify.Message:FireClient(player, `{boost.displayName} running for {boost.seconds // 60} minutes`)
	sendState(player)
	return nil
end

-- SECURITY: Roblox calls this, not the client, and retries until it hears
-- PurchaseGranted. DUPE-SAFE: each PurchaseId pays once, recorded in the
-- same profile the scrap goes into, so a retried receipt finds it paid.
local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.getData(player)
	if not (player and data) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if data.purchases[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local pack: Shop.ScrapPack? = nil
	for _, candidate in Shop.SCRAP_PACKS do
		if candidate.productId ~= 0 and candidate.productId == receipt.ProductId then
			pack = candidate
		end
	end
	if not pack then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local now = os.time()
	for id, at in data.purchases do
		if now - at > RECEIPT_KEEP_SECONDS then
			data.purchases[id] = nil
		end
	end
	data.purchases[purchaseId] = now
	DataService.addScrap(player, pack.scrap)
	DataService.save(player)
	Notify.Message:FireClient(player, `+{pack.scrap} scrap. Thanks!`)
	Notify.Sound:FireClient(player, "Purchase")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.init() end

function ShopService.start()
	RemoteGuard.listen(SYSTEM, Remotes.BuyWeapon, BUY_RATE, onBuyWeapon)
	RemoteGuard.listen(SYSTEM, Remotes.BuyBoost, BUY_RATE, onBuyBoost)
	RemoteGuard.listen(SYSTEM, Remotes.RequestShop, REQUEST_RATE, function(player: Player)
		sendState(player)
		return nil
	end)

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamePassId: number, purchased: boolean)
			if not purchased then
				return
			end
			for _, pass in Shop.PASSES do
				if pass.gamePassId ~= 0 and pass.gamePassId == gamePassId then
					setPassOwned(player, pass.name)
					Notify.Message:FireClient(player, `{pass.displayName} unlocked!`)
					Notify.Sound:FireClient(player, "Purchase")
				end
			end
			sendState(player)
		end
	)

	DataService.forEachLoaded(function(player)
		task.spawn(function()
			loadPasses(player)
			syncWeapons(player)
			ShopService.syncShield(player)
			sendState(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
	end)
end

return ShopService
