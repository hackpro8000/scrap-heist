--!strict
--[[
	ScrapKit

	Builds UI pieces from the ScrapKit images (art/ui/ScrapKit). Screens never
	create ImageLabels for kit art themselves; they ask this module, so slice
	margins, image IDs and placeholder fallbacks are handled in one place.

	Kit images are 9-sliced: the painted corners keep their size while the
	middle stretches, so one 96px button image fits any button size. Until an
	image's ID is set in Assets.UI, the piece is a flat rounded frame in the
	element's fallback color from Config/Theme.

	Public API:
		ScrapKit.image(element, props?): GuiObject
		ScrapKit.setImage(gui, element)        -- swap art, e.g. hover states
		ScrapKit.label(text, props?): TextLabel
		ScrapKit.button(text, element, onActivated): ImageButton
		ScrapKit.bar(fillElement): (Frame, (fraction: number) -> ())
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local ScrapKitSlices = require(ReplicatedStorage.Shared.UI.ScrapKitSlices)

local ScrapKit = {}

-- Fallback frames round their corners about as much as the painted art.
local FALLBACK_CORNER = UDim.new(0, 10)
-- Bars inset their fill so the trough's rim shows around it.
local BAR_INSET = 4

type Props = { [string]: any }

local function applyProps(gui: Instance, props: Props?)
	if not props then
		return
	end
	for key, value in props do
		(gui :: any)[key] = value
	end
end

function ScrapKit.setImage(gui: ImageLabel | ImageButton, element: string)
	local id = Assets.UI[element]
	assert(id ~= nil, `unknown ScrapKit element {element}`)
	local slice = ScrapKitSlices[element]

	if not Assets.isSet(id) then
		gui.Image = ""
		gui.BackgroundTransparency = 0
		gui.BackgroundColor3 = Theme.FALLBACK[element]
		return
	end

	gui.Image = Assets.image(id)
	gui.BackgroundTransparency = 1
	gui.ScaleType = if slice.slice then Enum.ScaleType.Slice else Enum.ScaleType.Fit
	if slice.slice then
		gui.SliceCenter = slice.slice
	end
end

local function decorate(gui: ImageLabel | ImageButton, element: string, props: Props?)
	gui.Name = element
	gui.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = FALLBACK_CORNER
	corner.Parent = gui
	ScrapKit.setImage(gui, element)
	applyProps(gui, props)
end

function ScrapKit.image(element: string, props: Props?): ImageLabel
	local gui = Instance.new("ImageLabel")
	gui.Size = UDim2.fromOffset(ScrapKitSlices[element].size.X, ScrapKitSlices[element].size.Y)
	decorate(gui, element, props)
	return gui
end

function ScrapKit.label(text: string, props: Props?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.FONT_BOLD
	label.Text = text
	label.TextColor3 = Theme.TEXT
	label.TextScaled = true
	label.TextStrokeColor3 = Theme.TEXT_STROKE
	label.TextStrokeTransparency = 0
	-- TextScaled with no size cap makes short labels huge on big screens.
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 28
	limit.Parent = label
	applyProps(label, props)
	return label
end

-- The plain Button swaps through its hover and pressed art; colored buttons
-- (action, danger) keep their color so their meaning never flickers away.
function ScrapKit.button(text: string, element: string, onActivated: () -> ()): ImageButton
	local button = Instance.new("ImageButton")
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(160, 48)
	decorate(button, element, nil)

	local label = ScrapKit.label(text, {
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	label.Parent = button

	if element == "Button" then
		button.MouseEnter:Connect(function()
			ScrapKit.setImage(button, "ButtonHover")
		end)
		button.MouseLeave:Connect(function()
			ScrapKit.setImage(button, "Button")
		end)
		button.MouseButton1Down:Connect(function()
			ScrapKit.setImage(button, "ButtonPressed")
		end)
		button.MouseButton1Up:Connect(function()
			ScrapKit.setImage(button, "ButtonHover")
		end)
	end
	button.Activated:Connect(onActivated)
	return button
end

function ScrapKit.bar(fillElement: string): (ImageLabel, (fraction: number) -> ())
	local trough = ScrapKit.image("BarTrough", { Size = UDim2.fromOffset(220, 24) })
	local fill = ScrapKit.image(fillElement, {
		Position = UDim2.fromOffset(BAR_INSET, BAR_INSET),
		Size = UDim2.new(1, -BAR_INSET * 2, 1, -BAR_INSET * 2),
	})
	fill.Parent = trough

	local function setFraction(fraction: number)
		local clamped = math.clamp(fraction, 0, 1)
		fill.Visible = clamped > 0
		fill.Size = UDim2.new(clamped, -BAR_INSET * 2 * clamped, 1, -BAR_INSET * 2)
	end
	return trough, setFraction
end

return ScrapKit
