--!strict
--[[
	Hud

	The always-on screen overlay, laid out like a Roblox simulator: every value
	is a plain dark plate holding just the number, with an oversized icon
	poking out of its left end. Scrap sits on the left edge with a 2x2 grid of
	square menu buttons under it. Top center holds two plates side by side,
	survivors and time left, the timer's colour and icon naming the phase. A
	red raid plate appears under them while someone raids, and health sits in
	the top right corner. It only draws; HudController decides what to show
	and when, so each value has one owner.

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
		_timerPlate: ImageLabel,
		_phaseIcon: ImageLabel,
		_raidAlert: Frame,
		_raidLabel: TextLabel,
		_timerLabel: TextLabel,
		_phase: Phase,
		_survivors: Frame,
		_survivorsLabel: TextLabel,
		_menuHandler: { open: (Menu) -> () },
	},
	Hud
))

-- The timer plate's colour and icon name the phase together, so it needs no
-- title.
local PHASE_PLATES: { [Phase]: string } = {
	Calm = "CounterCalm",
	Warning = "CounterWarning",
	Storm = "CounterStorm",
	Results = "CounterCalm",
}

-- Warning reuses the raid alert icon: both mean "danger is coming, act now".
local PHASE_ICONS: { [Phase]: string } = {
	Calm = "IconCalm",
	Warning = "IconAlert",
	Storm = "IconStorm",
	Results = "IconCalm",
}

-- A currency is a dark plate with an oversized icon straddling its left
-- end, the simulator look: the icon pokes out past the plate on every side.
-- Each plate's art is painted at the width it shows at, so nothing stretches.
-- Returns the plate and icon too, so the timer can swap them per phase.
local CURRENCY_ICON = 60
local CURRENCY_PLATE = Vector2.new(170, 44)
local CURRENCY_GAP = 10
local CURRENCY_PLATE_LEFT = CURRENCY_ICON / 2 - 6
local function currency(icon: string, plateArt: string, plateWidth: number): (Frame, TextLabel, ImageLabel, ImageLabel)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(CURRENCY_PLATE_LEFT + plateWidth, CURRENCY_PLATE.Y)
	local plate = ScrapKit.image(plateArt, {
		Size = UDim2.fromOffset(plateWidth, CURRENCY_PLATE.Y),
		Position = UDim2.fromOffset(CURRENCY_PLATE_LEFT, 0),
	})
	plate.Parent = holder
	local iconImage = ScrapKit.image(icon, {
		Size = UDim2.fromOffset(CURRENCY_ICON, CURRENCY_ICON),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	iconImage.Parent = holder
	local label = ScrapKit.label("0", {
		Size = UDim2.new(1, -52, 1, -10),
		Position = UDim2.fromOffset(44, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = plate
	return holder, label, plate, iconImage
end

-- The round plates top center: survivors is a short count, the timer fits
-- "0:00", and the raid plate is wide enough for a raider's name (longer names
-- shrink to fit).
local SURVIVORS_PLATE_WIDTH = 90
local TIMER_PLATE_WIDTH = 130
local RAID_PLATE_WIDTH = 260
local ROUND_GAP = 16
-- Room under the round row for the timer icon's overhang plus a little air.
local RAID_GAP = 22

local HEALTH_SIZE = Vector2.new(200, 28)

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
local MENU_LEFT = CURRENCY_PLATE_LEFT
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

	local scrap, scrapLabel = currency("IconScrap", "Counter", CURRENCY_PLATE.X)
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

	-- The plates sit low enough that the oversized icons don't clip the top
	-- of the screen.
	local plateTop = margin + (CURRENCY_ICON - CURRENCY_PLATE.Y) / 2

	-- Top right: health, level with the round plates so the top row holds
	-- everything the player glances at mid-fight.
	local health, setHealth = ScrapKit.bar("BarFillHealth", "BarTroughHealth")
	health.Size = UDim2.fromOffset(HEALTH_SIZE.X, HEALTH_SIZE.Y)
	health.AnchorPoint = Vector2.new(1, 0)
	health.Position = UDim2.new(1, -margin, 0, plateTop + (CURRENCY_PLATE.Y - HEALTH_SIZE.Y) / 2)
	health.Parent = gui

	-- Top center: survivors and the timer side by side. Survivors only shows
	-- while a count is set; the row recentres itself either way.
	local roundRow = Instance.new("Frame")
	roundRow.BackgroundTransparency = 1
	roundRow.AnchorPoint = Vector2.new(0.5, 0)
	roundRow.Position = UDim2.new(0.5, 0, 0, plateTop)
	roundRow.Size = UDim2.new(1, 0, 0, CURRENCY_PLATE.Y)
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, ROUND_GAP)
	rowLayout.Parent = roundRow
	roundRow.Parent = gui

	local survivors, survivorsLabel = currency("IconBot", "CounterSurvivors", SURVIVORS_PLATE_WIDTH)
	survivors.LayoutOrder = 1
	survivors.Visible = false
	survivors.Parent = roundRow
	local timer, timerLabel, timerPlate, phaseIcon = currency("IconCalm", "CounterCalm", TIMER_PLATE_WIDTH)
	timer.LayoutOrder = 2
	timer.Parent = roundRow

	-- Under it, only during a raid: who is raiding, in red.
	local raidAlert, raidLabel = currency("IconAlert", "CounterRaid", RAID_PLATE_WIDTH)
	raidAlert.AnchorPoint = Vector2.new(0.5, 0)
	raidAlert.Position = UDim2.new(0.5, 0, 0, plateTop + CURRENCY_PLATE.Y + RAID_GAP)
	raidAlert.Visible = false
	raidAlert.Parent = gui

	gui.Parent = parent

	local self = setmetatable({
		_gui = gui,
		_scrapLabel = scrapLabel,
		_setHealth = setHealth,
		_timerPlate = timerPlate,
		_phaseIcon = phaseIcon,
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
	ScrapKit.setImage(self._timerPlate, PHASE_PLATES[phase])
	ScrapKit.setImage(self._phaseIcon, PHASE_ICONS[phase])
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
