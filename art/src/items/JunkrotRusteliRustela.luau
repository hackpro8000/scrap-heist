-- Rusteli Rustela: Lirili Larila from scrap. A tall green oil barrel
-- ribbed like a cactus and bristling with rebar spines, standing up on
-- just two massive elephant legs in tyre-rubber sandals, toenails and all;
-- on top a grey tin elephant's head with huge sheet-tin ears, a hose trunk
-- hanging down its front and curling up at the end, two tusks and its own
-- small eyes; a cactus flower blooming on its back. No googly face. 4
-- studs tall.
-- include: JunkrotKit
local BARREL_GREEN = { 0.3, 0.52, 0.36 }
local ELEPHANT = { 0.6, 0.6, 0.58 }
local HIPS = 1.3 -- where the barrel starts, the legs' tops
local CROWN = 3.0 -- the barrel's top
local HEAD = { 0, -0.42, 3.05 }
local LEGS = { -0.42, 0.42 } -- the two legs' x
part("Barrel", nil, BARREL_GREEN, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.62, 0 }, { 0.74, 0.12 }, { 0.8, 0.6 }, { 0.8, 1.3 }, { 0.72, 1.6 }, { 0.5, 1.72 }, { 0, CROWN - HIPS } }, 24)
	-- Ribbed like a cactus: eight ribs round.
	m:transform(function(p)
		local f = 1 + 0.08 * math.cos(math.atan2(p[2], p[1]) * 8)
		return { p[1] * f, p[2] * f, p[3] }
	end)
	m:translate(0, 0.1, HIPS)
	m:emit(mesh)
end, 40, 0.3)
part("Spikes", nil, DARK_STEEL, function(mesh)
	-- Rebar spines along the rib crests, all round but the front, where the
	-- trunk hangs.
	for rib = 0, 7 do
		local a = rib * 45
		local c, s = math.cos(math.rad(a)), math.sin(math.rad(a))
		if s > -0.8 then
			for _, z in { 0.3, 0.75, 1.2 } do
				local spike = EditMesh.cone(0.04, 0.008, 0.3, 4, 1)
				-- Pointing straight out from the barrel's axis.
				Kit.turn(spike, "y", 90)
				Kit.turn(spike, "z", a)
				spike:translate(c * 0.98, 0.1 + s * 0.98, HIPS + z + (rib % 2) * 0.2)
				spike:emit(mesh)
			end
		end
	end
end, 40, 0.4)
part("Head", nil, ELEPHANT, function(mesh)
	local m = EditMesh.sphere(0.62, 12)
	Kit.size(m, { 1.05, 0.95, 0.95 })
	m:translate(HEAD[1], HEAD[2], HEAD[3])
	m:emit(mesh)
	-- Two massive legs, wider at the foot, and a thin tail behind.
	for _, x in LEGS do
		local leg = Kit.lathe({ { 0, 0 }, { 0.45, 0 }, { 0.44, 0.15 }, { 0.38, 0.6 }, { 0.37, HIPS - 0.05 }, { 0.3, HIPS + 0.25 }, { 0, HIPS + 0.3 } }, 16)
		leg:translate(x, 0.05, 0.1)
		leg:emit(mesh)
	end
	Kit.tube({ { 0, 0.88, HIPS + 0.6 }, { 0, 1.15, HIPS + 0.35 }, { 0.05, 1.22, HIPS }, }, 0.05, 6):emit(mesh)
end, true, 0.3)
part("Ears", nil, { 0.72, 0.7, 0.66 }, function(mesh)
	-- Huge flat tin ears out to the sides, facing forward.
	local outline = { { -0.1, -0.6 }, { 0.35, -0.5 }, { 0.6, -0.1 }, { 0.55, 0.35 }, { 0.2, 0.6 }, { -0.25, 0.4 }, { -0.35, -0.15 } }
	for _, side in { -1, 1 } do
		local ear = Kit.plate(outline, 0.05)
		if side < 0 then
			Kit.turn(ear, "z", 180)
		end
		Kit.turn(ear, "z", side * -15)
		ear:translate(HEAD[1] + side * 0.55, HEAD[2] + 0.1, HEAD[3] + 0.05)
		ear:emit(mesh)
	end
end, 40, 0.3)
part("Trunk", nil, { 0.16, 0.16, 0.17 }, function(mesh)
	local path = Kit.curve({
		{ 0, HEAD[2] - 0.45, HEAD[3] - 0.15 },
		{ 0, HEAD[2] - 0.66, HEAD[3] - 0.55 },
		{ 0, HEAD[2] - 0.7, HEAD[3] - 1.15 },
		{ 0, HEAD[2] - 0.78, HEAD[3] - 1.5 },
		{ 0, HEAD[2] - 1.0, HEAD[3] - 1.45 },
	}, 4)
	Kit.tube(path, function(t)
		return 0.17 - 0.07 * t
	end, 10):emit(mesh)
end, true, RUBBER)
part("Tusks", nil, { 0.92, 0.9, 0.82 }, function(mesh)
	for _, side in { -1, 1 } do
		local path = Kit.curve({ { side * 0.22, HEAD[2] - 0.4, HEAD[3] - 0.3 }, { side * 0.3, HEAD[2] - 0.72, HEAD[3] - 0.5 }, { side * 0.26, HEAD[2] - 0.9, HEAD[3] - 0.3 } }, 3)
		Kit.tube(path, function(t)
			return 0.065 * (1 - 0.75 * t)
		end, 8):emit(mesh)
	end
	-- Toenails, three on the front of each foot.
	for _, x in LEGS do
		for k = -1, 1 do
			local nail = EditMesh.sphere(0.08, 8)
			Kit.size(nail, { 1, 0.6, 0.8 })
			nail:translate(x + k * 0.2, 0.05 - 0.43, 0.24)
			nail:emit(mesh)
		end
	end
end, true, 0.1)
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.075, 8)
		eye:translate(HEAD[1] + side * 0.3, HEAD[2] - 0.5, HEAD[3] + 0.16)
		eye:emit(mesh)
	end
end, true, 0)
part("Sandals", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for _, x in LEGS do
		local sole = Kit.block(1.0, 1.05, 0.1, 0.05)
		sole:translate(x, -0.05, 0.05)
		sole:emit(mesh)
		Kit.tube({ { x - 0.42, -0.1, 0.1 }, { x, -0.35, 0.35 }, { x + 0.42, -0.1, 0.1 } }, 0.04, 6):emit(mesh)
	end
end, 40, RUBBER)
part("Flower", nil, { 0.95, 0.45, 0.6 }, function(mesh)
	-- A cactus flower blooming on its back: petals round a heart, each
	-- starting a little out from the middle so none share a point.
	for k = 0, 5 do
		local petal = Kit.plate({ { -0.06, 0.04 }, { 0.06, 0.04 }, { 0.08, 0.2 }, { 0, 0.26 }, { -0.08, 0.2 } }, 0.03)
		Kit.turn(petal, "x", 50)
		Kit.turn(petal, "z", k * 60)
		petal:translate(0, 0.45, CROWN - 0.12)
		petal:emit(mesh)
	end
end, 40, 0)
part("FlowerHeart", nil, { 1.0, 0.85, 0.25 }, function(mesh)
	local m = EditMesh.sphere(0.08, 8)
	m:translate(0, 0.45, CROWN - 0.06)
	m:emit(mesh)
end, true, 0)
finishParts()
