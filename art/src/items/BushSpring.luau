-- Bush (Spring): a clump of car coil springs standing on end at different
-- heights and leans, like a bush of tight curly stems.
local function coil(mesh, x, y, height, radius, lean)
	local points = {}
	local turns = math.floor(height / 0.35)
	for step = 0, turns * 6 do
		local t = step / 6 * math.pi * 2
		local z = step / 6 * 0.35
		points[step + 1] = { x + math.cos(t) * radius + z * lean, y + math.sin(t) * radius, z + 0.08 }
	end
	tube(mesh, points, 0.06, 5)
end

part("Springs", nil, STEEL, function(mesh)
	coil(mesh, 0, 0, 2.2, 0.4, 0)
	coil(mesh, 0.8, 0.3, 1.6, 0.35, 0.2)
	coil(mesh, -0.7, 0.5, 1.8, 0.35, -0.2)
end, nil, 0.5)

part("RustySprings", nil, RUST_ORANGE, function(mesh)
	coil(mesh, 0.2, -0.8, 1.3, 0.32, 0.1)
	coil(mesh, -0.6, -0.5, 1.1, 0.3, -0.3)
	coil(mesh, 0.9, -0.5, 0.9, 0.28, 0.4)
end, nil, 0.7)

finishParts()
