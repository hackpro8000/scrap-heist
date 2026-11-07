-- Boltolo Lonelo: one lost bolt standing on its shank, a chamfered hex
-- head up top on its washer face, a hex nut wound halfway up the plain
-- shank, and the shank's end chamfered where it meets the ground. 2.8
-- studs tall.
-- include: JunkrotKit
local FACE = { { -0.21, -0.74, 2.33, 0.18 }, { 0.21, -0.74, 2.35, 0.19 } }
local FEET = { 0.5, 0.55 }
local SHANK = 0.6 -- where the shank starts
local HEAD = 2.05 -- where the head starts
part("Shank", nil, STEEL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.28, 0 }, { 0.34, 0.06 }, { 0.34, HEAD - SHANK }, { 0, HEAD - SHANK } }, 16)
	m:translate(0, 0, SHANK)
	m:emit(mesh)
end, 40, 0.6)
part("Nut", nil, DARK_STEEL, function(mesh)
	-- Six sides: a lathe with six steps round is a hex, a flat to the front.
	local m = Kit.lathe({ { 0, 0 }, { 0.5, 0 }, { 0.58, 0.05 }, { 0.58, 0.28 }, { 0.5, 0.33 }, { 0, 0.33 } }, 6)
	m:translate(0, 0, SHANK + 0.45)
	m:emit(mesh)
end, 20, 0.65)
part("Head", nil, STEEL, function(mesh)
	local washer = Kit.lathe({ { 0, 0 }, { 0.62, 0 }, { 0.62, 0.05 }, { 0, 0.05 } }, 20)
	washer:translate(0, 0, HEAD)
	washer:emit(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.78, 0 }, { 0.78, 0.42 }, { 0.64, 0.55 }, { 0, 0.55 } }, 6)
	m:translate(0, 0, HEAD + 0.05)
	m:emit(mesh)
end, 20, 0.7)
-- include: JunkrotFace
