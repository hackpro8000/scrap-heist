--!strict
--[[
	Window

	A window: a dimmed backdrop, the kit panel centred on screen, its candy
	header with an icon and title at the left and the close button inside the
	right end. The panel pops open from its centre and shrinks away on close.
	The whole window scales down evenly to fit small screens, so the pixel
	layout inside holds on phones.

	Open state lives in Windows; tapping close or the backdrop calls
	`onClose` if given, else closes the window.

	Props: name, panel, header, title, icon?, sticky?, onClose?, children
	(laid out in the panel's pixels)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Windows = require(script.Parent.Parent.Windows)
local Art = require(script.Parent.Art)
local KitButton = require(script.Parent.KitButton)
local KitImage = require(script.Parent.KitImage)
local KitText = require(script.Parent.KitText)

local e = React.createElement

local SCREEN_PAD = 24
local POP_FROM = 0.85
local TITLE_ICON = 28
local CLOSE_INSET = 4

export type Props = {
	name: string,
	panel: string,
	header: string,
	title: string,
	icon: string?,
	sticky: boolean?,
	onClose: (() -> ())?,
	children: any?,
}

local function useFitScale(size: Vector2): number
	local function fit(): number
		local camera = Workspace.CurrentCamera
		if not camera then
			return 1
		end
		local viewport = camera.ViewportSize
		return math.min(1, (viewport.X - SCREEN_PAD * 2) / size.X, (viewport.Y - SCREEN_PAD * 2) / size.Y)
	end
	local scale, setScale = React.useState(fit)
	React.useEffect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return nil
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setScale(fit())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return scale
end

local function Window(props: Props)
	local isOpen = Windows.useOpen(props.name)
	-- Stays true through the closing shrink, so the panel animates out.
	local shown, setShown = React.useState(isOpen)
	local popRef = React.useRef(nil :: UIScale?)
	local size = Art.size(props.panel)
	local headerSize = Art.size(props.header)
	local fitScale = useFitScale(size)

	React.useEffect(function()
		if isOpen then
			setShown(true)
			return nil
		end
		local pop = popRef.current
		if not pop or not Juice.UI_TWEENS then
			setShown(false)
			return nil
		end
		local tween = TweenService:Create(
			pop,
			TweenInfo.new(Juice.POP_SECONDS * 0.6, Enum.EasingStyle.Quad),
			{ Scale = POP_FROM }
		)
		local connection = tween.Completed:Connect(function()
			setShown(false)
		end)
		tween:Play()
		return function()
			connection:Disconnect()
			tween:Cancel()
		end
	end, { isOpen })

	React.useEffect(function()
		local pop = popRef.current
		if not (isOpen and shown and pop) then
			return
		end
		if not Juice.UI_TWEENS then
			pop.Scale = 1
			return
		end
		pop.Scale = POP_FROM
		TweenService
			:Create(
				pop,
				TweenInfo.new(Juice.POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
			:Play()
	end, { isOpen, shown })

	if not shown then
		return nil
	end

	local function close()
		if props.onClose then
			props.onClose()
		else
			Windows.close(props.name)
		end
	end

	local titleX = if props.icon then 10 + TITLE_ICON + 8 else 14
	return e(React.Fragment, nil, {
		Backdrop = e("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Colors.Ink,
			BackgroundTransparency = 0.5,
			Size = UDim2.fromScale(1, 1),
			[React.Event.Activated] = function()
				if not props.sticky then
					close()
				end
			end,
		}),
		Holder = e("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size.X, size.Y),
			ZIndex = 2,
		}, {
			Fit = e("UIScale", { Scale = fitScale }),
			-- The panel pops inside the holder, from its centre, so the pop
			-- and the fit don't fight over one UIScale.
			Panel = e("ImageLabel", {
				BackgroundTransparency = 1,
				Active = true,
				Image = Art.image(props.panel),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(size.X, size.Y),
			}, {
				Pop = e("UIScale", { ref = popRef }),
				Header = e(KitImage, {
					element = props.header,
					position = UDim2.fromOffset(Art.HEADER_Y, Art.HEADER_Y),
					zIndex = 2,
				}, {
					Icon = if props.icon
						then e(KitImage, {
							element = props.icon,
							size = TITLE_ICON,
							anchor = Vector2.new(0, 0.5),
							position = UDim2.new(0, 10, 0.5, 0),
							zIndex = 3,
						})
						else nil,
					Title = e(KitText, {
						text = props.title,
						textSize = 26,
						position = UDim2.fromOffset(titleX, 0),
						size = UDim2.fromOffset(headerSize.X - titleX - 40, headerSize.Y),
						zIndex = 3,
					}),
					Close = e(KitButton, {
						element = "ButtonClose",
						onClick = close,
						anchor = Vector2.new(1, 0.5),
						position = UDim2.new(1, -CLOSE_INSET, 0.5, 0),
						zIndex = 3,
					}),
				}),
				Body = e(React.Fragment, nil, props.children),
			}),
		}),
	})
end

return Window
