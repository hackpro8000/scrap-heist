-- Camerino Flashetto: a box camera in a fresh black leatherette wrap
-- between chrome top and bottom plates, one big lens barrel out front for
-- a nose with its glass domed, a flash cube up top on a post, the
-- viewfinder hump, shutter button and wind lever on the top plate and a
-- strap lug on each end. 3 studs tall.
-- include: JunkrotKit
local FACE = { { -0.42, -0.55, 1.8, 0.18 }, { 0.42, -0.55, 1.82, 0.18 } }
local FEET = { 1.1, 0.55 }
local BASE = 0.55
part("Body", nil, { 0.15, 0.15, 0.17 }, function(mesh)
	local m = Kit.block(2.0, 0.95, 1.5, 0.12)
	m:translate(0, 0, BASE + 0.75)
	m:emit(mesh)
end, 50, RUBBER)
part("Trim", nil, BARE_METAL, function(mesh)
	for _, z in { BASE + 0.08, BASE + 1.42 } do
		local plate = Kit.block(2.06, 1.0, 0.18, 0.07)
		plate:translate(0, 0, z)
		plate:emit(mesh)
	end
	local hump = Kit.block(0.6, 0.6, 0.22, 0.08)
	hump:translate(0, 0.05, BASE + 1.6)
	hump:emit(mesh)
	local button = EditMesh.cylinder(0.08, 0.1, 8, 1)
	button:translate(0.7, 0.05, BASE + 1.55)
	button:emit(mesh)
	local lever = Kit.block(0.35, 0.1, 0.06, 0.03)
	lever:translate(-0.72, 0.15, BASE + 1.54)
	lever:emit(mesh)
	local post = EditMesh.cylinder(0.08, 0.2, 8, 1)
	post:translate(0.45, 0.05, BASE + 1.6)
	post:emit(mesh)
	for _, side in { -1, 1 } do
		local lug = EditMesh.torus(0.09, 0.03, 8, 4)
		Kit.turn(lug, "y", 90)
		lug:translate(side * 1.03, 0, BASE + 1.2)
		lug:emit(mesh)
	end
end, 50, 0.05)
part("Lens", nil, { 0.13, 0.13, 0.15 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.5, 0 }, { 0.5, 0.12 }, { 0.46, 0.14 }, { 0.46, 0.3 }, { 0.5, 0.32 }, { 0.5, 0.42 }, { 0.44, 0.5 }, { 0, 0.5 } }, 20)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.46, BASE + 0.72)
	m:emit(mesh)
end, 40, 0.1)
part("LensGlass", nil, { 0.35, 0.5, 0.7 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.38, 0 }, { 0.3, 0.07 }, { 0, 0.1 } }, 20)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.95, BASE + 0.72)
	m:emit(mesh)
end, true, 0)
part("Flash", nil, { 0.9, 0.92, 0.95 }, function(mesh)
	local m = Kit.block(0.45, 0.45, 0.45, 0.06)
	m:translate(0.45, 0.05, BASE + 1.92)
	m:emit(mesh)
end, 50, 0.05)
part("Knobs", nil, BARE_METAL, function(mesh)
	local rewind = EditMesh.cylinder(0.1, 0.1, 12, 1)
	rewind:translate(-0.45, 0.05, BASE + 1.56)
	rewind:emit(mesh)
	local timer = Kit.block(0.08, 0.06, 0.22, 0.02)
	Kit.turn(timer, "y", 25)
	timer:translate(-0.78, -0.5, BASE + 1.08)
	timer:emit(mesh)
end, 40, 0.05)
-- include: JunkrotFace
