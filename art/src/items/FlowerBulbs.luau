-- Flower Bulbs: old light bulbs on bent wire stalks with sheet-metal leaves,
-- a small clump of flowers. Centered on the origin.
local GLASS = { 0.95, 0.9, 0.62 }

local stems = {
	{ 0, 0, 1.2, 0.1 }, { 0.3, 0.2, 0.9, 0.25 }, { -0.25, 0.25, 1.0, -0.2 },
	{ 0.15, -0.3, 0.8, 0.15 }, { -0.3, -0.2, 0.7, -0.15 },
}

part("Stalks", nil, { 0.25, 0.38, 0.22 }, function(mesh)
	for _, s in stems do
		tube(mesh, { { s[1] * 0.3, s[2] * 0.3, 0 }, { s[1], s[2], s[3] * 0.6 }, { s[1] + s[4], s[2], s[3] } }, 0.025, 5)
		strut(mesh, s[1] * 0.6, s[2] * 0.6, s[3] * 0.3, s[1] * 0.6 + 0.15, s[2] * 0.6 + 0.05, s[3] * 0.4, 0.02)
	end
end, nil, 0.6)

part("Sockets", nil, STEEL, function(mesh)
	for _, s in stems do
		cylinder(mesh, s[1] + s[4], s[2], s[3] + 0.05, 0.06, 0.1, "z", 8)
	end
end, nil, 0.5)

part("Bulbs", nil, GLASS, function(mesh)
	for _, s in stems do
		sphere(mesh, s[1] + s[4], s[2], s[3] + 0.22, 0.13, 0.13, 0.16, 6, 10)
	end
end, true, 0)

finishParts()
