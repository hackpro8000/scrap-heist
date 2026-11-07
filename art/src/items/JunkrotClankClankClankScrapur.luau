-- Clank Clank Clank Scrapur: Tung Tung Tung Sahur from scrap. A length of
-- rusty pipe for its log of a body, flanged top and bottom and open at the
-- top, with its own big round eyes and a wide dark mouth on its front;
-- thin rebar arms, one swinging a rebar bat up over its shoulder, and thin
-- rebar legs down to flat feet. No googly face. 3.9 studs tall.
-- include: JunkrotKit
local BOTTOM = 1.0
local LONG = 2.35
part("Pipe", nil, RUST_ORANGE, function(mesh)
	local m = Kit.lathe({
		{ 0, 0 },
		{ 0.7, 0 },
		{ 0.7, 0.14 },
		{ 0.56, 0.16 },
		{ 0.56, LONG - 0.16 },
		{ 0.7, LONG - 0.14 },
		{ 0.7, LONG },
		{ 0.45, LONG },
		{ 0.45, LONG - 0.15 },
		{ 0, LONG - 0.15 },
	}, 20)
	m:translate(0, 0, BOTTOM)
	m:emit(mesh)
end, 40, 0.9)
part("Eyes", nil, { 0.95, 0.94, 0.9 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.28, 12)
		Kit.size(eye, { 1, 0.35, 1 })
		eye:translate(side * 0.25, -0.5, BOTTOM + 1.72)
		eye:emit(mesh)
	end
end, true, 0)
part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local pupil = EditMesh.sphere(0.13, 8)
		Kit.size(pupil, { 1, 0.35, 1 })
		pupil:translate(side * 0.24, -0.58, BOTTOM + 1.68)
		pupil:emit(mesh)
	end
end, true, 0)
part("Mouth", nil, { 0.1, 0.07, 0.05 }, function(mesh)
	-- A dark band round the front of the pipe.
	local m = EditMesh.spin({ { 0.575, 0 }, { 0.575, 0.08 }, { 0.575, 0.16 } }, 12, 70)
	m:solidify(0.03)
	Kit.turn(m, "z", -125)
	m:translate(0, 0, BOTTOM + 1.12)
	m:emit(mesh)
end, 40, 0.3)
part("Arms", nil, RUST_DARK, function(mesh)
	Kit.tube(Kit.curve({ { -0.55, 0, BOTTOM + 1.5 }, { -0.85, -0.05, BOTTOM + 1.1 }, { -0.9, -0.15, BOTTOM + 0.6 } }, 3), 0.07, 8):emit(mesh)
	Kit.tube(Kit.curve({ { 0.55, 0, BOTTOM + 1.5 }, { 0.92, -0.1, BOTTOM + 1.35 }, { 0.85, -0.3, BOTTOM + 1.85 } }, 3), 0.07, 8):emit(mesh)
	for _, at in { { -0.9, -0.15, BOTTOM + 0.58 }, { 0.85, -0.3, BOTTOM + 1.85 } } do
		local fist = EditMesh.sphere(0.11, 8)
		fist:translate(at[1], at[2], at[3])
		fist:emit(mesh)
	end
	-- Legs and flat feet.
	for _, side in { -1, 1 } do
		Kit.tube({ { side * 0.25, 0, BOTTOM + 0.05 }, { side * 0.3, -0.05, 0.1 } }, 0.07, 8):emit(mesh)
		local foot = Kit.block(0.24, 0.42, 0.1, 0.04)
		foot:translate(side * 0.3, -0.12, 0.05)
		foot:emit(mesh)
	end
end, true, 0.85)
part("Bat", nil, DARK_STEEL, function(mesh)
	-- From the fist up and back over its shoulder, thick end up.
	local m = Kit.tube({ { 0.85, -0.3, BOTTOM + 1.75 }, { 0.5, 0.1, BOTTOM + 2.45 }, { 0.1, 0.5, BOTTOM + 3.15 } }, function(t)
		return 0.085 + 0.12 * t ^ 1.5
	end, 10)
	m:emit(mesh)
end, true, 0.7)
finishParts()
