-- Cablo Tanglino: a knot of cable that got up and walked, a plug for a
-- tail, 2.6 studs tall.
local FACE = { { -0.28, -0.82, 1.6, 0.24 }, { 0.3, -0.8, 1.65, 0.27 } }
local FEET = { 0.8, 0.55 }
part("Knot", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	-- Loops round a ball, each tilted a different way.
	for k = 0, 5 do
		local tilt, lean = k * 0.55, k * 1.1
		local points = {}
		for step = 0, 10 do
			local angle = step / 10 * TAU
			local x, y, z = math.cos(angle) * 0.85, math.sin(angle) * 0.85, 0
			y, z = y * math.cos(tilt) - z * math.sin(tilt), y * math.sin(tilt) + z * math.cos(tilt)
			x, z = x * math.cos(lean) - z * math.sin(lean), x * math.sin(lean) + z * math.cos(lean)
			table.insert(points, { x, y, 1.5 + z })
		end
		tube(mesh, points, 0.11, 6)
	end
	sphere(mesh, 0, 0, 1.5, 0.62, 0.62, 0.62, 6, 10)
end, true, RUBBER)
part("Tail", nil, { 0.14, 0.14, 0.16 }, function(mesh)
	tube(mesh, { { 0.5, 0.5, 1.4 }, { 1.0, 0.8, 1.0 }, { 1.3, 0.7, 1.5 } }, 0.09, 6)
end, true, RUBBER)
part("Plug", nil, { 0.85, 0.83, 0.78 }, function(mesh)
	box(mesh, 1.3, 0.7, 1.5, 0.34, 0.26, 0.4)
	for _, x in { -0.08, 0.08 } do
		box(mesh, 1.3 + x, 0.7, 1.9, 0.05, 0.14, 0.22)
	end
end, nil, 0.3)
-- include: JunkrotFace
