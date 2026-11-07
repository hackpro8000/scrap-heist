-- Consolo Joypaddino: a game console standing on end, a black core
-- between two bright white wings that curve out top and bottom, a blue
-- light bar down the front edge of each wing, and its controller hung
-- round its neck by the cable: a pad with two grips, two sticks and four
-- buttons. 3.7 studs tall.
-- include: JunkrotKit
local FACE = { { -0.2, -0.57, 2.85, 0.18 }, { 0.2, -0.57, 2.87, 0.18 } }
local FEET = { 0.9, 0.5 }
local BASE = 0.55
local TALL = 2.9
local PAD = { 0, -0.86, 1.72 } -- where the controller hangs
part("Core", nil, { 0.08, 0.08, 0.1 }, function(mesh)
	local m = Kit.block(0.8, 1.0, TALL, 0.06)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
	-- The pad's two sticks.
	for _, x in { -0.22, 0.05 } do
		local stick = EditMesh.cylinder(0.06, 0.1, 8, 1)
		Kit.turn(stick, "x", 90)
		stick:translate(PAD[1] + x, PAD[2] - 0.18, PAD[3] + 0.04)
		stick:emit(mesh)
	end
end, 50, 0)
part("Shell", nil, { 0.95, 0.96, 0.98 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = Kit.block(0.16, 1.15, TALL + 0.2, 0.07, { 1, 2, 6 })
		-- Flaring out at both ends, hugging the core in the middle.
		m:transform(function(p)
			local t = p[3] / ((TALL + 0.2) / 2)
			return { p[1] + side * 0.12 * t * t, p[2], p[3] }
		end)
		m:translate(side * 0.48, 0, BASE + TALL / 2)
		m:emit(mesh)
	end
end, 40, 0)
part("LightBar", nil, { 0.3, 0.6, 1.0 }, function(mesh)
	for _, side in { -1, 1 } do
		local m = Kit.block(0.05, 0.05, TALL - 0.6, 0.02)
		m:translate(side * 0.41, -0.52, BASE + TALL / 2)
		m:emit(mesh)
	end
end, 50, 0, nil, 1.0)
part("Pad", nil, { 0.95, 0.96, 0.98 }, function(mesh)
	local body = Kit.block(0.8, 0.3, 0.36, 0.12)
	body:translate(PAD[1], PAD[2], PAD[3])
	body:emit(mesh)
	for _, side in { -1, 1 } do
		local grip = EditMesh.capsule(0.13, 0.22, 8)
		Kit.turn(grip, "y", side * 28)
		grip:translate(PAD[1] + side * 0.38, PAD[2], PAD[3] - 0.18)
		grip:emit(mesh)
	end
end, true, 0)
part("Buttons", nil, { 0.95, 0.3, 0.35 }, function(mesh)
	for _, at in { { 0.25, 0.08 }, { 0.35, 0 }, { 0.25, -0.08 }, { 0.15, 0 } } do
		local b = EditMesh.sphere(0.04, 8)
		b:translate(PAD[1] + at[1], PAD[2] - 0.15, PAD[3] + at[2])
		b:emit(mesh)
	end
end, true, 0)
part("Cable", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	-- Up from the pad, round the console's neck and back down.
	local top = BASE + TALL + 0.08
	local path = Kit.curve({
		{ -0.2, PAD[2], PAD[3] + 0.15 },
		{ -0.55, -0.62, 2.4 },
		{ -0.63, -0.1, 3.2 },
		{ -0.3, 0.05, top },
		{ 0.3, 0.05, top },
		{ 0.63, -0.1, 3.2 },
		{ 0.55, -0.62, 2.4 },
		{ 0.2, PAD[2], PAD[3] + 0.15 },
	}, 4)
	Kit.tube(path, 0.04, 6):emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
