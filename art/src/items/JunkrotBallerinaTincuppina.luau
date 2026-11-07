-- Ballerina Tincuppina: Ballerina Cappuccina bent from scrap. A dented tin
-- mug for a head, coffee and a dome of foam in it, its handle out to one
-- side, on a slim pink tin bodice; a tutu of crumpled pink foil; fence-wire
-- arms curved up over her head, and wire legs, up on one pointe with the
-- other knee drawn up in a retire. No googly face: the mug is her head.
-- Built stocky so she reads at a distance. 4.1 studs tall.
-- include: JunkrotKit
local PINK = { 0.95, 0.62, 0.72 }
local HEAD = 3.05 -- the mug's base
local WAIST = 2.12
-- Every piece widened about the middle, so she reads at a distance.
local function stout(m)
	return Kit.size(m, { 1.35, 1.35, 1 })
end
part("Mug", nil, { 0.85, 0.87, 0.9 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.3, 0 }, { 0.34, 0.04 }, { 0.42, 0.55 }, { 0.44, 0.6 }, { 0.39, 0.6 }, { 0.36, 0.5 }, { 0, 0.5 } }, 20)
	-- Dented on one side.
	m:select("vertex", "where", function(p)
		return p[1] < -0.25 and p[3] > 0.15 and p[3] < 0.45
	end):move({ 0.06, 0, 0 }, 0.12)
	m:translate(0, 0, HEAD)
	stout(m):emit(mesh)
	local handle = Kit.curve({ { 0.36, 0, HEAD + 0.45 }, { 0.6, 0, HEAD + 0.44 }, { 0.64, 0, HEAD + 0.22 }, { 0.36, 0, HEAD + 0.14 } }, 3)
	stout(Kit.tube(handle, 0.045, 8)):emit(mesh)
end, 40, 0.25)
part("Coffee", nil, { 0.36, 0.22, 0.12 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.37, 0 }, { 0.37, 0.02 }, { 0, 0.02 } }, 20)
	m:translate(0, 0, HEAD + 0.5)
	stout(m):emit(mesh)
end, 40, 0)
part("Foam", nil, { 0.95, 0.9, 0.8 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.3, 0 }, { 0.27, 0.07 }, { 0.15, 0.13 }, { 0, 0.15 } }, 20)
	m:translate(0, 0, HEAD + 0.51)
	stout(m):emit(mesh)
end, true, 0)
part("Bodice", nil, PINK, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.2, 0 }, { 0.26, 0.15 }, { 0.19, 0.42 }, { 0.26, 0.72 }, { 0.3, 0.84 }, { 0.16, 0.95 }, { 0, 0.97 } }, 16)
	m:translate(0, 0, WAIST - 0.05)
	stout(m):emit(mesh)
end, true, 0.15)
part("Tutu", nil, { 0.97, 0.78, 0.86 }, function(mesh)
	local m = EditMesh.cylinder(0.85, 0.14, 32, 1)
	-- Crumpled foil: the rim rises and falls all the way round and droops.
	m:transform(function(p)
		local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
		local a = math.atan2(p[2], p[1])
		local lift = math.clamp((r - 0.3) / 0.55, 0, 1)
		return { p[1], p[2], p[3] + lift * (0.07 * math.sin(a * 9) - 0.12 * lift) }
	end)
	m:translate(0, 0, WAIST + 0.05)
	stout(m):emit(mesh)
end, true, 0.05)
part("Wire", nil, DARK_STEEL, function(mesh)
	-- Neck, arms rounded up over the head to meet, and legs.
	stout(Kit.tube({ { 0, 0, HEAD - 0.12 }, { 0, 0, HEAD + 0.05 } }, 0.07, 8)):emit(mesh)
	for _, side in { -1, 1 } do
		local arm = Kit.curve({
			{ side * 0.26, 0, HEAD - 0.2 },
			{ side * 0.62, -0.05, HEAD + 0.15 },
			{ side * 0.62, -0.1, HEAD + 0.72 },
			{ side * 0.3, -0.1, HEAD + 1.0 },
			{ side * 0.02, -0.1, HEAD + 1.04 },
		}, 4)
		stout(Kit.tube(arm, 0.055, 8)):emit(mesh)
	end
	stout(Kit.tube({ { -0.1, 0, WAIST }, { -0.1, 0, 1.1 }, { -0.08, -0.02, 0.28 } }, 0.06, 8)):emit(mesh)
	stout(Kit.tube(Kit.curve({ { 0.1, 0, WAIST }, { 0.45, -0.1, 1.55 }, { 0.02, -0.05, 1.2 } }, 4), 0.06, 8)):emit(mesh)
end, true, 0.3)
part("Slippers", nil, PINK, function(mesh)
	-- Up on pointe: the standing shoe toe-down, the raised one at her knee.
	local standing = EditMesh.capsule(0.085, 0.22, 8)
	standing:translate(-0.08, -0.02, 0.2)
	stout(standing):emit(mesh)
	local raised = EditMesh.capsule(0.08, 0.18, 8)
	Kit.turn(raised, "y", 70)
	raised:translate(0, -0.05, 1.18)
	stout(raised):emit(mesh)
end, true, 0.1)
finishParts()
