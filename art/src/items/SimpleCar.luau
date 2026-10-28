-- Simple Car: a boxy hatchback about 4.2 studs long, 2.2 wide and 2.2 tall. A rust-streaked body, a
-- cabin with a glass band, four rubber wheels and two headlights. Local -y is the front.
local PAINT = { 0.62, 0.6, 0.55 }
local GLASS = { 0.2, 0.24, 0.27 }
local GLOW = { 1, 0.85, 0.5 }
local BUMPER = { 0.18, 0.17, 0.16 }

part("Body", nil, RUST_ORANGE, function(mesh)
	box(mesh, 0, 0, 0.5, 2.2, 4.2, 0.9)
end, nil, 0.6)

part("Cabin", nil, PAINT, function(mesh)
	box(mesh, 0, 0.3, 1.4, 1.9, 2.1, 0.8)
end, nil, 0.5)

-- A band of glass just outside the cabin walls, so the windows read from the game camera.
part("Glass", nil, GLASS, function(mesh)
	box(mesh, 0, 0.3, 1.5, 1.96, 1.8, 0.5)
end, nil, 0)

-- A separate pane in front of the cabin, so the windshield reads as glass from the game camera.
part("Windshield", nil, GLASS, function(mesh)
	box(mesh, 0, -0.78, 1.55, 1.7, 0.1, 0.55)
end, nil, 0)

-- A matching pane on the back of the cabin, so the rear window reads as glass too.
part("RearWindow", nil, GLASS, function(mesh)
	box(mesh, 0, 1.38, 1.55, 1.7, 0.1, 0.55)
end, nil, 0)

part("Bumper", nil, BUMPER, function(mesh)
	box(mesh, 0, -2.2, 0.45, 2.0, 0.15, 0.25)
end, nil, 0.3)

part("Lights", nil, GLOW, function(mesh)
	for _, x in { -0.7, 0.7 } do
		sphere(mesh, x, -2.1, 0.95, 0.12, 0.08, 0.12, 4, 6)
	end
end, nil, 0, nil, 2)

-- Wheels stick out past the body so they read as separate parts. The axle runs along x.
part("Wheels", nil, RUBBER_BLACK, function(mesh)
	for _, x in { -1.2, 1.2 } do
		for _, y in { -1.4, 1.4 } do
			cylinder(mesh, x, y, 0.5, 0.5, 0.3, "x", 14)
		end
	end
end, nil, 0.3)

finishParts()
