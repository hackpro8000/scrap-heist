-- Typewritto Clackini: a typewriter in fresh teal, a rounded body whose
-- front slopes down in a bank of round keys in four rows, a long space bar,
-- the black platen roller across the back with its knobs, a sheet of paper
-- standing out of it and the carriage return lever. 2.8 studs tall.
-- include: JunkrotKit
local FACE = { { -0.36, -0.12, 1.5, 0.18 }, { 0.36, -0.12, 1.52, 0.18 } }
local FEET = { 1.2, 0.5 }
local TEAL = { 0.16, 0.56, 0.58 }
local BASE = 0.55
-- The top of the body at y: level at the back, sloping down to the front.
local function topZ(y)
	local front = math.clamp(-y / 0.85, 0, 1)
	return BASE + 0.9 - front * 0.65 * 0.55
end
part("Body", nil, TEAL, function(mesh)
	local m = Kit.block(2.3, 1.7, 0.9, 0.22, { 3, 4, 1 })
	m:transform(function(p)
		local front = math.clamp(-p[2] / 0.85, 0, 1)
		return { p[1], p[2], p[3] - front * math.max(0, p[3] + 0.2) * 0.55 }
	end)
	m:translate(0, 0, BASE + 0.45)
	m:emit(mesh)
end, 50, 0.15)
part("Keys", nil, { 0.93, 0.9, 0.82 }, function(mesh)
	for row = 0, 3 do
		local y = -0.72 + row * 0.16
		for k = 0, 7 do
			local key = EditMesh.cylinder(0.065, 0.05, 8, 1)
			key:translate(-0.7 + k * 0.2 + (row % 2) * 0.05, y, topZ(y) + 0.06)
			key:emit(mesh)
		end
	end
	local space = Kit.block(0.9, 0.08, 0.05, 0.02)
	space:translate(0, -0.84, topZ(-0.84) + 0.04)
	space:emit(mesh)
end, 40, 0.05)
part("Roller", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	local m = EditMesh.cylinder(0.18, 2.0, 16, 1)
	Kit.turn(m, "y", 90)
	m:translate(0, 0.55, BASE + 1.05)
	m:emit(mesh)
end, true, RUBBER)
part("Paper", nil, { 0.96, 0.95, 0.9 }, function(mesh)
	local m = Kit.plate({ { -0.65, 0 }, { 0.65, 0 }, { 0.65, 0.95 }, { -0.65, 0.95 } }, 0.02)
	Kit.turn(m, "x", -12)
	m:translate(0, 0.62, BASE + 1.1)
	m:emit(mesh)
end, 40, 0, nil, nil, true)
part("Lever", nil, BARE_METAL, function(mesh)
	for _, side in { -1, 1 } do
		local knob = Kit.lathe({ { 0, 0 }, { 0.15, 0 }, { 0.15, 0.12 }, { 0, 0.14 } }, 12)
		Kit.turn(knob, "y", side * 90)
		knob:translate(side * 1.0, 0.55, BASE + 1.05)
		knob:emit(mesh)
	end
	Kit.tube({ { -1.05, 0.45, BASE + 1.15 }, { -1.3, 0.2, BASE + 1.3 }, { -1.42, -0.1, BASE + 1.25 } }, 0.035, 6):emit(mesh)
end, true, 0.05)
part("Spools", nil, { 0.12, 0.12, 0.13 }, function(mesh)
	for _, x in { -0.65, 0.65 } do
		local spool = EditMesh.cylinder(0.18, 0.06, 12, 1)
		spool:translate(x, 0.15, BASE + 0.93)
		spool:emit(mesh)
	end
end, true, RUBBER)
-- include: JunkrotFace
