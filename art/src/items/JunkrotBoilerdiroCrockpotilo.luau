-- Boilerdiro Crockpotilo: Bombardiro Crocodilo built from scrap. A brass
-- boiler tank for the bomber's fuselage, nose forward (+x), banded round;
-- on its front a crocodile's head of green riveted plate with a long
-- tapering snout, saw-blade teeth down both jaws, its own yellow eyes up
-- on bumps and nostrils at the tip; straight wings with an engine and a
-- three-bladed propeller on each, a tail fin and tailplanes, a bomb slung
-- under the belly and landing gear to stand on. No googly face. 2.4 studs
-- tall, 5 long.
-- include: JunkrotKit
local PLATE_GREEN = { 0.3, 0.44, 0.3 }
local MID = 1.45 -- the fuselage's axis
local ENGINES = { -1.15, 1.15 } -- the engines' y
part("Boiler", nil, { 0.5, 0.42, 0.3 }, function(mesh)
	-- Lathed along z, then laid along x: tail end at -x.
	local m = Kit.lathe({ { 0, -1.75 }, { 0.2, -1.7 }, { 0.42, -1.1 }, { 0.55, -0.3 }, { 0.56, 0.6 }, { 0.5, 0.92 }, { 0, 0.98 } }, 16)
	Kit.turn(m, "y", 90)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, 0.1)
part("Bands", nil, BARE_METAL, function(mesh)
	for _, x in { -0.7, 0.15 } do
		local ring = EditMesh.torus(0.56, 0.045, 16, 6)
		Kit.turn(ring, "y", 90)
		ring:translate(x, 0, MID)
		ring:emit(mesh)
	end
	-- Pylon and bomb under the belly.
	local pylon = Kit.block(0.3, 0.12, 0.25, 0.03)
	pylon:translate(-0.25, 0, MID - 0.6)
	pylon:emit(mesh)
end, 40, 0.05)
part("Croc", nil, PLATE_GREEN, function(mesh)
	local skull = Kit.block(1.0, 1.08, 0.88, 0.28)
	skull:translate(1.0, 0, MID + 0.05)
	skull:emit(mesh)
	-- Upper and lower jaw, each tapering to the tip.
	local upper = Kit.block(1.6, 0.76, 0.38, 0.13, { 3, 1, 1 })
	upper:taper("x", 1, 0.62)
	upper:translate(2.05, 0, MID + 0.06)
	upper:emit(mesh)
	local lower = Kit.block(1.45, 0.68, 0.22, 0.09, { 3, 1, 1 })
	lower:taper("x", 1, 0.62)
	lower:translate(2.0, 0, MID - 0.22)
	lower:emit(mesh)
	-- Eye bumps and nostrils.
	for _, side in { -1, 1 } do
		local bump = EditMesh.sphere(0.17, 8)
		bump:translate(1.12, side * 0.28, MID + 0.42)
		bump:emit(mesh)
		local nostril = EditMesh.sphere(0.06, 8)
		nostril:translate(2.72, side * 0.1, MID + 0.2)
		nostril:emit(mesh)
	end
	-- Tail fin, standing up at the back.
	local fin = Kit.plate({ { -1.72, MID + 0.1 }, { -1.15, MID + 0.1 }, { -1.45, MID + 0.88 }, { -1.8, MID + 0.92 } }, 0.08)
	fin:translate(0, -0.04, 0)
	fin:emit(mesh)
end, 40, 0.1)
part("Eyes", nil, { 0.95, 0.82, 0.2 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.12, 8)
		eye:translate(1.2, side * 0.31, MID + 0.5)
		eye:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local slit = EditMesh.sphere(0.09, 8)
		Kit.size(slit, { 0.3, 0.45, 1 })
		slit:translate(1.31, side * 0.33, MID + 0.5)
		slit:emit(mesh)
	end
end, true, 0)
part("Teeth", nil, BARE_METAL, function(mesh)
	-- Saw teeth, points down, along both sides of the upper jaw.
	for _, side in { -1, 1 } do
		for k = 0, 5 do
			local x = 1.45 + k * 0.22
			local tooth = EditMesh.cone(0.055, 0.01, 0.13, 4, 1)
			Kit.turn(tooth, "x", 180)
			tooth:translate(x, side * (0.3 - k * 0.025), MID - 0.15)
			tooth:emit(mesh)
		end
	end
end, 40, 0.03)
part("Wings", nil, PLATE_GREEN, function(mesh)
	local outline = { { -0.55, 0.35 }, { 0.38, 0.35 }, { 0.15, 2.1 }, { -0.45, 2.1 } }
	local near = Kit.plate(outline, 0.1)
	Kit.turn(near, "x", 90)
	near:translate(0, 0, MID - 0.05)
	near:emit(mesh)
	local far = Kit.plate(outline, 0.1)
	Kit.turn(far, "x", -90)
	far:translate(0, 0, MID + 0.05)
	far:emit(mesh)
	-- Tailplanes.
	local tail = { { -1.78, 0.2 }, { -1.35, 0.2 }, { -1.45, 0.75 }, { -1.78, 0.75 } }
	local a = Kit.plate(tail, 0.06)
	Kit.turn(a, "x", 90)
	a:translate(0, 0, MID + 0.1)
	a:emit(mesh)
	local b = Kit.plate(tail, 0.06)
	Kit.turn(b, "x", -90)
	b:translate(0, 0, MID + 0.16)
	b:emit(mesh)
end, 40, 0.1)
part("Engines", nil, DARK_STEEL, function(mesh)
	for _, y in ENGINES do
		local m = Kit.lathe({ { 0, -0.5 }, { 0.15, -0.45 }, { 0.2, 0 }, { 0.17, 0.42 }, { 0, 0.5 } }, 12)
		Kit.turn(m, "y", 90)
		m:translate(0.2, y, MID - 0.12)
		m:emit(mesh)
	end
	-- The bomb, a teardrop along x under the pylon.
	local bomb = Kit.lathe({ { 0, -0.5 }, { 0.1, -0.45 }, { 0.17, -0.1 }, { 0.16, 0.25 }, { 0, 0.4 } }, 12)
	Kit.turn(bomb, "y", 90)
	bomb:translate(-0.25, 0, MID - 0.85)
	bomb:emit(mesh)
end, true, 0.1)
part("Props", nil, DARK_STEEL, function(mesh)
	for _, y in ENGINES do
		local hub = EditMesh.cone(0.09, 0.02, 0.16, 8, 1)
		Kit.turn(hub, "y", 90)
		hub:translate(0.78, y, MID - 0.12)
		hub:emit(mesh)
		for k = 0, 2 do
			local blade = Kit.plate({ { -0.06, 0.04 }, { 0.06, 0.04 }, { 0.08, 0.55 }, { -0.04, 0.6 } }, 0.03)
			Kit.turn(blade, "z", 90)
			Kit.turn(blade, "x", 120 * k + 15)
			blade:translate(0.78, y, MID - 0.12)
			blade:emit(mesh)
		end
	end
end, 40, 0.05)
part("Gear", nil, DARK_STEEL, function(mesh)
	for _, y in { -0.75, 0.75 } do
		Kit.tube({ { 0.1, y, MID - 0.05 }, { 0.12, y, 0.3 } }, 0.05, 8):emit(mesh)
	end
	Kit.tube({ { -1.45, 0, MID - 0.2 }, { -1.5, 0, 0.18 } }, 0.04, 8):emit(mesh)
end, 40, 0.3)
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, w in { { 0.12, -0.75, 0.22 }, { 0.12, 0.75, 0.22 }, { -1.5, 0, 0.12 } } do
		local m = Kit.lathe({ { 0, -0.07 }, { w[3] * 0.8, -0.07 }, { w[3], 0 }, { w[3] * 0.8, 0.07 }, { 0, 0.07 } }, 12)
		Kit.turn(m, "x", 90)
		m:translate(w[1], w[2], w[3])
		m:emit(mesh)
	end
end, true, RUBBER)
finishParts()
