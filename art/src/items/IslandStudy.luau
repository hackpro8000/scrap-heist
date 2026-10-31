-- Island Study: step 1 of the island generator, the body only.
-- A flat-topped solid: the outline wobbles and takes one shallow bay, the wall
-- bows inward as it falls, and the underside closes on a small flat cap. No
-- rocks, no paint layers, no props yet; everything later hangs off this shape.
local SEED = 1
local RADIUS = 30
-- How deep the underside hangs, as a share of the radius.
local DEPTH_SHARE = 0.5
-- The top's height, matching the other islands so sea level stays at 0.
local CAP_TOP = 0.7
-- How far the outline moves in and out, as a share of the radius.
local WOBBLE = 0.08
-- The bay: how far it cuts in and how wide (radians) it is.
local BAY_DEPTH, BAY_WIDTH = 0.09, 0.5
-- The wall's reach at the rim, and the share it narrows to at the underside.
local WALL_REACH, UNDERSIDE_SHARE = 0.86, 0.34
local ANGLES, STEPS = 128, 28
local TAU = 2 * math.pi

-- A stable 0..1 number from `k`, so each seed picks its own wobble.
local function hash(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local phase = {}
for i = 1, 4 do
	phase[i] = hash(SEED * 7 + i) * TAU
end
local bayAngle = hash(SEED * 13) * TAU

-- The outline as a radius scale per angle: a sum of waves, so no two seeds
-- share an island, and one gaussian dip for the bay.
local function outlineScale(angle: number): number
	local wobble = 0.045 * math.sin(2 * angle + phase[1])
		+ 0.025 * math.sin(3 * angle + phase[2])
		+ 0.012 * math.sin(7 * angle + phase[3])
		+ 0.008 * math.sin(11 * angle + phase[4])
	-- The short way round from the bay's centre to this angle.
	local d = (angle - bayAngle + math.pi) % TAU - math.pi
	local bay = BAY_DEPTH * math.exp(-((d / BAY_WIDTH) ^ 2))
	return 1 + WOBBLE * wobble / 0.09 - bay
end

local DEPTH = RADIUS * DEPTH_SHARE
local RIM_Z = CAP_TOP - DEPTH

-- The wall's reach at each depth step: a cosine from the rim out to the
-- underside, so it leaves the rim vertically and meets the underside flat
-- instead of pulling in sharply under the top like a stem.
local profile = {}
for i = 0, STEPS do
	local t = i / STEPS
	local share = UNDERSIDE_SHARE + (1 - UNDERSIDE_SHARE) * (0.5 + 0.5 * math.cos(math.pi * t))
	table.insert(profile, { share, CAP_TOP - DEPTH * t })
end

part("Body", nil, { 0.33, 0.3, 0.26 }, function(mesh)
	-- One ring per profile step, the outline scaling every ring alike.
	local rings = {}
	for p, point in profile do
		local ring = {}
		for j = 0, ANGLES - 1 do
			local angle = TAU * j / ANGLES
			local r = RADIUS * WALL_REACH * point[1] * outlineScale(angle)
			ring[j] = mesh:vertex(r * math.cos(angle), r * math.sin(angle), point[2])
		end
		rings[p] = ring
	end
	-- Two triangles per quad between neighbouring rings.
	for p = 1, #profile - 1 do
		for j = 0, ANGLES - 1 do
			local l = (j + 1) % ANGLES
			local upper, lower = rings[p], rings[p + 1]
			mesh:face({ upper[j], lower[j], lower[l] })
			mesh:face({ upper[j], lower[l], upper[l] })
		end
	end
	-- The top and the underside are flat discs, fanned from the axis.
	local top = mesh:vertex(0, 0, CAP_TOP)
	local bottom = mesh:vertex(0, 0, RIM_Z)
	for j = 0, ANGLES - 1 do
		local l = (j + 1) % ANGLES
		mesh:face({ top, rings[1][j], rings[1][l] })
		mesh:face({ bottom, rings[#profile][l], rings[#profile][j] })
	end
end, nil, 0)

finishParts()
