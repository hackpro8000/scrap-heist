-- Canetto Rustini: a rusty tin can with rolled beads round its rim and
-- base and three ribs round its middle, opened, the jagged lid bent up off
-- the back of the rim like a cap, and its red label torn away down one
-- side. 2.7 studs tall.
-- include: JunkrotKit
local FACE = { { -0.26, -0.66, 1.85, 0.22 }, { 0.26, -0.66, 1.88, 0.23 } }
local FEET = { 0.8, 0.6 }
local BASE = 0.62
local TALL = 1.56
part("Can", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({
		{ 0, 0.02 },
		{ 0.6, 0 },
		{ 0.67, 0.05 },
		{ 0.64, 0.12 },
		{ 0.63, 0.35 },
		{ 0.66, 0.4 },
		{ 0.63, 0.45 },
		{ 0.63, 0.7 },
		{ 0.66, 0.75 },
		{ 0.63, 0.8 },
		{ 0.63, 1.05 },
		{ 0.66, 1.1 },
		{ 0.63, 1.15 },
		{ 0.63, 1.45 },
		{ 0.68, 1.52 },
		{ 0.65, TALL },
		{ 0.6, 1.5 },
		{ 0, 1.42 },
	}, 24)
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, 40, 0.9)
part("Label", nil, { 0.72, 0.2, 0.16 }, function(mesh)
	-- Wrapped most of the way round; torn off down the rest.
	local m = EditMesh.spin({ { 0.672, 0.48 }, { 0.672, 0.66 }, { 0.672, 0.84 }, { 0.672, 1.02 } }, 24, 290)
	m:solidify(0.015)
	Kit.turn(m, "z", 125)
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, 40, 0.6)
part("Lid", nil, RUST_ORANGE, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.6, 0 }, { 0.6, 0.04 }, { 0, 0.04 } }, 20)
	-- The torn edge: the rim pulled in and out unevenly.
	m:transform(function(p)
		local a = math.atan2(p[2], p[1])
		local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
		local f = if r > 0.3 then 1 + 0.06 * math.sin(a * 7) + 0.04 * math.sin(a * 13) else 1
		return { p[1] * f, p[2] * f, p[3] }
	end)
	-- Hinged on the back of the rim and bent up.
	m:translate(0, -0.6, 0)
	Kit.turn(m, "x", -65)
	m:translate(0, 0.6, BASE + TALL - 0.02)
	m:emit(mesh)
end, 40, 0.85)
-- include: JunkrotFace
