-- Flower Fan: desk-fan blades on bent pipe stems, each fan a flower head
-- turned a different way. Centered on the origin.
local BLADE_COLORS = { { 0.62, 0.16, 0.12 }, { 0.9, 0.72, 0.1 }, { 0.18, 0.3, 0.55 } }
local heads = { { 0, 0, 1.3, 0 }, { 0.5, 0.3, 0.9, 1.2 }, { -0.45, 0.2, 1.0, 2.4 } }

part("Stems", nil, DARK_STEEL, function(mesh)
	for _, h in heads do
		tube(mesh, { { h[1] * 0.4, h[2] * 0.4, 0 }, { h[1], h[2], h[3] - 0.15 } }, 0.03, 6)
		cylinder(mesh, h[1], h[2], h[3], 0.08, 0.12, "y", 8)
	end
end, nil, 0.6)

for index, h in heads do
	part("Blades" .. index, nil, BLADE_COLORS[index], function(mesh)
		for b = 0, 4 do
			local a = h[4] + b * math.pi * 2 / 5
			local dx, dz = math.cos(a) * 0.3, math.sin(a) * 0.3
			box(mesh, h[1] + dx, h[2] - 0.08, h[3] + dz - 0.08, 0.2, 0.03, 0.16)
		end
	end, nil, 0.5)
end

finishParts()
