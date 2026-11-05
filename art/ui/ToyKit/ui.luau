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

-- Every plate shares one silhouette: round corners and crisp, exact
-- outlines with no wobble. Only the colour inside is hand painted.
-- Nested frames are concentric: a frame set `pad` pixels inside another
-- gets the outer radius less `pad`, so the gap between them stays even
-- round the corners. Windows run PANEL_RADIUS, the frames on them
-- PLATE_RADIUS (16px in), and frames on a plate or card less again.
local CORNER = 16
local PANEL_RADIUS = 28
local PLATE_RADIUS = 12
-- Every outline is drawn at the HUD planks' 2.5px, so a window and the
-- scrap plank wear the same ink.
local INK_W = 2.5
local function plate(x0, y0, x1, y1, seed, radius)
	return {
		rect = { x0, y0, x1, y1 },
		radius = math.min(radius or CORNER, (x1 - x0) / 2, (y1 - y0) / 2),
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
	canvas:outline(shape, INK_W, INK)
	canvas:highlight(shape, lighter(color, 0.85), 5, 2.5)
end

local function bolts(canvas, points)
	for i, p in points do
		local head = { circle = { p[1], p[2], 4 }, wobble = 0, seed = i }
		canvas:fill(head, BARE_METAL)
		canvas:bevel(head, 3, { 1, 1, 0.95 }, DARK_STEEL, 1)
		canvas:outline(head, 1.5, INK)
		canvas:highlight(head, { 1, 1, 0.95 }, 2, 1)
	end
end

-- Every element is painted at the size the game shows it and stretched
-- as-is, with no 9-slice, so the big pieces get one element per screen.

-- Bolts sit on the centres of a plate's corner arcs, so each is ringed
-- evenly by the rounded corner and never touches the outline.
local function cornerBolts(canvas, shape)
	local r, k = shape.rect, shape.radius
	bolts(canvas, { { r[1] + k, r[2] + k }, { r[3] - k, r[2] + k }, { r[1] + k, r[4] - k }, { r[3] - k, r[4] - k } })
end

-- Panels: a window's backing, deep navy plastic. They stay dull so the
-- plates on them carry the layout; the plates and header cover the corners,
-- so panels carry no bolts of their own. Each is sized to its window's
-- content: a 16px pad inside its outline (20px from the image edge).
local function panel(name, w, h)
	local canvas = Canvas.new(w, h)
	paintPlate(canvas, plate(4, 4, w - 4, h - 4, #name, PANEL_RADIUS), DARK_STEEL, 0.35)
	ui.element(name, canvas)
	return canvas
end
local panelInventory = panel("PanelInventory", 764, 533)
panel("PanelShop", 688, 422)
panel("PanelTrade", 960, 526)
local panelResults = panel("PanelResults", 592, 520)
panel("PanelRewards", 592, 540)
panel("PanelTradePick", 380, 380)
panel("PanelSettings", 460, 376)

-- Scrap plates: bolted onto a panel to group its content. The metal says
-- how much attention a group gets, from quiet to loud:
--   backing   near-black, recessed behind grids and lists
--   content   bright bare metal, for the main info
--   hazard    stripes, for the one thing that must be seen
local GALVANIZED = { 0.98, 0.93, 0.8 }
local function scrapPlate(name, w, h, color, rustAmount, hazard)
	local canvas = Canvas.new(w, h)
	local shape = plate(4, 3, w - 6, h - 6, #name, PLATE_RADIUS)
	canvas:shadow(shape, 3, 5, 1, 0.8)
	if hazard then
		handPaint(canvas, shape, HAZARD_YELLOW)
		canvas:stripes(shape, HAZARD_YELLOW, RUBBER_BLACK, 10, -45)
		canvas:bevel(shape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
		canvas:outline(shape, INK_W, INK)
		canvas:highlight(shape, { 1, 0.95, 0.7 }, 3, 1.5)
	else
		paintPlate(canvas, shape, color, rustAmount)
	end
	if h >= 60 then
		cornerBolts(canvas, shape)
	end
	ui.element(name, canvas)
	return canvas
end
-- Backing is near-black so slots and text pop; content is bright bare
-- metal so it stands well clear of the dark panel.
local BACKING, CONTENT = darker(DARK_STEEL, 0.45), GALVANIZED
local plateInventoryGrid = scrapPlate("PlateInventoryGrid", 520, 396, BACKING, 0.4)
scrapPlate("PlateInventoryDetail", 212, 396, CONTENT, 0.15)
scrapPlate("PlateTradeOffer", 464, 270, BACKING, 0.4)
-- The bag strip under both offers, a row of small slots to offer from.
scrapPlate("PlateTradeBag", 930, 108, BACKING, 0.4)
scrapPlate("PlateTradeWarning", 506, 48, HAZARD_YELLOW, 0.1, true)
scrapPlate("PlateRaidShield", 300, 110, HAZARD_YELLOW, 0.1, true)
scrapPlate("PlateRewards", 552, 110, CONTENT, 0.15)
-- One playtime gift per row in the rewards window.
scrapPlate("PlateGift", 552, 68, CONTENT, 0.15)
-- A slim strip above the health bar: step, tip and one button.
scrapPlate("PlateTutorial", 600, 76, CONTENT, 0.15)
scrapPlate("PlateShowcase", 240, 330, BACKING, 0.4)

-- Buttons: sky-blue plastic, brighter on hover, pushed in when pressed.
local BUTTON_W, BUTTON_H = 200, 52
local function button(name, color, pressed, w, h)
	w, h = w or BUTTON_W, h or BUTTON_H
	local canvas = Canvas.new(w, h)
	local shape = plate(3, if pressed then 6 else 3, w - 3, h - 3, 7, if h >= BUTTON_H then 12 else 10)
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
local function actionButton(name, w, h)
	local canvas = Canvas.new(w, h)
	local shape = plate(3, 3, w - 3, h - 3, 9, if h >= BUTTON_H then 12 else 10)
	canvas:shadow(shape, 0, 5, 1, 0.85)
	paintPlate(canvas, shape, CRATE_GREEN, 0.15)
	ui.element(name, canvas)
	return canvas
end
local action = actionButton("ButtonAction", BUTTON_W, BUTTON_H)

-- Buttons come in three sizes, each painted at the size it's shown so the
-- ink and corners stay true: large (above), medium for cards and rows of
-- two, small for a button inside a row.
local MEDIUM_W, MEDIUM_H = 160, 44
local SMALL_W, SMALL_H = 120, 40
button("ButtonMedium", STEEL, false, MEDIUM_W, MEDIUM_H)
actionButton("ButtonActionMedium", MEDIUM_W, MEDIUM_H)
actionButton("ButtonActionSmall", SMALL_W, SMALL_H)
-- Disabled: grey plastic, for a button that can't be pressed yet (confirm
-- before both sides are ready, a gift still counting down).
local GREY = { 0.55, 0.57, 0.62 }
button("ButtonDisabled", GREY, false)
button("ButtonDisabledMedium", GREY, false, MEDIUM_W, MEDIUM_H)
button("ButtonDisabledSmall", GREY, false, SMALL_W, SMALL_H)

-- Headers: orange candy stripes across a window's title bar, one per window,
-- just tall enough for its title and the close button inside its right end.
-- Each sits 16px inside the panel's outline, so its corners run the panel's
-- radius less 16.
local HEADER_H = 40
local function header(name, w)
	local h = HEADER_H
	local canvas = Canvas.new(w, h)
	local tape = plate(2, 2, w - 2, h - 2, #name, PANEL_RADIUS - 16)
	handPaint(canvas, tape, HAZARD_YELLOW)
	canvas:stripes(tape, HAZARD_YELLOW, RUBBER_BLACK, 12, 45)
	canvas:bevel(tape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
	canvas:outline(tape, INK_W, INK)
	canvas:highlight(tape, { 1, 0.95, 0.7 }, 3, 1.5)
	ui.element(name, canvas)
	return canvas
end
-- Each spans its window less 18px either side.
local headerInventory = header("HeaderInventory", 728)
header("HeaderShop", 652)
header("HeaderTrade", 924)
header("HeaderResults", 556)
header("HeaderTradePick", 344)
header("HeaderSettings", 424)

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

-- Troughs for the playtime gifts and the settings sliders. A part-full bar
-- shows its fill clipped, not squeezed, so the rounded ends stay round.
local function bar(name, w, h)
	local canvas = Canvas.new(w, h)
	local shape = plate(2, 2, w - 2, h - 2, #name)
	paintPlate(canvas, shape, darker(DIRT, 0.55), 0)
	canvas:bevel(shape, 5, INK, lighter(DIRT, 0.2), 0.8)
	ui.element("BarTrough" .. name, canvas)
	local strip = Canvas.new(w - 14, h - 14)
	local stripShape = plate(0, 0, w - 14, h - 14, #name + 1)
	handPaint(strip, stripShape, HAZARD_YELLOW)
	strip:highlight(stripShape, { 1, 0.95, 0.7 }, 2, 1.2)
	strip:bevel(stripShape, 4, { 1, 0.95, 0.7 }, darker(HAZARD_YELLOW, 0.5), 0.9)
	ui.element("BarFill" .. name, strip)
end
bar("Gift", 282, 24)
-- The hotbar's health bar spans its six slots: a red fill over a cream
-- trail that drains after a hit.
bar("Hotbar", 376, 28)
do
	local w, h = 376 - 14, 28 - 14
	for name, color in { BarFillHealthHotbar = { 0.84, 0.23, 0.16 }, BarTrailHotbar = BARE_METAL } do
		local strip = Canvas.new(w, h)
		local shape = plate(0, 0, w, h, #name, 6)
		handPaint(strip, shape, color)
		strip:highlight(shape, lighter(color, 0.5), 2, 1.2)
		strip:bevel(shape, 4, lighter(color, 0.4), darker(color, 0.45), 0.9)
		ui.element(name, strip)
	end
end
bar("Slider", 190, 24)

-- Item slots: a recessed square framed in the item's rarity colour, at
-- three sizes: 80 in the bag, 72 in offers, loot and the daily streak, and
-- 56 in the trade bag strip and gift rows.
local SLOT_RADIUS = { [80] = 12, [72] = 10, [56] = 8 }
local function slot(name, color, size)
	size = size or 80
	local canvas = Canvas.new(size, size)
	local radius = SLOT_RADIUS[size]
	local frame = plate(3, 3, size - 3, size - 3, #name, radius)
	paintPlate(canvas, frame, color, 0.1)
	local inset = math.round(size * 11 / 80)
	local well = plate(inset, inset, size - inset, size - inset, #name + 1, radius - (inset - 3))
	handPaint(canvas, well, darker(DARK_STEEL, 0.4))
	canvas:bevel(well, 6, INK, lighter(DARK_STEEL, 0.15), 0.9)
	canvas:outline(well, INK_W, INK)
	ui.element(name, canvas)
	return canvas
end
local slots = { slot("Slot", DARK_STEEL) }
for _, rarity in { "Common", "Uncommon", "Rare", "Legendary" } do
	table.insert(slots, slot(`Slot{rarity}`, RARITY[rarity]))
end
for size, prefix in { [72] = "SlotMedium", [56] = "SlotSmall" } do
	slot(prefix, DARK_STEEL, size)
	for _, rarity in { "Common", "Uncommon", "Rare", "Legendary" } do
		slot(prefix .. rarity, RARITY[rarity], size)
	end
end
-- The gold ring laid over a selected or rare slot, painted rather than an
-- engine stroke so its ink matches the art.
for size, prefix in { [80] = "Slot", [72] = "SlotMedium", [56] = "SlotSmall" } do
	local canvas = Canvas.new(size, size)
	local ring = plate(1, 1, size - 1, size - 1, size, SLOT_RADIUS[size] + 2)
	-- Outlines draw inside the shape, so a wide gold one leaves the middle clear.
	canvas:outline(ring, 4.5, HAZARD_YELLOW)
	canvas:outline(ring, 1.5, INK)
	ui.element(prefix .. "Glow", canvas)
end

-- Danger button: candy red, for cancel, decline and raid.
local RUST_RED = { 0.95, 0.25, 0.35 }
local danger = button("ButtonDanger", RUST_RED, false)
button("ButtonDangerMedium", RUST_RED, false, MEDIUM_W, MEDIUM_H)

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
-- Sits inside the right end of a window's header, 4px in from its ends,
-- so its corners run the header's radius less 4.
local CLOSE = 32
local close = Canvas.new(CLOSE, CLOSE)
local closeShape = plate(2, 2, CLOSE - 2, CLOSE - 2, 11, 8)
paintPlate(close, closeShape, RUST_RED, 0.1)
close:fill(cross(CLOSE / 2, CLOSE / 2, 9, 3, 2), BARE_METAL)
close:outline(cross(CLOSE / 2, CLOSE / 2, 9, 3, 2), 1.5, INK)
ui.element("ButtonClose", close)

-- Tabs: raised galvanized when chosen, sunk dark steel otherwise.
local function tab(name, color, w, h)
	w, h = w or 156, h or 36
	local canvas = Canvas.new(w, h)
	paintPlate(canvas, plate(3, 3, w - 3, h, #name, 10), color, 0.1)
	ui.element(name, canvas)
	return canvas
end
local tabActive = tab("TabActive", GALVANIZED)
local tabIdle = tab("Tab", darker(DARK_STEEL, 0.2))
-- The leaderboard's Scrap / Raids switch, half its 260px rows each.
tab("TabSmallActive", GALVANIZED, 126, 34)
tab("TabSmall", darker(DARK_STEEL, 0.2), 126, 34)

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
-- Value plates are wooden planks nailed up at the right end, the simulator
-- look: warm grain behind cream numbers, the icon straddling the left end.
local PLANK = { 0.62, 0.4, 0.22 }
-- A painted board: grain, bevel, the HUD's 2.5px ink and edge light. Boards
-- are displays set into the HUD, so they cast no drop shadow.
local function board(canvas, shape, color)
	canvas:fill(shape, color)
	canvas:brushwork(shape, 1.6, 1.1, 0, "dry")
	canvas:bevel(shape, 5, lighter(color, 0.35), darker(color, 0.45), 1)
	canvas:outline(shape, 2.5, INK)
	canvas:edgeHighlight(2.5, 2, 0.7)
	canvas:highlight(shape, lighter(color, 0.6), 3, 1.5)
end
local function nail(canvas, x, y)
	local head = { circle = { x, y, 3.5 }, wobble = 0, seed = 1 }
	canvas:fill(head, darker(DARK_STEEL, 0.2))
	canvas:bevel(head, 2, { 0.6, 0.6, 0.7 }, INK, 1)
	canvas:outline(head, 2.5, INK)
end
local function plank(name, w, h)
	local canvas = Canvas.new(w, h)
	board(canvas, { rect = { 3, 3, w - 3, h - 3 }, radius = 6, wobble = 0.8, seed = #name }, PLANK)
	nail(canvas, w - 14, h / 2)
	ui.element(name, canvas)
	return canvas
end
local counter = plank("Counter", 200, 59)
-- The raid strip's planks: survivors left beside the storm timer.
plank("PlankCount", 92, 44)
plank("PlankTimer", 132, 44)

-- Alert banners: a board with its ends sloping out to a wide foot, red when
-- someone raids your yard and green once it's clear. The hazard icons are
-- separate images laid over each end.
local function alertBanner(name, color, w, h)
	local canvas = Canvas.new(w, h)
	local cut = 14
	board(canvas, { polygon = { 3 + cut, 3, w - 3 - cut, 3, w - 3, h - 3, 3, h - 3 }, wobble = 0.8, seed = #name }, color)
	ui.element(name, canvas)
	return canvas
end
alertBanner("BannerRaid", { 0.82, 0.24, 0.16 }, 300, 50)
alertBanner("BannerClear", { 0.3, 0.66, 0.26 }, 300, 50)

-- A hotbar slot: a dark stained board, square.
local function hotbarSlot(name, size)
	local canvas = Canvas.new(size, size)
	board(canvas, { rect = { 3, 3, size - 3, size - 3 }, radius = 5, wobble = 0.6, seed = #name }, darker(PLANK, 0.5))
	ui.element(name, canvas)
	return canvas
end
hotbarSlot("SlotWood", 56)
-- The held weapon's slot: the same board ringed in cream, painted so the
-- ring matches the art's ink instead of an engine stroke.
do
	local canvas = Canvas.new(56, 56)
	board(canvas, { rect = { 3, 3, 53, 53 }, radius = 5, wobble = 0.6, seed = 16 }, darker(PLANK, 0.5))
	local ring = { rect = { 1, 1, 55, 55 }, radius = 7, wobble = 0, seed = 2 }
	canvas:outline(ring, 4, BARE_METAL)
	canvas:outline(ring, 1.5, INK)
	ui.element("SlotWoodSelected", canvas)
end
-- Round plates top centre, each painted at its HUD width. Survivors is dark
-- like Counter; the timer is tinted by phase, and the raid plate is red, dark
-- enough that the white number still reads.
local counterSurvivors = plank("CounterSurvivors", 90, 44)
local counterCalm = well("CounterCalm", 130, 44, darker(CRATE_GREEN, 0.45))
local counterStorm = well("CounterStorm", 130, 44, darker({ 0.35, 0.55, 0.9 }, 0.45))
local counterWarning = well("CounterWarning", 130, 44, darker(RUST_RED, 0.35))
local counterRaid = well("CounterRaid", 236, 44, darker(RUST_RED, 0.35))

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
-- Sized for the bag grid's four rows; the thumb moves, never stretches.
well("ScrollTrack", 16, 350, darker(DIRT, 0.55))
local scrollThumb = Canvas.new(16, 110)
paintPlate(scrollThumb, plate(2, 3, 14, 107, 4), STEEL, 0.05)
ui.element("ScrollThumb", scrollThumb)

-- Ready check for trades: an empty well, or one holding a green tick.
local function tick(seed)
	return { polygon = { 9, 21, 15, 15, 19, 20, 30, 8, 35, 13, 19, 30 }, wobble = 0, seed = seed }
end
local function checkbox(name, ticked)
	local canvas = Canvas.new(40, 40)
	local frame = plate(3, 3, 37, 37, #name, 10)
	paintPlate(canvas, frame, STEEL, 0.05)
	local inner = plate(9, 9, 31, 31, #name + 1, 4)
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

-- A claimed day in the daily streak: a small green tick pinned to its slot.
local tickBadge = Canvas.new(30, 30)
local badge = { circle = { 15, 15, 12 }, wobble = 0, seed = 3 }
paintPlate(tickBadge, badge, { 0.4, 0.85, 0.3 }, 0)
local smallTick = { polygon = { 8, 15, 11, 12, 14, 15, 21, 8, 24, 11, 14, 21 }, wobble = 0, seed = 4 }
tickBadge:fill(smallTick, BARE_METAL)
tickBadge:outline(smallTick, 1.5, INK)
ui.element("TickBadge", tickBadge)

-- List rows for results and the leaderboard, alternating.
local function row(name, w, h, color)
	local canvas = Canvas.new(w, h)
	paintPlate(canvas, plate(2, 2, w - 2, h - 2, #name, 10), color, 0.05)
	ui.element(name, canvas)
	return canvas
end
local ROW_A, ROW_B = darker(DARK_STEEL, 0.35), lighter(DARK_STEEL, 0.18)
local rowA = row("ResultsRow", 552, 50, ROW_A)
local rowB = row("ResultsRowAlt", 552, 50, ROW_B)
-- The leaderboard's rows hang under its plank, top right of the HUD; your
-- own row is picked out in a warmer steel.
row("LeaderboardRow", 260, 36, ROW_A)
row("LeaderboardRowAlt", 260, 36, ROW_B)
row("LeaderboardRowYou", 260, 36, { 0.42, 0.34, 0.16 })
-- The trade picker: one player per row, with a trade button in it.
row("PlayerRow", 324, 60, ROW_A)
row("PlayerRowAlt", 324, 60, ROW_B)

-- Tooltips over plot pads: pale bare metal so dark text reads on it.
local function tooltip(name, w, h)
	local canvas = Canvas.new(w, h)
	local shape = plate(3, 3, w - 5, h - 6, #name, 12)
	canvas:shadow(shape, 3, 4, 1, 0.8)
	paintPlate(canvas, shape, BARE_METAL, 0.05)
	ui.element(name, canvas)
	return canvas
end
-- Both pad cards share one size, so buying and upgrading look alike.
local tooltipUpgrade = tooltip("TooltipUpgrade", 250, 128)
tooltip("TooltipBuyPad", 250, 128)
-- Cream cards: one shop item each, and an incoming trade request.
tooltip("CardShop", 208, 142)
tooltip("CardTradeRequest", 368, 150)

-- A dark recess behind a shop item's icon, so the icon stands off the cream
-- card. It sits on its own inside the card's padding, not concentric with it.
local previewWell = Canvas.new(72, 72)
local previewShape = plate(2, 2, 70, 70, 13, 10)
handPaint(previewWell, previewShape, darker(DARK_STEEL, 0.3))
previewWell:bevel(previewShape, 6, INK, lighter(DARK_STEEL, 0.2), 0.9)
previewWell:outline(previewShape, INK_W, INK)
ui.element("PreviewWell", previewWell)

-- Stat pips on a shop card: five in a row per stat, lit gold up to its value.
local function pip(name, color)
	local canvas = Canvas.new(16, 12)
	local shape = plate(1, 1, 15, 11, 14, 3)
	canvas:fill(shape, color)
	canvas:bevel(shape, 2, lighter(color, 0.4), darker(color, 0.4), 0.9)
	canvas:outline(shape, 1.5, INK)
	ui.element(name, canvas)
	return canvas
end
local pipOff = pip("StatPip", darker(DARK_STEEL, 0.1))
local pipOn = pip("StatPipOn", HAZARD_YELLOW)

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
	-- Halved so HUD icons share the plank's 2.5px ink on screen. An icon shown
	-- smaller than its art sets `ink` to thicken its strokes to match.
	local ICON_STROKE = 2.5
	-- The HUD shows menu icons at 116px and the scrap bolt at 76px; ink is
	-- scaled by art size over shown size so every outline lands at 2.5px.
	local HUD_INK = 104 / 116
	local BOLT_INK = 104 / 76
	-- The raid strip shows the bot and storm icons at 40px.
	local STRIP_INK = 104 / 40
	-- The raid sign's hazard icons are shown at 76px.
	local HAZARD_INK = 104 / 76
	-- The settings gear sits bottom left at 56px.
	local SETTINGS_INK = 104 / 56
	-- Shop cards show their item's icon at 64px.
	local SHOP_INK = 104 / 64
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
	-- Set while painting a front-on icon (`flat = true`), which skips the tilt.
	local paintingFlat = false
	local function place(shape, ox, oy, s, wobble, seed, box, flat)
		flat = flat or paintingFlat
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
	-- Surface detail (a stripe, a ribbon, a tie) painted onto the top face of
	-- the slab under it, `depth` deep: no sides, ink or shadow of its own, so
	-- it never reads as a separate piece.
	-- A `band` region (a ribbon) keeps its width down the slab's side instead
	-- of spreading with it, so it reads as wrapped round the edge.
	local function withRegion(p, shape, color, band)
		p.regions = p.regions or {}
		table.insert(p.regions, { shape = shape, color = color, band = band })
		return p
	end
	local function decal(shape, color, depth) return { shape = shape, color = color, height = 0, lift = depth, decal = true } end
	-- The gift and its bow as one outline: the bow loops sit on a neck that
	-- joins the ball at x 21..27, then the ball's edge runs round underneath.
	local function giftBody()
		local p = { 21, 13.3, 9, 16, 11, 4, 24, 9, 37, 4, 39, 16, 27, 13.3 }
		local start = math.atan2(13.3 - 29, 27 - 24)
		local finish = math.atan2(13.3 - 29, 21 - 24) + 2 * math.pi
		for k = 1, 23 do
			local a = start + (finish - start) * k / 24
			table.insert(p, 24 + math.cos(a) * 16)
			table.insert(p, 29 + math.sin(a) * 16)
		end
		return { polygon = p }
	end
	-- A thick arc round (24, 24) from angle `from` to `to` (degrees, clockwise
	-- on screen) ending in an arrowhead.
	local function arcArrow(from, to)
		local outer, inner, head = 19.5, 12.5, 20
		local p = {}
		for k = 0, 10 do
			local a = math.rad(from + (to - 10 - from) * k / 10)
			table.insert(p, 24 + math.cos(a) * outer); table.insert(p, 24 + math.sin(a) * outer)
		end
		local b = math.rad(to - 10)
		table.insert(p, 24 + math.cos(b) * (16 + head / 2)); table.insert(p, 24 + math.sin(b) * (16 + head / 2))
		local tip = math.rad(to + 20)
		table.insert(p, 24 + math.cos(tip) * 16); table.insert(p, 24 + math.sin(tip) * 16)
		table.insert(p, 24 + math.cos(b) * (16 - head / 2)); table.insert(p, 24 + math.sin(b) * (16 - head / 2))
		for k = 10, 0, -1 do
			local a = math.rad(from + (to - 10 - from) * k / 10)
			table.insert(p, 24 + math.cos(a) * inner); table.insert(p, 24 + math.sin(a) * inner)
		end
		return { polygon = p }
	end
	-- The sack, its neck and its flared crown as one outline.
	local BAG_CROWN = { polygon = { 13, 4, 24, 10, 35, 4, 31, 14, 17, 14 } }
	local function bagBody()
		local p = { 13, 4, 24, 10, 35, 4, 31, 14, 29, 14, 29, 16.9 }
		local start = math.atan2(16.9 - 31, 29 - 24)
		local finish = math.atan2(16.9 - 31, 19 - 24) + 2 * math.pi
		for k = 1, 23 do
			local a = start + (finish - start) * k / 24
			table.insert(p, 24 + math.cos(a) * 15)
			table.insert(p, 31 + math.sin(a) * 15)
		end
		for _, v in { 19, 16.9, 19, 14, 17, 14 } do table.insert(p, v) end
		return { polygon = p }
	end
	-- A slab whose depth spreads out from under its top face instead of
	-- stacking straight up: each layer is the face pushed out and down by half
	-- the depth left below it, so the side is the same thickness on every
	-- button and a round body keeps a perfectly round outline.
	local function swell(p)
		p.swell = true
		return p
	end
	-- The gift's ribbons on the side of its swelling slab, `below` pixels of
	-- depth under the face: each reaches just to the ball's edge at that depth.
	local function giftRibbonDown(below) return { rect = { 21, 13, 27, 44 + below / 2 } } end
	local function giftRibbonAcross(below) return { rect = { 9.5 - below / 2, 26, 38.5 + below / 2, 32 } } end
	-- How deep the front-on HUD menu buttons are extruded, in pixels.
	local BUTTON_DEPTH = 9
	-- Thread ridges ring the standing shaft, a little proud of it, every few studs up.
	local function threads()
		local list = {}
		for k = 0, 3 do
			table.insert(list, part({ circle = { 24, 30, 6.8 } }, darker(STEEL, 0.3), 1, 9 + k * 3.5))
		end
		return list
	end
	local PURPLE, TAN = { 0.62, 0.36, 0.92 }, { 0.82, 0.62, 0.4 }
	-- A thick arc between two radii, for basket handles.
	local function arc(cx, cy, outer, inner, from, to)
		local p = {}
		for k = 0, 12 do
			local a = math.rad(from + (to - from) * k / 12)
			table.insert(p, cx + math.cos(a) * outer)
			table.insert(p, cy + math.sin(a) * outer)
		end
		for k = 12, 0, -1 do
			local a = math.rad(from + (to - from) * k / 12)
			table.insert(p, cx + math.cos(a) * inner)
			table.insert(p, cy + math.sin(a) * inner)
		end
		return { polygon = p }
	end
	-- A basket handle: an arch between two radii whose legs drop straight down
	-- to `foot`, one outline so it is a single piece.
	local function handle(cx, cy, outer, inner, foot)
		local p = { cx - outer, foot }
		for k = 0, 12 do
			local a = math.rad(180 + 180 * k / 12)
			table.insert(p, cx + math.cos(a) * outer)
			table.insert(p, cy + math.sin(a) * outer)
		end
		table.insert(p, cx + outer); table.insert(p, foot)
		table.insert(p, cx + inner); table.insert(p, foot)
		for k = 12, 0, -1 do
			local a = math.rad(180 + 180 * k / 12)
			table.insert(p, cx + math.cos(a) * inner)
			table.insert(p, cy + math.sin(a) * inner)
		end
		table.insert(p, cx - inner); table.insert(p, foot)
		return { polygon = p }
	end
	local function concat(a, b) for _, v in b do table.insert(a, v) end return a end
	-- A cog's outline: `teeth` flat-topped teeth round a disc.
	local function cogShape(cx, cy, outer, inner, teeth)
		local points = {}
		for i = 0, teeth - 1 do
			local a = i / teeth * math.pi * 2
			local step = math.pi * 2 / teeth
			for _, corner in { { -0.5, inner }, { -0.3, outer }, { 0.05, outer }, { 0.25, inner } } do
				local angle = a + corner[1] * step
				table.insert(points, cx + math.cos(angle) * corner[2])
				table.insert(points, cy + math.sin(angle) * corner[2])
			end
		end
		return { polygon = points }
	end

	-- A shape mirrored top to bottom in the 48 box, for a magnet's arch below its legs.
	local function flipY(shape)
		local p = {}
		for k = 1, #shape.polygon, 2 do
			table.insert(p, shape.polygon[k])
			table.insert(p, 48 - shape.polygon[k + 1])
		end
		return { polygon = p }
	end
	-- Four round leaves about a centre, traced as one outline from the
	-- leaves' outer arcs.
	local function clover()
		local p = {}
		local cx, cy, d, r = 24, 22, 9, 9.5
		for leaf = 0, 3 do
			local a0 = math.rad(leaf * 90 - 45)
			local lx, ly = cx + math.cos(a0) * d * 1.2, cy + math.sin(a0) * d * 1.2
			for k = 0, 12 do
				local a = a0 - math.rad(110) + math.rad(220) * k / 12
				table.insert(p, lx + math.cos(a) * r)
				table.insert(p, ly + math.sin(a) * r)
			end
		end
		return { polygon = p }
	end

	local ICONS = {
		-- Parts: a bolt standing on its hex head, threaded shaft rising out of it.
		{ color = STEEL, focus = 1, raise = 6, ink = BOLT_INK, parts = concat({
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
		{ color = RED, focus = 3, ink = STRIP_INK, parts = {
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
		{ color = ORANGE, focus = 2, ink = HAZARD_INK, parts = {
			part({ polygon = { 24, 3, 46, 43, 2, 43 } }, DARK, 6),
			part({ polygon = { 24, 10, 40, 39, 8, 39 } }, GOLD, 2, 6),
			part({ rect = { 21.5, 17, 26.5, 30 }, radius = 2 }, DARK, 3, 8),
			part({ circle = { 24, 34.5, 2.8 } }, DARK, 3, 8),
		} },
		-- Trade: two fat arrows chasing each other round a circle, front-on.
		{ color = GREEN, flat = true, parts = {
			-- Each head stops 40 degrees short of the other arrow's tail, so the
			-- two never touch.
			swell(part(arcArrow(215, 335), GOLD, BUTTON_DEPTH)),
			swell(part(arcArrow(35, 155), RED, BUTTON_DEPTH)),
		} },
		-- Trophy: a wide gold cup front-on like the menu icons, its handles
		-- thick rings and its foot a wooden plinth, so it carries the same
		-- weight as the raid strip's bot and cloud beside it.
		{ color = GOLD, flat = true, parts = {
			swell(part(arc(11, 15, 8.5, 3.5, 90, 270), GOLD, BUTTON_DEPTH)),
			swell(part(arc(37, 15, 8.5, 3.5, -90, 90), GOLD, BUTTON_DEPTH)),
			swell(part({ rect = { 11, 37, 37, 45 }, radius = 2 }, WOOD, BUTTON_DEPTH)),
			swell(part({ polygon = { 8, 4, 40, 4, 38, 17, 32, 25, 27, 27, 27, 33, 32, 35, 33, 38, 15, 38, 16, 35, 21, 33, 21, 27, 16, 25, 10, 17 } }, GOLD, BUTTON_DEPTH)),
			decal({ rect = { 10, 6, 38, 10 }, radius = 2 }, lighter(GOLD, 0.35), BUTTON_DEPTH),
			decal({ circle = { 24, 17, 4 } }, RED, BUTTON_DEPTH),
		} },
		{ color = RED, focus = 2, parts = {
			part(crossShape(24, 25, 19, 6), RED, 8),
			part({ circle = { 24, 25, 4 } }, STEEL, 2, 8),
		} },
		-- Storm: a tall pale cloud with a fat gold bolt striking out of it, the two
		-- together roughly round so the icon fills its circle. No focus part, so
		-- it centres on the whole model instead of one puff of cloud.
		{ color = STEEL, ink = STRIP_INK, parts = {
			part({ circle = { 13, 20, 10 } }, STEEL, 5), part({ circle = { 25, 13, 12 } }, STEEL, 5),
			part({ circle = { 36, 20, 10 } }, STEEL, 5), part({ rect = { 3, 18, 46, 32 }, radius = 7 }, STEEL, 5),
			part({ polygon = { 21, 24, 35, 24, 29, 33, 37, 33, 15, 48, 21, 37, 13, 37 } }, GOLD, 3, 5),
		} },
		-- Calm: a round sun inside a ring of points.
		{ color = GOLD, focus = 2, parts = {
			part({ polygon = { 24.0, 2.0, 29.7, 10.1, 39.6, 8.4, 37.9, 18.3, 46.0, 24.0, 37.9, 29.7, 39.6, 39.6, 29.7, 37.9, 24.0, 46.0, 18.3, 37.9, 8.4, 39.6, 10.1, 29.7, 2.0, 24.0, 10.1, 18.3, 8.4, 8.4, 18.3, 10.1 } }, ORANGE, 4),
			part({ circle = { 24, 24, 12 } }, GOLD, 3, 4),
		} },
		-- Menu icons are front-on toys, every part the same depth so they read as
		-- one moulded piece. Shop: a red basket under a tall arched handle.
		{ color = RED, flat = true, parts = {
			-- The handle's legs run down behind the rim into the body, so the
			-- two read as one moulded piece.
			swell(part(handle(24, 21, 15, 10.5, 28), RED, BUTTON_DEPTH)),
			-- Rim and bowl are one slab; the rim is only a lighter painted band.
			swell(part({ polygon = { 3, 24, 45, 24, 45, 31, 42, 31, 39, 39, 31, 45, 17, 45, 9, 39, 6, 31, 3, 31 } }, RED, BUTTON_DEPTH)),
			decal({ rect = { 5, 25.5, 43, 29.5 }, radius = 2 }, lighter(RED, 0.25), BUTTON_DEPTH),
			decal({ rect = { 10, 34, 38, 36 } }, darker(RED, 0.35), BUTTON_DEPTH),
		} },
		-- Rewards: a round purple gift crossed by a gold ribbon, bow on top.
		{ color = PURPLE, flat = true, parts = {
			-- One gold slab with the ball's region purple, side and face.
			-- The vertical ribbon carries on down the side and round the bottom.
			swell(withRegion(withRegion(withRegion(part(giftBody(), GOLD, BUTTON_DEPTH), { circle = { 24, 29, 16 } }, PURPLE), giftRibbonDown, GOLD, true), giftRibbonAcross, GOLD, true)),
			decal({ circle = { 24, 29, 16 } }, PURPLE, BUTTON_DEPTH),
			decal({ circle = { 24, 12, 3.5 } }, GOLD, BUTTON_DEPTH),
			decal({ rect = { 21, 13.5, 27, 46 } }, GOLD, BUTTON_DEPTH),
			decal({ rect = { 8.5, 26, 39.5, 32 } }, GOLD, BUTTON_DEPTH),
			decal({ circle = { 24, 12, 2 } }, darker(GOLD, 0.2), BUTTON_DEPTH),
		} },
		-- Bag: a round tan sack tied at the neck, its top flared open.
		{ color = TAN, flat = true, parts = {
			swell(withRegion(part(bagBody(), TAN, BUTTON_DEPTH), BAG_CROWN, lighter(TAN, 0.1))),
			decal(BAG_CROWN, lighter(TAN, 0.1), BUTTON_DEPTH),
			decal({ rect = { 18, 14.5, 30, 18 }, radius = 1.5 }, darker(TAN, 0.3), BUTTON_DEPTH),
		} },
		-- Settings: a steel cog, front-on like the menu icons, a dark hole at its hub.
		{ color = STEEL, flat = true, ink = SETTINGS_INK, parts = {
			swell(part(cogShape(24, 24, 22, 16, 8), STEEL, BUTTON_DEPTH)),
			decal({ circle = { 24, 24, 11 } }, lighter(STEEL, 0.15), BUTTON_DEPTH),
			decal({ circle = { 24, 24, 6 } }, DARK, BUTTON_DEPTH),
		} },
		-- Shop items. Overdrive: a fat gold lightning bolt on a red gauge.
		{ color = GOLD, focus = 2, ink = SHOP_INK, parts = {
			part({ circle = { 24, 26, 19 } }, RED, 5),
			part({ polygon = { 27, 3, 13, 28, 22, 28, 18, 46, 35, 20, 26, 20, 31, 3 } }, GOLD, 4, 5),
		} },
		-- Big crate: a wooden crate, its lid crossed by a darker brace.
		{ color = WOOD, focus = 1, ink = SHOP_INK, parts = {
			part({ rect = { 5, 6, 43, 44 }, radius = 3 }, WOOD, 14),
			decal({ rect = { 9, 10, 39, 40 }, radius = 2 }, lighter(WOOD, 0.15), 14),
			decal({ polygon = { 9, 14, 13, 10, 39, 36, 35, 40 } }, darker(WOOD, 0.3), 14),
			decal({ rect = { 5, 22, 43, 28 } }, darker(WOOD, 0.3), 14),
		} },
		-- Auto collect: a red horseshoe magnet, steel tips up.
		{ color = RED, flat = true, ink = SHOP_INK, parts = {
			swell(part(flipY(handle(24, 24, 18, 8, 42)), RED, BUTTON_DEPTH)),
			decal({ rect = { 6.5, 6, 15.5, 14 } }, STEEL, BUTTON_DEPTH),
			decal({ rect = { 32.5, 6, 41.5, 14 } }, STEEL, BUTTON_DEPTH),
		} },
		-- VIP: a gold crown, three points each tipped with a red gem.
		{ color = GOLD, flat = true, ink = SHOP_INK, parts = {
			swell(part({ polygon = { 4, 14, 15, 24, 24, 6, 33, 24, 44, 14, 40, 40, 8, 40 } }, GOLD, BUTTON_DEPTH)),
			decal({ rect = { 9, 32, 39, 36 } }, darker(GOLD, 0.25), BUTTON_DEPTH),
			decal({ circle = { 24, 26, 3.5 } }, RED, BUTTON_DEPTH),
			decal({ circle = { 14, 30, 2.5 } }, BLUE, BUTTON_DEPTH),
			decal({ circle = { 34, 30, 2.5 } }, BLUE, BUTTON_DEPTH),
		} },
		-- Storm luck: a four-leaf clover on a short stem.
		{ color = GREEN, flat = true, ink = SHOP_INK, parts = {
			swell(part({ polygon = { 22, 30, 26, 30, 30, 46, 26, 46 } }, darker(GREEN, 0.2), BUTTON_DEPTH)),
			swell(part(clover(), GREEN, BUTTON_DEPTH)),
			decal({ circle = { 24, 22, 3 } }, lighter(GREEN, 0.3), BUTTON_DEPTH),
		} },
		-- Scrap heap: three bolts piled on a low mound of scrap.
		{ color = STEEL, focus = 2, ink = SHOP_INK, parts = {
			part({ rect = { 4, 26, 44, 44 }, radius = 9 }, darker(STEEL, 0.35), 4),
			part(hex(15, 30, 9), STEEL, 4, 4),
			part(hex(33, 30, 9), STEEL, 4, 4),
			part(hex(24, 22, 10), STEEL, 4, 8),
			part({ circle = { 24, 22, 4 } }, DARK, 1, 12),
		} },
		-- Scrap mountain: a tall pile of bolts topped with gold.
		{ color = GOLD, focus = 6, ink = SHOP_INK, parts = {
			part({ rect = { 2, 28, 46, 46 }, radius = 9 }, darker(STEEL, 0.35), 4),
			part(hex(11, 34, 8), STEEL, 4, 4),
			part(hex(24, 36, 8), STEEL, 4, 4),
			part(hex(37, 34, 8), STEEL, 4, 4),
			part(hex(17, 26, 8), STEEL, 4, 8), part(hex(31, 26, 8), STEEL, 4, 8),
			part(hex(24, 18, 9), GOLD, 4, 12),
			part({ circle = { 24, 18, 3.5 } }, DARK, 1, 16),
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
	-- Only the silhouette is inked, so parts carry no lines of their own.
	local function paintPart(c, p, ox, oy, scale, i)
		if p.decal then
			local face = place(p.shape, ox, oy - p.lift, scale, 0.7, i)
			paint(c, face, p.color)
			c:highlight(face, lighter(p.color, 0.6), 2, 1.5)
			return
		end
		local function layer(shape, up, keepWidth)
			if not p.swell then return place(shape, ox, oy - up, scale, 0.7, i) end
			local below = p.lift + p.height - up
			local o = place(shape, ox, oy - p.lift - p.height + below / 2, scale, 0.7, i)
			o.grow = if keepWidth then 0 else below / 2
			return o
		end
		local function at(up, _wobble) return layer(p.shape, up) end
		local sideDark, sideLight = darker(p.color, 0.55), darker(p.color, 0.25)
		if p.lift == 0 then c:shadow(at(0, 0.7), 4, 5, 1, 0.55) end
		for k = 0, p.height - 1 do
			local t = k / math.max(p.height - 1, 1)
			c:fill(at(p.lift + k, 0.7), { sideDark[1] + (sideLight[1] - sideDark[1]) * t, sideDark[2] + (sideLight[2] - sideDark[2]) * t, sideDark[3] + (sideLight[3] - sideDark[3]) * t })
		end
		if p.height > 1 then
			local b = SIDE_BRUSH
			for k = 0, p.height - 1 do c:brushwork(at(p.lift + k, 0.7), b[2] / p.height, b[3], b[4], b[1]) end
		end
		-- Regions of one slab whose side shows another colour, like a ball
		-- under its bow: the side is repainted in that colour where it falls.
		for _, region in p.regions or {} do
			local dark, light = darker(region.color, 0.55), darker(region.color, 0.25)
			for k = 0, p.height - 1 do
				local t = k / math.max(p.height - 1, 1)
				local function mix(n) return dark[n] + (light[n] - dark[n]) * t end
				local below = p.lift + p.height - (p.lift + k)
				local shape = if type(region.shape) == "function" then region.shape(below) else region.shape
				c:fill(layer(shape, p.lift + k, region.band), { mix(1), mix(2), mix(3) })
			end
		end
		local top = at(p.lift + p.height, 0.7)
		paint(c, top, p.color)
		c:bevel(top, 4, lighter(p.color, 0.6), darker(p.color, 0.3), 1)
		c:highlight(top, lighter(p.color, 0.85), 3, 2)
	end

	-- Each model is scaled and moved so it sits centred in, and fills most of, a
	-- circle the size of the canvas: the badge or button behind it can be any shape.
	local ICON_SIZE = 104
	local FIT_RADIUS = 43 -- canvas radius minus room for the ink silhouette
	local ICON_NAMES = { "IconScrap", "IconTimer", "IconBot", "IconShield", "IconAlert", "IconTrade", "IconTrophy", "IconCross", "IconStorm", "IconCalm", "IconShop", "IconRewards", "IconBag", "IconSettings", "IconOverdrive", "IconCrate", "IconMagnet", "IconCrown", "IconClover", "IconScrapHeap", "IconScrapMountain" }

	-- Each part's outline at its bottom and top, drawn at scale s from (0, 0).
	local function modelOutlines(icon, s)
		local outlines = {}
		for _, p in icon.parts do
			for _, up in (if p.decal then {} else { p.lift, p.lift + p.height }) do
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
	-- The square side every front-on icon's area matches.
	local FLAT_SIDE = 74
	local function fitInCircle(icon)
		-- Front-on menu icons are sized by area instead, so a wide icon and a
		-- tall one take up the same space on the HUD; the longest side still
		-- fits the square.
		if icon.flat then
			local s = 1.75
			local x0, y0, x1, y1
			for _ = 1, 4 do
				x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
				for _, poly in modelOutlines(icon, s) do
					for k = 1, #poly, 2 do
						x0, x1 = math.min(x0, poly[k]), math.max(x1, poly[k])
						y0, y1 = math.min(y0, poly[k + 1]), math.max(y1, poly[k + 1])
					end
				end
				local w, h = x1 - x0, y1 - y0
				s *= math.min(FLAT_SIDE / math.sqrt(w * h), 2 * FIT_RADIUS / math.max(w, h))
			end
			return s, ICON_SIZE / 2 - (x0 + x1) / 2, ICON_SIZE / 2 - (y0 + y1) / 2
		end
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

	local function paintIcon(i, name, ink)
		local icon = ICONS[i]
		local canvas = Canvas.new(ICON_SIZE, ICON_SIZE)
		paintingFlat = icon.flat == true
		local scale, ox, oy = fitInCircle(icon)
		for _, p in icon.parts do paintPart(canvas, p, ox, oy, scale, i) end
		-- One ink line round the whole model's outer edge, none between its parts.
		canvas:inkEdge(ICON_STROKE * ink, INK)
		-- A light catch just inside the ink on the edges facing the light.
		canvas:edgeHighlight(ICON_STROKE * ink, 2 * ink, 0.9)
		ui.element(name, canvas)
	end
	for i, icon in ICONS do
		paintIcon(i, ICON_NAMES[i], icon.ink or HUD_INK)
	end
	-- The same models painted again for another size on screen, so their ink
	-- still lands at 2.5px: window title icons at 28px, the leaderboard's
	-- trophy at 40px beside the raid strip's icons, and shop cards at 64px.
	local VARIANTS = {
		{ "IconBag", 28 }, { "IconShop", 28 }, { "IconTrade", 28 }, { "IconTrophy", 28 },
		{ "IconRewards", 28 }, { "IconSettings", 28 },
		{ "IconTrophy", 40 },
		{ "IconScrap", 64 }, { "IconShield", 64 },
	}
	for _, variant in VARIANTS do
		local i = table.find(ICON_NAMES, variant[1])
		paintIcon(i, variant[1] .. variant[2], 104 / variant[2])
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
show(panelInventory, 764, 533)
show(panelResults, 592, 520)
show(headerInventory, 728, 40)
show(bannerStormWarning, 700, 96)
show(plateInventoryGrid, 520, 396)
show(tooltipUpgrade, 250, 128)
show(rowA, 552, 50)
show(rowB, 552, 50)
show(counter, 170, 44)
show(counterSurvivors, 90, 44)
show(counterCalm, 130, 44)
show(counterStorm, 130, 44)
show(counterWarning, 130, 44)
show(counterRaid, 236, 44)
show(normal, BUTTON_W, BUTTON_H)
show(pressed, BUTTON_W, BUTTON_H)
show(menuButton, MENU_SIZE, MENU_SIZE)
show(action, BUTTON_W, BUTTON_H)
show(danger, BUTTON_W, BUTTON_H)
show(input, 300, 48)
show(close, CLOSE, CLOSE)
show(tabActive, 156, 36)
show(tabIdle, 156, 36)
show(previewWell, 72, 72)
show(pipOn, 16, 12)
show(pipOff, 16, 12)
ui.preview(preview)
