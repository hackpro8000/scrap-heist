--!strict
--[[
	Tutorial

	The current tutorial prompt on a slim cream strip just above the health
	bar: the step number, the tip, and a "Got it" button for tips.

	Props: step (number, 0 hides the strip), steps, text, isTip, onGotIt()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Kit = require(script.Parent.Parent.Kit)

local e = React.createElement
local Art = Kit.Art

-- Sits just above the hotbar's health bar.
local BOTTOM_GAP = 124
local INSET = 20
-- The strip's face runs from 3px down to 6px above its foot, centred here.
local FACE_MIDDLE = 35
local PILL_W, PILL_H = 56, 28
local SMALL_W, SMALL_H = 120, 40

export type Props = {
	step: number,
	steps: number,
	text: string,
	isTip: boolean,
	onGotIt: () -> (),
}

local function Tutorial(props: Props)
	if props.step == 0 then
		return nil
	end
	local width = Art.size("PlateTutorial").X
	local textLeft = INSET + PILL_W + 12
	local textRight = if props.isTip then width - INSET - SMALL_W - 12 else width - INSET
	return e(Kit.Image, {
		element = "PlateTutorial",
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -BOTTOM_GAP),
	}, {
		Pill = e("Frame", {
			BackgroundColor3 = Theme.Colors.PanelLight,
			Position = UDim2.fromOffset(INSET, FACE_MIDDLE - PILL_H / 2),
			Size = UDim2.fromOffset(PILL_W, PILL_H),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Ink = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Colors.Ink,
				Thickness = Art.INK,
			}),
			Step = e(Kit.Text, {
				text = `{props.step}/{props.steps}`,
				textSize = 15,
				align = Enum.TextXAlignment.Center,
			}),
		}),
		Tip = e(Kit.Text, {
			text = props.text,
			textSize = 17,
			kind = "note",
			color = Art.DARK_TEXT,
			position = UDim2.fromOffset(textLeft, FACE_MIDDLE - 23),
			size = UDim2.fromOffset(textRight - textLeft, 46),
		}),
		GotIt = if props.isTip
			then e(Kit.Button, {
				element = Art.SMALL.Action,
				text = "GOT IT",
				textSize = 18,
				onClick = props.onGotIt,
				position = UDim2.fromOffset(width - INSET - SMALL_W, FACE_MIDDLE - SMALL_H / 2),
			})
			else nil,
	})
end

return Tutorial
