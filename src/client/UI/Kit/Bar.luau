--!strict
--[[
	Bar

	A trough with its fill clipped to the fraction shown, never squeezed, so
	the fill's rounded ends stay round. The fill is painted 14px shorter each
	way than its trough. `fraction` may be a number or a React binding.

	Props: name (BarTrough<name> / BarFill<name>), fraction, position?,
	anchor?, layoutOrder?, zIndex?, children?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local Art = require(script.Parent.Art)
local KitImage = require(script.Parent.KitImage)

local e = React.createElement

export type Props = {
	name: string,
	fraction: any,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	children: any?,
}

local function Bar(props: Props)
	local size = Art.size("BarTrough" .. props.name)
	local w, h = size.X, size.Y
	local function clipSize(fraction: number): UDim2
		return UDim2.fromOffset(math.round((w - 14) * math.clamp(fraction, 0, 1)), h - 14)
	end
	local fraction = props.fraction
	local clip = if type(fraction) == "number" then clipSize(fraction) else fraction:map(clipSize)
	local z = props.zIndex or 1
	return e(KitImage, {
		element = "BarTrough" .. props.name,
		position = props.position,
		anchor = props.anchor,
		layoutOrder = props.layoutOrder,
		zIndex = z,
	}, {
		Clip = e("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(7, 7),
			Size = clip,
			ZIndex = z + 1,
		}, {
			Fill = e(KitImage, { element = "BarFill" .. props.name, zIndex = z + 1 }),
		}),
		Content = if props.children then e(React.Fragment, nil, props.children) else nil,
	})
end

return Bar
