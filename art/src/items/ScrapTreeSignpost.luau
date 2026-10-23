-- Scrap Tree (Signpost): a street signpost with stolen road signs bolted on
-- at every angle until they bush out into a leafy crown. Green street-name
-- plates and hazard-yellow warning diamonds give the yard its few spots of
-- "foliage" colour.
local SIGN_GREEN = { 0.18, 0.42, 0.24 }
local HAZARD = { 0.9, 0.72, 0.1 }

part("Post", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 0.25, 0.25, 9)
	box(mesh, 0, 0, 0, 0.7, 0.7, 0.1)
end, nil, 0.5)

part("StreetSigns", nil, SIGN_GREEN, function(mesh)
	for i = 0, 6 do
		local a = i * 0.9
		local z = 5.6 + (i % 4) * 0.7
		local x, y = math.cos(a) * 1.1, math.sin(a) * 1.1
		if i % 2 == 0 then
			box(mesh, x, y, z, 2.2, 0.06, 0.5)
		else
			box(mesh, x, y, z, 0.06, 2.2, 0.5)
		end
	end
end, nil, 0.3)

part("WarningSigns", nil, HAZARD, function(mesh)
	for i = 0, 5 do
		local a = i * 1.05 + 0.4
		local z = 6.4 + (i % 3) * 0.9
		local x, y = math.cos(a) * 1.3, math.sin(a) * 1.3
		-- A diamond is a square turned on its corner.
		strut(mesh, x - 0.5, y, z, x + 0.5, y, z, 0.7)
	end
	box(mesh, 0, 0, 9, 1.2, 1.2, 0.08)
end, nil, 0.35)

part("Clamps", nil, STEEL, function(mesh)
	for _, z in { 5.8, 6.6, 7.4, 8.2 } do
		box(mesh, 0, 0, z, 0.36, 0.36, 0.12)
	end
end, nil, 0.4)

finishParts()
