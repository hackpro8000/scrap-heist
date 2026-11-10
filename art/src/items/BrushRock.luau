-- A test for the brush strokes: the same stylized boulder with the current coat
-- on the left and the hand-painted coat on the right, then a hand-painted plank
-- and steel plate behind them.
useTexelDensity(40)

local ROCK = { 0.46, 0.44, 0.42 }
local OFFSET = 4.2

-- Sphere vertices pushed in and out, so its facets read as chunky rock planes.
local function rockFaces(mesh, cx: number)
	return {
		vertex = function(_self, x: number, y: number, z: number)
			local dx, dy, dz = x - cx, y, z - 2.2
			local k = 1 + 0.14 * math.sin(dx * 1.7 + dz * 1.1) + 0.12 * math.sin(dy * 2.1 - dx * 0.9 + 1.3) + 0.08 * math.sin(dz * 2.7 + dy * 1.4)
			return mesh:vertex(cx + dx * k, dy * k, 2.2 + dz * k)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end

local function boulder(name: string, cx: number)
	part(name, nil, ROCK, function(mesh)
		sphere(rockFaces(mesh, cx), cx, 0, 2.2, 3, 2.5, 2.2, 7, 12)
	end, nil, function(x, y, z)
		local k = 0.9 + 0.2 * math.noise((x - cx) * 0.6, y * 0.6, z * 0.6) + 0.08 * z
		return ROCK[1] * k, ROCK[2] * k, ROCK[3] * k
	end, nil, nil, true, 0.2)
	local entry = parts[#parts]
	entry.painted, entry.blend, entry.taper = true, 0.65, 0.6
end

-- Two layers of edge highlight: a wide one that fades away from the edge, and on
-- top a narrow, hard-edged one that tapers along it.
local function softEdges()
	local entry = parts[#parts]
	entry.softLit, entry.softEdge, entry.softUneven, entry.softTaper = 0.5, 0.8, 0, 1
	entry.softToZero, entry.softPower = true, 2
	entry.edge, entry.wide, entry.taper = 0.085, 1.4, 0.6
	entry.litUneven, entry.litUnevenStep = 0.8, 0.5
	entry.litToZero = true
end

boulder("Current", -OFFSET)
boulder("Hand", OFFSET)
parts[#parts].hand = "rock"
softEdges()

local function slab(name: string, color, x: number, sx: number, sz: number, hand: string)
	part(name, nil, color, function(mesh)
		box(mesh, x, 9, 0, sx, 1, sz)
	end, nil, function(_x, _y, _z)
		return color[1], color[2], color[3]
	end, nil, nil, true, 0.15)
	local entry = parts[#parts]
	entry.painted, entry.blend, entry.taper, entry.hand = true, 0.65, 0.6, hand
	softEdges()
end
slab("Plank", { 0.46, 0.33, 0.2 }, -OFFSET, 7, 2, "wood")
slab("Plate", { 0.42, 0.45, 0.5 }, OFFSET, 6, 4, "metal")

finishParts()
