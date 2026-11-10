-- A test sheet for brush motions on every layer: one block per layer.
useTexelDensity(40)

local STEEL = { 0.42, 0.44, 0.48 }
local SPACING = 8

local function block(index: number, name: string, rust: number?, extra: ((mesh: any, x: number) -> ())?)
	local x = (index - 1) * SPACING
	-- Reads `index` so each block keeps a paint function, and rust, of its own.
	local function paint(_x, _y, _z)
		return STEEL[1] + index * 0, STEEL[2], STEEL[3]
	end
	part(name, nil, STEEL, function(mesh)
		box(mesh, x, 0, 0, 4, 3, 2)
		if extra then
			extra(mesh, x)
		end
	end, nil, if rust then rusting(rust, paint) else paint, nil, nil, true, 0.15)
	return parts[#parts], x
end

local shade = block(1, "shade", nil, function(mesh, x)
	box(mesh, x, 0, 2, 2, 1.4, 0.8)
end)
shade.brushes = { shade = { motion = "feather" } }

local soft = block(2, "soft")
soft.softLit, soft.softEdge = 0.6, 0.7
soft.brushes = { soft = { motion = "zigzag" } }

local coat = block(3, "coat")
coat.brushes = { coat = { motion = "scrub" } }

local handCoat = block(4, "hand_coat")
handCoat.hand, handCoat.litMotion = "rock", false
handCoat.brushes = { coat = { motion = "twist" } }

local rust = block(5, "rust", 0.9)
rust.brushes = { rust = { motion = "scrub", tune = { length = 0.03, pitch = 0.025, spread = 0.09 } } }

local drip = block(6, "drip", 0.9)
drip.brushes = { drip = { motion = "tremble" } }

local scratch = block(7, "scratch", 0.6)
scratch.brushes = { scratch = { motion = "zigzag" } }

local list, listX = block(8, "strokes")
local function line(z: number, motion: string)
	return { start = { listX - 1.7, -1.5, z }, along = { 1, 0, 0 }, normal = { 0, -1, 0 }, length = 3.4, width = 0.16, color = { 0.92, 0.86, 0.68 }, motion = motion }
end
list.strokes = { line(1.6, "retrace"), line(1, "zigzag"), line(0.4, "flick") }

local edge = block(9, "edge_all")
edge.brushes = { edge = { motion = "press", tune = { taper = 0.8, uneven = 0.6, falloff = 0.5, stamp = 0.7 } } }

finishParts()
