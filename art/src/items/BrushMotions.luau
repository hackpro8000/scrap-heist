-- A test sheet for the edge highlight motions: one block per `litMotion`.
useTexelDensity(40)

local STEEL = { 0.3, 0.32, 0.37 }
local SPACING = 8
local MOTIONS = { "press", "worn", "skip", "feather", "flick", "zigzag", "retrace", "twist", "drag_off", "scrub", "overshoot", "tremble", "crosshatch", "stipple", "loops" }

for index, motion in MOTIONS do
	local x = (index - 1) * SPACING
	part(motion, nil, STEEL, function(mesh)
		box(mesh, x, 0, 0, 4, 3, 2)
	end, nil, function(_x, _y, _z)
		return STEEL[1], STEEL[2], STEEL[3]
	end, nil, nil, true, 0.15)
	local entry = parts[#parts]
	entry.painted, entry.blend, entry.taper, entry.hand = true, 0.65, 1.2, "metal"
	entry.litToZero, entry.litMotion = true, motion
end

finishParts()
