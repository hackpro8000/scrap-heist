-- Log Girder: a fallen, bent I-beam lying like a log with its rivet plates
-- and a snapped end. Centered on the origin, running along x.
local function ibeam(mesh, x, length, z)
	box(mesh, x, 0, z, length, 0.8, 0.1)
	box(mesh, x, 0, z + 0.1, length, 0.1, 0.7)
	box(mesh, x, 0, z + 0.8, length, 0.8, 0.1)
end

part("Beam", nil, RUST_ORANGE, function(mesh)
	ibeam(mesh, -1.2, 3.0, 0)
	-- Second half kinked upward where it bent.
	for i = 0, 5 do
		ibeam(mesh, 0.55 + i * 0.4, 0.42, i * 0.08)
	end
end, nil, 0.85)

part("Plates", nil, RUST_DARK, function(mesh)
	box(mesh, -0.4, 0.07, 0.15, 0.6, 0.04, 0.6)
	for _, z in { 0.25, 0.45, 0.65 } do
		bolt(mesh, -0.6, 0.1, z, "y", 0.05)
		bolt(mesh, -0.2, 0.1, z, "y", 0.05)
	end
	-- Snapped end shards.
	strut(mesh, 2.8, 0, 0.5, 3.1, 0.1, 0.9, 0.06)
	strut(mesh, 2.8, -0.2, 0.9, 3.05, -0.35, 1.2, 0.06)
end, nil, 0.8)

finishParts()
