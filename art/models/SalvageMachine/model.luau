-- Salvage machine: a junk shredder that chews scrap dropped in its hopper and
-- spits parts down a chute. Three upgrade tiers, each a group: a hand-cranked
-- shredder, then a motor with a belt and exhaust, then a magnet crane that
-- feeds the hopper. Sits on its pad with the base at the origin.
-- Sketch blockout: tiers stand side by side for review.

local SPACING = 6

local FRAME = { 0.42, 0.46, 0.5 }
local HOPPER = { 0.86, 0.55, 0.18 }
local ROLLER = { 0.3, 0.3, 0.32 }
local MOTOR = { 0.7, 0.2, 0.18 }
local MAGNET = { 0.25, 0.4, 0.75 }
local CHUTE = { 0.6, 0.62, 0.6 }

local TAU = 2 * math.pi

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local v = {}
	for i = 0, 7 do
		local x = cx + (if i % 2 == 0 then -sx else sx) / 2
		local y = cy + (if i // 2 % 2 == 0 then -sy else sy) / 2
		local z = cz + (if i // 4 == 0 then 0 else sz)
		v[i + 1] = mesh:vertex(x, y, z)
	end
	mesh:face({ v[1], v[3], v[4], v[2] })
	mesh:face({ v[5], v[6], v[8], v[7] })
	mesh:face({ v[1], v[2], v[6], v[5] })
	mesh:face({ v[3], v[7], v[8], v[4] })
	mesh:face({ v[1], v[5], v[7], v[3] })
	mesh:face({ v[2], v[4], v[8], v[6] })
end

-- Cylinder along X (axis "x") or Z (axis "z"), centered at (cx, cy, cz).
local function cylinder(mesh, cx, cy, cz, radius, length, axis)
	local sides = 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - length / 2, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + length / 2, cy + u, cz + w)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + length)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- Open-topped hopper flaring out from the shredder throat.
local function hopper(mesh, cx, z, bottom, top, height)
	local low, high = {}, {}
	for i, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		low[i] = mesh:vertex(cx + corner[1] * bottom / 2, corner[2] * bottom / 2, z)
		high[i] = mesh:vertex(cx + corner[1] * top / 2, corner[2] * top / 2, z + height)
	end
	for i = 1, 4 do
		local j = i % 4 + 1
		mesh:face({ low[i], low[j], high[j], high[i] })
	end
	mesh:solidify(-0.08)
	-- Reinforced rim: a flat lip band around the top edge.
	local lip = 0.12
	box(mesh, cx, -top / 2, z + height, top + lip, lip, lip)
	box(mesh, cx, top / 2, z + height, top + lip, lip, lip)
	box(mesh, cx - top / 2, 0, z + height, lip, top, lip)
	box(mesh, cx + top / 2, 0, z + height, lip, top, lip)
end

-- Hopper paint: orange that darkens with grime toward the throat, and a dark
-- band on the rim. bottomZ and height bound the funnel.
local function hopperColor(bottomZ, height)
	return function(x, y, z)
		local t = math.clamp((z - bottomZ) / height, 0, 1)
		local grime = (1 - t) * 0.45 + math.noise(x * 3, y * 3, z * 3) * 0.12
		if t > 0.97 then
			grime = 0.35
		end
		local k = 1 - math.clamp(grime, 0, 0.6)
		return HOPPER[1] * k, HOPPER[2] * k, HOPPER[3] * k
	end
end

local function part(name, mesh, color, group, paint)
	mesh:unwrap()
	local image = Image.new(256, 256, color[1], color[2], color[3])
	if paint then
		mesh:paint(image, paint)
	end
	mesh:paintShading(image, {})
	model.part(name, mesh, image, { group = group, preview = true })
end

for tier = 1, 3 do
	local group = `Tier_{tier}`
	local cx = (tier - 2) * SPACING
	local scale = 1 + (tier - 1) * 0.2

	local frame = Mesh.new()
	-- Legs and shredder housing.
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		box(frame, cx + corner[1] * 0.9 * scale, corner[2] * 0.7 * scale, 0, 0.2, 0.2, 1.2 * scale)
	end
	box(frame, cx, 0, 1.2 * scale, 2.2 * scale, 1.8 * scale, 0.9 * scale)
	part(`{group}_Frame`, frame, FRAME, group)

	local rollers = Mesh.new()
	for _, y in { -0.3, 0.3 } do
		cylinder(rollers, cx, y * scale, 2.15 * scale, 0.28 * scale, 1.9 * scale, "x")
	end
	part(`{group}_Rollers`, rollers, ROLLER, group)

	local bin = Mesh.new()
	hopper(bin, cx, 2.1 * scale, 1.9 * scale, 3 * scale, 1.1 * scale)
	part(`{group}_Hopper`, bin, HOPPER, group, hopperColor(2.1 * scale, 1.1 * scale))

	local chute = Mesh.new()
	box(chute, cx, 1.3 * scale, 0.3, 1 * scale, 1.4 * scale, 0.15)
	part(`{group}_Chute`, chute, CHUTE, group)

	local extras = Mesh.new()
	if tier == 1 then
		-- Hand crank on the side.
		cylinder(extras, cx + 1.25 * scale, 0, 1.6 * scale, 0.08, 0.3, "x")
		box(extras, cx + 1.4, 0, 1.6 * scale, 0.1, 0.1, 0.6)
	else
		-- Motor block with an exhaust stack.
		box(extras, cx + 1.6 * scale, 0, 0.6, 0.9, 1, 0.9)
		cylinder(extras, cx + 1.8 * scale, 0.3, 1.5, 0.1, 1.2, "z")
	end
	if tier == 3 then
		-- Magnet crane: mast, boom, hanging magnet over the hopper.
		box(extras, cx - 1.8 * scale, 0, 0, 0.3, 0.3, 4.6)
		box(extras, cx - 0.8 * scale, 0, 4.4, 2.8, 0.25, 0.25)
		cylinder(extras, cx + 0.3, 0, 3.4, 0.45, 0.25, "z")
	end
	part(`{group}_Extras`, extras, if tier == 1 then FRAME else if tier == 3 then MAGNET else MOTOR, group)
end
