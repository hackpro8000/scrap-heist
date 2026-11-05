--!strict
--[[
	Theme

	UI styling: colors, fonts and sizes every UI module reads.
	Restyling the game's UI starts (and mostly ends) here.
]]

local Theme = {}

-- ToyKit palette (art/ui/ToyKit): deep navy plastic, sky-blue buttons and
-- cream text, every piece edged in thick ink.
Theme.Colors = {
	Background = Color3.fromRGB(22, 27, 58),
	Panel = Color3.fromRGB(41, 51, 107),
	PanelLight = Color3.fromRGB(51, 158, 242),
	Text = Color3.fromRGB(250, 242, 219),
	TextDim = Color3.fromRGB(176, 182, 214),
	Accent = Color3.fromRGB(255, 199, 51),
	Good = Color3.fromRGB(77, 209, 77),
	Bad = Color3.fromRGB(242, 64, 89),
	Warning = Color3.fromRGB(255, 153, 31),
	Ink = Color3.fromRGB(13, 13, 31),
}

-- Matches the rarity accents in art/src/rarity.luau.
Theme.RarityColors = {
	Common = Color3.fromRGB(158, 158, 153),
	Uncommon = Color3.fromRGB(77, 184, 77),
	Rare = Color3.fromRGB(64, 128, 242),
	Legendary = Color3.fromRGB(255, 184, 46),
}

Theme.Font = Enum.Font.LuckiestGuy
Theme.BodyFont = Enum.Font.FredokaOne
Theme.CornerRadius = UDim.new(0, 12)
-- The ink outline every panel and button wears.
Theme.StrokeThickness = 3
Theme.Padding = 8

-- Text sizes scale with the screen but stay readable on phones.
Theme.TextSize = {
	Small = 14,
	Body = 18,
	Title = 26,
	Banner = 40,
}

return Theme
