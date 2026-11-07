-- Snackomatic Prototipo: a food replicator, a seamless white cabinet with
-- well-rounded edges, a glowing chamber sunk deep into its chest with one
-- perfect doughnut floating inside, a dark trim round the chamber and
-- along its foot, and an orange test-unit tag hung on its side. 4 studs
-- tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.77, 3.13, 0.2 }, { 0.3, -0.77, 3.15, 0.2 } }
local FEET = { 1.0, 0.5 }
local BASE = 0.55
local TALL = 3.0
local CHAMBER = BASE + 1.5 -- the chamber's middle
part("Cabinet", nil, { 0.96, 0.97, 0.98 }, function(mesh)
	local m = Kit.block(1.6, 1.4, TALL, 0.3, { 1, 1, 5 })
	local chest = m:select("face", "facing", { 0, -1, 0 }, 10):filter(function(p)
		return p[3] > -0.6 and p[3] < 0.6
	end)
	if chest:count() > 0 then
		Kit.recess(m, chest, 0.04, 0.45)
	end
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0)
part("Chamber", nil, { 0.45, 0.95, 1.0 }, function(mesh)
	local m = Kit.block(0.85, 0.04, 1.3, 0.03)
	m:translate(0, -0.23, CHAMBER)
	m:emit(mesh)
end, 50, 0, nil, 1.6)
part("Doughnut", nil, { 1.0, 0.55, 0.75 }, function(mesh)
	local m = EditMesh.torus(0.17, 0.08, 16, 8)
	Kit.turn(m, "x", 75)
	m:translate(0, -0.48, CHAMBER)
	m:emit(mesh)
end, true, 0, nil, 0.6)
part("Trim", nil, { 0.3, 0.32, 0.36 }, function(mesh)
	for _, z in { CHAMBER - 0.76, CHAMBER + 0.76 } do
		local bar = Kit.block(1.05, 0.05, 0.06, 0.02)
		bar:translate(0, -0.71, z)
		bar:emit(mesh)
	end
	for _, x in { -0.52, 0.52 } do
		local bar = Kit.block(0.06, 0.05, 1.58, 0.02)
		bar:translate(x, -0.71, CHAMBER)
		bar:emit(mesh)
	end
	local foot = Kit.block(1.5, 1.3, 0.08, 0.03)
	foot:translate(0, 0, BASE + 0.04)
	foot:emit(mesh)
	Kit.tube({ { 0.8, -0.2, BASE + 2.3 }, { 0.84, -0.25, BASE + 1.9 } }, 0.015, 4):emit(mesh)
end, 50, 0)
part("Tag", nil, { 0.98, 0.55, 0.12 }, function(mesh)
	local m = Kit.block(0.03, 0.25, 0.32, 0.02)
	m:translate(0.84, -0.26, BASE + 1.72)
	m:emit(mesh)
end, 50, 0)
-- include: JunkrotFace
