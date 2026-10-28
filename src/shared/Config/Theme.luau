--!strict
--[[
	Theme

	Placeholder UI styling: colors, fonts and sizes every UI module reads.
	Restyling the game's UI starts (and mostly ends) here.
]]

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(28, 30, 34),
	Panel = Color3.fromRGB(44, 47, 54),
	PanelLight = Color3.fromRGB(62, 66, 75),
	Text = Color3.fromRGB(235, 235, 235),
	TextDim = Color3.fromRGB(160, 165, 175),
	Accent = Color3.fromRGB(255, 170, 40),
	Good = Color3.fromRGB(90, 200, 110),
	Bad = Color3.fromRGB(230, 80, 70),
	Warning = Color3.fromRGB(255, 200, 60),
}

-- Matches the rarity accents in art/src/rarity.luau.
Theme.RarityColors = {
	Common = Color3.fromRGB(158, 158, 153),
	Uncommon = Color3.fromRGB(77, 184, 77),
	Rare = Color3.fromRGB(64, 128, 242),
	Legendary = Color3.fromRGB(255, 184, 46),
}

Theme.Font = Enum.Font.GothamBold
Theme.BodyFont = Enum.Font.Gotham
Theme.CornerRadius = UDim.new(0, 8)
Theme.Padding = 8

-- Text sizes scale with the screen but stay readable on phones.
Theme.TextSize = {
	Small = 14,
	Body = 18,
	Title = 26,
	Banner = 40,
}

return Theme
