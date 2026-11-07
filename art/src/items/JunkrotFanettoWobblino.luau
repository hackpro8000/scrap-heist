-- Fanetto Wobblino: a desk fan, a domed base with three push buttons on
-- its slope, a neck up to the motor, a wire cage of front and back rings
-- tied by ribs with spokes to a badge in the middle, three pitched blades
-- inside; the cage bent in on one side and the head nodding forward. 3.5
-- studs tall.
-- include: JunkrotKit
local FACE = { { -0.25, -0.7, 0.98, 0.17 }, { 0.25, -0.7, 1.0, 0.17 } }
local FEET = { 0.9, 0.5 }
local FAN_BLUE = { 0.36, 0.56, 0.66 }
local BASE = 0.55
local HEAD = 2.45 -- the cage's middle
local NOD = 12 -- degrees the head tips forward
-- Puts a head piece, built about the cage's middle facing -y, in place.
local function onHead(m)
	Kit.turn(m, "x", NOD)
	m:translate(0, 0.05, HEAD)
	return m
end
-- The cage bent in at its upper right.
local function bent(m)
	return m:transform(function(p)
		if p[1] > 0.35 and p[3] > 0.2 then
			return { p[1] * 0.93, p[2], p[3] * 0.95 }
		end
		return p
	end)
end
part("Base", nil, FAN_BLUE, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.82, 0 }, { 0.84, 0.08 }, { 0.72, 0.4 }, { 0.4, 0.58 }, { 0, 0.62 } }, 24)
	m:translate(0, 0, BASE)
	m:emit(mesh)
	Kit.tube({ { 0, 0, BASE + 0.55 }, { 0, 0.3, HEAD - 0.6 }, { 0, 0.4, HEAD - 0.25 } }, 0.1, 8):emit(mesh)
end, true, 0.5)
part("Motor", nil, FAN_BLUE, function(mesh)
	local m = EditMesh.capsule(0.32, 0.3, 12)
	Kit.turn(m, "x", 90)
	m:translate(0, 0.45, 0)
	onHead(m):emit(mesh)
	-- Buttons on the base's slope.
	for k = -1, 1 do
		local b = Kit.block(0.14, 0.12, 0.1, 0.03)
		Kit.turn(b, "x", -40)
		b:translate(k * 0.22, -0.62, BASE + 0.32)
		b:emit(mesh)
	end
end, true, 0.5)
part("Cage", nil, BARE_METAL, function(mesh)
	for _, ring in { { 0.95, -0.15 }, { 0.85, 0.25 } } do
		local m = EditMesh.torus(ring[1], 0.035, 32, 6)
		Kit.turn(m, "x", 90)
		m:translate(0, ring[2], 0)
		onHead(bent(m)):emit(mesh)
	end
	for k = 0, 7 do
		local a = math.rad(k * 45)
		local c, s = math.cos(a), math.sin(a)
		local rib = Kit.tube({ { c * 0.95, -0.15, s * 0.95 }, { c * 1.0, 0.05, s * 1.0 }, { c * 0.85, 0.25, s * 0.85 } }, 0.025, 4)
		onHead(bent(rib)):emit(mesh)
	end
	for k = 0, 5 do
		local a = math.rad(k * 60 + 15)
		local spoke = Kit.tube({ { math.cos(a) * 0.15, -0.17, math.sin(a) * 0.15 }, { math.cos(a) * 0.95, -0.15, math.sin(a) * 0.95 } }, 0.02, 4)
		onHead(bent(spoke)):emit(mesh)
	end
	local badge = Kit.lathe({ { 0, 0 }, { 0.16, 0 }, { 0.14, 0.04 }, { 0, 0.05 } }, 12)
	Kit.turn(badge, "x", 90)
	badge:translate(0, -0.17, 0)
	onHead(badge):emit(mesh)
end, true, 0.4)
part("Blades", nil, { 0.85, 0.83, 0.75 }, function(mesh)
	for k = 0, 2 do
		local blade = Kit.plate({ { -0.1, 0.1 }, { 0.1, 0.1 }, { 0.28, 0.6 }, { 0, 0.8 }, { -0.25, 0.6 } }, 0.03)
		Kit.turn(blade, "z", 18)
		Kit.turn(blade, "y", 120 * k)
		blade:translate(0, 0.02, 0)
		onHead(blade):emit(mesh)
	end
	local hub = Kit.lathe({ { 0, 0 }, { 0.14, 0 }, { 0.1, 0.1 }, { 0, 0.12 } }, 12)
	Kit.turn(hub, "x", 90)
	hub:translate(0, 0, 0)
	onHead(hub):emit(mesh)
end, true, 0.3)
-- include: JunkrotFace
