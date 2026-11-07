-- Airfryo Croccante: an egg-shaped air fryer in glossy black, flat across
-- its front where a basket drawer pulls out low down, a chunky D handle on
-- the drawer for a mouth, a tilted control panel on its brow with a
-- glowing-green dial, a vent panel sunk into its back and a sticker on its
-- side. 3.5 studs tall.
-- include: JunkrotKit
local FACE = { { -0.4, -1.06, 2.3, 0.24 }, { 0.4, -1.06, 2.32, 0.24 } }
local FEET = { 1.0, 0.5 }
local BASE = 0.55
part("Body", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.85, 0 }, { 1.12, 0.35 }, { 1.2, 0.95 }, { 1.12, 1.65 }, { 0.82, 2.2 }, { 0.4, 2.45 }, { 0, 2.5 } }, 24)
	-- Flat across the front, for the drawer and the face.
	m:transform(function(p)
		return { p[1], math.max(p[2], -0.98), p[3] }
	end)
	local back = m:select("face", "facing", { 0, 1, 0 }, 30):filter(function(p)
		return p[3] > 1.0 and p[3] < 1.7
	end)
	if back:count() > 0 then
		Kit.recess(m, back, 0.05, 0.05)
	end
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, 40, 0)
part("Drawer", nil, { 0.2, 0.2, 0.22 }, function(mesh)
	local m = Kit.block(1.35, 0.2, 0.95, 0.06)
	m:translate(0, -1.03, BASE + 0.75)
	m:emit(mesh)
end, 50, 0)
part("Handle", nil, BARE_METAL, function(mesh)
	local path = Kit.curve({
		{ -0.32, -1.1, BASE + 0.95 },
		{ -0.3, -1.4, BASE + 0.86 },
		{ 0, -1.46, BASE + 0.82 },
		{ 0.3, -1.4, BASE + 0.86 },
		{ 0.32, -1.1, BASE + 0.95 },
	}, 3)
	Kit.tube(path, 0.075, 8):emit(mesh)
end, true, 0.03)
part("Panel", nil, { 0.18, 0.18, 0.2 }, function(mesh)
	local m = Kit.block(0.85, 0.12, 0.4, 0.05)
	Kit.turn(m, "x", -35)
	m:translate(0, -0.76, BASE + 2.25)
	m:emit(mesh)
end, 50, 0)
part("Dial", nil, { 0.4, 0.95, 0.55 }, function(mesh)
	local m = EditMesh.cylinder(0.15, 0.08, 16, 1)
	Kit.turn(m, "x", 90 - 35)
	m:translate(0.2, -0.84, BASE + 2.27)
	m:emit(mesh)
end, true, 0, nil, 0.9)
part("Sticker", nil, { 0.95, 0.3, 0.25 }, function(mesh)
	local m = Kit.block(0.04, 0.4, 0.28, 0.01)
	m:translate(1.17, 0.15, BASE + 1.25)
	m:emit(mesh)
end, 50, 0)
-- include: JunkrotFace
