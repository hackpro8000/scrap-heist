-- Kettlina Dentata: a dented stovetop kettle, a wide-bottomed enamel body
-- knocked in on its front left, its spout drawn out of the side in crooked
-- steps, a domed lid with a knob, and a wire handle arched over the top on
-- two ears with a grip wrapped round its middle. 2.9 studs tall.
-- include: JunkrotKit
local FACE = { { -0.34, -0.99, 1.35, 0.24 }, { 0.34, -0.97, 1.38, 0.25 } }
local FEET = { 0.9, 0.55 }
local ENAMEL = { 0.5, 0.56, 0.6 }
local BASE = 0.6
local TOP = BASE + 1.22
part("Body", nil, ENAMEL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.9, 0 }, { 1.02, 0.12 }, { 1.06, 0.45 }, { 0.95, 0.85 }, { 0.68, 1.12 }, { 0.48, 1.22 }, { 0, 1.24 } }, 24)
	local spout = m:select("face", "facing", { 1, 0, 0 }, 25):filter(function(p)
		return p[3] > 0.45 and p[3] < 0.85
	end)
	for step = 1, 3 do
		spout = m:extrude(spout, { 0.17, if step == 2 then -0.05 else 0.02, 0.06 + 0.04 * step })
		spout:scale(0.74)
	end
	-- Knocked in on the front left.
	m:select("vertex", "where", function(p)
		return p[1] < -0.5 and p[2] < -0.4 and p[3] > 0.3 and p[3] < 0.8
	end):move({ 0.1, 0.08, 0 }, 0.3)
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, true, 0.7)
part("Lid", nil, DARK_STEEL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.5, 0 }, { 0.45, 0.12 }, { 0.25, 0.2 }, { 0.12, 0.22 }, { 0.1, 0.32 }, { 0.14, 0.36 }, { 0, 0.38 } }, 16)
	m:translate(0, 0, TOP - 0.02)
	m:emit(mesh)
end, true, 0.5)
part("Handle", nil, DARK_STEEL, function(mesh)
	local path = Kit.curve({ { -0.58, 0, TOP - 0.15 }, { -0.5, 0, TOP + 0.5 }, { 0, 0, TOP + 0.78 }, { 0.5, 0, TOP + 0.5 }, { 0.58, 0, TOP - 0.15 } }, 4)
	Kit.tube(path, 0.05, 6):emit(mesh)
	for _, side in { -1, 1 } do
		local ear = Kit.block(0.12, 0.16, 0.2, 0.03)
		ear:translate(side * 0.6, 0, TOP - 0.18)
		ear:emit(mesh)
	end
end, true, 0.5)
part("Grip", nil, RUBBER_BLACK, function(mesh)
	local path = Kit.curve({ { -0.3, 0, TOP + 0.71 }, { 0, 0, TOP + 0.78 }, { 0.3, 0, TOP + 0.71 } }, 3)
	Kit.tube(path, 0.09, 8):emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
