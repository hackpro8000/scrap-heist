--!strict
--[[
	Theme

	Fonts, text colors and the flat fallback colors UI uses while the ScrapKit
	images aren't uploaded yet (see Assets.UI). The fallback colors match
	each element's painted base color, so a placeholder build still reads
	like the real kit.

	Public API:
		Theme.FONT, Theme.FONT_BOLD: Font
		Theme.TEXT, Theme.TEXT_DIM, Theme.TEXT_STROKE: Color3
		Theme.FALLBACK[elementName]: Color3
		Theme.HUD_MARGIN: number   -- pixels from the screen edge
]]

local Theme = {}

Theme.FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
Theme.FONT_BOLD = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

Theme.TEXT = Color3.fromRGB(240, 232, 214)
Theme.TEXT_DIM = Color3.fromRGB(170, 162, 148)
Theme.TEXT_STROKE = Color3.fromRGB(24, 20, 16)

Theme.HUD_MARGIN = 16

local STEEL = Color3.fromRGB(64, 68, 74)
local DARK = Color3.fromRGB(34, 34, 36)
local LIGHT = Color3.fromRGB(170, 176, 182)
local HAZARD = Color3.fromRGB(230, 184, 26)
local GREEN = Color3.fromRGB(70, 120, 54)
local RED = Color3.fromRGB(168, 51, 36)
local BLUE = Color3.fromRGB(66, 120, 200)

Theme.FALLBACK = {
	Button = LIGHT,
	ButtonHover = Color3.fromRGB(196, 200, 204),
	ButtonPressed = Color3.fromRGB(130, 134, 140),
	ButtonMenu = LIGHT,
	ButtonMenuHover = Color3.fromRGB(196, 200, 204),
	ButtonMenuPressed = Color3.fromRGB(130, 134, 140),
	ButtonAction = GREEN,
	ButtonDanger = RED,
	ButtonClose = RED,
	Tab = DARK,
	TabActive = LIGHT,
	InputField = DARK,
	Counter = DARK,
	BarTrough = DARK,
	BarTroughHealth = DARK,
	BarFill = HAZARD,
	BarFillHealth = RED,
	BarFillStorm = BLUE,
	ScrollTrack = DARK,
	ScrollThumb = LIGHT,
	Checkbox = DARK,
	CheckboxOn = GREEN,
	Slot = DARK,
	SlotCommon = DARK,
	SlotUncommon = DARK,
	SlotRare = DARK,
	SlotLegendary = DARK,
	BannerStorm = BLUE,
	BannerRaid = RED,
	BannerCalm = GREEN,
	PanelInventory = STEEL,
	PanelTrade = STEEL,
	PanelResults = STEEL,
	PanelLeaderboard = STEEL,
	PlateInventoryGrid = DARK,
	PlateInventoryDetail = LIGHT,
	PlateTradeOffer = DARK,
	PlateTradeWarning = HAZARD,
	PlateRaidShield = HAZARD,
	PlateRewards = LIGHT,
	PlateTutorial = LIGHT,
	PlateShowcase = DARK,
	HeaderInventory = HAZARD,
	HeaderTrade = HAZARD,
	HeaderResults = HAZARD,
	HeaderLeaderboard = HAZARD,
	ResultsRow = DARK,
	ResultsRowAlt = Color3.fromRGB(110, 110, 114),
	LeaderboardRow = DARK,
	LeaderboardRowAlt = Color3.fromRGB(110, 110, 114),
	TooltipUpgrade = LIGHT,
	TooltipBuyPad = LIGHT,
	BannerStormWarning = RED,
	IconScrap = LIGHT,
	IconTimer = LIGHT,
	IconBot = LIGHT,
	IconShield = BLUE,
	IconAlert = HAZARD,
	IconTrade = GREEN,
	IconTrophy = HAZARD,
	IconCross = RED,
} :: { [string]: Color3 }

return Theme
