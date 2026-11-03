-- Grass Wire: loose strands of stripped copper and steel wire springing out
-- of the ground in a tuft. Centered on the origin.
local function strands(mesh, offset, count)
	for i = 1, count do
		local a = (i + offset) * 2.399
		local r = 0.05 + (i % 5) * 0.08
		local x, y = math.cos(a) * r, math.sin(a) * r
		local h = 0.5 + ((i + offset) % 4) * 0.15
		local bend = 0.25 + (i % 3) * 0.1
		tube(mesh, {
			{ x, y, 0 },
			{ x * 1.5, y * 1.5, h * 0.5 },
			{ x * 1.5 + math.cos(a) * bend, y * 1.5 + math.sin(a) * bend, h },
			{ x * 1.5 + math.cos(a) * bend * 1.8, y * 1.5 + math.sin(a) * bend * 1.8, h * 0.8 },
		}, 0.015, 4)
	end
end

part("Copper", nil, COPPER, function(mesh)
	strands(mesh, 0, 12)
end, nil, 0.3)

part("Steel", nil, STEEL, function(mesh)
	strands(mesh, 50, 9)
end, nil, 0.4)

finishParts()
