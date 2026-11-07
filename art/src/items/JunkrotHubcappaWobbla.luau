-- Hubcappa Wobbla: a chrome hubcap standing on edge, domed out toward us
-- with a rolled lip round its rim, ten vent slots pressed in round it, a
-- red centre cap, and buckled in on one side. 2.9 studs tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.38, 1.95, 0.2 }, { 0.3, -0.38, 1.97, 0.2 } }
local FEET = { 0.9, 0.55 }
local MID = 1.7
part("Disc", nil, BARE_METAL, function(mesh)
	-- Lathed with its dome up (+z), then stood up facing us.
	local m = Kit.lathe({
		{ 0, 0.16 },
		{ 0.3, 0.14 },
		{ 0.6, 0.08 },
		{ 0.95, -0.04 },
		{ 1.1, -0.06 },
		{ 1.12, 0 },
		{ 1.08, 0.04 },
		{ 0.9, 0.12 },
		{ 0.62, 0.24 },
		{ 0.35, 0.31 },
		{ 0, 0.34 },
	}, 20)
	-- Vent slots: every other face round the middle of the dome.
	local slots = m:select("face", "where", function(p)
		local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
		local sector = math.floor((math.deg(math.atan2(p[2], p[1])) % 360) / 18)
		return p[3] > 0.15 and r > 0.45 and r < 0.8 and sector % 2 == 0
	end)
	if slots:count() > 0 then
		Kit.recess(m, slots, 0.03, 0.06)
	end
	-- Buckled in on one side.
	m:transform(function(p)
		local dent = math.clamp((p[1] - 0.55) / 0.5, 0, 1)
		return { p[1], p[2], p[3] - 0.1 * dent }
	end)
	Kit.turn(m, "x", 90)
	m:translate(0, 0, MID)
	m:emit(mesh)
end, 40, 0.55)
part("Cap", nil, { 0.75, 0.18, 0.14 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.28, 0 }, { 0.24, 0.08 }, { 0, 0.12 } }, 16)
	Kit.turn(m, "x", 90)
	m:translate(0, -0.32, MID)
	m:emit(mesh)
end, true, 0.4)
-- include: JunkrotFace
