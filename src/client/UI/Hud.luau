--!strict
--[[
	Hud

	The always-on screen overlay, laid out like a Roblox simulator: scrap on the
	left edge with an oversized icon, a 2x2 grid of square menu buttons under
	it, one slim round strip top center (phase and time left, taken over in
	red by a raid alert) with the survivors count beside it since that is round
	info rather than a stat, and health in the top right corner. Everything is packed tight so the arena
	stays in view. It only draws; HudController
	decides what to show and when, so each value has one owner.

	Public API:
		Hud.new(parent): Hud
		hud:setScrap(amount)
		hud:setHealth(fraction)
		hud:setPhase(phase)                 -- phase: "Calm" | "Warning" | "Storm" | "Results"
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
		_bannerAlert: ImageLabel,
		_timerLabel: TextLabel,
		_phase: Phase,
		_raiderName: string?,
		_survivors: Frame,
		_survivorsLabel: TextLabel,
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
-- The plate is only as wide as the number it holds, so a short count gets a
-- short plate.
local CURRENCY_ICON = 60
local CURRENCY_PLATE = Vector2.new(170, 44)
local CURRENCY_GAP = 10
local function currency(icon: string, plateWidth: number): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(CURRENCY_ICON / 2 - 6 + plateWidth, CURRENCY_PLATE.Y)
	local plate = ScrapKit.image("Counter", {
		Size = UDim2.fromOffset(plateWidth, CURRENCY_PLATE.Y),
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
		Size = UDim2.new(1, -52, 1, -10),
		Position = UDim2.fromOffset(44, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = plate
	return holder, label
end

-- The round strip is one slim row: phase on the left, time left on the
-- right. A raid takes it over in red rather than stacking a second banner.
local ROUND_STRIP = Vector2.new(170, 28)

-- The survivors count is a small number beside the strip, so it gets a
-- shrunk currency plate with the icon at the strip's height.
local function roundCount(): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(54, ROUND_STRIP.Y)
	local plate = ScrapKit.image("Counter", {
		Size = UDim2.fromOffset(40, ROUND_STRIP.Y),
		Position = UDim2.fromOffset(14, 0),
	})
	plate.Parent = holder
	ScrapKit.image("IconBot", {
		Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}).Parent =
		holder
	local label = ScrapKit.label("0", {
		Size = UDim2.new(0, 16, 1, -4),
		Position = UDim2.fromOffset(24, 2),
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
local MENU_BUTTON_GAP = 8
local MENU_LEFT = CURRENCY_ICON / 2 - 6
local MENU_BUTTON_SIZE = (CURRENCY_PLATE.X - MENU_BUTTON_GAP) / 2
local function menuButton(icon: string, title: string, onActivated: () -> ()): ImageButton
	local button = ScrapKit.button("", "ButtonMenu", onActivated)
	button.Size = UDim2.fromOffset(MENU_BUTTON_SIZE, MENU_BUTTON_SIZE)
	ScrapKit.image(icon, {
		Size = UDim2.fromOffset(50, 50),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 5),
		BackgroundTransparency = 1,
	}).Parent =
		button
	ScrapKit.label(title, {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 56),
		TextSize = 13,
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
	leftColumn.Size = UDim2.fromOffset(
		MENU_LEFT + CURRENCY_PLATE.X,
		CURRENCY_PLATE.Y + CURRENCY_GAP + 2 * MENU_BUTTON_SIZE + MENU_BUTTON_GAP
	)
	leftColumn.Parent = gui

	local scrap, scrapLabel = currency("IconScrap", CURRENCY_PLATE.X)
	scrap.Parent = leftColumn

	local survivors, survivorsLabel = roundCount()
	-- Just right of the round strip, so the round's state reads as one row.
	survivors.Position = UDim2.new(0.5, ROUND_STRIP.X / 2 + 3, 0, margin)
	survivors.Visible = false
	survivors.Parent = gui

	local menuTop = CURRENCY_PLATE.Y + CURRENCY_GAP
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

	-- Top right: health, level with the round strip so the top row holds
	-- everything the player glances at mid-fight.
	local health, setHealth = ScrapKit.bar("BarFillHealth", "BarTroughHealth")
	health.Size = UDim2.fromOffset(200, ROUND_STRIP.Y)
	health.AnchorPoint = Vector2.new(1, 0)
	health.Position = UDim2.new(1, -margin, 0, margin)
	health.Parent = gui

	-- Top center: the round strip. The alert icon only shows during a raid,
	-- and the title shifts right to make room for it.
	local banner = ScrapKit.image("BannerCalm", {
		Size = UDim2.fromOffset(ROUND_STRIP.X, ROUND_STRIP.Y),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, margin),
	})
	local bannerAlert = ScrapKit.image("IconAlert", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(5, 4),
		BackgroundTransparency = 1,
		Visible = false,
	})
	bannerAlert.Parent = banner
	local bannerLabel = ScrapKit.label("", {
		Size = UDim2.new(1, -50, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	bannerLabel.Parent = banner
	local timerLabel = ScrapKit.label("", {
		Size = UDim2.new(0, 36, 1, -6),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 3),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	timerLabel.Parent = banner
	banner.Parent = gui

	gui.Parent = parent

	local self = setmetatable({
		_gui = gui,
		_scrapLabel = scrapLabel,
		_setHealth = setHealth,
		_banner = banner,
		_bannerLabel = bannerLabel,
		_bannerAlert = bannerAlert,
		_timerLabel = timerLabel,
		_phase = "Calm" :: Phase,
		_raiderName = nil :: string?,
		_survivors = survivors,
		_survivorsLabel = survivorsLabel,
		_menuHandler = menuHandler,
	}, Hud)
	self:setHealth(1)
	self:_drawBanner()
	return self
end

function Hud.setScrap(self: Hud, amount: number)
	self._scrapLabel.Text = tostring(math.floor(amount))
end

function Hud.setHealth(self: Hud, fraction: number)
	self._setHealth(fraction)
end

-- Shows the raid if there is one, otherwise the phase. Both setters store
-- their value and redraw through here, so neither overwrites the other.
function Hud._drawBanner(self: Hud)
	local raider = self._raiderName
	ScrapKit.setImage(self._banner, if raider then "BannerRaid" else PHASE_BANNERS[self._phase])
	self._bannerLabel.Text = if raider then `{raider} IS RAIDING!` else PHASE_TITLES[self._phase]
	self._bannerAlert.Visible = raider ~= nil
	self._bannerLabel.Position = UDim2.fromOffset(if raider then 28 else 8, 3)
	self._bannerLabel.Size = UDim2.new(1, if raider then -70 else -50, 1, -6)
end

function Hud.setPhase(self: Hud, phase: Phase)
	self._phase = phase
	self:_drawBanner()
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
	self._raiderName = raiderName
	self:_drawBanner()
end

function Hud.setMenuHandler(self: Hud, handler: (Menu) -> ())
	self._menuHandler.open = handler
end

function Hud.destroy(self: Hud)
	self._gui:Destroy()
end

return Hud
