-- Scrap Tree (Rebar): rebar rods twisted together into a gnarled trunk that
-- forks into bare branches, rooted in a broken concrete footing. A dead
-- winter tree for the bleaker corners of the yard.
-- include: HandFinish
local CONCRETE = { 0.5, 0.48, 0.44 }
-- Where each rod goes once it leaves the trunk: its bearing, its elbow out and
-- up, its second elbow, its end out and up, and the extra spur, if any.
-- Each bends gradually through two elbows, and they lean to two sides.
local RODS = {
	{ 0.2, 0.9, 7.45, 1.75, 8.1, 2.5, 9.15, 0.5, 1.2 },
	{ 0.95, 0.8, 7.5, 1.3, 8.45, 1.75, 9.8 },
	{ 3.05, 0.85, 7.4, 1.5, 7.95, 2.25, 8.65, -0.4, 0.9 },
	{ 3.75, 0.7, 7.55, 1.15, 8.3, 1.3, 9.2 },
	{ 5.0, 0.6, 7.3, 0.95, 7.65, 1.2, 7.95 },
}

local function steelAndRust(x: number, y: number, z: number): (number, number, number)
	local rust = math.clamp(0.55 + 0.7 * math.noise(x * 1.7, y * 1.7, z * 1.7), 0, 1)
	-- The ribs running round the bars.
	local rib = if ((x + y) * 5 + z * 11) % 1 < 0.3 then 0.74 else 1
	return (0.34 + rust * 0.26) * rib, (0.33 - rust * 0.06) * rib, (0.33 - rust * 0.18) * rib
end

part("Rebar", nil, STEEL, function(mesh)
	for i, rod in RODS do
		local a = i * math.pi * 2 / 5
		local r = 0.22
		local points = {}
		for step = 0, 6 do
			local t = a + step * 0.5
			points[step + 1] = { math.cos(t) * r, math.sin(t) * r, 0.3 + step * 1 }
		end
		local out = rod[1]
		local function outAt(distance: number, height: number, turn: number)
			return { math.cos(out + turn) * distance, math.sin(out + turn) * distance, height }
		end
		points[8] = outAt(rod[2], rod[3], 0)
		local elbow = outAt(rod[4], rod[5], 0.12)
		points[9] = elbow
		points[10] = outAt(rod[6], rod[7], 0.3)
		tube(mesh, roundedPath(points, 0.22), 0.075, 6)
		if rod[8] then
			strut(mesh, elbow[1], elbow[2], elbow[3], elbow[1] + math.cos(out + 1.2) * rod[8], elbow[2] + math.sin(out + 1.2) * rod[8], elbow[3] + rod[9], 0.05)
		end
	end
	-- Two rods snapped off low, sticking out of the bundle.
	strut(mesh, 0.15, 0.1, 3.4, 0.85, 0.5, 4.0, 0.05)
	strut(mesh, -0.1, -0.15, 5.1, -0.75, -0.45, 5.45, 0.05)
	-- Short stubs left in the footing.
	strut(mesh, 0.5, -0.35, 0.5, 0.62, -0.42, 1.05, 0.06)
	strut(mesh, -0.55, 0.2, 0.5, -0.72, 0.28, 0.9, 0.06)
end, true, steelAndRust)

part("Footing", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 1.6, 1.4, 0.45)
	box(mesh, 0, 0, 0.45, 0.9, 0.8, 0.12)
	box(mesh, 1.05, -0.5, 0, 0.7, 0.5, 0.25)
	box(mesh, -0.95, 0.6, 0, 0.5, 0.6, 0.2)
	box(mesh, 0.5, 0.82, 0, 0.42, 0.36, 0.16)
end, nil, 0.25)

part("Ties", nil, DARK_STEEL, function(mesh)
	for _, z in { 1.05, 2.7, 3.45 } do
		ring(mesh, 0, 0, z, 0.28, 0.34, 0.08, "z", 8)
	end
	-- A rusted collar where the rods enter the concrete.
	ring(mesh, 0, 0, 0.62, 0.24, 0.44, 0.12, "z", 12)
end, nil, 0.6)

handFinish({
	Rebar = "metal",
	Footing = "rock",
	Ties = "metal",
}, {}, PROP_FINISH)
finishParts()
