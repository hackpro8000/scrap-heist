-- Rusteli Rustela: Lirili Larila from scrap. An elephant whose body is a
-- green oil barrel ribbed like a cactus and bristling with rebar spines,
-- on four thick legs in tyre-rubber sandals, a thin tail behind; a head
-- with big sheet-tin ears, a hose trunk curling down and out, two tusks and
-- its own small eyes. No googly face. 3.4 studs tall.
-- include: JunkrotKit
local BARREL_GREEN = { 0.3, 0.52, 0.36 }
local MID = 1.75 -- the barrel's axis
local HEAD = { 1.15, 0, MID + 0.35 }
part("Barrel", nil, BARREL_GREEN, function(mesh)
	local m = Kit.lathe({ { 0, -1.05 }, { 0.62, -1.05 }, { 0.72, -0.95 }, { 0.8, -0.5 }, { 0.82, 0 }, { 0.8, 0.5 }, { 0.72, 0.95 }, { 0.62, 1.05 }, { 0, 1.05 } }, 24)
	-- Ribbed like a cactus: eight ribs round.
	m:transform(function(p)
		local f = 1 + 0.07 * math.cos(math.atan2(p[2], p[1]) * 8)
		return { p[1] * f, p[2] * f, p[3] }
	end)
	Kit.turn(m, "y", 90)
	m:translate(-0.2, 0, MID)
	m:emit(mesh)
end, 40, 0.3)
part("Spikes", nil, DARK_STEEL, function(mesh)
	for rib = 0, 7 do
		local a = rib * 45
		local c, s = math.cos(math.rad(a)), math.sin(math.rad(a))
		if s > -0.3 then
			for _, x in { -0.95, -0.45, 0.05, 0.5 } do
				local spike = EditMesh.cone(0.04, 0.008, 0.28, 4, 1)
				Kit.turn(spike, "x", a - 90)
				spike:translate(x - 0.2 * (rib % 2), c * 0.98, MID + s * 0.98)
				spike:emit(mesh)
			end
		end
	end
end, 40, 0.4)
part("Head", nil, BARREL_GREEN, function(mesh)
	local m = EditMesh.sphere(0.55, 12)
	Kit.size(m, { 1, 0.95, 1.05 })
	m:translate(HEAD[1], HEAD[2], HEAD[3])
	m:emit(mesh)
	-- Four thick legs, and a thin tail.
	for _, x in { -0.85, 0.45 } do
		for _, y in { -0.42, 0.42 } do
			local leg = EditMesh.cylinder(0.24, MID - 0.55, 12, 2)
			leg:translate(x, y, (MID - 0.55) / 2 + 0.08)
			leg:emit(mesh)
		end
	end
	Kit.tube({ { -1.25, 0, MID + 0.1 }, { -1.45, 0, MID - 0.2 }, { -1.5, 0, MID - 0.55 } }, 0.04, 6):emit(mesh)
end, true, 0.3)
part("Ears", nil, { 0.72, 0.7, 0.66 }, function(mesh)
	local outline = { { -0.05, -0.45 }, { 0.25, -0.35 }, { 0.4, 0 }, { 0.3, 0.32 }, { 0, 0.42 }, { -0.25, 0.2 }, { -0.28, -0.2 } }
	local near = Kit.plate(outline, 0.05)
	near:translate(HEAD[1] - 0.2, -0.56, HEAD[3] + 0.05)
	near:emit(mesh)
	local far = Kit.plate(outline, 0.05)
	far:translate(HEAD[1] - 0.2, 0.51, HEAD[3] + 0.05)
	far:emit(mesh)
end, 40, 0.3)
part("Trunk", nil, { 0.16, 0.16, 0.17 }, function(mesh)
	local path = Kit.curve({ { HEAD[1] + 0.45, 0, HEAD[3] - 0.2 }, { HEAD[1] + 0.62, 0, HEAD[3] - 0.65 }, { HEAD[1] + 0.65, 0, HEAD[3] - 1.15 }, { HEAD[1] + 0.82, 0, HEAD[3] - 1.4 }, { HEAD[1] + 1.0, 0, HEAD[3] - 1.2 } }, 4)
	Kit.tube(path, function(t)
		return 0.17 - 0.07 * t
	end, 10):emit(mesh)
end, true, RUBBER)
part("Tusks", nil, { 0.92, 0.9, 0.82 }, function(mesh)
	for _, side in { -1, 1 } do
		local path = Kit.curve({ { HEAD[1] + 0.38, side * 0.2, HEAD[3] - 0.3 }, { HEAD[1] + 0.7, side * 0.24, HEAD[3] - 0.55 }, { HEAD[1] + 0.85, side * 0.22, HEAD[3] - 0.35 } }, 3)
		Kit.tube(path, function(t)
			return 0.06 * (1 - 0.75 * t)
		end, 8):emit(mesh)
	end
end, true, 0.1)
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.07, 8)
		eye:translate(HEAD[1] + 0.35, side * 0.36, HEAD[3] + 0.15)
		eye:emit(mesh)
	end
end, true, 0)
part("FlipFlops", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for _, x in { -0.85, 0.45 } do
		for _, y in { -0.42, 0.42 } do
			local sole = Kit.block(0.62, 0.42, 0.08, 0.04)
			sole:translate(x + 0.08, y, 0.04)
			sole:emit(mesh)
			Kit.tube({ { x - 0.15, y - 0.2, 0.08 }, { x + 0.22, y, 0.22 }, { x - 0.15, y + 0.2, 0.08 } }, 0.03, 4):emit(mesh)
		end
	end
end, 40, RUBBER)
finishParts()
