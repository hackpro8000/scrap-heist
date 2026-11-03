-- Bush Chain Link: a wad of torn chain-link fence balled up around a bent
-- post, roughly bush sized. Each crumpled panel is a diamond mesh of wire
-- folded over a curved surface, centered on the origin.

-- Diamond mesh over a cylinder-ish fold: panel wraps partway around the
-- center at the given angle, sagging lower at its ends.
local function meshPanel(mesh, angle, spread, radius, height, lift)
	local columns = 7
	local rows = 5
	local function point(u, v)
		local a = angle + (u - 0.5) * spread
		local r = radius * (1 - 0.25 * math.abs(v - 0.5))
		local z = lift + v * height - math.abs(u - 0.5) * 0.6
		return math.cos(a) * r, math.sin(a) * r, math.max(z, 0.05)
	end
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local u0, u1 = column / columns, (column + 1) / columns
			local v0, v1 = row / rows, (row + 1) / rows
			local x0, y0, z0 = point(u0, v0)
			local x1, y1, z1 = point(u1, v1)
			local x2, y2, z2 = point(u1, v0)
			local x3, y3, z3 = point(u0, v1)
			strut(mesh, x0, y0, z0, x1, y1, z1, 0.04)
			strut(mesh, x2, y2, z2, x3, y3, z3, 0.04)
		end
	end
end

part("Mesh", nil, STEEL, function(mesh)
	meshPanel(mesh, 0, 2.4, 1.3, 1.8, 0.1)
	meshPanel(mesh, 2.4, 2.2, 1.1, 1.6, 0.2)
	meshPanel(mesh, 4.3, 2.0, 1.2, 1.4, 0.05)
end, nil, 0.45)

part("RustMesh", nil, RUST_DARK, function(mesh)
	meshPanel(mesh, 1.2, 1.8, 0.7, 1.4, 0.6)
	meshPanel(mesh, 3.6, 1.6, 0.6, 1.0, 0.9)
end, nil, 0.8)

part("Post", nil, DARK_STEEL, function(mesh)
	tube(mesh, {
		{ 0.2, -0.1, 0 },
		{ 0.25, -0.05, 1.3 },
		{ 0.7, 0.3, 2.1 },
		{ 1.4, 0.6, 2.3 },
	}, 0.09, 8)
	-- Top rail torn off and lying through the wad.
	strut(mesh, -1.6, -0.9, 0.12, 1.5, 1.1, 0.5, 0.08)
	-- Loose wire ends sticking out.
	strut(mesh, -1.2, 0.6, 1.2, -1.8, 0.9, 1.7, 0.03)
	strut(mesh, 1.0, -0.8, 1.4, 1.5, -1.3, 1.9, 0.03)
end, nil, 0.6)

finishParts()
