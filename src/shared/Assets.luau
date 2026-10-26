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
	Panel = 0,
	PlateBacking = 0,
	PlateContent = 0,
	PlateAction = 0,
	PlateWarning = 0,
	Button = 0,
	ButtonHover = 0,
	ButtonPressed = 0,
	ButtonAction = 0,
	ButtonDanger = 0,
	ButtonClose = 0,
	Header = 0,
	Tab = 0,
	TabActive = 0,
	InputField = 0,
	Counter = 0,
	BarTrough = 0,
	BarFill = 0,
	BarFillHealth = 0,
	BarFillStorm = 0,
	ScrollTrack = 0,
	ScrollThumb = 0,
	Checkbox = 0,
	CheckboxOn = 0,
	ListRow = 0,
	ListRowAlt = 0,
	Tooltip = 0,
	Slot = 0,
	SlotCommon = 0,
	SlotUncommon = 0,
	SlotRare = 0,
	SlotLegendary = 0,
	BannerStorm = 0,
	BannerRaid = 0,
	BannerCalm = 0,
	IconScrap = 0,
	IconTimer = 0,
	IconBot = 0,
	IconShield = 0,
	IconAlert = 0,
	IconTrade = 0,
	IconTrophy = 0,
	IconCross = 0,
}

function Assets.isSet(id: number): boolean
	return id ~= 0
end

function Assets.image(id: number): string
	return `rbxassetid://{id}`
end

return Assets
