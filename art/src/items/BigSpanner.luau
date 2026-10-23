-- Big Spanner: the starter weapon upgrade, about 4.5 studs long. A flat
-- steel bar with taped grip, an open-end head tilted 15 degrees on top and
-- a box-end ring below. Built along +Z with the grip end at the origin.

-- Flat plate: a convex outline in the x/z plane extruded along y.
local function plate(mesh, outline, depth)
	local front, back = {}, {}
	for i, point in outline do
		front[i] = mesh:vertex(point[1], -depth / 2, point[2])
		back[i] = mesh:vertex(point[1], depth / 2, point[2])
	end
	local n = #outline
	local reversed = {}
	for i = n, 1, -1 do
		table.insert(reversed, back[i])
	end
	mesh:face(front)
	mesh:face(reversed)
	for i = 1, n do
		local j = i % n + 1
		mesh:face({ front[j], front[i], back[i], back[j] })
	end
end

-- Open jaw: a rounded palm with two straight prongs either side of a
-- parallel slot, the whole head tilted by `tilt` about its center.
local function openJaw(mesh, cx, cz, halfWidth, slotHalf, prongLength, depth, tilt)
	local c, s = math.cos(tilt), math.sin(tilt)
	local function place(points)
		local placed = {}
		for i, point in points do
			placed[i] = { cx + point[1] * c + point[2] * s, cz - point[1] * s + point[2] * c }
		end
		return placed
	end
	local palm = {}
	for i = 0, 8 do
		local t = math.pi * i / 8
		table.insert(palm, { -math.cos(t) * halfWidth, -math.sin(t) * halfWidth * 0.75 })
	end
	plate(mesh, place(palm), depth)
	local chamfer = (halfWidth - slotHalf) * 0.4
	for _, side in { -1, 1 } do
		local inner, outer = slotHalf * side, halfWidth * side
		local prong = {
			{ inner, 0 }, { outer, 0 }, { outer, prongLength - chamfer }, { outer - chamfer * side, prongLength }, { inner, prongLength },
		}
		if side < 0 then
			prong = { prong[5], prong[4], prong[3], prong[2], prong[1] }
		end
		plate(mesh, place(prong), depth)
	end
end

part("Shaft", nil, STEEL, function(mesh)
	box(mesh, 0, 0, 0.35, 0.3, 0.12, 3.35)
	ring(mesh, 0, 0, 0.2, 0.15, 0.36, 0.16, "y", 12)
end, nil, 0.45)
part("Jaw", nil, DARK_STEEL, function(mesh)
	openJaw(mesh, 0, 3.85, 0.48, 0.2, 0.5, 0.18, math.rad(15))
	box(mesh, 0, 0, 3.55, 0.42, 0.16, 0.12)
end, nil, 0.55)
part("Grip", nil, TAPE, function(mesh)
	box(mesh, 0, 0, 0.75, 0.36, 0.18, 1.1)
	for i = 0, 3 do
		box(mesh, 0, 0, 0.8 + i * 0.27, 0.4, 0.22, 0.06)
	end
end, nil, RUBBER)
finishParts()
