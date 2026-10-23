-- Big Spanner: the starter weapon upgrade, about 4.5 studs long. A flat
-- steel bar with taped grip, an open-end head tilted 15 degrees on top and
-- a box-end ring below. Built along +Z with the grip end at the origin.

-- Open jaw: a ring around the y axis with a slot cut out, the slot centered
-- on angle `tilt` from +Z. The cut ends are capped so the jaw reads solid.
local function openJaw(mesh, cx, cz, inner, outer, depth, tilt, slot, sides)
	local t0, t1 = tilt + slot / 2, tilt + TAU - slot / 2
	local function at(r, t, d)
		return mesh:vertex(cx + math.sin(t) * r, d, cz + math.cos(t) * r)
	end
	local rows = {}
	for i = 0, sides do
		local t = t0 + (t1 - t0) * i / sides
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	local first, last = rows[1], rows[sides + 1]
	mesh:face({ first[4], first[3], first[2], first[1] })
	mesh:face({ last[1], last[2], last[3], last[4] })
end

part("Shaft", nil, STEEL, function(mesh)
	box(mesh, 0, 0, 0.35, 0.3, 0.12, 3.35)
	ring(mesh, 0, 0, 0.2, 0.15, 0.36, 0.16, "y", 12)
end, nil, 0.45)
part("Jaw", nil, DARK_STEEL, function(mesh)
	openJaw(mesh, 0, 4.0, 0.2, 0.5, 0.18, math.rad(15), math.rad(80), 14)
	box(mesh, 0, 0, 3.55, 0.42, 0.16, 0.12)
end, nil, 0.55)
part("Grip", nil, TAPE, function(mesh)
	box(mesh, 0, 0, 0.75, 0.36, 0.18, 1.1)
	for i = 0, 3 do
		box(mesh, 0, 0, 0.8 + i * 0.27, 0.4, 0.22, 0.06)
	end
end, nil, RUBBER)
finishParts()
