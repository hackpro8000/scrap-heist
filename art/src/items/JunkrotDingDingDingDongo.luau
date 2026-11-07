-- Ding Ding Ding Dongo: a snail whose shell is a chrome bicycle bell: a
-- soft green body gliding on its flat foot, tapering to a point behind,
-- its head up with two eyes out on stalks and two feelers below them; the
-- bell dome on its back facing us on its black base, the thumb lever
-- cocked to ring. No googly face and no legs: it glides. 2.9 studs tall.
-- include: JunkrotKit
local SNAIL = { 0.56, 0.62, 0.5 }
local SHELL = { -0.35, -0.05, 1.12 } -- the bell dome's middle
part("Body", nil, SNAIL, function(mesh)
	local path = Kit.curve({ { -1.35, 0, 0.16 }, { -0.7, 0, 0.26 }, { 0.15, 0, 0.32 }, { 0.75, 0, 0.55 }, { 0.98, 0, 1.05 }, { 1.0, 0, 1.4 } }, 4)
	local m = Kit.tube(path, function(t)
		local swell = 0.12 + 0.3 * math.sin(math.min(t, 0.75) / 0.75 * math.pi * 0.5)
		return swell - (if t > 0.75 then (t - 0.75) * 0.3 else 0)
	end, 12)
	-- Flat underneath: the foot it glides on.
	m:transform(function(p)
		return { p[1], p[2] * 1.15, math.max(p[3], 0.02) }
	end)
	m:emit(mesh)
	-- Eye stalks and feelers.
	for _, side in { -1, 1 } do
		Kit.tube({ { 1.0, side * 0.12, 1.62 }, { 1.06, side * 0.22, 1.98 }, { 1.12, side * 0.3, 2.28 } }, function(t)
			return 0.055 - 0.02 * t
		end, 8):emit(mesh)
		Kit.tube({ { 1.12, side * 0.1, 1.42 }, { 1.28, side * 0.15, 1.5 }, { 1.38, side * 0.18, 1.56 } }, 0.035, 6):emit(mesh)
	end
end, 45, RUBBER)
part("Eyes", nil, { 0.94, 0.93, 0.88 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.11, 8)
		eye:translate(1.13, side * 0.3, 2.34)
		eye:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local pupil = EditMesh.sphere(0.06, 8)
		pupil:translate(1.15, side * 0.3 - 0.08, 2.35)
		pupil:emit(mesh)
	end
end, true, 0)
part("Bell", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.72, 0 }, { 0.74, 0.05 }, { 0.68, 0.25 }, { 0.5, 0.45 }, { 0.25, 0.55 }, { 0, 0.57 } }, 24)
	Kit.turn(m, "x", 90)
	m:translate(SHELL[1], SHELL[2], SHELL[3])
	m:emit(mesh)
end, true, 0.3)
part("BellBase", nil, DARK_STEEL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.62, 0 }, { 0.62, 0.12 }, { 0, 0.12 } }, 20)
	Kit.turn(m, "x", 90)
	m:translate(SHELL[1], SHELL[2] + 0.12, SHELL[3])
	m:emit(mesh)
	local clamp = Kit.block(0.35, 0.3, 0.45, 0.05)
	clamp:translate(SHELL[1], SHELL[2] + 0.1, SHELL[3] - 0.65)
	clamp:emit(mesh)
end, 40, 0.4)
part("Lever", nil, DARK_STEEL, function(mesh)
	local arm = Kit.block(0.5, 0.08, 0.06, 0.02)
	Kit.turn(arm, "y", -25)
	arm:translate(SHELL[1] + 0.2, SHELL[2], SHELL[3] + 0.78)
	arm:emit(mesh)
	local pivot = EditMesh.cylinder(0.06, 0.12, 8, 1)
	pivot:translate(SHELL[1], SHELL[2], SHELL[3] + 0.72)
	pivot:emit(mesh)
	local knob = EditMesh.sphere(0.07, 8)
	knob:translate(SHELL[1] + 0.43, SHELL[2], SHELL[3] + 0.9)
	knob:emit(mesh)
end, 40, 0.4)
part("Rings", nil, BARE_METAL, function(mesh)
	-- The bell's pressed rings round its dome.
	for _, ring in { { 0.73, 0.12 }, { 0.6, 0.36 } } do
		local m = EditMesh.torus(ring[1], 0.025, 24, 4)
		m:translate(0, 0, ring[2])
		Kit.turn(m, "x", 90)
		m:translate(SHELL[1], SHELL[2], SHELL[3])
		m:emit(mesh)
	end
end, true, 0.3)
finishParts()
