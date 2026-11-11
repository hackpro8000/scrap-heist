-- A sample for scripts/bake-proof.sh, not a game model: three chunked strips,
-- one per kind of coat, each long enough that its end chunks lie out of each
-- other's stroke reach. It proves a baker change leaves the textures of
-- grouped parts as they were, in a few seconds.
useTexelDensity(2)

local LENGTH = 496

local function strip(mesh, y: number)
	for x = -LENGTH / 2 + 4, LENGTH / 2 - 4, 8 do
		box(mesh, x, y, 0, 8, 10, 1)
		-- A rib across every slab, for edges to highlight and creases to shade.
		box(mesh, x, y, 1, 1.5, 10, 0.6)
	end
end

chunkedPart("Brushed", nil, { 0.42, 0.45, 0.5 }, function(mesh)
	strip(mesh, 0)
end, nil, 0.5)

chunkedPart("Painted", nil, { 0.4, 0.36, 0.3 }, function(mesh)
	strip(mesh, 10)
end, nil, function(x, y, z)
	local k = 0.9 + 0.2 * math.noise(x * 0.3, y * 0.3, z * 0.3)
	return 0.4 * k, 0.36 * k, 0.3 * k
end)

chunkedPart("Hand", nil, { 0.46, 0.44, 0.42 }, function(mesh)
	strip(mesh, 20)
end, nil, 0.3)
for _, entry in parts do
	if entry.chunkOf == "Hand" then
		entry.hand, entry.painted, entry.blend, entry.taper = "rock", true, 0.65, 0.6
	end
end

finishParts()
