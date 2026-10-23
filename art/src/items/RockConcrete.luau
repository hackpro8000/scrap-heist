-- Rock Concrete: a broken chunk of reinforced concrete standing in for a
-- rock, stacked from offset slabs so the edges look snapped rather than
-- cast, with bent rebar sticking out of the breaks. Centered on the origin.
local CONCRETE = { 0.6, 0.59, 0.56 }

part("Concrete", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 3.0, 2.4, 0.7)
	box(mesh, -0.2, 0.15, 0.7, 2.5, 2.0, 0.6)
	box(mesh, 0.25, -0.1, 1.3, 1.7, 1.5, 0.5)
	box(mesh, -0.3, 0.2, 1.8, 0.9, 0.9, 0.35)
	-- Fallen fragments at the foot.
	box(mesh, 1.9, 0.9, 0, 0.6, 0.5, 0.3)
	box(mesh, -1.8, -1.1, 0, 0.45, 0.4, 0.22)
end, nil, 0.3)

part("Rebar", nil, RUST_ORANGE, function(mesh)
	tube(mesh, { { 0.6, 0.4, 1.6 }, { 0.8, 0.5, 2.4 }, { 1.4, 0.6, 2.7 } }, 0.05, 6)
	tube(mesh, { { -0.6, 0.5, 2.0 }, { -0.7, 0.6, 2.9 }, { -0.4, 0.9, 3.2 } }, 0.05, 6)
	tube(mesh, { { 1.2, -0.6, 0.9 }, { 1.9, -0.7, 1.1 }, { 2.3, -1.1, 0.8 } }, 0.05, 6)
	tube(mesh, { { -1.0, -0.8, 0.5 }, { -1.7, -1.0, 0.9 }, { -2.0, -1.5, 1.4 } }, 0.05, 6)
	tube(mesh, { { 0.1, -0.7, 1.7 }, { 0.15, -1.0, 2.4 } }, 0.05, 6)
end, nil, 0.9)

finishParts()
