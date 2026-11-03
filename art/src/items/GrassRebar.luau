-- Grass Rebar: a tuft of rusty rebar offcuts poking out of a broken
-- concrete clump, standing in for a patch of grass. Centered on the origin.
local CONCRETE = { 0.6, 0.59, 0.56 }

part("Clump", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, -0.05, 1.2, 1.0, 0.15)
end, nil, 0.4)

part("Rebar", nil, RUST_ORANGE, function(mesh)
	for i = 1, 14 do
		local a = i * 2.399
		local r = 0.1 + (i % 4) * 0.12
		local x, y = math.cos(a) * r, math.sin(a) * r
		local h = 0.6 + (i % 5) * 0.18
		local lean = 0.15 + (i % 3) * 0.12
		tube(mesh, { { x, y, 0 }, { x * 1.3, y * 1.3, h * 0.6 }, { x * 1.3 + math.cos(a) * lean, y * 1.3 + math.sin(a) * lean, h } }, 0.03, 5)
	end
end, nil, 0.85)

finishParts()
