--!strict
--[[
	Assets

	Every asset ID in the game lives here, so swapping art is one file. An ID
	of 0 is a placeholder: code calls Assets.isSet(id) and falls back (for UI,
	a flat colored frame) instead of showing a broken image.

	UI images are the ScrapKit PNGs in art/ui/ScrapKit. Upload each one to
	Roblox and paste its ID next to its name.

	Public API:
		Assets.UI[elementName]: number
		Assets.isSet(id): boolean
		Assets.image(id): string   -- "rbxassetid://<id>"
]]

local Assets = {}

Assets.UI = {
	Button = 0,
	ButtonHover = 0,
	ButtonPressed = 0,
	ButtonMenu = 0,
	ButtonMenuHover = 0,
	ButtonMenuPressed = 0,
	ButtonAction = 0,
	ButtonDanger = 0,
	ButtonClose = 0,
	Tab = 0,
	TabActive = 0,
	InputField = 0,
	Counter = 0,
	CounterSurvivors = 0,
	CounterCalm = 0,
	CounterStorm = 0,
	CounterWarning = 0,
	CounterRaid = 0,
	BarTrough = 0,
	BarTroughHealth = 0,
	BarFill = 0,
	BarFillHealth = 0,
	BarFillStorm = 0,
	ScrollTrack = 0,
	ScrollThumb = 0,
	Checkbox = 0,
	CheckboxOn = 0,
	Slot = 0,
	SlotCommon = 0,
	SlotUncommon = 0,
	SlotRare = 0,
	SlotLegendary = 0,
	PanelInventory = 0,
	PanelTrade = 0,
	PanelResults = 0,
	PanelLeaderboard = 0,
	PlateInventoryGrid = 0,
	PlateInventoryDetail = 0,
	PlateTradeOffer = 0,
	PlateTradeWarning = 0,
	PlateRaidShield = 0,
	PlateRewards = 0,
	PlateTutorial = 0,
	PlateShowcase = 0,
	HeaderInventory = 0,
	HeaderTrade = 0,
	HeaderResults = 0,
	HeaderLeaderboard = 0,
	ResultsRow = 0,
	ResultsRowAlt = 0,
	LeaderboardRow = 0,
	LeaderboardRowAlt = 0,
	TooltipUpgrade = 0,
	TooltipBuyPad = 0,
	BannerStormWarning = 0,
	IconScrap = 0,
	IconTimer = 0,
	IconBot = 0,
	IconShield = 0,
	IconAlert = 0,
	IconTrade = 0,
	IconTrophy = 0,
	IconCross = 0,
	IconStorm = 0,
	IconCalm = 0,
}

function Assets.isSet(id: number): boolean
	return id ~= 0
end

function Assets.image(id: number): string
	return `rbxassetid://{id}`
end

return Assets
