-- Phone Booth: a tipped-over phone booth leaning on a drum, its door hanging
-- open and the handset dangling. Centered on the origin.
local BOOTH = { 0.62, 0.14, 0.12 }

part("Booth", nil, BOOTH, function(mesh)
	box(mesh, 0, 0, 0, 1.2, 1.2, 0.15)
	for _, s in { { -0.55, 0 }, { 0.55, 0 }, { 0, 0.55 } } do
		box(mesh, s[1], s[2], 0.15, if s[1] == 0 then 1.2 else 0.1, if s[1] == 0 then 0.1 else 1.2, 2.6)
	end
	box(mesh, 0, 0, 2.75, 1.3, 1.3, 0.25)
	-- Door swung open.
	strut(mesh, -0.6, -0.6, 0.2, -1.2, -1.2, 0.2, 0.06)
	box(mesh, -0.95, -0.95, 0.15, 0.08, 0.08, 2.3)
end, nil, 0.6)

part("Glass", nil, { 0.55, 0.7, 0.75 }, function(mesh)
	box(mesh, -0.55, 0, 1.2, 0.03, 1.0, 1.3)
	box(mesh, 0.55, 0, 1.2, 0.03, 1.0, 1.3)
end, true, 0)

part("Phone", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0.45, 1.4, 0.45, 0.12, 0.6)
	tube(mesh, { { 0, 0.4, 1.4 }, { 0.1, 0.1, 1.0 }, { 0.05, 0, 0.6 } }, 0.02, 4)
	box(mesh, 0.05, 0, 0.45, 0.08, 0.25, 0.1)
end, nil, 0.5)

part("Sign", nil, { 0.92, 0.92, 0.9 }, function(mesh)
	box(mesh, 0, -0.66, 2.8, 0.9, 0.02, 0.15)
end, nil, 0.4)

finishParts()
