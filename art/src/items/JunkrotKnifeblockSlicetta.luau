-- Knifeblock Slicetta: a walnut knife block raked back, five dark slots
-- across its top with the knives' black handles standing out of them like
-- a quiff, fanned a little, each with a steel bolster and cap. 3.5 studs
-- tall.
-- include: JunkrotKit
local FEET = { 0.9, 0.5 }
local BASE = 0.55
local TALL = 2.3
local RAKE = 0.38 -- how far back the block leans per stud up
local function frontY(z)
	return -0.45 + (z - BASE) * RAKE
end
local FACE = { { -0.26, frontY(1.75) - 0.07, 1.75, 0.2 }, { 0.26, frontY(1.77) - 0.07, 1.77, 0.2 } }
-- Leans a piece built upright back with the block.
local function rake(m)
	m:transform(function(p)
		return { p[1], p[2] + (p[3] - BASE) * RAKE, p[3] }
	end)
	return m
end
local KNIVES = { -0.4, -0.2, 0, 0.2, 0.4 }
part("Block", nil, { 0.36, 0.22, 0.13 }, function(mesh)
	local m = Kit.block(1.2, 0.9, TALL, 0.1)
	m:translate(0, 0, BASE + TALL / 2)
	rake(m):emit(mesh)
end, 50, 0.03)
part("Handles", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for index, x in KNIVES do
		local slot = Kit.block(0.16, 0.36, 0.03, 0.01)
		slot:translate(x, (index % 2) * 0.12 - 0.06, BASE + TALL)
		rake(slot):emit(mesh)
		local handle = Kit.block(0.13, 0.28, 0.7, 0.06)
		Kit.turn(handle, "y", x * 25)
		handle:translate(x, (index % 2) * 0.12 - 0.06, BASE + TALL + 0.4)
		rake(handle):emit(mesh)
	end
end, 50, 0)
part("Caps", nil, BARE_METAL, function(mesh)
	-- A bolster at the foot of each handle and a cap on its end, turned
	-- with the handle about its middle.
	for index, x in KNIVES do
		for _, along in { -0.34, 0.36 } do
			local cap = Kit.block(0.14, 0.3, 0.1, 0.04)
			cap:translate(0, 0, along)
			Kit.turn(cap, "y", x * 25)
			cap:translate(x, (index % 2) * 0.12 - 0.06, BASE + TALL + 0.4)
			rake(cap):emit(mesh)
		end
	end
end, 50, 0.03)
part("Honing", nil, BARE_METAL, function(mesh)
	-- A honing steel standing at the back, its ring for hanging on top.
	local rod = Kit.tube({ { -0.45, 0.3, BASE + TALL - 0.1 }, { -0.45, 0.3, BASE + TALL + 1.0 } }, 0.035, 6)
	rake(rod):emit(mesh)
	local ring = EditMesh.torus(0.08, 0.02, 10, 4)
	Kit.turn(ring, "x", 90)
	ring:translate(-0.45, 0.3, BASE + TALL + 1.1)
	rake(ring):emit(mesh)
end, true, 0.03)
-- include: JunkrotFace
