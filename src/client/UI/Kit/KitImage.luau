--!strict
--[[
	KitImage

	One piece of ToyKit art at its painted size. Icons are the one art shown
	at many sizes, so pass `size` for them; everything else takes its size
	from the art.

	Props: element, size?, position?, anchor?, zIndex?, transparency?,
	color?, layoutOrder?, visible?, imageRef? (a ref to the ImageLabel), children?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local Art = require(script.Parent.Art)

local e = React.createElement

export type Props = {
	element: string,
	size: number?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	transparency: number?,
	color: Color3?,
	layoutOrder: number?,
	visible: boolean?,
	imageRef: any?,
	children: any?,
}

local function KitImage(props: Props)
	local size = if props.size then Vector2.new(props.size, props.size) else Art.size(props.element)
	return e("ImageLabel", {
		ref = props.imageRef,
		BackgroundTransparency = 1,
		Image = Art.image(props.element),
		ImageTransparency = props.transparency or 0,
		ImageColor3 = props.color or Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		ZIndex = props.zIndex or 1,
		LayoutOrder = props.layoutOrder or 0,
		Visible = if props.visible == nil then true else props.visible,
	}, props.children)
end

return KitImage
