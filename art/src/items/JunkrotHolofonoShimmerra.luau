-- Holofono Shimmerra: a hologram phone standing on end, a glass-black slab
-- with rounded corners in a chrome frame, side buttons and a camera bump on
-- its back, a cone of light fanning up out of its top and a little glowing
-- figure turning in it. 4.2 studs tall.
-- include: JunkrotKit
local FACE = { { -0.26, -0.17, 2.3, 0.18 }, { 0.26, -0.17, 2.32, 0.18 } }
local FEET = { 0.6, 0.5 }
local BASE = 0.55
local TALL = 2.2
local TOP = BASE + TALL
part("Slab", nil, { 0.05, 0.05, 0.07 }, function(mesh)
	local m = Kit.block(1.1, 0.2, TALL, 0.12)
	m:translate(0, 0, BASE + TALL / 2)
	m:emit(mesh)
end, 50, 0, nil, nil, true)
part("Edge", nil, BARE_METAL, function(mesh)
	local frame = Kit.block(1.16, 0.14, TALL + 0.06, 0.14)
	frame:translate(0, 0, BASE + TALL / 2)
	frame:emit(mesh)
	for _, z in { BASE + 1.7, BASE + 1.45 } do
		local button = Kit.block(0.06, 0.08, 0.18, 0.02)
		button:translate(0.59, 0, z)
		button:emit(mesh)
	end
	local bump = Kit.block(0.4, 0.06, 0.4, 0.08)
	bump:translate(-0.25, 0.12, TOP - 0.35)
	bump:emit(mesh)
end, 50, 0.03)
part("Cone", nil, { 0.5, 0.8, 1.0 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.08, 0.02 }, { 0.68, 1.25 }, { 0.62, 1.32 }, { 0, 1.3 } }, 24)
	m:translate(0, 0, TOP)
	m:emit(mesh)
end, nil, 0, nil, 1.4)
part("Figure", nil, { 0.9, 0.6, 1.0 }, function(mesh)
	local body = EditMesh.capsule(0.07, 0.2, 8)
	body:translate(0, 0, TOP + 0.62)
	body:emit(mesh)
	local head = EditMesh.sphere(0.07, 8)
	head:translate(0, 0, TOP + 0.86)
	head:emit(mesh)
	Kit.tube({ { -0.2, 0, TOP + 0.85 }, { 0, 0, TOP + 0.7 }, { 0.2, 0, TOP + 0.85 } }, 0.025, 4):emit(mesh)
	for _, side in { -1, 1 } do
		Kit.tube({ { side * 0.04, 0, TOP + 0.55 }, { side * 0.09, 0, TOP + 0.38 } }, 0.03, 4):emit(mesh)
	end
end, true, 0, nil, 2.0)
-- include: JunkrotFace
