-- Island Profile: the plain body of a floating island, with no rock detail.
-- It is a solid of revolution whose side curves smoothly inward as it goes
-- down, levelling out to a flat underside, and its outline wobbles like the
-- Pad Island's.
local RADIUS = 14
local CAP_TOP = 0.7
local WALL_REACH = 0.86
-- The side's depth, the depth over which its reach halves, and the share of
-- the reach it levels out at.
local PROFILE_DEPTH, HALF_DEPTH = 16, 4
local UNDERSIDE_SHARE = 0.4
local PROFILE_STEPS = 24
local ANGLES = 96

-- The island's wobbly outline, as a radius scale per angle.
local function outlineScale(angle: number): number
	local sector = (angle + math.pi / 8) % (math.pi / 4) - math.pi / 8
	local wobble = 0.07 * math.sin(3 * angle + 0.6) + 0.05 * math.sin(5 * angle + 2.1) + 0.03 * math.sin(9 * angle)
	return 1 / math.cos(sector * 0.85) + 0.2 * wobble
end

-- The profile as { share of the reach, height } points from the top rim down
-- the side. The share halves every HALF_DEPTH studs, so the side bows inward
-- and eases out to the underside.
local profile = {}
for i = 0, PROFILE_STEPS do
	local depth = PROFILE_DEPTH * i / PROFILE_STEPS
	local share = UNDERSIDE_SHARE + (1 - UNDERSIDE_SHARE) * 2 ^ (-depth / HALF_DEPTH)
	table.insert(profile, { share, CAP_TOP - depth })
end

part("Body", nil, { 0.3, 0.27, 0.22 }, function(mesh)
	-- One ring of vertices per profile point, scaled by the island's outline.
	local rings = {}
	for p, point in profile do
		local ring = {}
		for j = 0, ANGLES - 1 do
			local angle = 2 * math.pi * j / ANGLES
			local r = RADIUS * WALL_REACH * point[1] * outlineScale(angle)
			ring[j] = mesh:vertex(r * math.cos(angle), r * math.sin(angle), point[2])
		end
		rings[p] = ring
	end
	-- Each band between two rings is a quad strip, split into two triangles.
	for p = 1, #profile - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			local upper, lower = rings[p], rings[p + 1]
			local quads = { { upper[j], lower[j], lower[l] }, { upper[j], lower[l], upper[l] } }
			for _, tri in quads do
				mesh:face(tri)
			end
		end
	end
	-- The top and the underside are flat discs, fanned from the axis.
	local top = mesh:vertex(0, 0, profile[1][2])
	local bottom = mesh:vertex(0, 0, profile[#profile][2])
	for j = 0, ANGLES - 1 do
		local l = (j + 1) % ANGLES
		mesh:face({ top, rings[1][j], rings[1][l] })
		mesh:face({ bottom, rings[#profile][l], rings[#profile][j] })
	end
end, 0, 0.6)

finishParts()
