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

-- Panel: the window background, patched together from scrap plates of
-- different metals, bolted at the overlaps. Painted near its use size so
-- the patchwork in the middle barely stretches.
local GALVANIZED = { 0.5, 0.53, 0.55 }
local RUST_RED = { 0.45, 0.24, 0.14 }
local PANEL_W, PANEL_H = 512, 320
local panel = Canvas.new(PANEL_W, PANEL_H)
local backing = plate(4, 4, PANEL_W - 4, PANEL_H - 4, 12, 1)
paintPlate(panel, backing, DARK_STEEL, 0.35)
-- Each patch: corners, colour, rust, and whether it is hazard-striped.
local patches = {
	{ 18, 16, 230, 150, GALVANIZED, 0.15 },
	{ 200, 22, 494, 130, darker(CRATE_GREEN, 0.15), 0.25 },
	{ 24, 160, 180, 302, RUST_RED, 0.6 },
	{ 170, 120, 380, 296, DARK_STEEL, 0.3 },
	{ 360, 140, 496, 300, GALVANIZED, 0.2 },
	{ 400, 96, 476, 160, HAZARD_YELLOW, 0.1, true },
}
for i, patch in patches do
	local shape = { rect = { patch[1], patch[2], patch[3], patch[4] }, radius = 4, wobble = 2, seed = 10 + i }
	panel:shadow(shape, 2, 3, 5, 0.55)
	if patch[7] then
		panel:fill(shape, HAZARD_YELLOW)
		panel:stripes(shape, HAZARD_YELLOW, RUBBER_BLACK, 10, -45)
		panel:brushwork(shape, 1, 0.6, 0)
		panel:rust(shape, patch[6], 10, shape.seed)
		panel:grime(shape, 0.5)
		panel:bevel(shape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
		panel:rim(shape, 2, INK)
	else
		paintPlate(panel, shape, patch[5], patch[6])
	end
	-- Bolts in each patch's corners hold it to the backing.
	bolts(panel, {
		{ patch[1] + 9, patch[2] + 9 },
		{ patch[3] - 9, patch[2] + 9 },
		{ patch[1] + 9, patch[4] - 9 },
		{ patch[3] - 9, patch[4] - 9 },
	})
end
bolts(panel, { { 14, 14 }, { PANEL_W - 14, 14 }, { 14, PANEL_H - 14 }, { PANEL_W - 14, PANEL_H - 14 } })
local PANEL_SLICE = { 40, 40, 40, 40 }
ui.element("Panel", panel, { slice = PANEL_SLICE })

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
preview:drawSliced(panel, PANEL_SLICE, 40, 30, 560, 340)
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
