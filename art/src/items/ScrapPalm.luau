-- Scrap Palm: a leaning trunk of stacked pipe couplings, crowned with long
-- drooping fronds cut from sheet metal strips, with a few rusty paint cans
-- hanging under the crown as coconuts.
local trunk = { { 0, 0, 0 }, { 0.3, 0, 3 }, { 1, 0, 6 }, { 2, 0, 8.5 } }

part("Trunk", nil, DARK_STEEL, function(mesh)
	tube(mesh, trunk, 0.28, 8)
end, true, 0.6)

part("Couplings", nil, STEEL, function(mesh)
	for step = 1, 7 do
		local t = step / 8
		local x = if t < 0.5 then t * 1.2 else 0.6 + (t - 0.5) * 2.8
		ring(mesh, x, 0, t * 8.5, 0.28, 0.36, 0.2, "z", 8)
	end
end, nil, 0.5)

part("Fronds", nil, STEEL, function(mesh)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		local dx, dy = math.cos(a), math.sin(a)
		tube(mesh, {
			{ 2, 0, 8.6 },
			{ 2 + dx * 1.4, dy * 1.4, 9.2 },
			{ 2 + dx * 2.8, dy * 2.8, 8.6 },
			{ 2 + dx * 3.6, dy * 3.6, 7.4 },
		}, 0.1, 4)
		-- Strips cut along each frond, drooping off both sides like leaflets.
		for step = 1, 6 do
			local d = step * 0.55
			local x, y = 2 + dx * d, dy * d
			local z = 8.6 + math.sin(step / 7 * math.pi) * 0.7 - (if step > 4 then (step - 4) * 0.4 else 0)
			for _, side in { -1, 1 } do
				strut(mesh, x, y, z, x - dy * side * 0.7 + dx * 0.2, y + dx * side * 0.7 + dy * 0.2, z - 0.5, 0.12)
			end
		end
	end
end, nil, 0.3)

part("Cans", nil, RUST_ORANGE, function(mesh)
	for _, p in { { 1.8, 0.4 }, { 2.2, -0.3 }, { 1.7, -0.4 } } do
		cylinder(mesh, p[1], p[2], 8, 0.22, 0.45, "z", 8)
	end
end, nil, 0.6)

finishParts()
