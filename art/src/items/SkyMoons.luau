-- Sky Moons: the moons of the sky, baked as phenotypes of the sky body
-- genotypes: a red-orange cratered moon, two pale cratered moons, and a
-- lavender banded moon with its own ring. Each 10 studs in radius, in a
-- row 40 studs apart for the preview; the game places each on its own.
-- include: SkyBody

local RINGS, SIDES = 16, 32
local SPACING = 40

local function moon(name, index, painterOf)
	local cx = (index - 2.5) * SPACING
	bakeBody(name, 512, function(mesh)
		sphereRows(mesh, cx, 0, 0, BODY_RADIUS, RINGS, SIDES, 0, RINGS)
	end, painterOf(cx))
	return cx
end

moon("RedMoon", 1, function(cx)
	return crateredPainter({
		tones = { { 0.55, 0.2, 0.12 }, { 0.78, 0.33, 0.16 }, { 0.92, 0.47, 0.22 }, { 1, 0.66, 0.38 } },
		seed = 7,
		craters = 26,
	}, cx, 0, 0)
end)

for k = 1, 2 do
	moon("PaleMoon" .. k, 1 + k, function(cx)
		return crateredPainter({
			tones = { { 0.62, 0.66, 0.8 }, { 0.8, 0.83, 0.92 }, { 0.92, 0.94, 0.98 }, { 1, 1, 1 } },
			seed = 20 + k * 9,
			craters = 18 + k * 6,
		}, cx, 0, 0)
	end)
end

local ringed = moon("RingMoon", 4, function(cx)
	return bandedPainter({
		bands = {
			{ 0.7, 0.66, 0.9 },
			{ 0.86, 0.8, 0.97 },
			{ 0.62, 0.7, 0.92 },
			{ 0.92, 0.84, 0.95 },
			{ 0.74, 0.7, 0.94 },
			{ 0.8, 0.88, 0.98 },
			{ 0.68, 0.64, 0.88 },
		},
		seed = 77,
		storms = 2,
		deep = { 0.42, 0.38, 0.68 },
		pole = { 0.86, 0.86, 0.98 },
		shadow = -0.05,
	}, cx, 0, 0)
end)

bakeBody("RingMoonRing", 256, function(mesh)
	ringBand(mesh, ringed, 0, 0, 14, 17.5, 0.05, 64)
	ringBand(mesh, ringed, 0, 0, 18, 20, 0.05, 64)
end, ringPainter({ { 1, 0.92, 0.84 }, { 0.86, 0.84, 1 }, { 0.8, 0.94, 1 } }, ringed, 0, 14, 20, 9))
