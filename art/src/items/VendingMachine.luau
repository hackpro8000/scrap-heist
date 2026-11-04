-- Vending Machine: a gutted drinks and snacks machine, its window smashed
-- out to a fringe of jagged glass, most of its spiral shelves emptied, and
-- cans, coins and glass spilled on the ground in front. A hollow steel
-- cabinet on levelling feet, a framed front door hinged on the left with a
-- lit header sign, and a control column on the right: display, keypad, coin
-- and note slots, coin return and a T-handle lock. The front faces -y.
-- Centered on the origin.
local CASE = { 0.18, 0.3, 0.55 }
local SIGN_RED = { 0.72, 0.12, 0.1 }
local CREAM = { 0.9, 0.87, 0.78 }
local INTERIOR = { 0.1, 0.1, 0.11 }
local GLASS = { 0.55, 0.7, 0.75 }
local CAN_RED = { 0.62, 0.16, 0.12 }
local CAN_GREEN = { 0.2, 0.45, 0.22 }
local BAG_YELLOW = { 0.85, 0.65, 0.15 }
local BAG_PURPLE = { 0.4, 0.2, 0.5 }
local SCREEN = { 0.06, 0.12, 0.08 }
local NOTE_GREEN = { 0.15, 0.5, 0.25 }
local BRASS = { 0.72, 0.58, 0.28 }

-- Cabinet: x -0.7..0.7, y -0.5..0.5, standing on its plinth at z = 0.14
-- and topping out at z = 2.8.
local HX, HY = 0.7, 0.5
local BASE, TOP = 0.14, 2.8
local SKIN = 0.04
-- The front door, its face at y = -0.5, with the window cut out of it and
-- the control column to the window's right.
local DOOR = 0.06
local FRONT = -HY
local WIN_X0, WIN_X1, WIN_Z0, WIN_Z1 = -0.62, 0.26, 0.62, 2.38
local COLUMN_X0 = 0.34
-- The glass sat in the window just behind the door face.
local GLASS_Y = FRONT + 0.03
-- The delivery bin's opening in the door's bottom rail.
local BIN_X0, BIN_X1, BIN_Z0, BIN_Z1 = -0.55, 0.15, 0.25, 0.5

-- Builds into a mesh whose z axis points along (nx, ny, nz) from (cx, cy, cz),
-- so round and boxed pieces made about "z" at the origin face that way.
local function facing(mesh, cx: number, cy: number, cz: number, nx: number, ny: number, nz: number)
	local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(nx, ny, nz)
	return setmetatable({
		vertex = function(_, x, y, z)
			return mesh:vertex(cx + ux * x + vx * y + tx * z, cy + uy * x + vy * y + ty * z, cz + uz * x + vz * y + tz * z)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

-- A flat shard of glass lying on the ground: an outline anticlockwise seen
-- from above, `thick` tall.
local function lyingShard(mesh, outline, thick: number)
	local low, high = {}, {}
	for i, p in outline do
		low[i] = mesh:vertex(p[1], p[2], 0.002)
		high[i] = mesh:vertex(p[1], p[2], 0.002 + thick)
	end
	local n = #outline
	for i = 1, n do
		local j = i % n + 1
		mesh:face({ low[i], low[j], high[j], high[i] })
	end
	local under = {}
	for i = n, 1, -1 do
		table.insert(under, low[i])
	end
	mesh:face(under)
	mesh:face(high)
end

-- A drinks can standing at (x, y, z): its body, a tapered shoulder, and the
-- rolled rims top and bottom, with the ring pull on top.
local function standingCan(mesh, x: number, y: number, z: number)
	cylinder(mesh, x, y, z + 0.1, 0.055, 0.17, "z", 16)
	cylinder(mesh, x, y, z + 0.19, 0.048, 0.02, "z", 16)
	ring(mesh, x, y, z + 0.2, 0.038, 0.046, 0.008, "z", 16)
	cylinder(mesh, x, y, z + 0.01, 0.048, 0.02, "z", 16)
	box(mesh, x + 0.012, y, z + 0.2, 0.03, 0.016, 0.004)
end

part("Cabinet", nil, CASE, function(mesh)
	-- Sides, back, top and bottom: sheet steel round a hollow box.
	for _, side in { -1, 1 } do
		box(mesh, side * (HX - SKIN / 2), 0, BASE, SKIN, 2 * HY - DOOR, TOP - BASE)
		-- A rolled lip down the front edge of each side, where the door shuts.
		box(mesh, side * (HX - 0.015), FRONT + DOOR + 0.01, BASE, 0.05, 0.02, TOP - BASE)
	end
	box(mesh, 0, HY - SKIN / 2, BASE, 2 * HX - 2 * SKIN, SKIN, TOP - BASE)
	box(mesh, 0, DOOR / 2, TOP - SKIN, 2 * HX, 2 * HY - DOOR, SKIN)
	box(mesh, 0, DOOR / 2, BASE, 2 * HX - 2 * SKIN, 2 * HY - DOOR, SKIN)
	-- A raised drip edge round the top.
	for _, side in { -1, 1 } do
		box(mesh, side * (HX - 0.01), DOOR / 2, TOP, 0.02, 2 * HY - DOOR, 0.025)
	end
	box(mesh, 0, HY - 0.01, TOP, 2 * HX, 0.02, 0.025)
	-- Pressed stiffening ribs up each side and across the back.
	for _, side in { -1, 1 } do
		for _, y in { -0.15, 0.15 } do
			box(mesh, side * (HX + 0.006), y, BASE + 0.15, 0.012, 0.05, TOP - BASE - 0.3)
		end
	end
	for _, x in { -0.35, 0, 0.35 } do
		box(mesh, x, HY + 0.006, BASE + 0.15, 0.05, 0.012, TOP - BASE - 0.3)
	end
end, nil, 0.6, nil, nil, true)

part("Plinth", nil, DARK_STEEL, function(mesh)
	-- A kick plinth set back under the cabinet, and four levelling feet: a
	-- round pad, a threaded stem and a hex nut each.
	box(mesh, 0, 0.03, 0.05, 2 * HX - 0.12, 2 * HY - 0.14, BASE - 0.05)
	for _, x in { -0.6, 0.6 } do
		for _, y in { -0.38, 0.4 } do
			cylinder(mesh, x, y, 0.012, 0.06, 0.024, "z", 16)
			cylinder(mesh, x, y, 0.06, 0.018, 0.08, "z", 10)
			cylinder(mesh, x, y, 0.09, 0.04, 0.03, "z", 6)
		end
	end
	-- Vent louvres low on each side near the back: slats angled down to
	-- shed water, in a pressed frame.
	for _, side in { -1, 1 } do
		local x = side * (HX + 0.012)
		box(mesh, x, 0.22, 0.28, 0.02, 0.4, 0.02)
		box(mesh, x, 0.22, 0.7, 0.02, 0.4, 0.02)
		box(mesh, x, 0.03, 0.28, 0.02, 0.02, 0.44)
		box(mesh, x, 0.41, 0.28, 0.02, 0.02, 0.44)
		for k = 0, 7 do
			local z = 0.33 + k * 0.048
			strut(mesh, x + side * 0.01, 0.05, z + 0.02, x + side * 0.01, 0.39, z + 0.02, 0.012)
			strut(mesh, x + side * 0.02, 0.05, z, x + side * 0.02, 0.39, z, 0.01)
		end
	end
	-- Door hinges down the left edge: knuckles round a pin.
	for _, z in { 0.45, 1.45, 2.45 } do
		cylinder(mesh, -HX - 0.015, FRONT + 0.02, z, 0.025, 0.2, "z", 12)
		cylinder(mesh, -HX - 0.015, FRONT + 0.02, z + 0.11, 0.012, 0.02, "z", 8)
		box(mesh, -HX + 0.01, FRONT + 0.02, z - 0.08, 0.04, 0.012, 0.16)
	end
end, nil, 0.5, nil, nil, true)

part("Door", nil, CASE, function(mesh)
	local y = FRONT + DOOR / 2
	local function slab(x0: number, x1: number, z0: number, z1: number)
		box(mesh, (x0 + x1) / 2, y, z0, x1 - x0, DOOR, z1 - z0)
	end
	-- The frame round the window, the stile between window and column, the
	-- control column, the bottom rail round the bin opening and the header.
	slab(-HX, WIN_X0, BASE, TOP)
	slab(WIN_X1, HX, BASE, BIN_Z0)
	slab(WIN_X1, COLUMN_X0, BIN_Z0, TOP)
	slab(COLUMN_X0, HX, BIN_Z0, TOP)
	slab(WIN_X0, WIN_X1, BASE, BIN_Z0)
	slab(WIN_X0, BIN_X0, BIN_Z0, WIN_Z0)
	slab(BIN_X1, WIN_X1, BIN_Z0, WIN_Z0)
	slab(BIN_X0, BIN_X1, BIN_Z1, WIN_Z0)
	slab(WIN_X0, WIN_X1, WIN_Z1, TOP)
	-- A raised moulding round the window, mitred at the corners.
	local m, d = 0.035, 0.02
	box(mesh, (WIN_X0 + WIN_X1) / 2, FRONT - d / 2, WIN_Z0 - m, WIN_X1 - WIN_X0 + 2 * m, d, m)
	box(mesh, (WIN_X0 + WIN_X1) / 2, FRONT - d / 2, WIN_Z1, WIN_X1 - WIN_X0 + 2 * m, d, m)
	box(mesh, WIN_X0 - m / 2, FRONT - d / 2, WIN_Z0, m, d, WIN_Z1 - WIN_Z0)
	box(mesh, WIN_X1 + m / 2, FRONT - d / 2, WIN_Z0, m, d, WIN_Z1 - WIN_Z0)
	-- A raised panel on the control column, and a kick panel on the rail.
	box(mesh, (COLUMN_X0 + HX) / 2 + 0.005, FRONT - 0.008, 0.6, HX - COLUMN_X0 - 0.07, 0.016, 1.74)
	box(mesh, (WIN_X0 + WIN_X1) / 2, FRONT - 0.008, BASE + 0.02, WIN_X1 - WIN_X0 - 0.04, 0.016, BIN_Z0 - BASE - 0.05)
	-- The header sign's frame.
	box(mesh, 0, FRONT - 0.015, 2.42, 1.3, 0.03, 0.03)
	box(mesh, 0, FRONT - 0.015, 2.74, 1.3, 0.03, 0.03)
	box(mesh, -0.635, FRONT - 0.015, 2.42, 0.03, 0.03, 0.35)
	box(mesh, 0.635, FRONT - 0.015, 2.42, 0.03, 0.03, 0.35)
	-- A dent in the door's bottom rail, kicked in: a pressed hollow ringed
	-- by a raised crease.
	ring(mesh, -0.3, FRONT - 0.004, 0.19, 0.035, 0.05, 0.008, "y", 16)
end, nil, 0.6, nil, nil, true)

part("Gasket", nil, RUBBER_BLACK, function(mesh)
	-- Rubber seal round the inside of the window, where the glass sat.
	local g = 0.015
	box(mesh, (WIN_X0 + WIN_X1) / 2, GLASS_Y, WIN_Z0, WIN_X1 - WIN_X0, 0.03, g)
	box(mesh, (WIN_X0 + WIN_X1) / 2, GLASS_Y, WIN_Z1 - g, WIN_X1 - WIN_X0, 0.03, g)
	box(mesh, WIN_X0 + g / 2, GLASS_Y, WIN_Z0, g, 0.03, WIN_Z1 - WIN_Z0)
	box(mesh, WIN_X1 - g / 2, GLASS_Y, WIN_Z0, g, 0.03, WIN_Z1 - WIN_Z0)
	-- Rubber flap edge on the delivery bin opening.
	box(mesh, (BIN_X0 + BIN_X1) / 2, FRONT + 0.005, BIN_Z0 - 0.01, BIN_X1 - BIN_X0, 0.012, 0.012)
end, nil, 0.2, nil, nil, true)

part("SignPanel", nil, SIGN_RED, function(mesh)
	-- The header sign's backing, set into its frame.
	box(mesh, 0, FRONT - 0.006, 2.45, 1.24, 0.008, 0.29)
end, nil, 0.4, nil, nil, true)

-- "SODA" in raised block letters across the header, from a 5 by 7 grid.
local LETTERS = {
	{ ".###.", "#...#", "#....", ".###.", "....#", "#...#", ".###." },
	{ ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
	{ "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####." },
	{ ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
}
local PIXEL = 0.028
local LETTER_GAP = 0.05
part("Lettering", nil, CREAM, function(mesh)
	local width = #LETTERS * 5 * PIXEL + (#LETTERS - 1) * LETTER_GAP
	local left = -width / 2
	local top = 2.595 + 3.5 * PIXEL
	for l, rows in LETTERS do
		local x0 = left + (l - 1) * (5 * PIXEL + LETTER_GAP)
		for r, row in rows do
			for c = 1, 5 do
				if row:sub(c, c) == "#" then
					box(mesh, x0 + (c - 0.5) * PIXEL, FRONT - 0.016, top - r * PIXEL, PIXEL * 0.92, 0.014, PIXEL * 0.92)
				end
			end
		end
	end
end, nil, 0.3, nil, nil, true)

part("Interior", nil, INTERIOR, function(mesh)
	-- The dark inside: a back wall and side liners behind the window.
	box(mesh, (WIN_X0 + COLUMN_X0) / 2, 0.42, BASE + SKIN, COLUMN_X0 - WIN_X0 + 0.1, 0.02, TOP - BASE - 2 * SKIN)
	box(mesh, WIN_X0 - 0.02, 0, BASE + SKIN, 0.02, 0.84, TOP - BASE - 2 * SKIN)
	box(mesh, COLUMN_X0 + 0.02, 0, BASE + SKIN, 0.02, 0.84, TOP - BASE - 2 * SKIN)
	-- The delivery bin: a sloped chute down to a tray behind the opening.
	box(mesh, (BIN_X0 + BIN_X1) / 2, -0.25, BIN_Z0 - 0.04, BIN_X1 - BIN_X0, 0.42, 0.02)
	local chute = facing(mesh, (BIN_X0 + BIN_X1) / 2, -0.05, 0.55, 0, 0.6, 0.8)
	box(chute, 0, 0, -0.01, BIN_X1 - BIN_X0, 0.45, 0.02)
end, nil, 0.3, nil, nil, true)

-- Shelves: five trays behind the window, each with a price strip along its
-- front edge, four wire spirals that push the stock forward, and the
-- motors that turn them at the back.
local SHELF_ZS = { 0.72, 1.05, 1.38, 1.71, 2.04 }
local SPIRAL_XS = { -0.5, -0.29, -0.08, 0.13 }
local SPIRAL_RADIUS = 0.07
local SPIRAL_TURNS = 7
part("Shelves", nil, STEEL, function(mesh)
	for _, z in SHELF_ZS do
		box(mesh, (WIN_X0 + WIN_X1) / 2, 0, z, WIN_X1 - WIN_X0, 0.8, 0.012)
		-- Dividers between the spiral lanes.
		for k = 1, #SPIRAL_XS - 1 do
			local x = (SPIRAL_XS[k] + SPIRAL_XS[k + 1]) / 2
			box(mesh, x, 0, z + 0.012, 0.008, 0.76, 0.15)
		end
	end
end, nil, 0.3, nil, nil, true)

part("Spirals", nil, BARE_METAL, function(mesh)
	for _, z in SHELF_ZS do
		for _, x in SPIRAL_XS do
			local points = {}
			local steps = SPIRAL_TURNS * 12
			for i = 0, steps do
				local a = i / 12 * TAU
				table.insert(points, { x + math.cos(a) * SPIRAL_RADIUS, -0.38 + 0.74 * i / steps, z + 0.085 + math.sin(a) * SPIRAL_RADIUS })
			end
			tube(mesh, points, 0.008, 5)
		end
	end
end, nil, 0.25, nil, nil, true)

part("Motors", nil, DARK_STEEL, function(mesh)
	for _, z in SHELF_ZS do
		for _, x in SPIRAL_XS do
			box(mesh, x, 0.37, z + 0.03, 0.09, 0.05, 0.11)
			cylinder(mesh, x, 0.34, z + 0.085, 0.02, 0.02, "y", 10)
		end
	end
end, nil, 0.4, nil, nil, true)

part("PriceStrips", nil, CREAM, function(mesh)
	for _, z in SHELF_ZS do
		box(mesh, (WIN_X0 + WIN_X1) / 2, -0.405, z - 0.035, WIN_X1 - WIN_X0, 0.01, 0.045)
		-- A raised label tab under each lane.
		for _, x in SPIRAL_XS do
			box(mesh, x, -0.412, z - 0.028, 0.08, 0.006, 0.03)
		end
	end
end, nil, 0.2, nil, nil, true)

-- What's left of the stock: a few cans standing in the spirals and a few
-- snack bags hanging in them, one knocked crooked.
part("Cans", nil, CAN_RED, function(mesh)
	standingCan(mesh, SPIRAL_XS[1], -0.25, SHELF_ZS[1] + 0.012)
	standingCan(mesh, SPIRAL_XS[1], -0.11, SHELF_ZS[1] + 0.012)
	standingCan(mesh, SPIRAL_XS[3], -0.32, SHELF_ZS[2] + 0.012)
	standingCan(mesh, SPIRAL_XS[4], 0.1, SHELF_ZS[5] + 0.012)
end, nil, 0.4)

part("CansGreen", nil, CAN_GREEN, function(mesh)
	standingCan(mesh, SPIRAL_XS[2], -0.18, SHELF_ZS[1] + 0.012)
	standingCan(mesh, SPIRAL_XS[2], 0.2, SHELF_ZS[4] + 0.012)
end, nil, 0.4)

-- A snack bag: a pillow of foil with crimped seals top and bottom, standing
-- in a spiral, leaning `lean` sideways.
local function snackBag(mesh, x: number, y: number, z: number, lean: number)
	local bag = facing(mesh, x, y, z, math.sin(lean), 0, math.cos(lean))
	box(bag, 0, 0, 0.02, 0.15, 0.035, 0.2)
	box(bag, 0, 0, 0.005, 0.15, 0.014, 0.018)
	box(bag, 0, 0, 0.217, 0.15, 0.014, 0.018)
	box(bag, 0, 0, 0.06, 0.13, 0.045, 0.12)
end
part("Snacks", nil, BAG_YELLOW, function(mesh)
	snackBag(mesh, SPIRAL_XS[4], -0.3, SHELF_ZS[2] + 0.015, 0)
	snackBag(mesh, SPIRAL_XS[1], -0.28, SHELF_ZS[4] + 0.015, 0)
	snackBag(mesh, SPIRAL_XS[3], -0.2, SHELF_ZS[4] + 0.015, math.rad(18))
end, nil, 0.3)

part("SnacksPurple", nil, BAG_PURPLE, function(mesh)
	snackBag(mesh, SPIRAL_XS[2], -0.31, SHELF_ZS[3] + 0.015, 0)
	snackBag(mesh, SPIRAL_XS[2], -0.1, SHELF_ZS[3] + 0.015, 0)
end, nil, 0.3)

-- The control column: a display, a keypad, a coin slot with its reject
-- button, a note acceptor, the coin return cup and the door lock. Each
-- fitting is a plate on the column's raised panel; everything on a plate is
-- placed from the plate's own middle and face, and its screws sit in its
-- corners, so it all lines up.
local COLUMN_X = (COLUMN_X0 + HX) / 2
local PANEL_FACE = FRONT - 0.016
local PLATES = {
	display = { z0 = 2.08, z1 = 2.28, half = 0.13, thick = 0.024 },
	keypad = { z0 = 1.6, z1 = 2.0, half = 0.13, thick = 0.016 },
	coin = { z0 = 1.42, z1 = 1.56, half = 0.13, thick = 0.02 },
	note = { z0 = 1.13, z1 = 1.33, half = 0.13, thick = 0.04 },
	change = { z0 = 0.72, z1 = 0.92, half = 0.11, thick = 0.02 },
}
-- A plate's middle height and the y of its face.
local function plateAt(name: string): (number, number)
	local plate = PLATES[name]
	return (plate.z0 + plate.z1) / 2, PANEL_FACE - plate.thick
end
-- The keypad: three columns by four rows, centred on its plate.
local KEY_PITCH_X, KEY_PITCH_Z = 0.075, 0.085
local function keyAt(row: number, col: number): (number, number)
	local middle = plateAt("keypad")
	return COLUMN_X + col * KEY_PITCH_X, middle + (1.5 - row) * KEY_PITCH_Z
end
local COIN_SLOT_X, REJECT_X = COLUMN_X - 0.03, COLUMN_X + 0.07
-- The lock sits centred on the column between the note acceptor and the
-- coin return.
local LOCK_Z = (PLATES.change.z1 + PLATES.note.z0) / 2

part("Controls", nil, DARK_STEEL, function(mesh)
	for _, plate in PLATES do
		box(mesh, COLUMN_X, PANEL_FACE - plate.thick / 2, plate.z0, 2 * plate.half, plate.thick, plate.z1 - plate.z0)
		-- A security screw in each corner.
		for _, z in { plate.z0 + 0.02, plate.z1 - 0.02 } do
			for _, side in { -1, 1 } do
				cylinder(mesh, COLUMN_X + side * (plate.half - 0.02), PANEL_FACE - plate.thick - 0.004, z, 0.009, 0.008, "y", 8)
			end
		end
	end
	-- Each key's skirt.
	local _, keyFace = plateAt("keypad")
	for row = 0, 3 do
		for col = -1, 1 do
			local x, z = keyAt(row, col)
			box(mesh, x, keyFace - 0.008, z - 0.03, 0.06, 0.016, 0.06)
		end
	end
	-- The coin slot's raised lips either side of it, and the reject
	-- button's collar.
	local coinZ, coinFace = plateAt("coin")
	for _, side in { -1, 1 } do
		box(mesh, COIN_SLOT_X + side * 0.018, coinFace - 0.006, coinZ - 0.04, 0.012, 0.012, 0.08)
	end
	ring(mesh, REJECT_X, coinFace - 0.006, coinZ, 0.022, 0.032, 0.012, "y", 16)
	-- The note acceptor's mouth: a lip sloping out over the slot.
	local noteZ, noteFace = plateAt("note")
	local mouth = facing(mesh, COLUMN_X, noteFace - 0.02, noteZ + 0.035, 0, -0.5, 0.87)
	box(mouth, 0, 0, -0.008, 0.2, 0.05, 0.016)
	-- The coin return's flap, hinged at the top of its cup and swung out.
	local changeZ, changeFace = plateAt("change")
	local flap = facing(mesh, COLUMN_X, changeFace - 0.03, changeZ + 0.005, 0, -0.5, -0.87)
	box(flap, 0, 0, -0.006, 0.13, 0.07, 0.012)
	-- The T-handle lock: its escutcheon, barrel and handle.
	cylinder(mesh, COLUMN_X, PANEL_FACE - 0.008, LOCK_Z, 0.04, 0.016, "y", 16)
	cylinder(mesh, COLUMN_X, PANEL_FACE - 0.041, LOCK_Z, 0.022, 0.05, "y", 16)
	box(mesh, COLUMN_X, PANEL_FACE - 0.07, LOCK_Z - 0.045, 0.03, 0.02, 0.09)
end, nil, 0.45, nil, nil, true)

part("Keys", nil, CREAM, function(mesh)
	local _, keyFace = plateAt("keypad")
	for row = 0, 3 do
		for col = -1, 1 do
			local x, z = keyAt(row, col)
			box(mesh, x, keyFace - 0.022, z - 0.024, 0.048, 0.012, 0.048)
		end
	end
	local coinZ, coinFace = plateAt("coin")
	cylinder(mesh, REJECT_X, coinFace - 0.01, coinZ, 0.02, 0.02, "y", 16)
end, nil, 0.2, nil, nil, true)

part("Screen", nil, SCREEN, function(mesh)
	local z, face = plateAt("display")
	box(mesh, COLUMN_X, face - 0.002, z - 0.07, 0.22, 0.004, 0.14)
end, nil, 0.1, nil, nil, true)

part("Slots", nil, INTERIOR, function(mesh)
	-- The coin slot between its lips, the note slot under its mouth, and the
	-- coin return cup's hollow.
	local coinZ, coinFace = plateAt("coin")
	box(mesh, COIN_SLOT_X, coinFace - 0.002, coinZ - 0.035, 0.016, 0.004, 0.07)
	local noteZ, noteFace = plateAt("note")
	box(mesh, COLUMN_X, noteFace - 0.002, noteZ - 0.007, 0.16, 0.004, 0.014)
	local changeZ, changeFace = plateAt("change")
	box(mesh, COLUMN_X, changeFace - 0.002, changeZ - 0.07, 0.14, 0.004, 0.08)
end, nil, 0.1, nil, nil, true)

part("NoteBezel", nil, NOTE_GREEN, function(mesh)
	-- A green guide strip under the note slot.
	local noteZ, noteFace = plateAt("note")
	box(mesh, COLUMN_X, noteFace - 0.002, noteZ - 0.045, 0.2, 0.004, 0.02)
end, nil, 0.3, nil, nil, true)

part("Lock", nil, BRASS, function(mesh)
	-- The key face on the barrel's end, with its keyway.
	cylinder(mesh, COLUMN_X, PANEL_FACE - 0.07, LOCK_Z, 0.014, 0.008, "y", 12)
	box(mesh, COLUMN_X, PANEL_FACE - 0.075, LOCK_Z - 0.006, 0.004, 0.004, 0.012)
end, nil, 0.4, nil, nil, true)

-- The delivery bin's push flap, hinged along its top edge and swung in.
part("BinFlap", nil, DARK_STEEL, function(mesh)
	local height = BIN_Z1 - BIN_Z0
	local swing = math.rad(30)
	local flap = facing(mesh, (BIN_X0 + BIN_X1) / 2, FRONT + 0.02 + math.sin(swing) * height / 2, BIN_Z1 - math.cos(swing) * height / 2, 0, -math.cos(swing), math.sin(swing))
	box(flap, 0, 0, -0.006, BIN_X1 - BIN_X0 - 0.02, height - 0.01, 0.012)
	-- The hinge rod across the top of the opening.
	cylinder(mesh, (BIN_X0 + BIN_X1) / 2, FRONT + 0.02, BIN_Z1 - 0.005, 0.01, BIN_X1 - BIN_X0, "x", 8)
	-- A pressed "PUSH" bar on the door rail above it.
	box(mesh, (BIN_X0 + BIN_X1) / 2, FRONT - 0.01, BIN_Z1 + 0.03, 0.3, 0.012, 0.03)
end, nil, 0.4, nil, nil, true)

-- What's left of the window glass: jagged shards still held in the gasket
-- round the edges, each outline clockwise seen from the front.
local STUCK_SHARDS = {
	{ { -0.6, 0.63 }, { -0.6, 1.05 }, { -0.52, 0.88 }, { -0.45, 0.95 }, { -0.38, 0.7 }, { -0.2, 0.78 }, { -0.1, 0.63 } },
	{ { 0.25, 2.37 }, { 0.25, 1.9 }, { 0.18, 2.05 }, { 0.1, 1.98 }, { 0.02, 2.2 }, { -0.15, 2.15 }, { -0.25, 2.37 } },
	{ { -0.6, 1.4 }, { -0.6, 1.95 }, { -0.56, 1.7 }, { -0.575, 1.5 } },
	{ { 0, 0.63 }, { 0.05, 0.75 }, { 0.12, 0.68 }, { 0.2, 0.8 }, { 0.25, 0.74 }, { 0.25, 0.63 } },
	{ { -0.6, 2.37 }, { -0.4, 2.37 }, { -0.47, 2.27 }, { -0.55, 2.3 }, { -0.6, 2.15 } },
}
-- Shards fallen in front, each outline anticlockwise seen from above.
local FALLEN_SHARDS = {
	{ { -0.3, -0.75 }, { -0.18, -0.72 }, { -0.24, -0.62 } },
	{ { 0.05, -0.85 }, { 0.2, -0.8 }, { 0.12, -0.7 }, { 0.02, -0.74 } },
	{ { -0.5, -0.65 }, { -0.42, -0.7 }, { -0.4, -0.58 } },
	{ { 0.3, -1.0 }, { 0.38, -0.95 }, { 0.3, -0.9 } },
	{ { -0.1, -1.05 }, { 0.02, -1.02 }, { -0.05, -0.95 } },
	{ { -0.62, -0.9 }, { -0.5, -0.88 }, { -0.56, -0.8 } },
	{ { 0.1, -0.6 }, { 0.2, -0.62 }, { 0.16, -0.54 } },
}
part("Glass", nil, GLASS, function(mesh)
	for _, outline in STUCK_SHARDS do
		plate(mesh, outline, GLASS_Y, 0.012, 0.002)
	end
	for _, outline in FALLEN_SHARDS do
		lyingShard(mesh, outline, 0.01)
	end
end, true, 0)

-- Cans and coins spilled on the ground: two cans on their sides, one
-- stamped flat, and a scatter of coins.
part("Spilled", nil, CAN_RED, function(mesh)
	for _, can in { { 0.2, -0.9, 0.4 }, { -0.4, -1.1, 1.9 } } do
		local dx, dy = math.cos(can[3]), math.sin(can[3])
		local lying = facing(mesh, can[1], can[2], 0.055, dx, dy, 0)
		cylinder(lying, 0, 0, 0, 0.055, 0.17, "z", 16)
		cylinder(lying, 0, 0, 0.095, 0.048, 0.02, "z", 16)
		cylinder(lying, 0, 0, -0.095, 0.048, 0.02, "z", 16)
		ring(lying, 0, 0, 0.105, 0.038, 0.046, 0.008, "z", 16)
	end
	-- Stamped flat: a crumpled disc with its rims splayed.
	cylinder(mesh, -0.05, -0.62, 0.02, 0.075, 0.04, "z", 12)
	ring(mesh, -0.05, -0.62, 0.04, 0.05, 0.068, 0.012, "z", 12)
end, nil, 0.5)

part("Coins", nil, BRASS, function(mesh)
	for _, coin in { { 0.35, -0.7 }, { 0.42, -0.78 }, { 0.3, -0.85 }, { 0.5, -0.66 }, { 0.55, -0.9 }, { 0.46, -0.6 } } do
		cylinder(mesh, coin[1], coin[2], 0.004, 0.025, 0.006, "z", 12)
	end
end, nil, 0.3)

-- The power cable from the back down to a plug on the ground.
part("PowerCable", nil, RUBBER_BLACK, function(mesh)
	tube(mesh, { { 0.5, HY, 0.4 }, { 0.5, HY + 0.08, 0.3 }, { 0.55, HY + 0.15, 0.03 }, { 0.75, HY + 0.3, 0.03 }, { 0.85, HY + 0.32, 0.03 } }, 0.02, 8)
	box(mesh, 0.9, HY + 0.32, 0.005, 0.1, 0.06, 0.05)
	box(mesh, 0.5, HY + 0.012, 0.36, 0.08, 0.024, 0.08)
end, nil, 0.3, nil, nil, true)

finishParts()
