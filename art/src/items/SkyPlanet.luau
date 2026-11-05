-- Sky Planet: the pastel banded giant that fills a corner of the sky, with
-- its ring system. The sphere is two hemispheres so each gets a full
-- texture; the ring is six flat bands with gaps between them. 10 studs in
-- radius, spinning about z; the game scales it up a few hundred times.
-- include: SkyBody

local PASTEL = {
	{ 0.8, 0.76, 0.97 },
	{ 1, 0.8, 0.66 },
	{ 1, 0.95, 0.8 },
	{ 0.98, 0.7, 0.78 },
	{ 0.72, 0.84, 1 },
	{ 1, 0.88, 0.62 },
	{ 0.66, 0.9, 0.86 },
	{ 0.93, 0.74, 0.95 },
	{ 1, 0.96, 0.86 },
	{ 1, 0.74, 0.6 },
	{ 0.74, 0.8, 1 },
	{ 0.99, 0.84, 0.88 },
	{ 0.7, 0.9, 0.9 },
	{ 1, 0.9, 0.7 },
	{ 0.84, 0.74, 0.97 },
	{ 0.98, 0.78, 0.72 },
	{ 0.76, 0.86, 1 },
	{ 0.86, 0.8, 0.98 },
}
local look = {
	bands = PASTEL,
	seed = 41,
	storms = 5,
	deep = { 0.5, 0.42, 0.74 },
	pole = { 0.8, 0.8, 0.98 },
	shadow = -0.04,
}
local RINGS, SIDES = 32, 64
local paint = bandedPainter(look, 0, 0, 0)

bakeBody("North", 1024, function(mesh)
	sphereRows(mesh, 0, 0, 0, BODY_RADIUS, RINGS, SIDES, 0, RINGS // 2)
end, paint)
bakeBody("South", 1024, function(mesh)
	sphereRows(mesh, 0, 0, 0, BODY_RADIUS, RINGS, SIDES, RINGS // 2, RINGS)
end, paint)

local RING_COLORS = { { 1, 0.95, 0.82 }, { 0.92, 0.82, 1 }, { 0.78, 0.92, 1 }, { 1, 0.86, 0.92 }, { 0.9, 0.86, 1 } }
local BANDS = { { 13.4, 14.5 }, { 14.8, 17.3 }, { 17.55, 18.05 }, { 18.5, 20.7 }, { 20.95, 21.35 }, { 21.65, 22.2 } }
bakeBody("Ring", 1024, function(mesh)
	for _, band in BANDS do
		ringBand(mesh, 0, 0, 0, band[1], band[2], 0.05, 96)
	end
end, ringPainter(RING_COLORS, 0, 0, 13.4, 22.2, 3))
