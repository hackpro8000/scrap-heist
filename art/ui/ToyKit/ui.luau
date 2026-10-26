-- ToyKit: an alternative UI skin, chunky and clean like a toy box. Deep
-- navy panels, cream cards, candy-bright buttons and thick black outlines,
-- with no rust or grime. Same element names and sizes as ScrapKit, so the
-- two can be swapped. Text stays with Roblox fonts.
local DARK_STEEL = { 0.16, 0.2, 0.42 }
local STEEL = { 0.2, 0.62, 0.95 }
local BARE_METAL = { 0.98, 0.95, 0.86 }
local HAZARD_YELLOW = { 1.0, 0.6, 0.12 }
local RUBBER_BLACK = { 0.95, 0.42, 0.06 }
local CRATE_GREEN = { 0.3, 0.82, 0.3 }
local DIRT = { 0.36, 0.3, 0.62 }
local INK = { 0.05, 0.05, 0.12 }
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

-- Every plate shares one silhouette: big round corners and crisp, exact
-- outlines with no wobble. Only the colour inside is hand painted.
local CORNER = 16
local function plate(x0, y0, x1, y1, seed)
	return {
		rect = { x0, y0, x1, y1 },
		radius = math.min(CORNER, (x1 - x0) / 2, (y1 - y0) / 2),
		wobble = 0,
		seed = seed,
	}
end

-- Visible strokes over a flat fill, so every surface looks hand painted.
local function handPaint(canvas, shape, color)
	canvas:fill(shape, color)
	canvas:brushwork(shape, 1.2, 1.6, 30, "drag")
end

-- A moulded plastic plate: fill, a soft bevel, a thick black outline and
-- a bright gloss along the top. Rust amounts are ignored: toys stay clean.
local function paintPlate(canvas, shape, color, _rustAmount)
	handPaint(canvas, shape, color)
	canvas:bevel(shape, 8, lighter(color, 0.45), darker(color, 0.45), 1)
	canvas:outline(shape, 5, INK)
	canvas:highlight(shape, lighter(color, 0.85), 5, 2.5)
end

local function bolts(canvas, points)
	for i, p in points do
		local head = { circle = { p[1], p[2], 4 }, wobble = 0, seed = i }
		canvas:fill(head, BARE_METAL)
		canvas:bevel(head, 3, { 1, 1, 0.95 }, DARK_STEEL, 1)
		canvas:outline(head, 2, INK)
		canvas:highlight(head, { 1, 1, 0.95 }, 2, 1)
	end
end

-- Every element is painted at the size the game shows it and stretched
-- as-is, with no 9-slice, so the big pieces get one element per screen.

-- Bolts sit a fixed distance in from each corner of a w by h plate.
local function cornerBolts(canvas, w, h, inset)
	bolts(canvas, { { inset, inset }, { w - inset, inset }, { inset, h - inset }, { w - inset, h - inset } })
end

-- Panels: a window's backing, deep navy plastic with corner screws. They
-- stay dull so the scrap plates bolted onto them carry the layout.
local function panel(name, w, h)
	local canvas = Canvas.new(w, h)
	paintPlate(canvas, plate(4, 4, w - 4, h - 4, #name), DARK_STEEL, 0.35)
	cornerBolts(canvas, w, h, 16)
	ui.element(name, canvas)
	return canvas
end
local panelInventory = panel("PanelInventory", 800, 560)
panel("PanelTrade", 1000, 590)
local panelResults = panel("PanelResults", 600, 570)
panel("PanelLeaderboard", 320, 340)

-- Scrap plates: bolted onto a panel to group its content. The metal says
-- how much attention a group gets, from quiet to loud:
--   backing   near-black, recessed behind grids and lists
--   content   bright bare metal, for the main info
--   hazard    stripes, for the one thing that must be seen
local GALVANIZED = { 0.98, 0.93, 0.8 }
local function scrapPlate(name, w, h, color, rustAmount, hazard)
	local canvas = Canvas.new(w, h)
	local shape = plate(4, 3, w - 6, h - 6, #name)
	canvas:shadow(shape, 3, 5, 1, 0.8)
	if hazard then
		handPaint(canvas, shape, HAZARD_YELLOW)
		canvas:stripes(shape, HAZARD_YELLOW, RUBBER_BLACK, 10, -45)
		canvas:bevel(shape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
		canvas:outline(shape, 5, INK)
		canvas:highlight(shape, { 1, 0.95, 0.7 }, 3, 1.5)
	else
		paintPlate(canvas, shape, color, rustAmount)
	end
	if h >= 60 then
		cornerBolts(canvas, w - 2, h - 3, 12)
	end
	ui.element(name, canvas)
	return canvas
end
-- Backing is near-black so slots and text pop; content is bright bare
-- metal so it stands well clear of the dark panel.
local BACKING, CONTENT = darker(DARK_STEEL, 0.45), GALVANIZED
local plateInventoryGrid = scrapPlate("PlateInventoryGrid", 520, 394, BACKING, 0.4)
scrapPlate("PlateInventoryDetail", 216, 394, CONTENT, 0.15)
scrapPlate("PlateTradeOffer", 456, 330, BACKING, 0.4)
scrapPlate("PlateTradeWarning", 636, 48, HAZARD_YELLOW, 0.1, true)
scrapPlate("PlateRaidShield", 300, 110, HAZARD_YELLOW, 0.1, true)
scrapPlate("PlateRewards", 552, 110, CONTENT, 0.15)
scrapPlate("PlateTutorial", 560, 150, CONTENT, 0.15)
scrapPlate("PlateShowcase", 240, 330, BACKING, 0.4)

-- Buttons: sky-blue plastic, brighter on hover, pushed in when pressed.
local BUTTON_W, BUTTON_H = 200, 52
local function button(name, color, pressed, w, h)
	w, h = w or BUTTON_W, h or BUTTON_H
	local canvas = Canvas.new(w, h)
	local shape = plate(3, if pressed then 6 else 3, w - 3, h - 3, 7)
	if not pressed then
		canvas:shadow(shape, 0, 5, 1, 0.85)
	end
	paintPlate(canvas, shape, color, 0.12)
	-- Lighter up top, darker below, blended in a few loose strokes so the
	-- button reads as lit from above without an airbrushed ramp.
	canvas:gradient(shape, 1.15, 0.42, 3)
	ui.element(name, canvas)
	return canvas
end
local normal = button("Button", STEEL, false)
button("ButtonHover", lighter(STEEL, 0.25), false)
local pressed = button("ButtonPressed", darker(STEEL, 0.2), true)

-- Menu buttons: the same plastic drawn square at the HUD's 94px, so the
-- simulator-style menu grid shows true corners instead of a squashed bar.
local MENU_SIZE = 94
local menuButton = button("ButtonMenu", STEEL, false, MENU_SIZE, MENU_SIZE)
button("ButtonMenuHover", lighter(STEEL, 0.25), false, MENU_SIZE, MENU_SIZE)
button("ButtonMenuPressed", darker(STEEL, 0.2), true, MENU_SIZE, MENU_SIZE)

-- Action button: crate green, for buy and confirm.
local action = Canvas.new(BUTTON_W, BUTTON_H)
local actionShape = plate(3, 3, BUTTON_W - 3, BUTTON_H - 3, 9)
action:shadow(actionShape, 0, 5, 1, 0.85)
paintPlate(action, actionShape, CRATE_GREEN, 0.15)
ui.element("ButtonAction", action)

-- Headers: orange candy stripes across a window's title bar, one per window.
local function header(name, w, h)
	local canvas = Canvas.new(w, h)
	local tape = plate(2, 2, w - 2, h - 2, #name)
	handPaint(canvas, tape, HAZARD_YELLOW)
	canvas:stripes(tape, HAZARD_YELLOW, RUBBER_BLACK, 12, 45)
	canvas:bevel(tape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
	canvas:outline(tape, 5, INK)
	canvas:highlight(tape, { 1, 0.95, 0.7 }, 3, 1.5)
	ui.element(name, canvas)
	return canvas
end
local headerInventory = header("HeaderInventory", 712, 48)
header("HeaderTrade", 912, 48)
header("HeaderResults", 568, 48)
header("HeaderLeaderboard", 288, 44)

-- Progress bar: a sunken dirt-dark trough and a hazard-yellow fill.
local BAR_W, BAR_H = 220, 24
local trough = Canvas.new(BAR_W, BAR_H)
local troughShape = plate(2, 2, BAR_W - 2, BAR_H - 2, 5)
paintPlate(trough, troughShape, darker(DIRT, 0.55), 0)
trough:bevel(troughShape, 5, INK, lighter(DIRT, 0.2), 0.8)
ui.element("BarTrough", trough)

-- The health bar runs wider and taller along the bottom, so it gets its own trough.
local HEALTH_W, HEALTH_H = 320, 28
local healthTrough = Canvas.new(HEALTH_W, HEALTH_H)
local healthTroughShape = plate(2, 2, HEALTH_W - 2, HEALTH_H - 2, 5)
paintPlate(healthTrough, healthTroughShape, darker(DIRT, 0.55), 0)
healthTrough:bevel(healthTroughShape, 5, INK, lighter(DIRT, 0.2), 0.8)
ui.element("BarTroughHealth", healthTrough)

-- Fills are painted at the full bar's width; a part-full bar squeezes them.
local fill = Canvas.new(BAR_W - 14, BAR_H - 14)
local fillShape = plate(0, 0, BAR_W - 14, BAR_H - 14, 6)
handPaint(fill, fillShape, HAZARD_YELLOW)
fill:highlight(fillShape, { 1, 0.95, 0.7 }, 2, 1.2)
fill:bevel(fillShape, 4, { 1, 0.95, 0.7 }, darker(HAZARD_YELLOW, 0.5), 0.9)
ui.element("BarFill", fill)

-- Item slots: a recessed square framed in the item's rarity colour.
local function slot(name, color)
	local canvas = Canvas.new(80, 80)
	local frame = plate(3, 3, 77, 77, #name)
	paintPlate(canvas, frame, color, 0.1)
	local well = plate(11, 11, 69, 69, #name + 1)
	handPaint(canvas, well, darker(DARK_STEEL, 0.4))
	canvas:bevel(well, 6, INK, lighter(DARK_STEEL, 0.15), 0.9)
	canvas:outline(well, 3, INK)
	ui.element(name, canvas)
	return canvas
end
local slots = { slot("Slot", DARK_STEEL) }
for _, rarity in { "Common", "Uncommon", "Rare", "Legendary" } do
	table.insert(slots, slot(`Slot{rarity}`, RARITY[rarity]))
end

-- Danger button: candy red, for cancel, decline and raid.
local RUST_RED = { 0.95, 0.25, 0.35 }
local danger = button("ButtonDanger", RUST_RED, false)

-- Close button: a small red square marked with an inked cross.
local function cross(cx, cy, r, t, seed)
	local points = {}
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local c, s = math.cos(a), math.sin(a)
		-- Each arm: out along a, across by t, back to the centre notch.
		for _, p in { { t, -t }, { r, -t }, { r, t } } do
			table.insert(points, cx + p[1] * c - p[2] * s)
			table.insert(points, cy + p[1] * s + p[2] * c)
		end
	end
	return { polygon = points, wobble = 0, seed = seed }
end
local close = Canvas.new(40, 40)
local closeShape = plate(3, 3, 37, 37, 11)
close:shadow(closeShape, 0, 4, 1, 0.85)
paintPlate(close, closeShape, RUST_RED, 0.1)
close:fill(cross(20, 20, 11, 3.5, 2), BARE_METAL)
close:outline(cross(20, 20, 11, 3.5, 2), 1.5, INK)
ui.element("ButtonClose", close)

-- Tabs: raised galvanized when chosen, sunk dark steel otherwise.
local function tab(name, color)
	local canvas = Canvas.new(124, 40)
	paintPlate(canvas, plate(3, 3, 121, 40, #name), color, 0.1)
	ui.element(name, canvas)
	return canvas
end
local tabActive = tab("TabActive", GALVANIZED)
local tabIdle = tab("Tab", darker(DARK_STEEL, 0.2))

-- Sunken wells: text input and counters sit in these.
local function well(name, w, h, color)
	local canvas = Canvas.new(w, h)
	local shape = plate(2, 2, w - 2, h - 2, #name)
	paintPlate(canvas, shape, color, 0)
	canvas:bevel(shape, 5, INK, lighter(color, 0.3), 0.8)
	ui.element(name, canvas)
	return canvas
end
local input = well("InputField", 300, 48, darker(DIRT, 0.55))
local counter = well("Counter", 170, 44, darker(DARK_STEEL, 0.35))
-- Round plates top centre, each painted at its HUD width. Survivors is dark
-- like Counter; the timer is tinted by phase, and the raid plate is red, dark
-- enough that the white number still reads.
local counterSurvivors = well("CounterSurvivors", 90, 44, darker(DARK_STEEL, 0.35))
local counterCalm = well("CounterCalm", 130, 44, darker(CRATE_GREEN, 0.45))
local counterStorm = well("CounterStorm", 130, 44, darker({ 0.35, 0.55, 0.9 }, 0.45))
local counterWarning = well("CounterWarning", 130, 44, darker(RUST_RED, 0.35))
local counterRaid = well("CounterRaid", 260, 44, darker(RUST_RED, 0.35))

-- Bar fills for health and the storm timer, sharing the trough above.
local function barFill(name, color, w, h)
	local canvas = Canvas.new(w - 14, h - 14)
	local shape = plate(0, 0, w - 14, h - 14, #name)
	handPaint(canvas, shape, color)
	canvas:bevel(shape, 4, lighter(color, 0.5), darker(color, 0.5), 0.9)
	ui.element(name, canvas)
	return canvas
end
local health = barFill("BarFillHealth", { 0.8, 0.22, 0.16 }, HEALTH_W, HEALTH_H)
local storm = barFill("BarFillStorm", { 0.35, 0.55, 0.9 }, BAR_W, BAR_H)

-- Scroll bar: a thin trough and a bolted steel thumb.
well("ScrollTrack", 20, 370, darker(DIRT, 0.55))
local scrollThumb = Canvas.new(20, 110)
paintPlate(scrollThumb, plate(2, 3, 18, 107, 4), STEEL, 0.05)
ui.element("ScrollThumb", scrollThumb)

-- Ready check for trades: an empty well, or one holding a green tick.
local function tick(seed)
	return { polygon = { 9, 21, 15, 15, 19, 20, 30, 8, 35, 13, 19, 30 }, wobble = 0, seed = seed }
end
local function checkbox(name, ticked)
	local canvas = Canvas.new(40, 40)
	local frame = plate(3, 3, 37, 37, #name)
	paintPlate(canvas, frame, STEEL, 0.05)
	local inner = plate(9, 9, 31, 31, #name + 1)
	canvas:fill(inner, darker(DARK_STEEL, 0.4))
	canvas:bevel(inner, 4, INK, lighter(DARK_STEEL, 0.15), 0.9)
	if ticked then
		canvas:fill(tick(1), { 0.4, 0.85, 0.3 })
		canvas:bevel(tick(1), 2, { 0.8, 1, 0.7 }, { 0.15, 0.4, 0.1 }, 0.8)
		canvas:outline(tick(1), 1.5, INK)
	end
	ui.element(name, canvas)
	return canvas
end
local checkOff = checkbox("Checkbox", false)
local checkOn = checkbox("CheckboxOn", true)

-- List rows for results and the leaderboard, alternating.
local function row(name, w, h, color)
	local canvas = Canvas.new(w, h)
	paintPlate(canvas, plate(2, 2, w - 2, h - 2, #name), color, 0.05)
	ui.element(name, canvas)
	return canvas
end
local ROW_A, ROW_B = darker(DARK_STEEL, 0.35), lighter(DARK_STEEL, 0.18)
local rowA = row("ResultsRow", 552, 50, ROW_A)
local rowB = row("ResultsRowAlt", 552, 50, ROW_B)
row("LeaderboardRow", 288, 44, ROW_A)
row("LeaderboardRowAlt", 288, 44, ROW_B)

-- Tooltips over plot pads: pale bare metal so dark text reads on it.
local function tooltip(name, w, h)
	local canvas = Canvas.new(w, h)
	local shape = plate(3, 3, w - 5, h - 6, #name)
	canvas:shadow(shape, 3, 4, 1, 0.8)
	paintPlate(canvas, shape, BARE_METAL, 0.05)
	ui.element(name, canvas)
	return canvas
end
local tooltipUpgrade = tooltip("TooltipUpgrade", 340, 190)
tooltip("TooltipBuyPad", 260, 120)

-- Banners: candy stripes across the screen for round phases and raids.
local function banner(name, a, b, w, h)
	-- Strokes scale with height, so the slim HUD strip keeps room for stripes.
	local k = math.min(1, h / 56)
	local canvas = Canvas.new(w, h)
	local shape = plate(1, 1, w - 1, h - 1 - 5 * k, #name)
	canvas:shadow(shape, 0, 5 * k, 1, 0.85)
	handPaint(canvas, shape, a)
	canvas:stripes(shape, a, b, 14 * k, -45)
	canvas:bevel(shape, 5 * k, lighter(a, 0.5), INK, 0.8)
	canvas:outline(shape, 5 * k, INK)
	ui.element(name, canvas)
	return canvas
end
local bannerStormWarning = banner("BannerStormWarning", RUST_RED, RUBBER_BLACK, 700, 96)

do
	-- Icons, 104 square: each one a tiny toy model in 3/4 view, painted with no
	-- badge behind it so it can sit on any panel, button or counter.
	local CREAM = { 0.98, 0.95, 0.86 }
	-- Icons are painted at twice their HUD size, so the silhouette is twice the
	-- plates' 5px outline to read the same width on screen.
	local ICON_STROKE = 10
	local BLUE, ORANGE, GREEN, RED, GOLD, STEEL =
		{ 0.2, 0.62, 0.95 }, { 1, 0.6, 0.12 }, { 0.3, 0.82, 0.3 }, { 0.95, 0.25, 0.35 }, { 1, 0.78, 0.2 }, { 0.86, 0.9, 0.97 }

	-- 3/4 view: every shape becomes a polygon tipped back (squashed vertically) and
	-- turned a little (sheared), around the centre of its box.
	local SQUASH, SHEAR = 0.7, 0.15

	local function outlinePoints(shape)
		local p = {}
		if shape.circle then
			local c = shape.circle
			for k = 0, 39 do
				local a = k / 40 * math.pi * 2
				table.insert(p, { c[1] + math.cos(a) * c[3], c[2] + math.sin(a) * c[3] })
			end
		elseif shape.rect then
			local r, rad = shape.rect, shape.radius or 0
			local corners = { { r[3] - rad, r[4] - rad, 0 }, { r[1] + rad, r[4] - rad, 90 }, { r[1] + rad, r[2] + rad, 180 }, { r[3] - rad, r[2] + rad, 270 } }
			for _, k in corners do
				for step = 0, 6 do
					local a = math.rad(k[3] + step * 15)
					table.insert(p, { k[1] + math.cos(a) * rad, k[2] + math.sin(a) * rad })
				end
			end
		else
			for k = 1, #shape.polygon, 2 do
				table.insert(p, { shape.polygon[k], shape.polygon[k + 1] })
			end
		end
		return p
	end

	-- Shapes in a box (48 unless given), tilted unless flat, moved to (ox, oy) and scaled by s.
	local function place(shape, ox, oy, s, wobble, seed, box, flat)
		local mid = (box or 48) / 2
		local squash, shear = if flat then 1 else SQUASH, if flat then 0 else SHEAR
		local p = {}
		for _, v in outlinePoints(shape) do
			local dx, dy = v[1] - mid, v[2] - mid
			table.insert(p, ox + (mid + dx + dy * shear) * s)
			table.insert(p, oy + (mid + dy * squash) * s)
		end
		return { polygon = p, wobble = wobble or 0, seed = seed }
	end
	local function hex(cx, cy, r)
		local p = {}
		for i = 0, 5 do
			local a = math.rad(i * 60)
			table.insert(p, cx + math.cos(a) * r)
			table.insert(p, cy + math.sin(a) * r)
		end
		return { polygon = p }
	end
	local function crossShape(cx, cy, r, t)
		local p = {}
		for i = 0, 3 do
			local a = math.rad(45 + i * 90)
			local c, s = math.cos(a), math.sin(a)
			for _, q in { { t, -t }, { r, -t }, { r, t } } do
				table.insert(p, cx + q[1] * c - q[2] * s)
				table.insert(p, cy + q[1] * s + q[2] * c)
			end
		end
		return { polygon = p }
	end

	-- Each icon is a small model: parts stacked from the casing up. `focus` names
	-- the part the eye goes to first (the bot's head, the trophy's cup); the icon is
	-- centred near it. `raise` lifts a model by hand, in pixels. A part is a shape extruded by `height`, resting `lift` above the casing, in its own colour.
	local WOOD, GLASS, DARK = { 0.55, 0.32, 0.18 }, { 1, 0.95, 0.55 }, { 0.14, 0.15, 0.22 }
	local function part(shape, color, height, lift) return { shape = shape, color = color, height = height, lift = lift or 0 } end
	-- Thread ridges ring the standing shaft, a little proud of it, every few studs up.
	local function threads()
		local list = {}
		for k = 0, 3 do
			table.insert(list, part({ circle = { 24, 30, 6.8 } }, darker(STEEL, 0.3), 1, 9 + k * 3.5))
		end
		return list
	end
	local function concat(a, b) for _, v in b do table.insert(a, v) end return a end
	local ICONS = {
		-- Parts: a bolt standing on its hex head, threaded shaft rising out of it.
		{ color = STEEL, focus = 1, raise = 6, parts = concat({
			part(hex(24, 30, 15), STEEL, 6),
			part({ circle = { 24, 30, 9 } }, darker(STEEL, 0.25), 1, 6),
			part({ circle = { 24, 30, 6 } }, STEEL, 16, 6),
		}, threads()) },
		{ color = BLUE, focus = 3, parts = {
			part({ circle = { 13, 8, 6 } }, GOLD, 5), part({ circle = { 35, 8, 6 } }, GOLD, 5),
			part({ circle = { 24, 26, 20 } }, BLUE, 7),
			part({ circle = { 24, 26, 15 } }, CREAM, 1, 7),
			part({ polygon = { 22.5, 27, 25.5, 27, 25.5, 14, 22.5, 14 } }, DARK, 2, 8),
			part({ polygon = { 23, 25, 33, 29, 32, 31.5, 22, 28 } }, RED, 2, 9),
			part({ circle = { 24, 26, 2.5 } }, GOLD, 2, 10),
		} },
		{ color = RED, focus = 3, parts = {
			part({ rect = { 22, 4, 26, 14 } }, STEEL, 4),
			part({ circle = { 24, 5, 4.5 } }, GOLD, 4, 4),
			part({ rect = { 7, 12, 41, 45 }, radius = 7 }, RED, 9),
			part({ rect = { 11, 17, 37, 37 }, radius = 4 }, DARK, 1, 9),
			part({ circle = { 17.5, 25, 4 } }, GLASS, 2, 10), part({ circle = { 30.5, 25, 4 } }, GLASS, 2, 10),
			part({ rect = { 16, 31, 32, 34 } }, STEEL, 1, 10),
		} },
		{ color = BLUE, focus = 2, raise = 5, parts = {
			part({ polygon = { 24, 3, 43, 9, 41, 28, 24, 46, 7, 28, 5, 9 } }, STEEL, 7),
			part({ polygon = { 24, 8, 38, 12, 36.5, 27, 24, 40, 11.5, 27, 10, 12 } }, BLUE, 2, 7),
			part({ polygon = { 21, 12, 27, 12, 27, 36, 24, 39, 21, 36 } }, GOLD, 2, 9),
		} },
		{ color = ORANGE, focus = 2, parts = {
			part({ polygon = { 24, 3, 46, 43, 2, 43 } }, DARK, 6),
			part({ polygon = { 24, 10, 40, 39, 8, 39 } }, GOLD, 2, 6),
			part({ rect = { 21.5, 17, 26.5, 30 }, radius = 2 }, DARK, 3, 8),
			part({ circle = { 24, 34.5, 2.8 } }, DARK, 3, 8),
		} },
		{ color = GREEN, parts = {
			part({ polygon = { 44, 32, 32, 43, 32, 37, 12, 37, 12, 27, 32, 27, 32, 21 } }, RED, 5),
			part({ polygon = { 4, 16, 16, 5, 16, 11, 36, 11, 36, 21, 16, 21, 16, 27 } }, GOLD, 5, 6),
		} },
		-- Trophy: a squat, wide cup on a short stem, so it fills the circle instead of standing tall in it.
		{ color = GOLD, focus = 6, raise = 12, parts = {
			part({ rect = { 8, 34, 40, 42 }, radius = 2 }, WOOD, 5),
			part({ rect = { 14, 31, 34, 36 }, radius = 2 }, GOLD, 2, 5),
			part({ rect = { 20, 25, 28, 33 } }, GOLD, 3, 6),
			part({ circle = { 6, 12, 6 } }, GOLD, 3, 8), part({ circle = { 42, 12, 6 } }, GOLD, 3, 8),
			part({ polygon = { 5, 4, 43, 4, 40, 16, 30, 26, 18, 26, 8, 16 } }, GOLD, 5, 9),
			part({ circle = { 24, 12, 4 } }, RED, 1, 14),
		} },
		{ color = RED, focus = 2, parts = {
			part(crossShape(24, 25, 19, 6), RED, 8),
			part({ circle = { 24, 25, 4 } }, STEEL, 2, 8),
		} },
		-- Storm: a tall pale cloud with a fat gold bolt striking out of it, the two
		-- together roughly round so the icon fills its circle. No focus part, so
		-- it centres on the whole model instead of one puff of cloud.
		{ color = STEEL, parts = {
			part({ circle = { 13, 20, 10 } }, STEEL, 5), part({ circle = { 25, 13, 12 } }, STEEL, 5),
			part({ circle = { 36, 20, 10 } }, STEEL, 5), part({ rect = { 3, 18, 46, 32 }, radius = 7 }, STEEL, 5),
			part({ polygon = { 21, 24, 35, 24, 29, 33, 37, 33, 15, 48, 21, 37, 13, 37 } }, GOLD, 3, 5),
		} },
		-- Calm: a round sun inside a ring of points.
		{ color = GOLD, focus = 2, parts = {
			part({ polygon = { 24.0, 2.0, 29.7, 10.1, 39.6, 8.4, 37.9, 18.3, 46.0, 24.0, 37.9, 29.7, 39.6, 39.6, 29.7, 37.9, 24.0, 46.0, 18.3, 37.9, 8.4, 39.6, 10.1, 29.7, 2.0, 24.0, 10.1, 18.3, 8.4, 8.4, 18.3, 10.1 } }, ORANGE, 4),
			part({ circle = { 24, 24, 12 } }, GOLD, 3, 4),
		} },
	}

	-- Each surface gets the brush that says what it is made of. Metal is brushed in
	-- long straight drags, painted plastic in soft dabs, wood in dry grain strokes,
	-- and dark rubber or glass in sponge stipple. Shaded sides are hatched like an
	-- ink drawing, and casings are sponged so they stay quiet behind the model.
	local BRUSH_FOR = {
		[STEEL] = { "drag", 1.3, 1.4, 20 },
		[GOLD] = { "drag", 1.1, 1.6, 35 },
		[WOOD] = { "dry", 1.4, 1.2, 0 },
		[DARK] = { "sponge", 1.0, 1.2, 0 },
		[GLASS] = { "sponge", 0.8, 1.6, 0 },
	}
	local PLASTIC_BRUSH = { "dab", 1.2, 1.5, 30 }
	local SIDE_BRUSH = { "hatch", 0.9, 1.0, 60 }

	local function paint(c, shape, color, brush)
		local b = brush or BRUSH_FOR[color] or PLASTIC_BRUSH
		c:fill(shape, color)
		c:brushwork(shape, b[2], b[3], b[4], b[1])
	end

	-- Each model part is drawn as an extruded slab: a cast shadow, then its side
	-- built up in shaded layers, then a lit top face.
	local function paintPart(c, p, ox, oy, scale, i)
		local function at(up, wobble) return place(p.shape, ox, oy - up, scale, wobble, i) end
		local sideDark, sideLight = darker(p.color, 0.55), darker(p.color, 0.25)
		if p.lift == 0 then c:shadow(at(0, 0.7), 4, 5, 1, 0.55) end
		c:rim(at(p.lift, 0.7), 3, INK)
		for k = 0, p.height - 1 do
			local t = k / math.max(p.height - 1, 1)
			c:fill(at(p.lift + k, 0.7), { sideDark[1] + (sideLight[1] - sideDark[1]) * t, sideDark[2] + (sideLight[2] - sideDark[2]) * t, sideDark[3] + (sideLight[3] - sideDark[3]) * t })
		end
		if p.height > 1 then
			local b = SIDE_BRUSH
			for k = 0, p.height - 1 do c:brushwork(at(p.lift + k, 0.7), b[2] / p.height, b[3], b[4], b[1]) end
		end
		local top = at(p.lift + p.height, 0.7)
		paint(c, top, p.color)
		c:bevel(top, 4, lighter(p.color, 0.6), darker(p.color, 0.3), 1)
		c:highlight(top, lighter(p.color, 0.85), 3, 2)
		c:rim(top, 2.5, INK)
	end

	-- Each model is scaled and moved so it sits centred in, and fills most of, a
	-- circle the size of the canvas: the badge or button behind it can be any shape.
	local ICON_SIZE = 104
	local FIT_RADIUS = 43 -- canvas radius minus room for the ink silhouette
	local ICON_NAMES = { "IconScrap", "IconTimer", "IconBot", "IconShield", "IconAlert", "IconTrade", "IconTrophy", "IconCross", "IconStorm", "IconCalm" }

	-- Each part's outline at its bottom and top, drawn at scale s from (0, 0).
	local function modelOutlines(icon, s)
		local outlines = {}
		for _, p in icon.parts do
			for _, up in { p.lift, p.lift + p.height } do
				table.insert(outlines, place(p.shape, 0, -up, s).polygon)
			end
		end
		return outlines
	end

	-- The centre of a set of outlines, each weighted by its area (shoelace formula).
	local function areaCentre(outlines)
		local total, wx, wy = 0, 0, 0
		for _, poly in outlines do
			local n = #poly
			for k = 1, n, 2 do
				local x0, y0 = poly[k], poly[k + 1]
				local x1, y1 = poly[(k + 1) % n + 1], poly[(k + 2) % n + 1]
				local cross = x0 * y1 - x1 * y0
				total += cross
				wx += (x0 + x1) * cross
				wy += (y0 + y1) * cross
			end
		end
		return wx / (3 * total), wy / (3 * total)
	end

	-- Where the icon should be centred: the visible top face of its focus part, or
	-- for an icon with no single focus (the trade arrows), the whole model.
	-- How far the centre leans from the whole model toward its focus part. Full lean
	-- shrinks icons whose focus sits at one end (trophy cup, shield face); half keeps
	-- the focus near the middle while the model still fills the circle.
	local FOCUS_PULL = 0.5

	local function focusCentre(icon, s, outlines)
		local ax, ay = areaCentre(outlines)
		local p = icon.parts[icon.focus or 0]
		if not p then return ax, ay end
		local fx, fy = areaCentre({ place(p.shape, 0, -(p.lift + p.height), s).polygon })
		return ax + (fx - ax) * FOCUS_PULL, ay + (fy - ay) * FOCUS_PULL
	end

	-- Centre the model on its focus, then size it so its farthest point just
	-- reaches the circle. Part heights are in pixels, not scaled, so refine a few times.
	local function fitInCircle(icon)
		local s, cx, cy = 1.75, 0, 0
		for _ = 1, 4 do
			local outlines = modelOutlines(icon, s)
			cx, cy = focusCentre(icon, s, outlines)
			local reach = 0
			for _, poly in outlines do
				for k = 1, #poly, 2 do reach = math.max(reach, math.sqrt((poly[k] - cx) ^ 2 + (poly[k + 1] - cy) ^ 2)) end
			end
			s *= FIT_RADIUS / reach
		end
		-- `raise` lifts a model by hand, in pixels, when its 3D depth still leaves it sitting low.
		return s, ICON_SIZE / 2 - cx, ICON_SIZE / 2 - cy - (icon.raise or 0)
	end

	for i, icon in ICONS do
		local canvas = Canvas.new(ICON_SIZE, ICON_SIZE)
		local scale, ox, oy = fitInCircle(icon)
		-- A thick ink silhouette behind the whole model makes it pop off any panel.
		for _, p in icon.parts do
			for _, up in { p.lift, p.lift + p.height } do
				canvas:outline(place(p.shape, ox, oy - up, scale, 0.7, i), ICON_STROKE, INK)
			end
		end
		for _, p in icon.parts do paintPart(canvas, p, ox, oy, scale, i) end
		ui.element(ICON_NAMES[i], canvas)
	end
end

-- Preview: a contact sheet of the kit at half size. The screen mocks show
-- the pieces in place.
local preview = Canvas.new(1024, 768, DIRT[1], DIRT[2], DIRT[3], 1)
local x, y, rowH = 8, 8, 0
local function show(canvas, w, h)
	w, h = w / 2, h / 2
	if x + w > 1016 then
		x, y, rowH = 8, y + rowH + 8, 0
	end
	preview:draw(canvas, x, y, w, h)
	x, rowH = x + w + 8, math.max(rowH, h)
end
show(panelInventory, 800, 560)
show(panelResults, 600, 570)
show(headerInventory, 712, 48)
show(bannerStormWarning, 700, 96)
show(plateInventoryGrid, 520, 394)
show(tooltipUpgrade, 340, 190)
show(rowA, 552, 50)
show(rowB, 552, 50)
show(counter, 170, 44)
show(counterSurvivors, 90, 44)
show(counterCalm, 130, 44)
show(counterStorm, 130, 44)
show(counterWarning, 130, 44)
show(counterRaid, 260, 44)
show(normal, BUTTON_W, BUTTON_H)
show(pressed, BUTTON_W, BUTTON_H)
show(menuButton, MENU_SIZE, MENU_SIZE)
show(action, BUTTON_W, BUTTON_H)
show(danger, BUTTON_W, BUTTON_H)
show(input, 300, 48)
ui.preview(preview)
