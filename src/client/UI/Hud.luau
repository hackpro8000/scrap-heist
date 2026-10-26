--!strict
--[[
	Hud

	The always-on screen overlay: scrap counter and health (top left), round
	phase banner and countdown (top center), survivors left (top right) and
	the raid alert under it. It only draws; HudController decides what to
	show and when, so each value has one owner.

	Public API:
		Hud.new(parent): Hud
		hud:setScrap(amount)
		hud:setHealth(fraction)
		hud:setPhase(phase, timeFraction)   -- phase: "Calm" | "Warning" | "Storm" | "Results"
		hud:setTimeLeft(seconds)
		hud:setSurvivors(count?)            -- nil hides the counter
		hud:setRaidAlert(raiderName?)       -- nil hides the alert
		hud:destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local ScrapKit = require(script.Parent.ScrapKit)

local Hud = {}
Hud.__index = Hud

export type Phase = "Calm" | "Warning" | "Storm" | "Results"

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

local COUNTER_SIZE = UDim2.fromOffset(180, 44)
local ICON_SIZE = UDim2.fromOffset(52, 52)

-- A counter is a dark plate with an icon sitting inside one end and a
-- number filling the rest.
local ICON_INSET = 24
local function counter(icon: string, anchorRight: boolean): (ImageLabel, TextLabel)
	local plate = ScrapKit.image("Counter", { Size = COUNTER_SIZE })
	ScrapKit.image(icon, {
		Size = ICON_SIZE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = if anchorRight then UDim2.new(1, -ICON_INSET, 0.5, 0) else UDim2.new(0, ICON_INSET, 0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}).Parent =
		plate
	local label = ScrapKit.label("0", {
		Size = UDim2.new(1, -60, 1, -10),
		Position = if anchorRight then UDim2.fromOffset(12, 5) else UDim2.fromOffset(48, 5),
		TextXAlignment = if anchorRight then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
	})
	label.Parent = plate
	return plate, label
end

function Hud.new(parent: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local margin = Theme.HUD_MARGIN

	-- Top left: scrap and health.
	local scrap, scrapLabel = counter("IconScrap", false)
	scrap.Position = UDim2.fromOffset(margin, margin)
	scrap.Parent = gui

	local health, setHealth = ScrapKit.bar("BarFillHealth")
	health.Position = UDim2.fromOffset(margin, margin + 56)
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

	-- Top right: survivors, and the raid alert below it.
	local survivors, survivorsLabel = counter("IconBot", true)
	survivors.AnchorPoint = Vector2.new(1, 0)
	survivors.Position = UDim2.new(1, -margin, 0, margin)
	survivors.Visible = false
	survivors.Parent = gui

	local raidAlert = ScrapKit.image("BannerRaid", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -margin, 0, margin + 60),
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

function Hud.destroy(self: Hud)
	self._gui:Destroy()
end

return Hud
