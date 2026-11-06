-- Rebirth Press: the hydraulic press that flattens a yard's scrap into a
-- medal, 16 x 8 studs and 7.6 tall. A heavy bed between two columns, a top
-- beam carrying the ram and its striped platen, and a control console at
-- the right end with a big red button. Stands on the origin, its front on
-- the -y side.
local HAZARD_YELLOW = { 0.95, 0.76, 0.12 }
local PRESS_BLUE = { 0.24, 0.36, 0.5 }
local BUTTON_RED = { 1.0, 0.2, 0.15 }
part("Base", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 16, 8, 0.6)
	box(mesh, -1.5, 0, 0.6, 7.5, 5.6, 0.7)
end, nil, 0.5)
part("Frame", nil, PRESS_BLUE, function(mesh)
	for _, x in { -6.6, 3.6 } do
		box(mesh, x, 0, 0.6, 1.5, 3.0, 5.6)
	end
	box(mesh, -1.5, 0, 6.2, 12.4, 3.6, 1.4)
end, nil, 0.4)
part("Ram", nil, BARE_METAL, function(mesh)
	cylinder(mesh, -1.5, 0, 5.0, 0.9, 2.4, "z", 16)
	cylinder(mesh, -1.5, 0, 6.0, 1.3, 0.5, "z", 16)
end, nil, 0.15)
part("Platen", nil, HAZARD_YELLOW, function(mesh)
	box(mesh, -1.5, 0, 3.3, 6.4, 4.8, 0.55)
end, nil, 0.35)
part("Stripes", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	for k = -3, 3 do
		box(mesh, -1.5 + k * 0.9, -2.42, 3.34, 0.36, 0.04, 0.47)
	end
end, nil, 0.3)
part("Bolts", nil, STEEL, function(mesh)
	for _, x in { -6.6, 3.6 } do
		for _, y in { -1.1, 1.1 } do
			bolt(mesh, x, y, 7.66, "z", 0.22)
			bolt(mesh, x - 0.5, y * 1.2, 0.66, "z", 0.2)
		end
	end
	-- Hydraulic lines from the beam down the left column.
	tube(mesh, { { -5.0, 1.9, 6.9 }, { -7.5, 1.9, 6.6 }, { -7.5, 1.9, 1.0 } }, 0.12, 6)
	tube(mesh, { { -5.0, 2.2, 6.6 }, { -7.8, 2.2, 6.2 }, { -7.8, 2.2, 1.0 } }, 0.12, 6)
end, nil, 0.45)
part("Console", nil, PRESS_BLUE, function(mesh)
	box(mesh, 6.4, -2.2, 0.6, 2.0, 1.6, 2.6)
	box(mesh, 6.4, -2.5, 3.2, 2.0, 1.0, 0.3)
end, nil, 0.4)
part("Button", nil, BUTTON_RED, function(mesh)
	cylinder(mesh, 6.4, -2.6, 3.62, 0.42, 0.26, "z", 14)
end, true, 0, nil, 1.2)
finishParts()
