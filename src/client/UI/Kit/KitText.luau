--!strict
--[[
	KitText

	A label in one of the kit's three voices:
		"cream"  Luckiest Guy in cream, wearing the art's 2.5px ink (default)
		"dark"   Luckiest Guy in dark ink, for headings on cream cards
		"note"   Fredoka, wrapped, for body copy

	Luckiest labels are padded down by Art.DROP of their size so their caps
	centre on the row. `fit` sizes the label to its text across, for rows.

	Props: text, textSize, kind?, align?, alignY?, position?, size?, anchor?,
	color?, fit?, height?, zIndex?, layoutOrder?, visible?, transparency?, rich?,
	wrap?, scaled?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Art = require(script.Parent.Art)

local e = React.createElement

export type Props = {
	text: string,
	textSize: number,
	kind: ("cream" | "dark" | "note")?,
	align: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	position: UDim2?,
	size: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	fit: boolean?,
	height: number?,
	zIndex: number?,
	layoutOrder: number?,
	visible: boolean?,
	transparency: number?,
	rich: boolean?,
	wrap: boolean?,
	-- Shrinks the text to fit its box, never past textSize.
	scaled: boolean?,
}

local function KitText(props: Props)
	local kind = props.kind or "cream"
	local luckiest = kind ~= "note"
	local drop = if luckiest then math.round(props.textSize * Art.DROP) else 0
	local color = props.color
		or if kind == "cream" then Theme.Colors.Text elseif kind == "dark" then Art.DARK_TEXT else Theme.Colors.TextDim
	local size = props.size or UDim2.fromScale(1, 1)
	if props.fit then
		size = UDim2.fromOffset(0, props.height or props.textSize + 8)
	end
	return e("TextLabel", {
		BackgroundTransparency = 1,
		Text = props.text,
		RichText = props.rich == true,
		Font = if luckiest then Theme.Font else Theme.BodyFont,
		TextSize = props.textSize,
		TextScaled = props.scaled == true,
		TextColor3 = color,
		TextTransparency = props.transparency or 0,
		TextWrapped = if props.wrap == nil then kind == "note" else props.wrap,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = props.alignY or Enum.TextYAlignment.Center,
		AutomaticSize = if props.fit then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		Size = size,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		ZIndex = props.zIndex or 1,
		LayoutOrder = props.layoutOrder or 0,
		Visible = if props.visible == nil then true else props.visible,
	}, {
		Drop = if drop ~= 0
			then e("UIPadding", { PaddingTop = UDim.new(0, drop), PaddingBottom = UDim.new(0, -drop) })
			else nil,
		Fit = if props.scaled then e("UITextSizeConstraint", { MaxTextSize = props.textSize }) else nil,
		Ink = if kind == "cream"
			then e("UIStroke", {
				Color = Theme.Colors.Ink,
				Thickness = Art.INK,
				Transparency = props.transparency or 0,
				LineJoinMode = Enum.LineJoinMode.Round,
			})
			else nil,
	})
end

return KitText
