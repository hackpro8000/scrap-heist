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

-- Matching bumpers on the front and the back.
part("Bumper", nil, BUMPER, function(mesh)
	for _, y in { -2.15, 2.15 } do
		box(mesh, 0, y, 0.45, 2.0, 0.15, 0.25)
	end
end, nil, 0.3)

-- A dark grille block between the headlights, resting on the front bumper.
part("Grille", nil, BUMPER, function(mesh)
	box(mesh, 0, -2.15, 0.65, 0.9, 0.12, 0.3)
end, nil, 0.3)

-- Three pale horizontal slats set into the face of the grille.
part("GrilleSlats", nil, PAINT, function(mesh)
	for _, z in { 0.72, 0.8, 0.88 } do
		box(mesh, 0, -2.22, z, 0.8, 0.04, 0.03)
	end
end, nil, 0.5)

-- A dark rocker panel band along the bottom of each side, between the wheels.
part("Sills", nil, BUMPER, function(mesh)
	for _, x in { -1.12, 1.12 } do
		box(mesh, x, 0, 0.45, 0.06, 1.6, 0.15)
	end
end, nil, 0.3)

-- A stepped fender over each wheel: a top plate, two shoulders and two legs that wrap the tire.
part("Fenders", nil, RUST_ORANGE, function(mesh)
	for _, x in { -1.2, 1.2 } do
		for _, y in { -1.4, 1.4 } do
			box(mesh, x, y, 1.0, 0.4, 1.0, 0.08)
			for _, side in { -1, 1 } do
				box(mesh, x, y + side * 0.52, 0.78, 0.4, 0.16, 0.27)
				box(mesh, x, y + side * 0.64, 0.55, 0.4, 0.12, 0.3)
			end
		end
	end
end, nil, 0.6)

-- Thin flared lips along the top edge of each fender.
part("ArchLips", nil, RUST_ORANGE, function(mesh)
	for _, x in { -1.22, 1.22 } do
		for _, y in { -1.4, 1.4 } do
			box(mesh, x, y, 1.06, 0.4, 1.1, 0.06)
		end
	end
end, nil, 0.6)

-- Two dark door seams cut into each side of the body.
part("DoorSeams", nil, BUMPER, function(mesh)
	for _, x in { -1.105, 1.105 } do
		for _, y in { -0.6, 0.5 } do
			box(mesh, x, y, 0.58, 0.02, 0.04, 0.66)
		end
	end
end, nil, 0)

-- A small side mirror on each side of the cabin front.
part("Mirrors", nil, PAINT, function(mesh)
	for _, x in { -1.05, 1.05 } do
		box(mesh, x, -0.65, 1.5, 0.3, 0.08, 0.12)
	end
end, nil, 0.5)

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
