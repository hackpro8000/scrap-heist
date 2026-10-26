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
	canvas:bevel(shape, 6, lighter(color, 0.6), darker(color, 0.65), 0.9)
	canvas:rim(shape, 3.5, INK)
--	canvas:highlight(shape, lighter(color, 0.75), 3, 1.5)
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

-- Panel: the window's backing, rusty dark steel with corner bolts. It
-- stays dull so the scrap plates bolted onto it carry the layout.
local panel = Canvas.new(128, 128)
paintPlate(panel, plate(4, 4, 124, 124, 1), DARK_STEEL, 0.35)
bolts(panel, { { 16, 16 }, { 112, 16 }, { 16, 112 }, { 112, 112 } })
local PANEL_SLICE = { 28, 28, 28, 28 }
ui.element("Panel", panel, { slice = PANEL_SLICE })

-- Scrap plates: bolted onto a panel to group its content. The metal says
-- how much attention a group gets, from quiet to loud:
--   PlateBacking  near the panel's own steel, for secondary info
--   PlateContent  galvanized, for the main content
--   PlateAction   crate green, behind what the player should do next
--   PlateWarning  hazard stripes, for the one thing that must be seen
local GALVANIZED = { 0.5, 0.53, 0.55 }
local PLATE_SLICE = { 20, 20, 20, 20 }
local function scrapPlate(name, color, rustAmount, hazard)
	local canvas = Canvas.new(96, 96)
	local shape = plate(4, 3, 90, 90, #name)
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
	bolts(canvas, { { 13, 12 }, { 81, 12 }, { 13, 81 }, { 81, 81 } })
	ui.element(name, canvas, { slice = PLATE_SLICE })
	return canvas
end
local plateBacking = scrapPlate("PlateBacking", darker(DARK_STEEL, 0.25), 0.4)
local plateContent = scrapPlate("PlateContent", GALVANIZED, 0.15)
local plateAction = scrapPlate("PlateAction", darker(CRATE_GREEN, 0.1), 0.2)
local plateWarning = scrapPlate("PlateWarning", HAZARD_YELLOW, 0.1, true)

-- Buttons: galvanized steel, warmer on hover, pushed in when pressed.
local function button(name, color, pressed)
	local canvas = Canvas.new(96, 48)
	local shape = plate(3, if pressed then 6 else 3, 93, 45, 7)
	if not pressed then
		canvas:shadow(shape, 0, 5, 1, 0.85)
	end
	paintPlate(canvas, shape, color, 0.12)
	ui.element(name, canvas, { slice = { 16, 16, 16, 16 } })
	return canvas
end
local normal = button("Button", STEEL, false)
button("ButtonHover", lighter(STEEL, 0.25), false)
local pressed = button("ButtonPressed", darker(STEEL, 0.2), true)

-- Action button: crate green, for buy and confirm.
local action = Canvas.new(96, 48)
local actionShape = plate(3, 3, 93, 45, 9)
action:shadow(actionShape, 0, 5, 1, 0.85)
paintPlate(action, actionShape, CRATE_GREEN, 0.15)
ui.element("ButtonAction", action, { slice = { 16, 16, 16, 16 } })

-- Header: hazard tape across a window's title bar.
local header = Canvas.new(128, 40)
local tape = plate(2, 2, 126, 38, 3)
handPaint(header, tape, HAZARD_YELLOW)
header:stripes(tape, HAZARD_YELLOW, RUBBER_BLACK, 12, 45)
header:rust(tape, 0.1, 10, 3)
header:grime(tape, 0.6)
header:bevel(tape, 4, { 1, 0.95, 0.7 }, INK, 0.7)
header:rim(tape, 3.5, INK)
header:highlight(tape, { 1, 0.95, 0.7 }, 3, 1.5)
ui.element("Header", header, { slice = { 12, 12, 12, 12 } })

-- Progress bar: a sunken dirt-dark trough and a hazard-yellow fill.
local trough = Canvas.new(64, 24)
local troughShape = plate(2, 2, 62, 22, 5)
paintPlate(trough, troughShape, darker(DIRT, 0.55), 0)
trough:bevel(troughShape, 5, INK, lighter(DIRT, 0.2), 0.8)
ui.element("BarTrough", trough, { slice = { 10, 10, 10, 10 } })

local fill = Canvas.new(64, 24)
local fillShape = plate(4, 4, 60, 20, 6)
handPaint(fill, fillShape, HAZARD_YELLOW)
fill:highlight(fillShape, { 1, 0.95, 0.7 }, 2, 1.2)
fill:bevel(fillShape, 4, { 1, 0.95, 0.7 }, darker(HAZARD_YELLOW, 0.5), 0.9)
ui.element("BarFill", fill, { slice = { 8, 8, 8, 8 } })

-- Item slots: a recessed square framed in the item's rarity colour.
local function slot(name, color)
	local canvas = Canvas.new(80, 80)
	local frame = plate(3, 3, 77, 77, #name)
	paintPlate(canvas, frame, color, 0.1)
	local well = plate(11, 11, 69, 69, #name + 1)
	handPaint(canvas, well, darker(DARK_STEEL, 0.4))
	canvas:bevel(well, 6, INK, lighter(DARK_STEEL, 0.15), 0.9)
	canvas:rim(well, 3, INK)
	ui.element(name, canvas, { slice = { 20, 20, 20, 20 } })
	return canvas
end
local slots = { slot("Slot", DARK_STEEL) }
for _, rarity in { "Common", "Uncommon", "Rare", "Legendary" } do
	table.insert(slots, slot(`Slot{rarity}`, RARITY[rarity]))
end

-- Danger button: rusty red, for cancel, decline and raid.
local RUST_RED = { 0.66, 0.2, 0.14 }
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
	local canvas = Canvas.new(96, 40)
	paintPlate(canvas, plate(3, 3, 93, 40, #name), color, 0.1)
	ui.element(name, canvas, { slice = { 16, 16, 16, 16 } })
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
	ui.element(name, canvas, { slice = { 14, 14, 14, 14 } })
	return canvas
end
local input = well("InputField", 96, 40, darker(DIRT, 0.55))
local counter = well("Counter", 96, 40, darker(DARK_STEEL, 0.35))

-- Bar fills for health and the storm timer, sharing the trough above.
local function barFill(name, color)
	local canvas = Canvas.new(64, 24)
	local shape = plate(4, 4, 60, 20, #name)
	handPaint(canvas, shape, color)
	canvas:bevel(shape, 4, lighter(color, 0.5), darker(color, 0.5), 0.9)
	ui.element(name, canvas, { slice = { 8, 8, 8, 8 } })
	return canvas
end
local health = barFill("BarFillHealth", { 0.8, 0.22, 0.16 })
local storm = barFill("BarFillStorm", { 0.35, 0.55, 0.9 })

-- Scroll bar: a thin trough and a bolted steel thumb.
local scrollTrack = well("ScrollTrack", 24, 64, darker(DIRT, 0.55))
local scrollThumb = Canvas.new(24, 48)
paintPlate(scrollThumb, plate(3, 3, 21, 45, 4), STEEL, 0.05)
ui.element("ScrollThumb", scrollThumb, { slice = { 10, 10, 10, 10 } })

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

-- List rows for the leaderboard, trade log and results, alternating.
local function row(name, color)
	local canvas = Canvas.new(96, 32)
	paintPlate(canvas, plate(2, 2, 94, 30, #name), color, 0.05)
	ui.element(name, canvas, { slice = { 12, 12, 12, 12 } })
	return canvas
end
local rowA = row("ListRow", darker(DARK_STEEL, 0.1))
local rowB = row("ListRowAlt", lighter(DARK_STEEL, 0.1))

-- Tooltip and tutorial bubble: pale bare metal so dark text reads on it.
local tooltip = Canvas.new(96, 48)
local tooltipShape = plate(3, 3, 93, 45, 12)
tooltip:shadow(tooltipShape, 3, 4, 1, 0.8)
paintPlate(tooltip, tooltipShape, BARE_METAL, 0.05)
ui.element("Tooltip", tooltip, { slice = { 16, 16, 16, 16 } })

-- Banners: hazard stripes across the screen for round phases and raids.
local function banner(name, a, b)
	local canvas = Canvas.new(128, 48)
	local shape = plate(2, 2, 126, 46, #name)
	canvas:shadow(shape, 0, 5, 1, 0.85)
	handPaint(canvas, shape, a)
	canvas:stripes(shape, a, b, 14, -45)
	canvas:grime(shape, 0.5)
	canvas:bevel(shape, 5, lighter(a, 0.5), INK, 0.8)
	canvas:rim(shape, 3.5, INK)
	ui.element(name, canvas, { slice = { 16, 16, 16, 16 } })
	return canvas
end
local bannerStorm = banner("BannerStorm", { 0.35, 0.55, 0.9 }, RUBBER_BLACK)
local bannerRaid = banner("BannerRaid", RUST_RED, RUBBER_BLACK)
local bannerCalm = banner("BannerCalm", CRATE_GREEN, darker(CRATE_GREEN, 0.5))

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
		badge(c, { polygon = { 24, 4, 42, 10, 40, 28, 24, 44, 8, 28, 6, 10 }, wobble = 0.8, seed = 6 }, { 0.35, 0.55, 0.9 })
	end),
	icon("IconAlert", function(c)
		badge(c, { polygon = { 24, 4, 45, 42, 3, 42 }, wobble = 0.8, seed = 7 }, HAZARD_YELLOW)
		c:fill({ rect = { 22, 16, 26, 31 }, radius = 2 }, INK)
		c:fill(disc(24, 36, 2.5, 8), INK)
	end),
	icon("IconTrade", function(c)
		badge(c, { polygon = { 4, 16, 16, 6, 16, 12, 36, 12, 36, 20, 16, 20, 16, 26 }, wobble = 0.6, seed = 9 }, CRATE_GREEN)
		badge(c, { polygon = { 44, 32, 32, 42, 32, 36, 12, 36, 12, 28, 32, 28, 32, 22 }, wobble = 0.6, seed = 10 }, HAZARD_YELLOW)
	end),
	icon("IconTrophy", function(c)
		badge(c, { rect = { 14, 38, 34, 45 }, radius = 2, wobble = 0.5, seed = 11 }, DARK_STEEL)
		badge(c, { polygon = { 10, 5, 38, 5, 36, 20, 28, 28, 27, 38, 21, 38, 20, 28, 12, 20 }, wobble = 0.8, seed = 12 }, RARITY.Legendary)
	end),
	icon("IconCross", function(c)
		badge(c, cross(24, 24, 18, 5, 13), RUST_RED)
	end),
}

-- Preview: the game's screens on one sheet. The HUD across the top, the
-- inventory and trade window, round results, and every small piece.
-- Halftone is painted at final size, after slicing, so dots stay round.
local function sliced(canvas, source, slice, x, y, w, h, color, inset)
	canvas:drawSliced(source, slice, x, y, w, h)
	local i = inset or 4
	canvas:halftone(plate(x + i, y + i, x + w - i, y + h - i, 0), color or INK, 5, 45, 22, 0.03)
	canvas:halftone(plate(x + i, y + i, x + w - i, y + h - i, 0), { 1, 0.95, 0.8 }, 4, 45, 10, 0, true, 0.5)
end
local S16, S12, S8, S14 = { 16, 16, 16, 16 }, { 12, 12, 12, 12 }, { 8, 8, 8, 8 }, { 14, 14, 14, 14 }
local preview = Canvas.new(1024, 768, DIRT[1], DIRT[2], DIRT[3], 1)
preview:halftone({ rect = { 0, 0, 1024, 768 } }, darker(DIRT, 0.3), 10, 45, 1, 0.08)

-- HUD: scrap counter and health left, round banner and timer centre,
-- survivors right, raid alert under it.
sliced(preview, counter, S14, 20, 20, 180, 48, INK, 4)
preview:draw(icons[1], 12, 14, 56, 56)
sliced(preview, trough, { 10, 10, 10, 10 }, 20, 76, 200, 26, INK, 3)
sliced(preview, health, S8, 20, 76, 140, 26, { 0.4, 0.1, 0.08 }, 5)
sliced(preview, bannerStorm, S16, 362, 14, 300, 56, INK, 6)
sliced(preview, trough, { 10, 10, 10, 10 }, 392, 76, 240, 22, INK, 3)
sliced(preview, storm, S8, 392, 76, 160, 22, { 0.15, 0.25, 0.45 }, 5)
sliced(preview, counter, S14, 844, 20, 160, 48, INK, 4)
preview:draw(icons[3], 836, 14, 56, 56)
sliced(preview, bannerRaid, S16, 734, 80, 270, 48, INK, 6)
preview:draw(icons[5], 740, 80, 48, 48)

-- Inventory and trade window.
preview:shadow(plate(20, 150, 600, 748, 0), 8, 10, 1, 0.75)
sliced(preview, panel, PANEL_SLICE, 20, 150, 580, 598, darker(DARK_STEEL, 0.55), 6)
sliced(preview, header, S12, 40, 168, 490, 40)
preview:draw(close, 542, 168, 40, 40)
preview:draw(icons[6], 260, 164, 48, 48)
sliced(preview, tabActive, S16, 40, 218, 120, 40, darker(GALVANIZED, 0.55))
sliced(preview, tabIdle, S16, 164, 218, 120, 40, INK)
sliced(preview, tabIdle, S16, 288, 218, 120, 40, INK)
for side = 0, 1 do
	local y = 262 + side * 196
	local back = if side == 0 then plateContent else plateBacking
	sliced(preview, back, PLATE_SLICE, 38, y, 504, 186, darker(GALVANIZED, 0.55), 6)
	for i = 0, 7 do
		local x, sy = 54 + (i % 4) * 92, y + 14 + (i // 4) * 82
		local s = slots[(i + side) % #slots + 1]
		preview:draw(s, x, sy, 78, 78)
		preview:halftone(plate(x + 11, sy + 11, x + 67, sy + 67, 0), INK, 4, 45, 30, 0.1)
	end
	preview:draw(if side == 0 then checkOn else checkOff, 432, y + 20, 40, 40)
	sliced(preview, scrollTrack, S14, 506, y + 14, 24, 158, INK, 3)
	sliced(preview, scrollThumb, { 10, 10, 10, 10 }, 506, y + 20, 24, 60, darker(STEEL, 0.55), 3)
end
sliced(preview, danger, S16, 40, 664, 170, 60, darker(RUST_RED, 0.55))
sliced(preview, action, S16, 370, 664, 210, 60, darker(CRATE_GREEN, 0.55))
sliced(preview, input, S14, 222, 672, 136, 44, INK, 4)

-- Round results.
preview:shadow(plate(620, 150, 1004, 500, 0), 8, 10, 1, 0.75)
sliced(preview, panel, PANEL_SLICE, 620, 150, 384, 350, darker(DARK_STEEL, 0.55), 6)
sliced(preview, bannerCalm, S16, 640, 168, 344, 48, INK, 6)
preview:draw(icons[7], 788, 168, 48, 48)
for i = 0, 4 do
	sliced(preview, if i % 2 == 0 then rowA else rowB, S12, 640, 226 + i * 38, 344, 34, INK, 3)
	preview:draw(slots[i + 1], 646, 229 + i * 38, 28, 28)
end
sliced(preview, normal, S16, 640, 424, 160, 56, darker(STEEL, 0.55))
sliced(preview, action, S16, 816, 424, 168, 56, darker(CRATE_GREEN, 0.55))

-- Small pieces: tooltip, buttons in each state, warning plate and icons.
sliced(preview, tooltip, S16, 620, 516, 220, 64, darker(BARE_METAL, 0.5))
preview:draw(icons[8], 854, 524, 48, 48)
sliced(preview, plateWarning, PLATE_SLICE, 916, 516, 88, 64)
sliced(preview, normal, S16, 620, 594, 120, 48, darker(STEEL, 0.55))
sliced(preview, pressed, S16, 750, 594, 120, 48, darker(STEEL, 0.65), 7)
preview:draw(checkOff, 884, 598, 40, 40)
preview:draw(checkOn, 934, 598, 40, 40)
for i, canvas in icons do
	preview:draw(canvas, 616 + (i - 1) * 48, 660, 46, 46)
end
sliced(preview, trough, { 10, 10, 10, 10 }, 620, 716, 384, 22, INK, 3)
sliced(preview, fill, S8, 620, 716, 250, 22, darker(HAZARD_YELLOW, 0.5), 5)
ui.preview(preview)
