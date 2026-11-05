--!strict
--[[
	ShopController

	The shop window (Shop button): four tabs of cards from Config/Shop.
	- Weapons and Boosts are bought with scrap through the Shop remotes.
	- Passes and Scrap packs open Roblox's purchase prompt; a card whose
	  Roblox ID isn't set yet shows SOON and can't be pressed.
	Each card shows what you already own or have running, from the state
	the server last sent (ShopUpdated). The window itself is
	UI/Screens/Shop.

	Public API: none.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Remotes = require(ReplicatedStorage.Shared.Net.Shop)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local HudController = require(script.Parent.HudController)
local Kit = require(script.Parent.Parent.UI.Kit)
local ShopScreen = require(script.Parent.Parent.UI.Screens.Shop)
local Windows = require(script.Parent.Parent.UI.Windows)

type CardSpec = ShopScreen.CardSpec

local localPlayer = Players.LocalPlayer

local WINDOW = "Shop"
local BOOSTS_TAB = 2
local PIPS = 5

local ShopController = {}

local state: { [string]: any } = { weapons = {}, boosts = {}, passes = {} }
-- The card last pressed, and the one celebrating a purchase (its name and
-- when, so a second purchase of the same thing celebrates again).
local pressedCard: string? = nil
local celebrated: { name: string, at: number }? = nil
local tab = 1
local root: Kit.Root

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- A weapon's power (a full combo's damage) and speed (hits a second),
-- each in pips out of five against the strongest player weapon.
local function weaponStats(): { [string]: { power: number, speed: number } }
	local raw = {}
	local most = { power = 0, speed = 0 }
	for _, name in WeaponConfig.PLAYER_WEAPONS do
		local power, seconds = 0, 0
		local combo = WeaponConfig.Weapons[name].combo
		for _, hit in combo do
			power += hit.damage
			seconds += hit.windup + hit.recovery
		end
		raw[name] = { power = power, speed = #combo / seconds }
		most.power = math.max(most.power, power)
		most.speed = math.max(most.speed, #combo / seconds)
	end
	local stats = {}
	for name, value in raw do
		stats[name] = {
			power = math.max(1, math.round(PIPS * value.power / most.power)),
			speed = math.max(1, math.round(PIPS * value.speed / most.speed)),
		}
	end
	return stats
end
local WEAPON_STATS = weaponStats()

local function weaponCards(): { CardSpec }
	local list = {}
	for _, entry in Shop.WEAPONS do
		local owned = state.weapons[entry.weapon] == true or entry.price == 0
		local stats = WEAPON_STATS[entry.weapon]
		table.insert(list, {
			icon = "Weapon" .. entry.weapon,
			name = string.upper(WeaponConfig.Weapons[entry.weapon].displayName),
			stats = { { label = "PWR", pips = stats.power }, { label = "SPD", pips = stats.speed } },
			price = tostring(entry.price),
			scrapPrice = true,
			owned = owned,
			action = if owned
				then nil
				else function()
					Remotes.BuyWeapon:FireServer(entry.weapon)
				end,
		})
	end
	return list
end

local function boostCards(): { CardSpec }
	local list = {}
	local now = workspace:GetServerTimeNow()
	for _, boost in Shop.BOOSTS do
		local left = (state.boosts[boost.name] or 0) - now
		table.insert(list, {
			icon = boost.icon,
			name = boost.displayName,
			line = if left > 0 then `{formatTime(left)} left` else `{boost.description}, {boost.seconds // 60} min`,
			price = tostring(boost.price),
			scrapPrice = true,
			owned = false,
			action = function()
				Remotes.BuyBoost:FireServer(boost.name)
			end,
		})
	end
	return list
end

local function passCards(): { CardSpec }
	local list = {}
	for _, pass in Shop.PASSES do
		local ready = pass.gamePassId ~= 0
		table.insert(list, {
			icon = pass.icon,
			badge = pass.badge,
			name = pass.displayName,
			line = pass.description,
			price = if ready then `R$ {pass.robux}` else "SOON",
			scrapPrice = false,
			owned = state.passes[pass.name] == true,
			action = if ready
				then function()
					MarketplaceService:PromptGamePassPurchase(localPlayer, pass.gamePassId)
				end
				else nil,
		})
	end
	return list
end

local function scrapCards(): { CardSpec }
	local list = {}
	for _, pack in Shop.SCRAP_PACKS do
		local ready = pack.productId ~= 0
		table.insert(list, {
			icon = pack.icon,
			name = pack.displayName,
			line = `+{pack.scrap} scrap`,
			price = if ready then `R$ {pack.robux}` else "SOON",
			scrapPrice = false,
			owned = false,
			action = if ready
				then function()
					MarketplaceService:PromptProductPurchase(localPlayer, pack.productId)
				end
				else nil,
		})
	end
	return list
end

-- Marks the card that's celebrating a purchase, and notes which card each
-- press came from so the server's purchase sound can be matched to it.
local function withCelebration(list: { CardSpec }): { CardSpec }
	for _, spec in list do
		local action = spec.action
		if action then
			spec.action = function()
				pressedCard = spec.name
				action()
			end
		end
		if celebrated and celebrated.name == spec.name then
			spec.celebrate = celebrated.at
		end
	end
	return list
end

local function render()
	root.render(React.createElement(ShopScreen, {
		lists = {
			withCelebration(weaponCards()),
			withCelebration(boostCards()),
			withCelebration(passCards()),
			withCelebration(scrapCards()),
		},
		tab = tab,
		onTab = function(index: number)
			tab = index
			render()
		end,
	}))
end

function ShopController.init()
	root = Kit.mount("Shop", 10)
	Windows.opened:connect(function(name: string)
		if name == WINDOW then
			render()
		end
	end)
	render()
end

function ShopController.start()
	Remotes.ShopUpdated.OnClientEvent:Connect(function(newState: any)
		if type(newState) == "table" then
			state = newState
			render()
		end
	end)
	Remotes.RequestShop:FireServer()
	Notify.Sound.OnClientEvent:Connect(function(key: string)
		if key == "Purchase" and pressedCard and Windows.isOpen(WINDOW) then
			celebrated = { name = pressedCard, at = os.clock() }
			render()
		end
	end)

	-- Boost timers count down while the window is open.
	task.spawn(function()
		while true do
			task.wait(1)
			if Windows.isOpen(WINDOW) and tab == BOOSTS_TAB then
				render()
			end
		end
	end)

	HudController.addButton("Shop", 2, function()
		Windows.toggle(WINDOW)
	end)
end

return ShopController
