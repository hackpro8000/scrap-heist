-- Speakerone Boomba: a party speaker, a tall black cabinet with rounded
-- edges, two woofers with their cones and dust caps each ringed in glowing
-- colour, a tweeter dome between its eyes, a steel carry handle on top and
-- a bass port sunk into its back. 3.9 studs tall.
-- include: JunkrotKit
local FACE = { { -0.36, -0.67, 3.0, 0.18 }, { 0.36, -0.67, 3.02, 0.18 } }
local FEET = { 1.0, 0.5 }
local BASE = 0.55
local TALL = 2.9
local WOOFERS = { BASE + 0.75, BASE + 1.85 }
part("Cabinet", nil, { 0.09, 0.09, 0.1 }, function(mesh)
	local m = Kit.block(1.5, 1.2, TALL, 0.16, { 1, 1, 6 })
	local port = m:select("face", "facing", { 0, 1, 0 }, 10):filter(function(p)
		return p[3] > -0.9 and p[3] < -0.3
	end)
	if port:count() > 0 then
		Kit.recess(m, port, 0.15, 0.2)
	end
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0)
part("Cones", nil, { 0.2, 0.2, 0.22 }, function(mesh)
	for _, z in WOOFERS do
		local m = Kit.lathe({ { 0, -0.25 }, { 0.5, -0.25 }, { 0.55, -0.2 }, { 0.55, 0 }, { 0.48, 0 }, { 0.15, -0.15 }, { 0.14, -0.13 }, { 0.1, -0.07 }, { 0, -0.05 } }, 24)
		Kit.turn(m, "x", 90)
		m:translate(0, -0.6, z)
		m:emit(mesh)
	end
	local tweeter = Kit.lathe({ { 0, 0 }, { 0.12, 0 }, { 0.1, 0.06 }, { 0, 0.08 } }, 12)
	Kit.turn(tweeter, "x", 90)
	tweeter:translate(0, -0.6, BASE + 2.45)
	tweeter:emit(mesh)
end, true, 0)
part("RingPink", nil, { 1.0, 0.25, 0.7 }, function(mesh)
	local m = EditMesh.torus(0.58, 0.05, 32, 6)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.6, WOOFERS[2])
	m:emit(mesh)
end, true, 0, nil, 1.2)
part("RingCyan", nil, { 0.2, 0.9, 1.0 }, function(mesh)
	local m = EditMesh.torus(0.58, 0.05, 32, 6)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.6, WOOFERS[1])
	m:emit(mesh)
end, true, 0, nil, 1.2)
part("Handle", nil, BARE_METAL, function(mesh)
	local path = Kit.curve({ { -0.45, 0, BASE + TALL - 0.05 }, { -0.4, 0, BASE + TALL + 0.25 }, { 0.4, 0, BASE + TALL + 0.25 }, { 0.45, 0, BASE + TALL - 0.05 } }, 3)
	Kit.tube(path, 0.06, 8):emit(mesh)
end, true, 0.03)
-- include: JunkrotFace
