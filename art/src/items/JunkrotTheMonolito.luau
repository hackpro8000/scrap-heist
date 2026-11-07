-- The Monolito: a black slab with no seams, no feet and no face but one
-- slit of violet light, hanging a little off the ground over a faint ring,
-- its edges bevelled just enough to catch the light. 4.6 studs tall.
-- Nobody knows who made it.
-- include: JunkrotKit
-- floats: Hum
part("Slab", nil, { 0.03, 0.03, 0.04 }, function(mesh)
	local m = Kit.block(1.15, 0.46, 4.0, 0.04)
	m:translate(0, 0, 0.55 + 2.0)
	m:emit(mesh)
end, 50, 0, nil, nil, true)
part("Eye", nil, { 0.65, 0.4, 1.0 }, function(mesh)
	local m = Kit.block(0.55, 0.04, 0.06, 0.02)
	m:translate(0, -0.235, 3.9)
	m:emit(mesh)
end, 50, 0, nil, 2.5, true)
part("Hum", nil, { 0.5, 0.3, 0.9 }, function(mesh)
	local m = EditMesh.torus(0.85, 0.035, 32, 6)
	Kit.size(m, { 1, 1, 0.5 })
	m:translate(0, 0, 0.05)
	m:emit(mesh)
end, true, 0, nil, 1.5, true)
finishParts()
