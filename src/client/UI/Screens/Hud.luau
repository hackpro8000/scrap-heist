--!strict
--[[
	Hud

	The always-on HUD, laid out like a Roblox simulator: the scrap count on a
	wooden plank with the bolt icon straddling its left end, and under it a
	two-column grid of menu buttons. Each button is a big toy icon with its
	name under it and no backing.

	Props: scrap (number?), buttons ({ { text, order, onClick } })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local React = require(ReplicatedStorage.Packages.React)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement

-- One gap between every pair of neighbours: plank to grid, and between grid
-- cells both ways. Gaps are measured between the drawn models, not the
-- padded images.
local GAP = 8
-- Icon art fits its model in the middle 86/104 of the image.
local ICON_FILL = 86 / 104

local PLANK_SIZE = Vector2.new(200, 59)
local SCRAP_ICON = 76
-- The bolt fills the plank's top-left corner, poking a little past its top
-- and left edges.
local PLANK_POSITION = Vector2.new(10, 14)
-- The number starts just past the bolt's drawn right edge.
local SCRAP_TEXT_LEFT = (SCRAP_ICON * (1 + ICON_FILL) / 2) - PLANK_POSITION.X + 2

local MENU_ICON = 116
local MENU_LABEL = 20
local MENU_MODEL = math.floor(MENU_ICON * ICON_FILL)
-- Each cell is exactly the drawn model plus the half of its label that hangs
-- below it, so GAP is the gap you see.
local MENU_CELL = Vector2.new(MENU_MODEL, MENU_MODEL + MENU_LABEL / 2)
local MENU_COLUMNS = 2
local MENU_WIDTH = MENU_COLUMNS * MENU_CELL.X + (MENU_COLUMNS - 1) * GAP
local MENU_TOP = PLANK_POSITION.Y + PLANK_SIZE.Y + GAP
-- The grid is centred under the plank.
local MENU_LEFT = PLANK_POSITION.X + (PLANK_SIZE.X - MENU_WIDTH) / 2
local HOVER_SCALE = 1.12
local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Back)
-- Held down, a button sinks a few pixels, shrinks and dims a touch.
local PRESS_SCALE = 0.92
local PRESS_DROP = 4
local PRESS_TINT = Color3.fromRGB(215, 215, 215)
local PRESS_TWEEN = TweenInfo.new(0.06, Enum.EasingStyle.Quad)
-- The image's centre sits on the cell's model area centre, so scaling about
-- it swells and squashes the icon in place.
local ICON_CENTRE = MENU_MODEL / 2

-- Which toy icon each menu shows; unknown menus fall back to the trophy.
local MENU_ICONS: { [string]: string } = {
	Bag = "IconBag",
	Trade = "IconTrade",
	Shop = "IconShop",
	Rewards = "IconRewards",
	Showcase = "IconTrophy",
}

export type MenuButton = { text: string, order: number, onClick: () -> () }

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- The icon swells under the cursor and squashes down while held, so a
-- backless button still answers every touch.
local function MenuButtonView(props: MenuButton)
	local iconRef = React.useRef(nil :: ImageLabel?)
	local scaleRef = React.useRef(nil :: UIScale?)
	local hovered = React.useRef(false)
	local pressed = React.useRef(false)

	local function react()
		local icon, scale = iconRef.current, scaleRef.current
		if not icon or not scale then
			return
		end
		local down = pressed.current
		local info = if down then PRESS_TWEEN else HOVER_TWEEN
		TweenService
			:Create(scale, info, { Scale = if down then PRESS_SCALE elseif hovered.current then HOVER_SCALE else 1 })
			:Play()
		TweenService:Create(icon, info, {
			Position = UDim2.new(0.5, 0, 0, ICON_CENTRE + (if down then PRESS_DROP else 0)),
			ImageColor3 = if down then PRESS_TINT else Color3.new(1, 1, 1),
		}):Play()
	end

	return e("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
		[React.Event.Activated] = props.onClick,
		[React.Event.MouseEnter] = function()
			hovered.current = true
			react()
		end,
		[React.Event.MouseLeave] = function()
			hovered.current, pressed.current = false, false
			react()
		end,
		[React.Event.InputBegan] = function(_gui, input: InputObject)
			if isPointer(input) then
				pressed.current = true
				react()
			end
		end,
		[React.Event.InputEnded] = function(_gui, input: InputObject)
			if not isPointer(input) then
				return
			end
			pressed.current = false
			-- A finger lifting leaves no hover behind.
			if input.UserInputType == Enum.UserInputType.Touch then
				hovered.current = false
			end
			react()
		end,
	}, {
		Icon = e("ImageLabel", {
			ref = iconRef,
			BackgroundTransparency = 1,
			Image = Kit.Art.image(MENU_ICONS[props.text] or "IconTrophy"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(MENU_ICON, MENU_ICON),
			Position = UDim2.new(0.5, 0, 0, ICON_CENTRE),
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
		}),
		-- Centred on the model's bottom edge, drawn over the icon.
		Label = e(Kit.Text, {
			text = string.upper(props.text),
			textSize = MENU_LABEL,
			align = Enum.TextXAlignment.Center,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, 0, 0, MENU_MODEL),
			size = UDim2.new(1, 8, 0, MENU_LABEL),
			zIndex = 2,
		}),
	})
end

export type Props = {
	scrap: number?,
	-- Rank, income and parts, on one line beside the scrap plank.
	stats: string?,
	buttons: { MenuButton },
}

local function Hud(props: Props)
	local buttons = {}
	for _, button in props.buttons do
		buttons[button.text] = e(MenuButtonView, button)
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(
			math.max(PLANK_POSITION.X + PLANK_SIZE.X, MENU_LEFT + MENU_WIDTH),
			MENU_TOP + 2 * MENU_CELL.Y + GAP
		),
	}, {
		Plank = e(Kit.Image, {
			element = "Counter",
			position = UDim2.fromOffset(PLANK_POSITION.X, PLANK_POSITION.Y),
		}, {
			-- Centred between the bolt and the nail at the plank's right end.
			Scrap = e(Kit.Text, {
				text = if props.scrap then Format.short(math.floor(props.scrap)) else "...",
				textSize = 38,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(SCRAP_TEXT_LEFT, 6),
				size = UDim2.new(1, -SCRAP_TEXT_LEFT - 24, 1, -12),
			}),
		}),
		Bolt = e(Kit.Image, { element = "IconScrap", size = SCRAP_ICON, zIndex = 2 }),
		Stats = if props.stats
			then e(Kit.Text, {
				text = props.stats,
				textSize = 20,
				fit = true,
				height = PLANK_SIZE.Y,
				position = UDim2.fromOffset(PLANK_POSITION.X + PLANK_SIZE.X + 10, PLANK_POSITION.Y),
			})
			else nil,
		Menu = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(MENU_LEFT, MENU_TOP),
			Size = UDim2.new(0, MENU_WIDTH, 1, -MENU_TOP),
		}, {
			Grid = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(MENU_CELL.X, MENU_CELL.Y),
				CellPadding = UDim2.fromOffset(GAP, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Buttons = e(React.Fragment, nil, buttons),
		}),
	})
end

return Hud
