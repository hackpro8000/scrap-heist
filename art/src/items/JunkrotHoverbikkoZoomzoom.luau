-- Hoverbikko Zoomzoom: a hoverbike with no wheels, a sleek white body
-- drawn down to a nose and swept up at the tail, an orange stripe down its
-- side, a low tinted screen with bars behind it, a seat, and two glowing
-- lift pads in dark rims underneath. 2.2 studs tall, 4.6 long.
-- include: JunkrotKit
local FACE = { { 1.25, -0.42, 1.15, 0.17 }, { 1.6, -0.35, 1.13, 0.15 } }
local FEET = { 1.2, 0.5 }
local MID = 1.05
part("Body", nil, { 0.95, 0.96, 0.98 }, function(mesh)
	local m = Kit.block(3.4, 0.95, 0.7, 0.3, { 6, 2, 2 })
	m:transform(function(p)
		local nose = math.clamp(p[1] / 1.7, 0, 1)
		local tail = math.clamp(-p[1] / 1.7, 0, 1)
		local w = 1 - 0.45 * nose * nose
		return { p[1], p[2] * w, p[3] * (1 - 0.35 * nose) + 0.25 * tail * tail - 0.08 * nose }
	end)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, true, 0)
part("Pads", nil, { 0.4, 0.9, 1.0 }, function(mesh)
	for _, x in { -1.0, 1.0 } do
		local m = EditMesh.cylinder(0.3, 0.06, 16, 1)
		m:translate(x, 0, MID - 0.38)
		m:emit(mesh)
	end
end, true, 0, nil, 2.0)
part("PadRims", nil, { 0.25, 0.27, 0.3 }, function(mesh)
	for _, x in { -1.0, 1.0 } do
		local m = EditMesh.torus(0.33, 0.06, 20, 6)
		m:translate(x, 0, MID - 0.36)
		m:emit(mesh)
	end
end, true, 0)
part("Seat", nil, { 0.12, 0.12, 0.14 }, function(mesh)
	local m = Kit.block(1.0, 0.6, 0.18, 0.08)
	m:translate(-0.55, 0, MID + 0.4)
	m:emit(mesh)
end, true, RUBBER)
part("Stripe", nil, { 1.0, 0.45, 0.1 }, function(mesh)
	local m = Kit.block(1.8, 0.03, 0.08, 0.01)
	m:translate(-0.3, -0.48, MID + 0.05)
	m:emit(mesh)
end, 50, 0)
part("Screen", nil, { 0.5, 0.85, 1.0 }, function(mesh)
	local m = Kit.plate({ { -0.32, 0 }, { 0.32, 0 }, { 0.22, 0.32 }, { -0.22, 0.32 } }, 0.03)
	Kit.turn(m, "z", 90)
	Kit.turn(m, "y", -35)
	m:translate(0.6, 0, MID + 0.3)
	m:emit(mesh)
end, 40, 0, nil, 0.8)
part("Bars", nil, BARE_METAL, function(mesh)
	Kit.tube({ { 0.35, -0.45, MID + 0.6 }, { 0.38, 0, MID + 0.52 }, { 0.35, 0.45, MID + 0.6 } }, 0.04, 6):emit(mesh)
	Kit.tube({ { 0.38, 0, MID + 0.52 }, { 0.42, 0, MID + 0.2 } }, 0.05, 6):emit(mesh)
end, true, 0.03)
-- include: JunkrotFace
