-- Billboard Frame: a tall roadside billboard on twin legs, its poster torn
-- away to show the girder lattice behind, a catwalk along the bottom.
-- Centered on the origin.
local POSTER = { 0.75, 0.68, 0.55 }
local AD = { 0.7, 0.2, 0.15 }

part("Legs", nil, DARK_STEEL, function(mesh)
	for _, x in { -2.5, 2.5 } do
		box(mesh, x, 0, 0, 0.4, 0.4, 6)
		box(mesh, x, 0, 0, 1.0, 1.0, 0.2)
	end
end, nil, 0.6)

part("Lattice", nil, RUST_DARK, function(mesh)
	box(mesh, 0, 0.3, 5.5, 8, 0.15, 0.15)
	box(mesh, 0, 0.3, 9.4, 8, 0.15, 0.15)
	for i = 0, 4 do
		local x = -4 + i * 2
		box(mesh, x, 0.3, 5.5, 0.15, 0.15, 4)
		if i < 4 then
			strut(mesh, x, 0.3, 5.6, x + 2, 0.3, 9.4, 0.08)
		end
	end
	-- Catwalk.
	box(mesh, 0, -0.5, 5.3, 8, 0.8, 0.06)
	box(mesh, 0, -0.9, 5.3, 8, 0.05, 0.6)
end, nil, 0.8)

part("Poster", nil, POSTER, function(mesh)
	box(mesh, -2.5, 0.42, 5.6, 3, 0.04, 3.8)
	box(mesh, 0.5, 0.42, 7.5, 2.0, 0.04, 1.9)
	box(mesh, 2.8, 0.42, 5.6, 1.2, 0.04, 1.4)
end, nil, 0.1)

part("Ad", nil, AD, function(mesh)
	box(mesh, -2.5, 0.38, 6.6, 2.4, 0.04, 1.6)
	box(mesh, 0.5, 0.38, 8.0, 1.6, 0.04, 0.8)
end, nil, 0.1)

finishParts()
