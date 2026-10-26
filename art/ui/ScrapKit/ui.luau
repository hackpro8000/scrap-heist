-- ScrapKit: the game's UI skin, painted in the same brushed hand-painted
-- style as the models. Rusty dark steel panels, galvanized buttons, hazard
-- stripes and rarity-coloured frames. Text stays with Roblox fonts.
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local STEEL = { 0.62, 0.64, 0.66 }
local BARE_METAL = { 0.74, 0.73, 0.7 }
local HAZARD_YELLOW = { 0.9, 0.72, 0.12 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local CRATE_GREEN = { 0.3, 0.42, 0.24 }
local DIRT = { 0.42, 0.36, 0.28 }
local INK = { 0.07, 0.06, 0.06 }
local RARITY = {
	Common = { 0.62, 0.62, 0.6 },
	Uncommon = { 0.3, 0.72, 0.3 },
	Rare = { 0.25, 0.5, 0.95 },
	Legendary = { 1.0, 0.72, 0.18 },
}

local function lighter(color, k)
	return { color[1] + (1 - color[1]) * k, color[2] + (1 - color[2]) * k, color[3] + (1 - color[3]) * k }
end

local function darker(color, k)
	return { color[1] * (1 - k), color[2] * (1 - k), color[3] * (1 - k) }
end

local function plate(x0, y0, x1, y1, radius, seed)
	return { rect = { x0, y0, x1, y1 }, radius = radius, wobble = 1.2, seed = seed }
end

-- A painted metal plate: fill, brushwork, bevel and an inked rim.
local function paintPlate(canvas, shape, color, rustAmount)
	canvas:fill(shape, color)
	canvas:brushwork(shape, 1.0, 0.8, 20)
	if rustAmount > 0 then
		canvas:rust(shape, rustAmount, 16, shape.seed)
	end
	canvas:grime(shape, 0.5)
	canvas:bevel(shape, 6, lighter(color, 0.45), darker(color, 0.55), 0.9)
	canvas:rim(shape, 2, INK)
end

local function bolts(canvas, points)
	for i, p in points do
		local head = { circle = { p[1], p[2], 4 }, wobble = 0.3, seed = i }
		canvas:fill(head, BARE_METAL)
		canvas:bevel(head, 3, { 1, 1, 0.95 }, DARK_STEEL, 1)
		canvas:rim(head, 1.2, INK)
	end
end

-- Panel: the window background, rusty dark steel with corner bolts.
local panel = Canvas.new(128, 128)
paintPlate(panel, plate(4, 4, 124, 124, 10, 1), DARK_STEEL, 0.35)
bolts(panel, { { 16, 16 }, { 112, 16 }, { 16, 112 }, { 112, 112 } })
ui.element("Panel", panel, { slice = { 28, 28, 28, 28 } })

-- Buttons: galvanized steel, warmer on hover, pushed in when pressed.
local function button(name, color, pressed)
	local canvas = Canvas.new(96, 48)
	local shape = plate(3, if pressed then 6 else 3, 93, 45, 8, 7)
	if not pressed then
		canvas:shadow(shape, 0, 3, 4, 0.7)
	end
	paintPlate(canvas, shape, color, 0.12)
	ui.element(name, canvas, { slice = { 16, 16, 16, 16 } })
	return canvas
end
local normal = button("Button", STEEL, false)
local hover = button("ButtonHover", lighter(STEEL, 0.25), false)
local pressed = button("ButtonPressed", darker(STEEL, 0.2), true)

-- Action button: crate green, for buy and confirm.
local action = Canvas.new(96, 48)
local actionShape = plate(3, 3, 93, 45, 8, 9)
action:shadow(actionShape, 0, 3, 4, 0.7)
paintPlate(action, actionShape, CRATE_GREEN, 0.15)
ui.element("ButtonAction", action, { slice = { 16, 16, 16, 16 } })

-- Header: hazard tape across a window's title bar.
local header = Canvas.new(128, 40)
local tape = plate(2, 2, 126, 38, 4, 3)
header:fill(tape, HAZARD_YELLOW)
header:stripes(tape, HAZARD_YELLOW, RUBBER_BLACK, 12, 45)
header:brushwork(tape, 1.2, 0.6, 0)
header:rust(tape, 0.1, 10, 3)
header:grime(tape, 0.6)
header:bevel(tape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
header:rim(tape, 2, INK)
ui.element("Header", header, { slice = { 12, 12, 12, 12 } })

-- Progress bar: a sunken dirt-dark trough and a hazard-yellow fill.
local trough = Canvas.new(64, 24)
local troughShape = plate(2, 2, 62, 22, 6, 5)
paintPlate(trough, troughShape, darker(DIRT, 0.55), 0)
trough:bevel(troughShape, 5, INK, lighter(DIRT, 0.2), 0.8)
ui.element("BarTrough", trough, { slice = { 10, 10, 10, 10 } })

local fill = Canvas.new(64, 24)
local fillShape = plate(4, 4, 60, 20, 4, 6)
fill:fill(fillShape, HAZARD_YELLOW)
fill:brushwork(fillShape, 1.2, 0.5, 0)
fill:bevel(fillShape, 4, { 1, 0.95, 0.7 }, darker(HAZARD_YELLOW, 0.5), 0.9)
ui.element("BarFill", fill, { slice = { 8, 8, 8, 8 } })

-- Item slots: a recessed square framed in the item's rarity colour.
local function slot(name, color)
	local canvas = Canvas.new(80, 80)
	local frame = plate(3, 3, 77, 77, 9, #name)
	paintPlate(canvas, frame, color, 0.1)
	local well = plate(11, 11, 69, 69, 5, #name + 1)
	canvas:fill(well, darker(DARK_STEEL, 0.4))
	canvas:brushwork(well, 0.8, 0.6, 30)
	canvas:bevel(well, 6, INK, lighter(DARK_STEEL, 0.15), 0.9)
	canvas:rim(well, 1.5, INK)
	ui.element(name, canvas, { slice = { 20, 20, 20, 20 } })
	return canvas
end
local slots = { slot("Slot", DARK_STEEL) }
for _, rarity in { "Common", "Uncommon", "Rare", "Legendary" } do
	table.insert(slots, slot(`Slot{rarity}`, RARITY[rarity]))
end

-- Preview: a mock shop window with each element stretched to use size,
-- so the 9-slices get checked.
local preview = Canvas.new(640, 400, DIRT[1], DIRT[2], DIRT[3], 1)
preview:brushwork({ rect = { 0, 0, 640, 400 } }, 1.4, 2, 10)
preview:shadow(plate(40, 30, 600, 370, 10, 0), 6, 8, 10, 0.6)
preview:drawSliced(panel, { 28, 28, 28, 28 }, 40, 30, 560, 340)
preview:drawSliced(header, { 12, 12, 12, 12 }, 60, 48, 520, 40)
for i, canvas in slots do
	preview:draw(canvas, 72 + (i - 1) * 100, 112, 88, 88)
end
preview:drawSliced(trough, { 10, 10, 10, 10 }, 72, 228, 496, 28)
preview:drawSliced(fill, { 8, 8, 8, 8 }, 72, 228, 330, 28)
for i, canvas in { action, normal, hover, pressed } do
	preview:drawSliced(canvas, { 16, 16, 16, 16 }, 72 + (i - 1) * 126, 290, 116, 52)
end
ui.preview(preview)
