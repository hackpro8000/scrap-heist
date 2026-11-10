-- Bus Stop Wreck: a bus shelter whose roof has torn in half and caved in over
-- the snapped front post. The left glass panel is cracked, the right one smashed
-- to a stub in its rail. Runs along x, centered.
local PANE_Y = 0.82
-- Builds into a mesh laid along two directions from a point: local x runs along
-- (ux, uy, uz) and local z along (wx, wy, wz), so a plate's x-z outline lies there.
local function laidOn(mesh, ox: number, oy: number, oz: number, ux: number, uy: number, uz: number, wx: number, wy: number, wz: number)
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	local along = wx * ux + wy * uy + wz * uz
	wx, wy, wz = wx - ux * along, wy - uy * along, wz - uz * along
	local wl = math.sqrt(wx * wx + wy * wy + wz * wz)
	wx, wy, wz = wx / wl, wy / wl, wz / wl
	local vx, vy, vz = wy * uz - wz * uy, wz * ux - wx * uz, wx * uy - wy * ux
	return {
		vertex = function(_self, x: number, y: number, z: number)
			return mesh:vertex(ox + ux * x + vx * y + wx * z, oy + uy * x + vy * y + wy * z, oz + uz * x + vz * y + wz * z)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end

part("Frame", nil, DARK_STEEL, function(mesh)
	for _, x in { -2, 2 } do
		box(mesh, x, 0.8, 0, 0.14, 0.14, 2.6)
		box(mesh, x, -0.8, 0, 0.14, 0.14, if x < 0 then 2.6 else 1.85)
		-- Foot plates, and a weld plate at the top of each post that reaches the beams.
		for _, y in { -0.8, 0.8 } do
			box(mesh, x, y, 0, 0.36, 0.36, 0.04)
		end
		box(mesh, x, 0.8, 2.48, 0.26, 0.26, 0.12)
	end
	box(mesh, 0, 0.8, 0, 0.14, 0.14, 2.6)
	box(mesh, -2, -0.8, 2.48, 0.26, 0.26, 0.12)
	box(mesh, 0, 0.8, 2.6, 4.2, 0.12, 0.12)
	-- The front beam only runs to where the roof tore.
	box(mesh, -1, -0.8, 2.6, 2.2, 0.12, 0.12)
	-- Rails across each end, tying the front posts to the back ones.
	box(mesh, -2, 0, 1.5, 0.1, 1.6, 0.1)
	box(mesh, 2, 0, 1.2, 0.1, 1.6, 0.1)
	-- A purlin across the shelter where the roof broke.
	box(mesh, 0.02, 0, 2.55, 0.17, 1.66, 0.17)
	-- A rafter under the sagging half, from the break down to the short post.
	strut(mesh, 0.1, -0.05, 2.6, 2.0, -0.8, 1.82, 0.13)
	-- The bottom rail the panes sit in.
	box(mesh, 0, PANE_Y, 0.24, 4, 0.1, 0.08)
end, nil, 0.6)

part("Roof", nil, RUST_ORANGE, function(mesh)
	-- The half still up, lying on the beams.
	plate(laidOn(mesh, -1, 0, 2.72, 1, 0, 0, 0, 1, 0), {
		{ -1.15, 0.98 }, { 0.75, 0.98 }, { 1.05, 0.7 }, { 0.86, 0.3 }, { 1.12, -0.1 }, { 0.9, -0.55 }, { 1.0, -0.98 }, { -1.15, -0.98 },
	}, 0, 0.05, 0.008)
	-- The half that tore off, sagging from the tear onto the snapped post.
	plate(laidOn(mesh, 1.2, -0.05, 2.24, 2.1, 0, -0.98, 0, 1, 0), {
		{ -1.2, 0.72 }, { 0.5, 0.72 }, { 0.9, 0.5 }, { 0.8, 0.1 }, { 1.22, -0.25 }, { 1.0, -0.72 }, { 1.2, -0.92 }, { -1.2, -0.92 },
	}, 0, 0.05, 0.008)
	-- A piece that came right off, on the ground.
	plate(laidOn(mesh, 1.15, -0.25, 0.1, 1, 0.3, 0.06, -0.3, 1, 0.05), {
		{ -0.6, 0.3 }, { 0.1, 0.42 }, { 0.5, 0.1 }, { 0.65, -0.3 }, { -0.1, -0.4 }, { -0.55, -0.2 },
	}, 0, 0.05, 0.008)
end, nil, 0.75)

part("Glass", nil, { 0.55, 0.7, 0.75 }, function(mesh)
	-- Cracked away at the top corner, by the middle post.
	plate(mesh, {
		{ -1.95, 2.6 }, { -0.95, 2.6 }, { -0.8, 2.1 }, { -0.5, 2.25 }, { -0.28, 1.7 }, { -0.05, 1.75 }, { -0.05, 0.28 }, { -1.95, 0.28 },
	}, PANE_Y, 0.03, 0.004)
	-- All that is left of the other pane.
	plate(mesh, {
		{ 0.05, 1.1 }, { 0.3, 0.75 }, { 0.55, 0.95 }, { 0.9, 0.5 }, { 1.3, 0.62 }, { 1.6, 0.38 }, { 1.95, 0.42 }, { 1.95, 0.28 }, { 0.05, 0.28 },
	}, PANE_Y, 0.03, 0.004)
	-- The rest of it, smashed on the ground round the bench's foot.
	for _, shard in { { 0.72, 0.5, 0.4 }, { 1.35, 0.55, 0.34 }, { 1.0, 0.12, 0.28 }, { 1.6, 0.15, 0.22 } } do
		local x, y, r = shard[1], shard[2], shard[3]
		cylinder(mesh, x, y, 0.015, r, 0.03, "z", 3)
	end
end, true, 0)

part("Bench", nil, STEEL, function(mesh)
	box(mesh, 0, 0.5, 0.45, 2.4, 0.42, 0.09)
	-- A back rest against the rear rail.
	box(mesh, 0, 0.72, 0.54, 2.4, 0.05, 0.42)
	for _, x in { -1, 1 } do
		box(mesh, x, 0.5, 0, 0.16, 0.34, 0.45)
		box(mesh, x, 0.5, 0, 0.2, 0.4, 0.03)
	end
end, nil, 0.5)

part("Timetable", nil, { 0.86, 0.82, 0.68 }, function(mesh)
	box(mesh, -2, -0.885, 0.95, 0.46, 0.03, 0.66)
end, nil, 0.3)

part("SignPole", nil, DARK_STEEL, function(mesh)
	box(mesh, 2.16, -0.96, 0, 0.3, 0.3, 0.04)
	-- Strapped against the shelter's corner post.
	for _, z in { 0.65, 1.5 } do
		box(mesh, 2.08, -0.88, z, 0.34, 0.34, 0.09)
	end
	-- Knocked over at the top by whatever hit the shelter.
	tube(mesh, roundedPath({ { 2.16, -0.96, 0 }, { 2.16, -0.96, 2.3 }, { 2.5, -0.98, 3.05 } }, 0.2), 0.06, 8)
	-- The frame round the timetable, on the left front post.
	box(mesh, -2, -0.85, 0.9, 0.56, 0.06, 0.76)
end, nil, 0.6)

part("Sign", nil, { 0.18, 0.3, 0.55 }, function(mesh)
	plate(laidOn(mesh, 2.58, -1.0, 3.22, 0.9, 0, -0.42, 0.42, 0, 0.9), {
		{ -0.28, 0.2 }, { 0.28, 0.2 }, { 0.28, -0.2 }, { -0.28, -0.2 },
	}, 0, 0.04, 0.008)
end, nil, 0.5)

finishParts()
