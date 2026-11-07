-- Tyro Flattino: a flat tyre slumped on its rim, chunky tread blocks round
-- it, its fat sidewalls bulging out where it sags flat on the ground, a
-- rusty steel rim with five lug holes and a valve stem, and a nail still
-- stuck in the top. 2.6 studs tall.
-- include: JunkrotKit
local FACE = { { -0.26, -0.3, 1.7, 0.2 }, { 0.26, -0.3, 1.72, 0.21 } }
local FEET = { 0.9, 0.5 }
local MID = 1.6
part("Tyre", nil, RUBBER_BLACK, function(mesh)
	local m = EditMesh.torus(0.88, 0.36, 32, 10)
	-- Tread: blocks raised on every other face round the outside.
	local tread = m:select("face", "where", function(p)
		local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
		local sector = math.floor((math.deg(math.atan2(p[2], p[1])) % 360) / 11.25)
		return r > 1.1 and math.abs(p[3]) < 0.2 and sector % 2 == 0
	end)
	if tread:count() > 0 then
		m:extrude(tread, 0.06)
	end
	-- Stood up facing us, sagging flat and bulging at the bottom.
	Kit.turn(m, "x", 90)
	m:transform(function(p)
		local sag = math.clamp((-p[3] - 0.85) / 0.4, 0, 1)
		return { p[1] * (1 + 0.12 * sag), p[2] * (1 + 0.3 * sag), math.max(p[3], -1.12) }
	end)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, RUBBER)
part("Rim", nil, RUST_DARK, function(mesh)
	-- A ring of faces round the hub for the lug holes, clear of its middle.
	local m = Kit.lathe({ { 0, -0.22 }, { 0.62, -0.22 }, { 0.66, -0.15 }, { 0.6, 0 }, { 0.62, 0.2 }, { 0.42, 0.21 }, { 0.15, 0.22 }, { 0, 0.22 } }, 20)
	local lugs = m:select("face", "where", function(p)
		local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
		local sector = math.floor((math.deg(math.atan2(p[2], p[1])) % 360) / 18)
		return p[3] > 0.15 and r > 0.15 and r < 0.4 and sector % 4 == 0
	end)
	if lugs:count() > 0 then
		Kit.recess(m, lugs, 0.02, 0.04)
	end
	Kit.turn(m, "x", 90)
	m:translate(0, 0, MID)
	m:emit(mesh)
	Kit.tube({ { -0.3, -0.12, MID - 0.5 }, { -0.36, -0.28, MID - 0.6 } }, 0.04, 6):emit(mesh)
end, 40, 0.85)
part("Nail", nil, BARE_METAL, function(mesh)
	local m = EditMesh.cylinder(0.03, 0.42, 8, 1)
	Kit.turn(m, "y", 12)
	m:translate(0.18, 0, MID + 1.32)
	m:emit(mesh)
	local head = EditMesh.cylinder(0.08, 0.03, 8, 1)
	Kit.turn(head, "y", 12)
	head:translate(0.22, 0, MID + 1.53)
	head:emit(mesh)
end, 40, 0.4)
-- include: JunkrotFace
