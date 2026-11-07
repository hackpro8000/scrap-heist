-- La Vacuuma Saturnita: La Vaca Saturno Saturnita from scrap. A round
-- vacuum canister for the planet, two pale bands round it, a flat ring of
-- plate round it tilted like Saturn's, edged with the coiled hose, a
-- glowing power button on its front; on top a tin cow's head with a pink
-- muzzle, ears out to the sides, steel horns, black spots and its own
-- eyes; and two thin legs down to little black shoes. No googly face. 4
-- studs tall.
-- include: JunkrotKit
local MID = 1.7 -- the planet's middle
local TILT = 18 -- degrees the ring tips
local HEAD = { 0, -0.1, MID + 1.35 }
-- The cow's head and all on it a quarter bigger, about its middle.
local function big(m)
	return m:transform(function(p)
		return { HEAD[1] + (p[1] - HEAD[1]) * 1.25, HEAD[2] + (p[2] - HEAD[2]) * 1.25, HEAD[3] + (p[3] - HEAD[3]) * 1.25 }
	end)
end
part("Planet", nil, { 0.9, 0.62, 0.3 }, function(mesh)
	local m = EditMesh.sphere(0.95, 16)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, 0)
part("Bands", nil, { 0.98, 0.9, 0.7 }, function(mesh)
	for _, z in { -0.42, 0.38 } do
		local m = EditMesh.torus(math.sqrt(0.95 * 0.95 - z * z), 0.07, 24, 6)
		m:translate(0, 0, MID + z)
		m:emit(mesh)
	end
	local ring = EditMesh.tube(1.55, 0.88, 0.05, 32)
	Kit.turn(ring, "x", TILT)
	ring:translate(0, 0, MID)
	ring:emit(mesh)
end, true, 0)
part("HoseRing", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	local m = EditMesh.torus(1.58, 0.08, 40, 8)
	Kit.turn(m, "x", TILT)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, RUBBER)
part("Glow", nil, { 0.5, 0.9, 1.0 }, function(mesh)
	local m = EditMesh.cylinder(0.11, 0.05, 12, 1)
	Kit.turn(m, "x", 90)
	m:translate(0.3, -0.88, MID + 0.28)
	m:emit(mesh)
end, true, 0, nil, 1.8)
part("CowHead", nil, { 0.9, 0.9, 0.88 }, function(mesh)
	local skull = EditMesh.sphere(0.45, 12)
	Kit.size(skull, { 1, 1.1, 0.95 })
	skull:translate(HEAD[1], HEAD[2], HEAD[3])
	big(skull):emit(mesh)
	for _, side in { -1, 1 } do
		local ear = Kit.plate({ { -0.1, -0.12 }, { 0.12, -0.08 }, { 0.14, 0.08 }, { -0.1, 0.12 } }, 0.04)
		Kit.turn(ear, "z", 90)
		ear:translate(side * 0.5, HEAD[2], HEAD[3] + 0.15)
		big(ear):emit(mesh)
	end
end, true, 0.05)
part("Muzzle", nil, { 0.95, 0.72, 0.7 }, function(mesh)
	local m = EditMesh.sphere(0.28, 12)
	Kit.size(m, { 1.2, 0.85, 0.85 })
	m:translate(HEAD[1], HEAD[2] - 0.45, HEAD[3] - 0.15)
	big(m):emit(mesh)
end, true, 0.05)
part("Spots", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for _, at in { { 0.3, -0.2, 0.2 }, { -0.25, 0.15, 0.3 }, { 0.1, 0.35, 0.0 } } do
		local spot = EditMesh.sphere(0.16, 8)
		Kit.size(spot, { 1, 1, 0.5 })
		spot:translate(HEAD[1] + at[1], HEAD[2] + at[2], HEAD[3] + at[3] + 0.18)
		big(spot):emit(mesh)
	end
	for _, side in { -1, 1 } do
		local nostril = EditMesh.sphere(0.04, 8)
		nostril:translate(HEAD[1] + side * 0.09, HEAD[2] - 0.68, HEAD[3] - 0.12)
		big(nostril):emit(mesh)
	end
end, true, 0)
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.07, 8)
		eye:translate(HEAD[1] + side * 0.22, HEAD[2] - 0.4, HEAD[3] + 0.12)
		big(eye):emit(mesh)
	end
end, true, 0)
part("Horns", nil, BARE_METAL, function(mesh)
	for _, side in { -1, 1 } do
		local path = Kit.curve({ { side * 0.26, HEAD[2], HEAD[3] + 0.3 }, { side * 0.42, HEAD[2], HEAD[3] + 0.48 }, { side * 0.4, HEAD[2] + 0.05, HEAD[3] + 0.66 } }, 3)
		big(Kit.tube(path, function(t)
			return 0.07 * (1 - 0.7 * t)
		end, 8)):emit(mesh)
	end
end, true, 0.03)
part("Legs", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	for _, side in { -1, 1 } do
		Kit.tube({ { side * 0.3, 0, MID - 0.8 }, { side * 0.35, -0.05, 0.15 } }, 0.07, 8):emit(mesh)
		local shoe = Kit.shoe(0.42, 0.24, 0.18)
		Kit.turn(shoe, "z", -90)
		shoe:translate(side * 0.35, -0.08, 0)
		shoe:emit(mesh)
	end
end, true, 0.1)
part("Cowbell", nil, { 0.82, 0.66, 0.3 }, function(mesh)
	local bell = Kit.lathe({ { 0, 0 }, { 0.14, 0 }, { 0.12, 0.18 }, { 0.06, 0.25 }, { 0, 0.26 } }, 12)
	bell:translate(0, -0.82, MID + 0.5)
	bell:emit(mesh)
end, true, 0.3)
part("Strap", nil, { 0.35, 0.2, 0.1 }, function(mesh)
	Kit.tube({ { 0, -0.82, MID + 0.74 }, { 0, -0.66, MID + 0.98 } }, 0.04, 6):emit(mesh)
end, true, RUBBER)
finishParts()
