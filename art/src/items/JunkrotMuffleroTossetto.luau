-- Mufflero Tossetto: a coughing exhaust silencer standing on end, an oval
-- drum heat-blued and rusted through in places, rolled seams at both ends,
-- an inlet pipe out of the bottom side, its bent tailpipe up top with a
-- chrome tip and a cloud of soot puffing out of it. 3.5 studs tall.
-- include: JunkrotKit
local FACE = { { -0.26, -0.6, 1.95, 0.2 }, { 0.26, -0.6, 1.97, 0.2 } }
local FEET = { 0.8, 0.55 }
local BASE = 0.6
local TALL = 1.9
local TIP = { 0.48, -0.05, BASE + TALL + 0.82 } -- the tailpipe's mouth
part("Silencer", nil, { 0.42, 0.4, 0.42 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.62, 0 }, { 0.7, 0.06 }, { 0.66, 0.14 }, { 0.68, TALL - 0.14 }, { 0.72, TALL - 0.06 }, { 0.64, TALL }, { 0, TALL } }, 24)
	Kit.size(m, { 1.15, 0.78, 1 })
	-- Rusted through in a few places.
	for _, at in { { -0.4, -0.45, 0.6 }, { 0.5, -0.3, 1.3 }, { -0.2, 0.5, 1.0 } } do
		local spot = m:select("face", "where", function(p)
			local dx, dy, dz = p[1] - at[1], p[2] - at[2], p[3] - at[3]
			return dx * dx + dy * dy + dz * dz < 0.05
		end)
		if spot:count() > 0 then
			Kit.recess(m, spot, 0.02, 0.04)
		end
	end
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, true, 0.8)
part("Pipe", nil, RUST_DARK, function(mesh)
	Kit.tube({ { 0.6, 0, BASE + 0.4 }, { 1.12, 0.05, BASE + 0.32 } }, 0.13, 10):emit(mesh)
	local path = Kit.curve({ { 0.1, 0, BASE + TALL - 0.05 }, { 0.12, 0, BASE + TALL + 0.35 }, { 0.22, 0, BASE + TALL + 0.62 }, { TIP[1] - 0.05, TIP[2], TIP[3] } }, 4)
	Kit.tube(path, 0.14, 10):emit(mesh)
end, true, 0.85)
part("Tip", nil, BARE_METAL, function(mesh)
	Kit.tube({ { TIP[1] - 0.12, TIP[2], TIP[3] - 0.04 }, { TIP[1] + 0.12, TIP[2], TIP[3] + 0.04 } }, 0.17, 10):emit(mesh)
end, true, 0.1)
part("Soot", nil, { 0.2, 0.19, 0.19 }, function(mesh)
	for _, puff in { { 0.2, 0, 0.1, 0.17 }, { 0.42, -0.08, 0.28, 0.22 }, { 0.7, 0.05, 0.45, 0.27 } } do
		local m = EditMesh.sphere(puff[4], 8)
		m:translate(TIP[1] + puff[1], TIP[2] + puff[2], TIP[3] + puff[3])
		m:emit(mesh)
	end
end, true, 0)
part("Hangers", nil, RUBBER_BLACK, function(mesh)
	for _, z in { BASE + 0.5, BASE + 1.5 } do
		local m = EditMesh.torus(0.1, 0.03, 10, 4)
		Kit.turn(m, "y", 90)
		m:translate(0, 0.6, z)
		m:emit(mesh)
	end
end, true, RUBBER)
-- include: JunkrotFace
