-- Shopping Carts: two wire carts nested together, the front one tipped on
-- its side. Centered on the origin.
local function cart(mesh, ox, oy, oz, tipped)
	-- Local (u, v, w) to world: tipped carts lie on their side along y.
	local function p(u, v, w)
		if tipped then
			return ox + u, oy + w, oz + v + 0.5
		end
		return ox + u, oy + v, oz + w
	end
	local function line(a, b)
		local x0, y0, z0 = p(a[1], a[2], a[3])
		local x1, y1, z1 = p(b[1], b[2], b[3])
		strut(mesh, x0, y0, z0, x1, y1, z1, 0.04)
	end
	-- Basket: bottom and top rims, tapering to the front.
	for _, w in { 0.6, 1.4 } do
		local back, front = 0.5, if w > 1 then 0.45 else 0.35
		line({ -0.8, -back, w }, { 0.8, -front, w })
		line({ -0.8, back, w }, { 0.8, front, w })
		line({ -0.8, -back, w }, { -0.8, back, w })
		line({ 0.8, -front, w }, { 0.8, front, w })
	end
	for i = 0, 6 do
		local u = -0.8 + i * 0.27
		line({ u, -0.5, 0.6 }, { u, -0.5, 1.4 })
		line({ u, 0.5, 0.6 }, { u, 0.5, 1.4 })
	end
	-- Legs, base and handle.
	for _, v in { -0.4, 0.4 } do
		line({ -0.8, v, 0.6 }, { -0.8, v, 0.1 })
		line({ 0.7, v, 0.6 }, { 0.7, v, 0.1 })
		line({ -0.8, v, 0.1 }, { 0.7, v, 0.1 })
		line({ -0.8, v * 1.2, 1.4 }, { -1.05, v * 1.2, 1.55 })
	end
end

part("Wire", nil, STEEL, function(mesh)
	cart(mesh, -0.6, 0, 0, false)
	cart(mesh, 1.3, 0.3, 0, true)
end, nil, 0.45)

part("Handle", nil, { 0.7, 0.15, 0.12 }, function(mesh)
	cylinder(mesh, -1.65, 0, 1.55, 0.06, 1.0, "y", 8)
end, nil, 0.3)

part("Casters", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.4, 0.1 } do
		for _, y in { -0.4, 0.4 } do
			cylinder(mesh, x, y, 0.07, 0.07, 0.05, "y", 8)
		end
	end
	cylinder(mesh, 0.5, 0.7, 0.5, 0.07, 0.05, "z", 8)
	cylinder(mesh, 2.0, 0.7, 0.5, 0.07, 0.05, "z", 8)
end, nil, RUBBER)

finishParts()
