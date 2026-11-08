--!strict
--[[
	Clipping check for check.luau. Pieces of different parts whose boxes
	overlap by more than CLIP on every axis are tested on their meshes: the
	vertices of one that lie inside the other (a closed piece; open ones have
	no inside), found by ray parity, and how far the deepest of them sits
	below the other's surface. A pair clips when that depth is over CLIP and
	the buried vertices are more than a sliver: at least SLIVER_COUNT of
	them, or SLIVER_SHARE of the piece's vertices. So a panel resting on a
	ball passes even though its box sinks into the ball's box.
]]
local CLIP = 0.3
local SLIVER_COUNT = 3
local SLIVER_SHARE = 0.05
-- Off every axis, so the ray never runs along an edge or a flat face.
local RAY = { 1, 0.00731, 0.00419 }

export type Vec = { number }
export type Piece = {
	part: string,
	box: { number },
	points: { Vec },
	triangles: { { Vec } },
	closed: boolean,
}

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function along(a: Vec, d: Vec, t: number): Vec
	return { a[1] + d[1] * t, a[2] + d[2] * t, a[3] + d[3] * t }
end

-- Whether the ray from p along RAY crosses triangle abc (Möller–Trumbore).
-- Written out in numbers: it runs millions of times on a big model.
local function crosses(p: Vec, a: Vec, b: Vec, c: Vec): boolean
	local rx, ry, rz = RAY[1], RAY[2], RAY[3]
	local e1x, e1y, e1z = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local e2x, e2y, e2z = c[1] - a[1], c[2] - a[2], c[3] - a[3]
	local hx, hy, hz = ry * e2z - rz * e2y, rz * e2x - rx * e2z, rx * e2y - ry * e2x
	local det = e1x * hx + e1y * hy + e1z * hz
	if math.abs(det) < 1e-12 then
		return false
	end
	local sx, sy, sz = p[1] - a[1], p[2] - a[2], p[3] - a[3]
	local u = (sx * hx + sy * hy + sz * hz) / det
	if u < 0 or u > 1 then
		return false
	end
	local qx, qy, qz = sy * e1z - sz * e1y, sz * e1x - sx * e1z, sx * e1y - sy * e1x
	local v = (rx * qx + ry * qy + rz * qz) / det
	if v < 0 or u + v > 1 then
		return false
	end
	return (e2x * qx + e2y * qy + e2z * qz) / det > 1e-9
end

-- Distance from p to triangle abc (Ericson, Real-Time Collision Detection).
local function distance(p: Vec, a: Vec, b: Vec, c: Vec): number
	local ab, ac, ap = sub(b, a), sub(c, a), sub(p, a)
	local d1, d2 = dot(ab, ap), dot(ac, ap)
	if d1 <= 0 and d2 <= 0 then
		return math.sqrt(dot(ap, ap))
	end
	local bp = sub(p, b)
	local d3, d4 = dot(ab, bp), dot(ac, bp)
	if d3 >= 0 and d4 <= d3 then
		return math.sqrt(dot(bp, bp))
	end
	local vc = d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0 then
		local q = sub(p, along(a, ab, d1 / (d1 - d3)))
		return math.sqrt(dot(q, q))
	end
	local cp = sub(p, c)
	local d5, d6 = dot(ab, cp), dot(ac, cp)
	if d6 >= 0 and d5 <= d6 then
		return math.sqrt(dot(cp, cp))
	end
	local vb = d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0 then
		local q = sub(p, along(a, ac, d2 / (d2 - d6)))
		return math.sqrt(dot(q, q))
	end
	local va = d3 * d6 - d5 * d4
	if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0 then
		local q = sub(p, along(b, sub(c, b), (d4 - d3) / ((d4 - d3) + (d5 - d6))))
		return math.sqrt(dot(q, q))
	end
	local n = cross(ab, ac)
	return math.abs(dot(ap, n)) / math.sqrt(dot(n, n))
end

-- Each triangle's box as {xLow, xHigh, yLow, yHigh, zLow, zHigh}, worked
-- out once per piece.
local boundsCache: { [Piece]: { { number } } } = setmetatable({}, { __mode = "k" }) :: any
local function boundsOf(piece: Piece): { { number } }
	local cached = boundsCache[piece]
	if cached then
		return cached
	end
	local list = table.create(#piece.triangles)
	for index, t in piece.triangles do
		local a, b, c = t[1], t[2], t[3]
		list[index] = {
			math.min(a[1], b[1], c[1]),
			math.max(a[1], b[1], c[1]),
			math.min(a[2], b[2], c[2]),
			math.max(a[2], b[2], c[2]),
			math.min(a[3], b[3], c[3]),
			math.max(a[3], b[3], c[3]),
		}
	end
	boundsCache[piece] = list
	return list
end

-- How deep `inner`'s vertices within `overlap` sit inside `outer`: the
-- deepest one's distance to the surface, or 0 when only a sliver is buried.
local function buried(inner: Piece, outer: Piece, overlap: { number }): number
	if not outer.closed then
		return 0
	end
	local candidates = {}
	for _, p in inner.points do
		local within = true
		for k = 1, 3 do
			if p[k] < overlap[k] or p[k] > overlap[k + 3] then
				within = false
				break
			end
		end
		if within then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		return 0
	end
	-- Rays from the overlap run along X and drift off it by at most `drift`
	-- across the outer piece, so only triangles reaching that slab of Y and
	-- Z can be crossed.
	local drift = (outer.box[4] - outer.box[1]) * math.max(RAY[2], RAY[3]) + 1e-6
	-- Each kept with its reach: highest X, and Y and Z ranges widened by
	-- the drift.
	local bounds = boundsOf(outer)
	local inPath = {}
	for index, t in outer.triangles do
		local box = bounds[index]
		local yLow, yHigh, zLow, zHigh = box[3] - drift, box[4] + drift, box[5] - drift, box[6] + drift
		if yHigh >= overlap[2] and yLow <= overlap[5] and zHigh >= overlap[3] and zLow <= overlap[6] then
			table.insert(inPath, { triangle = t, xHigh = box[2], yLow = yLow, yHigh = yHigh, zLow = zLow, zHigh = zHigh })
		end
	end
	local count, deepest = 0, 0
	for _, p in candidates do
		local crossings = 0
		for _, entry in inPath do
			if entry.xHigh < p[1] or p[2] < entry.yLow or p[2] > entry.yHigh or p[3] < entry.zLow or p[3] > entry.zHigh then
				continue
			end
			local t = entry.triangle
			if crosses(p, t[1], t[2], t[3]) then
				crossings += 1
			end
		end
		if crossings % 2 == 0 then
			continue
		end
		-- The nearest vertex of `outer` lies on its surface, so the surface is
		-- at most that far; a triangle whose box lies further off than the
		-- nearest so far can't be nearer.
		local nearest = math.huge
		for _, q in outer.points do
			local dx, dy, dz = q[1] - p[1], q[2] - p[2], q[3] - p[3]
			nearest = math.min(nearest, dx * dx + dy * dy + dz * dz)
		end
		local surface = math.sqrt(nearest)
		for index, t in outer.triangles do
			local box = bounds[index]
			local gap = math.max(0, box[1] - p[1], p[1] - box[2], box[3] - p[2], p[2] - box[4], box[5] - p[3], p[3] - box[6])
			if gap < surface then
				surface = math.min(surface, distance(p, t[1], t[2], t[3]))
			end
		end
		count += 1
		deepest = math.max(deepest, surface)
	end
	if count < SLIVER_COUNT and count < SLIVER_SHARE * #inner.points then
		return 0
	end
	return deepest
end

-- One line per pair of parts that clips, skipping pairs in `mates`, which
-- are keyed by `key(a, b)`.
local function check(pieces: { Piece }, mates: { [string]: boolean }, key: (string, string) -> string): { string }
	local clips: { [string]: { inner: string, outer: string, depth: number } } = {}
	local order = {}
	for i = 1, #pieces do
		local a = pieces[i]
		for j = i + 1, #pieces do
			local b = pieces[j]
			if a.part == b.part or mates[key(a.part, b.part)] then
				continue
			end
			local overlap, shallowest = {}, math.huge
			for k = 1, 3 do
				overlap[k] = math.max(a.box[k], b.box[k])
				overlap[k + 3] = math.min(a.box[k + 3], b.box[k + 3])
				shallowest = math.min(shallowest, overlap[k + 3] - overlap[k])
			end
			if shallowest <= CLIP then
				continue
			end
			local aDepth, bDepth = buried(a, b, overlap), buried(b, a, overlap)
			local depth = math.max(aDepth, bDepth)
			if depth <= CLIP then
				continue
			end
			local pair = key(a.part, b.part)
			local clip = clips[pair]
			if not clip then
				clip = { inner = a.part, outer = b.part, depth = 0 }
				clips[pair] = clip
				table.insert(order, pair)
			end
			if depth > clip.depth then
				clip.inner = if aDepth >= bDepth then a.part else b.part
				clip.outer = if aDepth >= bDepth then b.part else a.part
				clip.depth = depth
			end
		end
	end
	local lines = {}
	for _, pair in order do
		local clip = clips[pair]
		table.insert(lines, string.format("%s clips into %s by %.2f studs", clip.inner, clip.outer, clip.depth))
	end
	return lines
end

return { check = check }
