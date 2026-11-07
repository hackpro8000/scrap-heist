-- lune run tools/modelcheck/pieces <Name>: every connected piece of every part
-- must reach the ground through a chain of pieces that touch (within GAP).
-- Stricter than check.luau, which tests whole parts: a part like Rivets
-- spans the model, so one loose rivet passes there and fails here.
-- Touching means a vertex of either within GAP of a face of the other, or
-- some of one's vertices inside the other (closed pieces). Two pieces that
-- only cross face through face, no vertex near, are not seen: embed ends
-- (a leg's top inside the body) rather than just passing through.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local name = process.args[1]
local GAP = 0.04
local parts = {}
local function newMesh()
	local mesh = { verts = {}, faces = {} }
	function mesh:vertex(x, y, z) table.insert(self.verts, { x, y, z }) return #self.verts end
	function mesh:face(list) table.insert(self.faces, table.clone(list)) end
	function mesh:setSmooth() end
	function mesh:unwrap() return 1 end
	function mesh:paint() end
	function mesh:paintShading() end
	function mesh:weld() end
	return mesh
end
local env = setmetatable({ Mesh = { new = newMesh }, Image = { new = function() return {} end }, model = { part = function(n, m) table.insert(parts, { name = n, mesh = m }) end }, TEXEL_SCALE = 1 }, { __index = _G })
luau.load(fs.readFile(`art/models/{name}/model.luau`), { environment = env })()

local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function len2(a) return dot(a, a) end
-- Squared distance from point p to triangle abc (Ericson).
local function pointTri(p, a, b, c)
	local ab, ac, ap = sub(b, a), sub(c, a), sub(p, a)
	local d1, d2 = dot(ab, ap), dot(ac, ap)
	if d1 <= 0 and d2 <= 0 then return len2(ap) end
	local bp = sub(p, b)
	local d3, d4 = dot(ab, bp), dot(ac, bp)
	if d3 >= 0 and d4 <= d3 then return len2(bp) end
	local vc = d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0 then
		local v = d1 / (d1 - d3)
		return len2(sub(p, { a[1] + ab[1] * v, a[2] + ab[2] * v, a[3] + ab[3] * v }))
	end
	local cp = sub(p, c)
	local d5, d6 = dot(ab, cp), dot(ac, cp)
	if d6 >= 0 and d5 <= d6 then return len2(cp) end
	local vb = d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0 then
		local w = d2 / (d2 - d6)
		return len2(sub(p, { a[1] + ac[1] * w, a[2] + ac[2] * w, a[3] + ac[3] * w }))
	end
	local va = d3 * d6 - d5 * d4
	if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0 then
		local w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return len2(sub(p, { b[1] + (c[1] - b[1]) * w, b[2] + (c[2] - b[2]) * w, b[3] + (c[3] - b[3]) * w }))
	end
	local n = cross(ab, ac)
	local d = dot(ap, n)
	return d * d / len2(n)
end

-- Pieces: union-find over welded vertex positions.
local function pieces(mesh)
	local canonical, byPos = {}, {}
	for i, p in mesh.verts do
		local key = string.format("%.4f,%.4f,%.4f", p[1], p[2], p[3])
		byPos[key] = byPos[key] or i
		canonical[i] = byPos[key]
	end
	local parent = {}
	local function find(i) while parent[i] and parent[i] ~= i do parent[i] = parent[parent[i]] or parent[i]; i = parent[i] end return i end
	for i in canonical do parent[i] = i end
	for _, f in mesh.faces do
		local r = find(canonical[f[1]])
		for k = 2, #f do
			local r2 = find(canonical[f[k]])
			if r2 ~= r then parent[r2] = r end
		end
	end
	local groups = {}
	for fi, f in mesh.faces do
		local r = find(canonical[f[1]])
		groups[r] = groups[r] or { faces = {}, verts = {}, lo = { 1e9, 1e9, 1e9 }, hi = { -1e9, -1e9, -1e9 } }
		local g = groups[r]
		table.insert(g.faces, f)
		for _, vi in f do
			local p = mesh.verts[vi]
			g.verts[vi] = p
			for k = 1, 3 do g.lo[k] = math.min(g.lo[k], p[k]); g.hi[k] = math.max(g.hi[k], p[k]) end
		end
	end
	return groups
end
-- Every piece of every part, its triangles with bboxes; then pieces that
-- touch (a vertex of one within GAP of a triangle of the other) are joined,
-- and anything not joined, through some chain, to a piece on the ground is
-- loose. A rivet on a plate on the body counts as attached; so does a ridge
-- on a lever of its own part.
local all = {}
for pi, part in parts do
	for _, g in pieces(part.mesh) do
		g.part = part.name
		g.tris = {}
		for _, f in g.faces do
			for k = 2, #f - 1 do
				local a, b, c = part.mesh.verts[f[1]], part.mesh.verts[f[k]], part.mesh.verts[f[k + 1]]
				table.insert(g.tris, { a = a, b = b, c = c,
					lo = { math.min(a[1], b[1], c[1]), math.min(a[2], b[2], c[2]), math.min(a[3], b[3], c[3]) },
					hi = { math.max(a[1], b[1], c[1]), math.max(a[2], b[2], c[2]), math.max(a[3], b[3], c[3]) } })
			end
		end
		table.insert(all, g)
	end
end
local parent = {}
for i in all do
	parent[i] = i
end
local function find(i)
	while parent[i] ~= i do
		parent[i] = parent[parent[i]]
		i = parent[i]
	end
	return i
end
local function near(g, h)
	return g.lo[1] < h.hi[1] + GAP and g.hi[1] > h.lo[1] - GAP and g.lo[2] < h.hi[2] + GAP and g.hi[2] > h.lo[2] - GAP and g.lo[3] < h.hi[3] + GAP and g.hi[3] > h.lo[3] - GAP
end
-- Whether a vertex of g lies within GAP of a triangle of h.
local function reaches(g, h)
	for _, t in h.tris do
		if near(t, g) then
			for _, p in g.verts do
				if p[1] > t.lo[1] - GAP and p[1] < t.hi[1] + GAP and p[2] > t.lo[2] - GAP and p[2] < t.hi[2] + GAP and p[3] > t.lo[3] - GAP and p[3] < t.hi[3] + GAP then
					if pointTri(p, t.a, t.b, t.c) < GAP * GAP then
						return true
					end
				end
			end
		end
	end
	return false
end
-- Either way round: a corner of one may sit on a face of the other without
-- the reverse holding.
local function touches(g, h)
	return reaches(g, h) or reaches(h, g)
end
-- Whether point p lies inside piece h (a ray up +z crossing its
-- triangles an odd number of times; h should be closed).
local function inside(p, h)
	if p[1] < h.lo[1] or p[1] > h.hi[1] or p[2] < h.lo[2] or p[2] > h.hi[2] or p[3] < h.lo[3] or p[3] > h.hi[3] then
		return false
	end
	local crossings = 0
	for _, t in h.tris do
		if p[1] >= t.lo[1] and p[1] <= t.hi[1] and p[2] >= t.lo[2] and p[2] <= t.hi[2] and t.hi[3] >= p[3] then
			local a, b, c = t.a, t.b, t.c
			local d = (b[2] - c[2]) * (a[1] - c[1]) + (c[1] - b[1]) * (a[2] - c[2])
			if math.abs(d) > 1e-12 then
				local l1 = ((b[2] - c[2]) * (p[1] - c[1]) + (c[1] - b[1]) * (p[2] - c[2])) / d
				local l2 = ((c[2] - a[2]) * (p[1] - c[1]) + (a[1] - c[1]) * (p[2] - c[2])) / d
				local l3 = 1 - l1 - l2
				if l1 >= 0 and l2 >= 0 and l3 >= 0 and l1 * a[3] + l2 * b[3] + l3 * c[3] > p[3] then
					crossings += 1
				end
			end
		end
	end
	return crossings % 2 == 1
end
-- A piece reaches into another when a few of its vertices lie inside it.
-- Sampled evenly over the piece (at most 48 vertices), so a leg's foot
-- end is tried, not just its top.
local function within(g, h)
	local list = {}
	for _, p in g.verts do
		table.insert(list, p)
	end
	local step = math.max(1, #list // 48)
	for k = 1, #list, step do
		if inside(list[k], h) then
			return true
		end
	end
	return false
end
local GROUND = #all + 1
parent[GROUND] = GROUND
for i, g in all do
	if g.lo[3] < GAP then
		parent[find(i)] = find(GROUND)
	end
end
for i = 1, #all do
	for j = i + 1, #all do
		if find(i) ~= find(j) and near(all[i], all[j]) and (touches(all[i], all[j]) or within(all[i], all[j]) or within(all[j], all[i])) then
			parent[find(i)] = find(j)
		end
	end
end
local loose = 0
for i, g in all do
	if find(i) ~= find(GROUND) then
		loose += 1
		print(string.format("LOOSE %s piece at x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f (%d faces)", g.part, g.lo[1], g.hi[1], g.lo[2], g.hi[2], g.lo[3], g.hi[3], #g.faces))
	end
end
print(`{name}: {#parts} parts, {loose} loose pieces`)
