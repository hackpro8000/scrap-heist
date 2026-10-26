--!strict
--[[
	Hud

	The always-on screen overlay, laid out like a Roblox simulator: scrap on the
	left edge with an oversized icon, a 2x2 grid of square menu buttons under
	it, one slim storm strip top center (phase, survivors and time left), a
	separate red raid strip under it while someone raids, and health in the top
	right corner. Everything is packed tight so the arena
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
		_raidAlert: ImageLabel,
		_raidLabel: TextLabel,
		_timerLabel: TextLabel,
		_phase: Phase,
		_survivors: ImageLabel,
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

-- The round strip is one slim banner holding the storm state: phase,
-- survivors and time left, centred as one group. A raid is a separate event,
-- so it gets its own strip of the same shape under it, only while it lasts.
local ROUND_STRIP = Vector2.new(236, 28)
-- The stripes only show as a rim around this dark pill, so the text sits on
-- something calm and stays readable.
local ROUND_PILL_INSET = Vector2.new(5, 5)
local ROUND_PILL_COLOR = Color3.fromRGB(22, 20, 40)
local ROUND_TEXT_SIZE = 14
-- Small gaps inside a group (icon and its number), wide ones between groups.
local ROUND_GAP = 4
local ROUND_GROUP_GAP = 12

-- A fixed size text piece of the strip that grows to fit its words, so the
-- list layout can centre the whole row.
local function roundText(order: number): TextLabel
	return ScrapKit.label("", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = ROUND_TEXT_SIZE,
		LayoutOrder = order,
	})
end

-- A slim striped strip with a dark pill on it whose children line up in one
-- centred row. Returns the strip and the pill to put children in.
-- The strip art is 300x56 but the strip is far wider for its height. Slicing
-- keeps the rounded ends whole at half scale and only stretches the striped
-- middle, which the pill mostly covers anyway. ScrapKit.setImage resets the
-- scale type, so this runs again after every art swap.
local function sliceRoundStrip(strip: ImageLabel)
	strip.ScaleType = Enum.ScaleType.Slice
	strip.SliceCenter = Rect.new(28, 27, 272, 29)
	strip.SliceScale = ROUND_STRIP.Y / 56
end

local function stripWithPill(art: string): (ImageLabel, Frame)
	local strip = ScrapKit.image(art, {
		Size = UDim2.fromOffset(ROUND_STRIP.X, ROUND_STRIP.Y),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	sliceRoundStrip(strip)
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = ROUND_PILL_COLOR
	pill.BackgroundTransparency = 0.15
	pill.BorderSizePixel = 0
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.new(1, -2 * ROUND_PILL_INSET.X, 1, -2 * ROUND_PILL_INSET.Y)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, ROUND_GAP)
	row.Parent = pill
	pill.Parent = strip
	return strip, pill
end

-- An empty frame that widens the gap between two groups in the row.
local function roundSpacer(order: number): Frame
	local spacer = Instance.new("Frame")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(0, ROUND_GROUP_GAP - 2 * ROUND_GAP, 1, 0)
	spacer.LayoutOrder = order
	return spacer
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

	-- Top center: the round strip, with survivors only shown while a count
	-- is set; the row recentres itself either way.
	local banner, pill = stripWithPill("BannerCalm")
	banner.Position = UDim2.new(0.5, 0, 0, margin)
	local bannerLabel = roundText(1)
	bannerLabel.Parent = pill
	roundSpacer(3).Parent = pill
	local survivors = ScrapKit.image("IconBot", {
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 4,
	})
	survivors.Parent = pill
	local survivorsLabel = roundText(5)
	survivorsLabel.Visible = false
	survivorsLabel.Parent = pill
	roundSpacer(6).Parent = pill
	local timerLabel = roundText(7)
	timerLabel.Parent = pill

	-- Under it, only during a raid: who is raiding, in red.
	local raidAlert, raidPill = stripWithPill("BannerRaid")
	raidAlert.Position = UDim2.new(0.5, 0, 0, margin + ROUND_STRIP.Y + 4)
	raidAlert.Visible = false
	ScrapKit.image("IconAlert", {
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}).Parent =
		raidPill
	local raidLabel = roundText(2)
	raidLabel.Parent = raidPill
	banner.Parent = gui

	gui.Parent = parent

	local self = setmetatable({
		_gui = gui,
		_scrapLabel = scrapLabel,
		_setHealth = setHealth,
		_banner = banner,
		_bannerLabel = bannerLabel,
		_raidAlert = raidAlert,
		_raidLabel = raidLabel,
		_timerLabel = timerLabel,
		_phase = "Calm" :: Phase,
		_survivors = survivors,
		_survivorsLabel = survivorsLabel,
		_menuHandler = menuHandler,
	}, Hud)
	self:setHealth(1)
	self:setPhase("Calm")
	return self
end

function Hud.setScrap(self: Hud, amount: number)
	self._scrapLabel.Text = tostring(math.floor(amount))
end

function Hud.setHealth(self: Hud, fraction: number)
	self._setHealth(fraction)
end

function Hud.setPhase(self: Hud, phase: Phase)
	self._phase = phase
	ScrapKit.setImage(self._banner, PHASE_BANNERS[phase])
	sliceRoundStrip(self._banner)
	self._bannerLabel.Text = PHASE_TITLES[phase]
end

function Hud.setTimeLeft(self: Hud, seconds: number)
	local whole = math.max(0, math.ceil(seconds))
	self._timerLabel.Text = string.format("%d:%02d", whole // 60, whole % 60)
end

function Hud.setSurvivors(self: Hud, count: number?)
	self._survivors.Visible = count ~= nil
	self._survivorsLabel.Visible = count ~= nil
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
