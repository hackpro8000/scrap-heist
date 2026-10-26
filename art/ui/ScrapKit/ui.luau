-- ScrapKit: the game's UI skin, painted in the same brushed hand-painted
-- style as the models. Rusty dark steel panels, galvanized buttons, hazard
-- stripes and rarity-coloured frames. Text stays with Roblox fonts.
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local STEEL = { 0.7, 0.72, 0.74 }
local BARE_METAL = { 0.74, 0.73, 0.7 }
local HAZARD_YELLOW = { 0.9, 0.72, 0.12 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local CRATE_GREEN = { 0.3, 0.6, 0.22 }
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

-- Every plate shares one silhouette: the same corner and the same hand
-- wobble, so the kit reads as one set. Only the paint varies.
local CORNER = 10
local function plate(x0, y0, x1, y1, seed)
	return { rect = { x0, y0, x1, y1 }, radius = CORNER, wobble = 2.5, seed = seed }
end

-- Visible strokes over a flat fill, so every surface looks hand painted.
local function handPaint(canvas, shape, color)
	canvas:fill(shape, color)
	canvas:brushwork(shape, 1.2, 1.6, 30, "drag")
end

-- A painted metal plate: fill, brushwork, bevel and an inked rim.
local function paintPlate(canvas, shape, color, rustAmount)
	handPaint(canvas, shape, color)
	if rustAmount > 0 then
		canvas:rust(shape, rustAmount, 16, shape.seed)
	end
	canvas:bevel(shape, 6, lighter(color, 0.7), darker(color, 0.75), 1)
	canvas:rim(shape, 3.5, INK)
	canvas:highlight(shape, lighter(color, 0.75), 3, 1.5)
end

local function bolts(canvas, points)
	for i, p in points do
		local head = { circle = { p[1], p[2], 4 }, wobble = 0.3, seed = i }
		canvas:fill(head, BARE_METAL)
		canvas:bevel(head, 3, { 1, 1, 0.95 }, DARK_STEEL, 1)
		canvas:rim(head, 2, INK)
		canvas:highlight(head, { 1, 1, 0.95 }, 2, 1)
	end
end

-- Every element is painted at the size the game shows it and stretched
-- as-is, with no 9-slice, so the big pieces get one element per screen.

-- Bolts sit a fixed distance in from each corner of a w by h plate.
local function cornerBolts(canvas, w, h, inset)
	bolts(canvas, { { inset, inset }, { w - inset, inset }, { inset, h - inset }, { w - inset, h - inset } })
end

-- Panels: a window's backing, rusty dark steel with corner bolts. They
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
local GALVANIZED = { 0.8, 0.79, 0.74 }
local function scrapPlate(name, w, h, color, rustAmount, hazard)
	local canvas = Canvas.new(w, h)
	local shape = plate(4, 3, w - 6, h - 6, #name)
	canvas:shadow(shape, 3, 5, 1, 0.8)
	if hazard then
		handPaint(canvas, shape, HAZARD_YELLOW)
		canvas:stripes(shape, HAZARD_YELLOW, RUBBER_BLACK, 10, -45)
		canvas:rust(shape, rustAmount, 10, shape.seed)
		canvas:grime(shape, 0.5)
		canvas:bevel(shape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
		canvas:rim(shape, 3.5, INK)
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
local BACKING, CONTENT = darker(DARK_STEEL, 0.6), GALVANIZED
local plateInventoryGrid = scrapPlate("PlateInventoryGrid", 520, 394, BACKING, 0.4)
scrapPlate("PlateInventoryDetail", 216, 394, CONTENT, 0.15)
scrapPlate("PlateTradeOffer", 456, 330, BACKING, 0.4)
scrapPlate("PlateTradeWarning", 636, 48, HAZARD_YELLOW, 0.1, true)
scrapPlate("PlateRaidShield", 300, 110, HAZARD_YELLOW, 0.1, true)
scrapPlate("PlateRewards", 552, 110, CONTENT, 0.15)
scrapPlate("PlateTutorial", 560, 150, CONTENT, 0.15)
scrapPlate("PlateShowcase", 240, 330, BACKING, 0.4)

-- Buttons: galvanized steel, warmer on hover, pushed in when pressed.
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

-- Headers: hazard tape across a window's title bar, one per window.
local function header(name, w, h)
	local canvas = Canvas.new(w, h)
	local tape = plate(2, 2, w - 2, h - 2, #name)
	handPaint(canvas, tape, HAZARD_YELLOW)
	canvas:stripes(tape, HAZARD_YELLOW, RUBBER_BLACK, 12, 45)
	canvas:rust(tape, 0.1, 10, 3)
	canvas:grime(tape, 0.6)
	canvas:bevel(tape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
	canvas:rim(tape, 3.5, INK)
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
	canvas:rim(well, 3, INK)
	ui.element(name, canvas)
	return canvas
end
local slots = { slot("Slot", DARK_STEEL) }
for _, rarity in { "Common", "Uncommon", "Rare", "Legendary" } do
	table.insert(slots, slot(`Slot{rarity}`, RARITY[rarity]))
end

-- Danger button: rusty red, for cancel, decline and raid.
local RUST_RED = { 0.82, 0.2, 0.12 }
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
	return { polygon = points, wobble = 0.6, seed = seed }
end
local close = Canvas.new(40, 40)
local closeShape = plate(3, 3, 37, 37, 11)
close:shadow(closeShape, 0, 4, 1, 0.85)
paintPlate(close, closeShape, RUST_RED, 0.1)
close:fill(cross(20, 20, 11, 3.5, 2), BARE_METAL)
close:rim(cross(20, 20, 11, 3.5, 2), 1.5, INK)
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
	return { polygon = { 9, 21, 15, 15, 19, 20, 30, 8, 35, 13, 19, 30 }, wobble = 0.6, seed = seed }
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
		canvas:rim(tick(1), 1.5, INK)
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
local ROW_A, ROW_B = darker(DARK_STEEL, 0.55), lighter(DARK_STEEL, 0.2)
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

-- Banners: hazard stripes across the screen for round phases and raids.
local function banner(name, a, b, w, h)
	-- Strokes scale with height, so the slim HUD strip keeps room for stripes.
	local k = math.min(1, h / 56)
	local canvas = Canvas.new(w, h)
	local shape = plate(1, 1, w - 1, h - 1 - 5 * k, #name)
	canvas:shadow(shape, 0, 5 * k, 1, 0.85)
	handPaint(canvas, shape, a)
	canvas:stripes(shape, a, b, 14 * k, -45)
	canvas:grime(shape, 0.5)
	canvas:bevel(shape, 5 * k, lighter(a, 0.5), INK, 0.8)
	canvas:rim(shape, 3.5 * k, INK)
	ui.element(name, canvas)
	return canvas
end
local bannerStormWarning = banner("BannerStormWarning", RUST_RED, RUBBER_BLACK, 700, 96)

-- Icons, 48 square: painted badges for counters, prompts and alerts.
local function icon(name, paint)
	local canvas = Canvas.new(48, 48)
	paint(canvas)
	ui.element(name, canvas)
	return canvas
end
local function badge(canvas, shape, color)
	canvas:shadow(shape, 2, 3, 1, 0.7)
	handPaint(canvas, shape, color)
	canvas:bevel(shape, 4, lighter(color, 0.55), darker(color, 0.6), 0.9)
	canvas:rim(shape, 2.5, INK)
end
local function gear(cx, cy, r0, r1, teeth)
	local points = {}
	for i = 0, teeth * 4 - 1 do
		local a = i / (teeth * 4) * math.pi * 2
		local r = if i % 4 < 2 then r1 else r0
		table.insert(points, cx + math.cos(a) * r)
		table.insert(points, cy + math.sin(a) * r)
	end
	return { polygon = points, wobble = 0.6, seed = teeth }
end
local function disc(x, y, r, seed)
	return { circle = { x, y, r }, wobble = 0.5, seed = seed }
end
local icons = {
	icon("IconScrap", function(c)
		badge(c, gear(24, 24, 15, 21, 8), BARE_METAL)
		c:fill(disc(24, 24, 6, 1), darker(DARK_STEEL, 0.3))
		c:rim(disc(24, 24, 6, 1), 2, INK)
	end),
	icon("IconTimer", function(c)
		badge(c, disc(24, 25, 19, 2), STEEL)
		c:fill(disc(24, 25, 14, 3), lighter(BARE_METAL, 0.4))
		c:fill({ polygon = { 23, 25, 25, 25, 25, 13, 23, 13 } }, INK)
		c:fill({ polygon = { 24, 24, 33, 28, 32, 30, 23, 26 } }, INK)
	end),
	icon("IconBot", function(c)
		c:fill({ rect = { 22, 3, 26, 12 } }, INK)
		badge(c, disc(24, 6, 4, 4), RUST_RED)
		badge(c, { rect = { 7, 11, 41, 43 }, radius = 7, wobble = 1, seed = 5 }, STEEL)
		for _, x in { 17, 31 } do
			c:fill(disc(x, 25, 5, x), INK)
			c:fill(disc(x, 25, 3, x + 1), { 1, 0.4, 0.2 })
		end
		c:fill({ rect = { 15, 34, 33, 37 } }, INK)
	end),
	icon("IconShield", function(c)
		badge(
			c,
			{ polygon = { 24, 4, 42, 10, 40, 28, 24, 44, 8, 28, 6, 10 }, wobble = 0.8, seed = 6 },
			{ 0.35, 0.55, 0.9 }
		)
	end),
	icon("IconAlert", function(c)
		badge(c, { polygon = { 24, 4, 45, 42, 3, 42 }, wobble = 0.8, seed = 7 }, HAZARD_YELLOW)
		c:fill({ rect = { 22, 16, 26, 31 }, radius = 2 }, INK)
		c:fill(disc(24, 36, 2.5, 8), INK)
	end),
	icon("IconTrade", function(c)
		badge(
			c,
			{ polygon = { 4, 16, 16, 6, 16, 12, 36, 12, 36, 20, 16, 20, 16, 26 }, wobble = 0.6, seed = 9 },
			CRATE_GREEN
		)
		badge(
			c,
			{ polygon = { 44, 32, 32, 42, 32, 36, 12, 36, 12, 28, 32, 28, 32, 22 }, wobble = 0.6, seed = 10 },
			HAZARD_YELLOW
		)
	end),
	icon("IconTrophy", function(c)
		badge(c, { rect = { 14, 38, 34, 45 }, radius = 2, wobble = 0.5, seed = 11 }, DARK_STEEL)
		badge(
			c,
			{ polygon = { 10, 5, 38, 5, 36, 20, 28, 28, 27, 38, 21, 38, 20, 28, 12, 20 }, wobble = 0.8, seed = 12 },
			RARITY.Legendary
		)
	end),
	icon("IconCross", function(c)
		badge(c, cross(24, 24, 18, 5, 13), RUST_RED)
	end),
	icon("IconStorm", function(c)
		badge(c, { rect = { 3, 6, 45, 30 }, radius = 11, wobble = 0.8, seed = 14 }, BARE_METAL)
		badge(c, { polygon = { 22, 20, 36, 20, 29, 30, 36, 30, 16, 46, 21, 34, 14, 34 }, wobble = 0.5, seed = 15 }, HAZARD_YELLOW)
	end),
	icon("IconCalm", function(c)
		badge(c, { polygon = { 24.0, 2.0, 29.7, 10.1, 39.6, 8.4, 37.9, 18.3, 46.0, 24.0, 37.9, 29.7, 39.6, 39.6, 29.7, 37.9, 24.0, 46.0, 18.3, 37.9, 8.4, 39.6, 10.1, 29.7, 2.0, 24.0, 10.1, 18.3, 8.4, 8.4, 18.3, 10.1 }, wobble = 0.5, seed = 16 }, HAZARD_YELLOW)
		badge(c, { circle = { 24, 24, 11 }, wobble = 0.5, seed = 17 }, BARE_METAL)
	end),
}

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
