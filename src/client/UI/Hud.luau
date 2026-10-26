--!strict
--[[
	Hud

	The always-on screen overlay, laid out like a Roblox simulator: scrap and
	survivors stacked on the left edge with oversized icons, a 2x2 grid of
	square menu buttons under them, the round phase banner, countdown and raid
	alert top center, and health along the bottom. It only draws; HudController
	decides what to show and when, so each value has one owner.

	Public API:
		Hud.new(parent): Hud
		hud:setScrap(amount)
		hud:setHealth(fraction)
		hud:setPhase(phase, timeFraction)   -- phase: "Calm" | "Warning" | "Storm" | "Results"
		hud:setTimeLeft(seconds)
		hud:setSurvivors(count?)            -- nil hides the counter
		hud:setRaidAlert(raiderName?)       -- nil hides the alert
		hud:setMenuHandler(handler)         -- called with the Menu a button opens
		hud:destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local ScrapKit = require(script.Parent.ScrapKit)

local Hud = {}
Hud.__index = Hud

export type Phase = "Calm" | "Warning" | "Storm" | "Results"
export type Menu = "Inventory" | "Trade" | "Leaderboard" | "Shield"

export type Hud = typeof(setmetatable(
	{} :: {
		_gui: ScreenGui,
		_scrapLabel: TextLabel,
		_setHealth: (number) -> (),
		_banner: ImageLabel,
		_bannerLabel: TextLabel,
		_setTimer: (number) -> (),
		_timerLabel: TextLabel,
		_survivors: ImageLabel,
		_survivorsLabel: TextLabel,
		_raidAlert: ImageLabel,
		_raidLabel: TextLabel,
		_menuHandler: { open: (Menu) -> () },
	},
	Hud
))

-- Warning reuses the raid banner: both mean "danger is coming, act now".
local PHASE_BANNERS: { [Phase]: string } = {
	Calm = "BannerCalm",
	Warning = "BannerRaid",
	Storm = "BannerStorm",
	Results = "BannerCalm",
}

local PHASE_TITLES: { [Phase]: string } = {
	Calm = "CALM",
	Warning = "STORM INCOMING",
	Storm = "SCRAP STORM",
	Results = "RESULTS",
}

-- A currency is a dark plate with an oversized icon straddling its left
-- end, the simulator look: the icon pokes out past the plate on every side.
local CURRENCY_ICON = 68
local CURRENCY_PLATE = Vector2.new(200, 48)
local CURRENCY_GAP = 16
local function currency(icon: string): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(CURRENCY_ICON / 2 - 6 + CURRENCY_PLATE.X, CURRENCY_PLATE.Y)
	local plate = ScrapKit.image("Counter", {
		Size = UDim2.fromOffset(CURRENCY_PLATE.X, CURRENCY_PLATE.Y),
		Position = UDim2.fromOffset(CURRENCY_ICON / 2 - 6, 0),
	})
	plate.Parent = holder
	ScrapKit.image(icon, {
		Size = UDim2.fromOffset(CURRENCY_ICON, CURRENCY_ICON),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}).Parent =
		holder
	local label = ScrapKit.label("0", {
		Size = UDim2.new(1, -60, 1, -12),
		Position = UDim2.fromOffset(52, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = plate
	return holder, label
end

-- Menu buttons are big squares with the icon on top and a short name under
-- it, so they read at a glance on a phone.
local MENU_BUTTONS: { { menu: Menu, icon: string, title: string } } = {
	{ menu = "Trade", icon = "IconTrade", title = "TRADE" },
	{ menu = "Leaderboard", icon = "IconTrophy", title = "TOP" },
	{ menu = "Shield", icon = "IconShield", title = "SHIELD" },
	{ menu = "Inventory", icon = "IconScrap", title = "BAG" },
}
-- The grid sits under the stat plates and spans exactly their width, the
-- icons poking out to the left of both alike.
local MENU_BUTTON_GAP = 12
local MENU_LEFT = CURRENCY_ICON / 2 - 6
local MENU_BUTTON_SIZE = (CURRENCY_PLATE.X - MENU_BUTTON_GAP) / 2
local function menuButton(icon: string, title: string, onActivated: () -> ()): ImageButton
	local button = ScrapKit.button("", "ButtonMenu", onActivated)
	button.Size = UDim2.fromOffset(MENU_BUTTON_SIZE, MENU_BUTTON_SIZE)
	ScrapKit.image(icon, {
		Size = UDim2.fromOffset(62, 62),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		BackgroundTransparency = 1,
	}).Parent =
		button
	ScrapKit.label(title, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 66),
		TextSize = 15,
		ZIndex = 2,
	}).Parent =
		button
	return button
end

function Hud.new(parent: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local margin = Theme.HUD_MARGIN

	-- Left edge, centered vertically: currencies with the menu grid under them.
	local leftColumn = Instance.new("Frame")
	leftColumn.BackgroundTransparency = 1
	leftColumn.AnchorPoint = Vector2.new(0, 0.5)
	leftColumn.Position = UDim2.new(0, margin, 0.5, 0)
	leftColumn.Size = UDim2.fromOffset(240, 300)
	leftColumn.Parent = gui

	local scrap, scrapLabel = currency("IconScrap")
	scrap.Parent = leftColumn

	local survivors, survivorsLabel = currency("IconBot")
	survivors.Position = UDim2.fromOffset(0, CURRENCY_PLATE.Y + CURRENCY_GAP)
	survivors.Visible = false
	survivors.Parent = leftColumn

	local menuTop = 2 * (CURRENCY_PLATE.Y + CURRENCY_GAP)
	-- The buttons exist before the Hud does, so they call through this table,
	-- which setMenuHandler fills in later.
	local menuHandler = { open = function(_menu: Menu) end }
	for i, entry in MENU_BUTTONS do
		local column, row = (i - 1) % 2, (i - 1) // 2
		local button = menuButton(entry.icon, entry.title, function()
			menuHandler.open(entry.menu)
		end)
		button.Position = UDim2.fromOffset(
			MENU_LEFT + column * (MENU_BUTTON_SIZE + MENU_BUTTON_GAP),
			menuTop + row * (MENU_BUTTON_SIZE + MENU_BUTTON_GAP)
		)
		button.Parent = leftColumn
	end

	-- Bottom center: health, wide so it reads from the corner of the eye.
	local health, setHealth = ScrapKit.bar("BarFillHealth", "BarTroughHealth")
	health.AnchorPoint = Vector2.new(0.5, 1)
	health.Position = UDim2.new(0.5, 0, 1, -margin)
	health.Parent = gui

	-- Top center: phase banner with the countdown bar under it.
	local banner = ScrapKit.image("BannerCalm", {
		Size = UDim2.fromOffset(300, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, margin),
	})
	local bannerLabel = ScrapKit.label("", { Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromOffset(12, 7) })
	bannerLabel.Parent = banner
	banner.Parent = gui

	local timer, setTimer = ScrapKit.bar("BarFillStorm")
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, margin + 62)
	timer.Parent = gui
	local timerLabel = ScrapKit.label("", {
		Size = UDim2.new(0, 80, 0, 22),
		Position = UDim2.new(1, 8, 0, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	timerLabel.Parent = timer

	-- Under the countdown: the raid alert, where the eye already is.
	local raidAlert = ScrapKit.image("BannerRaid", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, margin + 98),
		Visible = false,
	})
	ScrapKit.image("IconAlert", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(10, 6),
		BackgroundTransparency = 1,
	}).Parent =
		raidAlert
	local raidLabel = ScrapKit.label("", { Size = UDim2.new(1, -66, 1, -14), Position = UDim2.fromOffset(56, 7) })
	raidLabel.Parent = raidAlert
	raidAlert.Parent = gui

	gui.Parent = parent

	local self = setmetatable({
		_gui = gui,
		_scrapLabel = scrapLabel,
		_setHealth = setHealth,
		_banner = banner,
		_bannerLabel = bannerLabel,
		_setTimer = setTimer,
		_timerLabel = timerLabel,
		_survivors = survivors,
		_survivorsLabel = survivorsLabel,
		_raidAlert = raidAlert,
		_raidLabel = raidLabel,
		_menuHandler = menuHandler,
	}, Hud)
	self:setHealth(1)
	self:setPhase("Calm", 1)
	return self
end

function Hud.setScrap(self: Hud, amount: number)
	self._scrapLabel.Text = tostring(math.floor(amount))
end

function Hud.setHealth(self: Hud, fraction: number)
	self._setHealth(fraction)
end

function Hud.setPhase(self: Hud, phase: Phase, timeFraction: number)
	ScrapKit.setImage(self._banner, PHASE_BANNERS[phase])
	self._bannerLabel.Text = PHASE_TITLES[phase]
	self._setTimer(timeFraction)
end

function Hud.setTimeLeft(self: Hud, seconds: number)
	local whole = math.max(0, math.ceil(seconds))
	self._timerLabel.Text = string.format("%d:%02d", whole // 60, whole % 60)
end

function Hud.setSurvivors(self: Hud, count: number?)
	self._survivors.Visible = count ~= nil
	self._survivorsLabel.Text = if count then tostring(count) else ""
end

function Hud.setRaidAlert(self: Hud, raiderName: string?)
	self._raidAlert.Visible = raiderName ~= nil
	self._raidLabel.Text = if raiderName then `{raiderName} IS RAIDING!` else ""
end

function Hud.setMenuHandler(self: Hud, handler: (Menu) -> ())
	self._menuHandler.open = handler
end

function Hud.destroy(self: Hud)
	self._gui:Destroy()
end

return Hud
