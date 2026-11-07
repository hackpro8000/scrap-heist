-- Junkrot Face: the bits every junkrot shares. An item sets FACE, a list of
-- eyes { x, y, z, size } on its front (-y), and FEET { spread, height }: how
-- far apart its two legs stand and how tall they are (the body starts at
-- that height). It includes this after its own parts.
--
-- Each piece is one edit mesh shaped from a single starting shape:
-- - an eye is a squashed ball with a lens rim inset into its front;
-- - a pupil is a flat disc lying on the lens, looking a little off to one
--   side, so no two junkrots stare the same way;
-- - a leg is a boot block whose back-middle top face is pulled up into the
--   leg, then smoothed, the sole kept flat by a crease.
-- include: EditMesh
-- include: EditOps
-- include: EditShapes

-- A disc of radius r and thickness t facing -y, centred on the origin.
local function faceDisc(r, t, sides)
	local m = EditMesh.cylinder(r, t, sides, 1)
	-- A quarter turn about x, z up to -y (a turn, not a swap, so faces
	-- keep their winding).
	return m:transform(function(p)
		return { p[1], -p[3], p[2] }
	end)
end

part("Eyes", nil, { 0.96, 0.96, 0.92 }, function(mesh)
	for _, eye in FACE do
		local size = eye[4]
		local m = EditMesh.sphere(size, 12)
		m:transform(function(p)
			return { p[1], p[2] * 0.6, p[3] }
		end)
		-- The lens: the front faces inset into a ring, the middle raised a
		-- touch, a googly eye's clear dome.
		local front = m:select("face", "facing", { 0, -1, 0 }, 40)
		m:inset(front, size * 0.12, size * 0.04)
		m:smoothSubdivide(1)
		m:translate(eye[1], eye[2], eye[3])
		m:emit(mesh)
	end
end, true, 0)

part("Pupils", nil, { 0.05, 0.05, 0.06 }, function(mesh)
	for index, eye in FACE do
		local size = eye[4]
		local drift = (if index % 2 == 0 then 0.25 else -0.15) * size
		local m = faceDisc(size * 0.42, size * 0.14, 12)
		m:smoothSubdivide(1)
		-- Resting on the lens, which sits about 0.55 of the size in front.
		m:translate(eye[1] + drift, eye[2] - size * 0.56, eye[3] - size * 0.12)
		m:emit(mesh)
	end
end, true, 0)

part("Legs", nil, RUBBER_BLACK, function(mesh)
	local spread, height = FEET[1], FEET[2]
	for _, side in { -1, 1 } do
		-- The boot, toe forward (-y); the leg rises from its back middle.
		local m = EditMesh.lattice({ -0.24, -0.1, 0.1, 0.24 }, { -0.4, -0.14, 0.06, 0.26, 0.4 }, { 0, 0.26 })
		local top = m:select("face", "facing", { 0, 0, 1 }, 10):filter(function(p)
			return math.abs(p[1]) < 0.1 and p[2] > 0.06 and p[2] < 0.26
		end)
		-- Ankle, then the leg up into the body.
		local ankle = m:extrude(top, 0.12)
		ankle:scale(0.85)
		m:extrude(ankle, math.max(0.1, height + 0.2 - 0.38))
		m:select("edge", "where", function(p)
			return p[3] < 0.01
		end):crease(1)
		m:smoothSubdivide(1)
		m:translate(side * spread / 2, -0.16, 0)
		m:emit(mesh)
	end
end, nil, RUBBER)
finishParts()
