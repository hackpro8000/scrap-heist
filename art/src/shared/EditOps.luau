-- Edit Ops: the operations that reshape an Edit Mesh (shared/EditMesh.luau,
-- included first). Include with `-- include: EditOps` after EditMesh.
--
-- Each works on a selection (m:select(...)) or the whole mesh, keeps faces
-- four-sided wherever the input was, keeps a closed surface closed, and
-- returns what it made as a selection so the next step can use it. What
-- it makes is also tagged with the name passed as `tag`, when given.
--
--   extrude(faces, distance | {x, y, z}, options)  faces out, sides between
--   inset(faces, width, depth, options)            a smaller face inside
--   loopCut(edge, cuts, at)                        cuts across a quad ring
--   subdivide(levels)                              each face into quads
--   smoothSubdivide(levels)                        Catmull-Clark, with creases
--   bridge(edgesA, edgesB)                         quads joining two holes
--   bridgeFaces(a, b)                              a tunnel or handle between
--                                                  two faces or regions
--   bevel(edges, width, segments)                  chamfered or rounded edges
--   poke(faces)                                    a point in each face
--   spin / sweep (shared/EditShapes.luau)          lathe and profile sweeps
--   bend, taper, twist(axis...)                    reshape whole or selection
--   smooth(selection, amount, rounds)              relax towards neighbours
--   push(selection, distance)                      along vertex normals
--   toCircle(vertex loop)                          round a loop out
--   toSphere(selection, amount)                    pull towards a sphere
--   dissolve(edges)                                two faces into one
--   weld(distance)                                 merge vertices that touch
--   fill(edges)                                    close a hole with one face
--   mirror(axis, at)                               build one side, get both
--   solidify(thickness)                            give a sheet thickness
--   array(count, offset)                           copies in a row
--   transform(function)                            any reshaping by position

local vec = EditMesh.vec

local function sortedKeys(set)
	local list = {}
	for key in set do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

local function asFaces(m, faces)
	if faces == nil then
		return m:select("face", "all")
	end
	if faces.kind then
		return faces:faces()
	end
	return m:select("face", "ids", faces)
end

local function asVerts(m, selection)
	if selection == nil then
		return m:select("vertex", "all")
	end
	return selection:verts()
end

-- The region's edges that have one side in the region and one out (or no
-- other side), each as {a, b} running the way the region's face runs it.
local function boundaryRuns(m, faces)
	local runs = {}
	for face in faces.ids do
		local verts = m.faces[face].verts
		for index, a in verts do
			local b = verts[index % #verts + 1]
			local edge = m:edge(a, b)
			local inside = 0
			for other in m.edgeFaces[edge] do
				if faces.ids[other] then
					inside += 1
				end
			end
			if inside == 1 then
				table.insert(runs, { a, b, face })
			end
		end
	end
	return runs
end

-- ---------------------------------------------------------------- extrude and inset

-- Copies the region's vertices, moves the region onto the copies, and joins
-- old to new with a side quad on every boundary edge. `place(vert, copy)`
-- positions each copy. Returns the region (same faces) and the side faces.
local function lift(m, faces, place, tag)
	local runs = boundaryRuns(m, faces)
	local copies = {}
	local sides = {}
	-- Inner vertices of the region go when it moves; remember where they were.
	local before = {}
	for vert in faces:verts().ids do
		before[vert] = m.verts[vert].position
	end
	m:rebuilding(function()
		for vert in faces:verts().ids do
			local p = m.verts[vert].position
			copies[vert] = m:addVertex(p[1], p[2], p[3])
		end
		for face in faces.ids do
			local moved = {}
			for index, vert in m.faces[face].verts do
				moved[index] = copies[vert]
			end
			m:replaceFace(face, moved)
		end
		for _, run in runs do
			local a, b = run[1], run[2]
			local side = m:addFace({ a, b, copies[b], copies[a] }, tag and { [tag] = true } or nil)
			sides[side] = true
		end
	end)
	for vert, copy in copies do
		place(before[vert], copy, vert)
	end
	return faces, setmetatable({ mesh = m, kind = "face", ids = sides }, EditMesh.Selection)
end

-- The average normal of a region's faces at each of its vertices, and of
-- the whole region.
local function regionNormals(m, faces)
	local perVert, whole = {}, { 0, 0, 0 }
	for face in faces.ids do
		local n = vec.scale(m:faceNormal(face), m:faceArea(face))
		whole = vec.add(whole, n)
		for _, vert in m.faces[face].verts do
			perVert[vert] = vec.add(perVert[vert] or { 0, 0, 0 }, n)
		end
	end
	for vert, n in perVert do
		perVert[vert] = vec.unit(n)
	end
	return perVert, vec.unit(whole)
end

-- Extrudes faces. `amount` is a distance along the region's normal, or a
-- vector. options.each: every face on its own (default: the region as
-- one). options.along = "vertex": each vertex along its own normal (an
-- inflate). Returns the moved faces and the new side faces.
function EditMesh:extrude(faces, amount, options)
	options = options or {}
	faces = asFaces(self, faces)
	if options.each then
		local tops, sides = {}, {}
		for _, face in sortedKeys(faces.ids) do
			local top, side = self:extrude({ face }, amount, { along = options.along, tag = options.tag })
			for id in top.ids do
				tops[id] = true
			end
			for id in side.ids do
				sides[id] = true
			end
		end
		local Selection = EditMesh.Selection
		return setmetatable({ mesh = self, kind = "face", ids = tops }, Selection),
			setmetatable({ mesh = self, kind = "face", ids = sides }, Selection)
	end
	local perVert, whole = regionNormals(self, faces)
	return lift(self, faces, function(p, copy, vert)
		local offset
		if type(amount) == "table" then
			offset = amount
		elseif options.along == "vertex" then
			offset = vec.scale(perVert[vert], amount)
		else
			offset = vec.scale(whole, amount)
		end
		self.verts[copy].position = vec.add(p, offset)
	end, options.tag)
end

-- For each boundary vertex, the direction into the region along its
-- surface, scaled so an inset of 1 keeps edges 1 apart (mitred corners).
local function insetDirections(m, faces)
	local runs = boundaryRuns(m, faces)
	local into, outOf = {}, {}
	for _, run in runs do
		local a, b, face = run[1], run[2], run[3]
		local d = vec.unit(vec.sub(m.verts[b].position, m.verts[a].position))
		local inward = vec.unit(vec.cross(m:faceNormal(face), d))
		outOf[a] = inward
		into[b] = inward
	end
	local directions = {}
	for vert, before in into do
		local after = outOf[vert] or before
		local sum = vec.add(before, after)
		local denominator = 1 + vec.dot(before, after)
		directions[vert] = if denominator > 1e-6 then vec.scale(sum, 1 / denominator) else before
	end
	return directions
end

-- Insets faces: a smaller copy of the region inside it, `width` in from
-- its edges, raised by `depth` (negative to sink it). options.each: every
-- face on its own. Returns the inner faces and the ring of faces round them.
function EditMesh:inset(faces, width, depth, options)
	options = options or {}
	faces = asFaces(self, faces)
	if options.each then
		local inner, rings = {}, {}
		for _, face in sortedKeys(faces.ids) do
			local a, b = self:inset({ face }, width, depth, { tag = options.tag })
			for id in a.ids do
				inner[id] = true
			end
			for id in b.ids do
				rings[id] = true
			end
		end
		local Selection = EditMesh.Selection
		return setmetatable({ mesh = self, kind = "face", ids = inner }, Selection),
			setmetatable({ mesh = self, kind = "face", ids = rings }, Selection)
	end
	local directions = insetDirections(self, faces)
	local perVert = regionNormals(self, faces)
	return lift(self, faces, function(p, copy, vert)
		local offset = vec.scale(directions[vert] or { 0, 0, 0 }, width)
		offset = vec.add(offset, vec.scale(perVert[vert], depth or 0))
		self.verts[copy].position = vec.add(p, offset)
	end, options.tag)
end

-- ---------------------------------------------------------------- loop cut

-- The quad ring from `edge` in order, each step as {edge, face to the next,
-- sideA}: sideA is the end of the edge on the same side as the first edge's
-- lower end, so cuts line up all the way round.
local function orderedRing(m, edge)
	local function across(face, current, sideA)
		local verts = m.faces[face].verts
		if #verts ~= 4 then
			return nil
		end
		local e = m.edges[current]
		for index, vert in verts do
			local nextVert = verts[index % 4 + 1]
			if (vert == e.a and nextVert == e.b) or (vert == e.b and nextVert == e.a) then
				local c, d = verts[(index + 1) % 4 + 1], verts[(index + 2) % 4 + 1]
				-- d is joined to vert, c to nextVert.
				local nextA = if vert == sideA then d else c
				return m:edge(c, d), nextA
			end
		end
		return nil
	end
	local steps = { { edge = edge, a = m.edges[edge].a } }
	local seen = { [edge] = true }
	local closed = false
	local faces = sortedKeys(m.edgeFaces[edge])
	-- Forward through the first face, then backward through the second.
	for direction, startFace in faces do
		local current, sideA, face = edge, m.edges[edge].a, startFace
		while face do
			local nextEdge, nextA = across(face, current, sideA)
			if not nextEdge then
				break
			end
			if seen[nextEdge] then
				closed = nextEdge == edge
				if closed then
					-- The face that comes back round to the first edge.
					steps[1].via = face
				end
				break
			end
			seen[nextEdge] = true
			-- `via` is always the face between a step and the one before it.
			if direction == 1 then
				table.insert(steps, { edge = nextEdge, a = nextA, via = face })
			else
				steps[1].via = face
				table.insert(steps, 1, { edge = nextEdge, a = nextA })
			end
			local following = nil
			for other in m.edgeFaces[nextEdge] do
				if other ~= face then
					following = other
				end
			end
			current, sideA, face = nextEdge, nextA, following
		end
		if closed then
			break
		end
	end
	return steps, closed
end

-- Cuts `cuts` new edge loops across the quad ring through `edge`, evenly
-- spaced or at the fractions in `at` (measured from one side of the ring).
-- Returns the new edges.
function EditMesh:loopCut(edge, cuts, at)
	cuts = cuts or 1
	if not at then
		at = {}
		for k = 1, cuts do
			at[k] = k / (cuts + 1)
		end
	end
	table.sort(at)
	local steps, closed = orderedRing(self, edge)
	-- Split every edge of the ring at the fractions, from its side A.
	local made = {}
	for index, step in steps do
		local e = self.edges[step.edge]
		local other = if e.a == step.a then e.b else e.a
		local points = {}
		local remaining, from = step.edge, step.a
		local done = 0
		for k, t in at do
			-- Each split shortens what's left; rescale the fraction to it.
			local local_t = (t - done) / (1 - done)
			local re = self.edges[remaining]
			local frac = if re.a == from then local_t else 1 - local_t
			local middle = self:splitEdge(remaining, frac)
			points[k] = middle
			remaining = self:edge(middle, other)
			from = middle
			done = t
		end
		made[index] = points
	end
	-- Connect matching points across each quad of the ring: between each
	-- step and the next, and from the last back to the first if it closes.
	local newEdges = {}
	local function join(from, to)
		for k = 1, #at do
			local a, b = made[from][k], made[to][k]
			local shared = nil
			for candidate in self.vertFaces[a] do
				if self.vertFaces[b][candidate] then
					shared = candidate
				end
			end
			if shared and not self:edge(a, b) then
				self:connect(shared, a, b)
				newEdges[self:edge(a, b)] = true
			end
		end
	end
	for index = 1, #steps - 1 do
		join(index, index + 1)
	end
	if closed and #steps > 2 then
		join(#steps, 1)
	end
	return setmetatable({ mesh = self, kind = "edge", ids = newEdges }, EditMesh.Selection)
end

-- ---------------------------------------------------------------- subdivision

-- One level of splitting every face into quads: a point in the middle of
-- each face and each edge. `smooth` positions them by Catmull-Clark,
-- honouring edge creases (1 keeps an edge sharp, between blends).
local function subdivideOnce(m, smooth)
	local facePoint, edgePoint = {}, {}
	local oldFaces = sortedKeys(m.faces)
	local oldEdges = sortedKeys(m.edges)
	local oldVerts = sortedKeys(m.verts)
	local creases, faceTags = {}, {}
	for _, face in oldFaces do
		facePoint[face] = m:faceCentre(face)
		faceTags[face] = table.clone(m.faces[face].tags)
	end
	local edgePosition = {}
	for _, edge in oldEdges do
		local e = m.edges[edge]
		local a, b = m.verts[e.a].position, m.verts[e.b].position
		local middle = vec.lerp(a, b, 0.5)
		local p = middle
		local faces = sortedKeys(m.edgeFaces[edge])
		if smooth and #faces == 2 then
			local soft = vec.scale(vec.add(vec.add(a, b), vec.add(facePoint[faces[1]], facePoint[faces[2]])), 0.25)
			p = vec.lerp(soft, middle, e.crease)
		end
		edgePosition[edge] = p
		creases[edge] = e.crease
	end
	local vertPosition = {}
	for _, vert in oldVerts do
		local p = m.verts[vert].position
		if not smooth then
			vertPosition[vert] = p
			continue
		end
		local edges = sortedKeys(m.vertEdges[vert])
		local faces = sortedKeys(m.vertFaces[vert])
		local sharp, border = {}, {}
		for _, edge in edges do
			if #sortedKeys(m.edgeFaces[edge]) < 2 then
				table.insert(border, edge)
			end
			if m.edges[edge].crease > 0 then
				table.insert(sharp, edge)
			end
		end
		local n = #faces
		local soft
		if #border > 0 or n == 0 then
			-- Open edge: keep to the boundary curve.
			if #border == 2 then
				local function far(edge)
					local e = m.edges[edge]
					return m.verts[if e.a == vert then e.b else e.a].position
				end
				soft = vec.scale(vec.add(vec.scale(p, 6), vec.add(far(border[1]), far(border[2]))), 1 / 8)
			else
				soft = p
			end
			vertPosition[vert] = soft
			continue
		end
		local faceAverage, edgeAverage = { 0, 0, 0 }, { 0, 0, 0 }
		for _, face in faces do
			faceAverage = vec.add(faceAverage, facePoint[face])
		end
		faceAverage = vec.scale(faceAverage, 1 / n)
		for _, edge in edges do
			local e = m.edges[edge]
			edgeAverage = vec.add(edgeAverage, vec.lerp(m.verts[e.a].position, m.verts[e.b].position, 0.5))
		end
		edgeAverage = vec.scale(edgeAverage, 1 / #edges)
		soft = vec.scale(vec.add(vec.add(faceAverage, vec.scale(edgeAverage, 2)), vec.scale(p, n - 3)), 1 / n)
		if #sharp == 2 then
			local function far(edge)
				local e = m.edges[edge]
				return m.verts[if e.a == vert then e.b else e.a].position
			end
			local creased = vec.scale(vec.add(vec.scale(p, 6), vec.add(far(sharp[1]), far(sharp[2]))), 1 / 8)
			local weight = (m.edges[sharp[1]].crease + m.edges[sharp[2]].crease) / 2
			soft = vec.lerp(soft, creased, weight)
		elseif #sharp > 2 then
			local weight = 0
			for _, edge in sharp do
				weight = math.max(weight, m.edges[edge].crease)
			end
			soft = vec.lerp(soft, p, weight)
		end
		vertPosition[vert] = soft
	end

	-- Rebuild: a fresh mesh keeps it simple; ids of the old vertices carry over.
	local rebuilt = EditMesh.new()
	rebuilt.nextVert = m.nextVert
	for _, vert in oldVerts do
		local p = vertPosition[vert]
		rebuilt.verts[vert] = { position = { p[1], p[2], p[3] }, tags = table.clone(m.verts[vert].tags) }
		rebuilt.vertFaces[vert] = {}
		rebuilt.vertEdges[vert] = {}
	end
	local edgeVert, faceVert = {}, {}
	for _, edge in oldEdges do
		local p = edgePosition[edge]
		edgeVert[edge] = rebuilt:addVertex(p[1], p[2], p[3])
	end
	for _, face in oldFaces do
		local p = facePoint[face]
		if smooth then
			-- Catmull-Clark face points are the plain centres.
			p = facePoint[face]
		end
		faceVert[face] = rebuilt:addVertex(p[1], p[2], p[3])
	end
	rebuilt.nextFace = m.nextFace
	local childCreases = {}
	for _, face in oldFaces do
		local verts = m.faces[face].verts
		local count = #verts
		for index, vert in verts do
			local before = verts[(index - 2) % count + 1]
			local after = verts[index % count + 1]
			local e1 = edgeVert[m:edge(before, vert)]
			local e2 = edgeVert[m:edge(vert, after)]
			rebuilt:addFace({ vert, e2, faceVert[face], e1 }, faceTags[face])
		end
	end
	-- Each crease passes to the two halves of its edge.
	for _, edge in oldEdges do
		local e = m.edges[edge]
		for _, half in { rebuilt:edge(e.a, edgeVert[edge]), rebuilt:edge(edgeVert[edge], e.b) } do
			if half then
				rebuilt.edges[half].crease = creases[edge]
				for name in e.tags do
					rebuilt.edges[half].tags[name] = true
				end
			end
		end
	end
	for key, value in rebuilt do
		m[key] = value
	end
	setmetatable(m, EditMesh)
	return childCreases
end

-- Splits every face into quads, `levels` times, without moving anything.
function EditMesh:subdivide(levels)
	for _ = 1, levels or 1 do
		subdivideOnce(self, false)
	end
	return self:select("face", "all")
end

-- Catmull-Clark subdivision, `levels` times: a rough cage becomes a smooth
-- shape. Creased edges (m:setCrease, selection:crease) stay sharp.
function EditMesh:smoothSubdivide(levels)
	for _ = 1, levels or 1 do
		subdivideOnce(self, true)
	end
	return self:select("face", "all")
end

-- ---------------------------------------------------------------- bridging and filling

-- Orders a set of edges forming one closed loop into a vertex cycle, each
-- step running the way the edge's one face runs it (a hole's rim).
local function rimCycle(m, edges)
	local nextOf = {}
	for edge in edges.ids do
		local e = m.edges[edge]
		local face = sortedKeys(m.edgeFaces[edge])[1]
		assert(face, "EditMesh: a rim edge with no face")
		local verts = m.faces[face].verts
		for index, vert in verts do
			local after = verts[index % #verts + 1]
			if (vert == e.a and after == e.b) or (vert == e.b and after == e.a) then
				nextOf[vert] = after
			end
		end
	end
	local start = sortedKeys(nextOf)[1]
	local cycle, vert = {}, start
	repeat
		table.insert(cycle, vert)
		vert = nextOf[vert]
		assert(vert, "EditMesh: those edges aren't one closed loop")
	until vert == start
	assert(#cycle == m:count(edges.ids), `EditMesh: those edges make more than one loop ({#cycle} of {m:count(edges.ids)} in the first)`)
	return cycle
end

-- Joins two holes' rims (edge selections of equal length) with quads.
-- The rims are matched where they line up best. Returns the new faces.
function EditMesh:bridge(edgesA, edgesB, tag)
	local a, b = rimCycle(self, edgesA), rimCycle(self, edgesB)
	assert(#a == #b, `EditMesh: bridge needs rims of one length ({#a} and {#b})`)
	local n = #a
	local best, bestCost = 0, math.huge
	for offset = 0, n - 1 do
		local cost = 0
		for i = 0, n - 1 do
			local j = (offset - i) % n
			cost += vec.length(vec.sub(self.verts[a[i + 1]].position, self.verts[b[j + 1]].position))
		end
		if cost < bestCost then
			best, bestCost = offset, cost
		end
	end
	local made = {}
	for i = 0, n - 1 do
		local j, k = (best - i) % n, (best - i - 1) % n
		local face = self:addFace({ a[(i + 1) % n + 1], a[i + 1], b[j + 1], b[k + 1] }, tag and { [tag] = true } or nil)
		made[face] = true
	end
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- Removes two faces (or two regions of faces, given as selections) and
-- joins their rims: a tunnel through the mesh, or a handle between two
-- ends turned to face each other.
function EditMesh:bridgeFaces(faceA, faceB, tag)
	local regionA = if type(faceA) == "table" then faceA:faces() else self:select("face", "ids", { faceA })
	local regionB = if type(faceB) == "table" then faceB:faces() else self:select("face", "ids", { faceB })
	local keepA, keepB = regionA:boundary().ids, regionB:boundary().ids
	return self:rebuilding(function()
		for face in regionA.ids do
			self:removeFace(face)
		end
		for face in regionB.ids do
			self:removeFace(face)
		end
		local function restore(ids)
			return setmetatable({ mesh = self, kind = "edge", ids = ids }, EditMesh.Selection)
		end
		return self:bridge(restore(keepA), restore(keepB), tag)
	end)
end

-- Closes a hole with one face over its rim. Returns the face.
function EditMesh:fill(edges, tag)
	local cycle = rimCycle(self, edges)
	local reversed = {}
	for index = #cycle, 1, -1 do
		table.insert(reversed, cycle[index])
	end
	return self:addFace(reversed, tag and { [tag] = true } or nil)
end

-- Removes the edges between pairs of faces, joining each pair into one.
function EditMesh:dissolve(edges)
	self:rebuilding(function()
		for _, edge in sortedKeys(edges:edges().ids) do
			local e = self.edges[edge]
			if not e then
				continue
			end
			local faces = sortedKeys(self.edgeFaces[edge])
			if #faces ~= 2 then
				continue
			end
			local f1, f2 = self.faces[faces[1]].verts, self.faces[faces[2]].verts
			-- Walk f1 from e.b round to e.a, then f2 from e.a round to e.b.
			local function from(verts, start, stop)
				local list, index = {}, table.find(verts, start)
				while verts[index] ~= stop do
					table.insert(list, verts[index])
					index = index % #verts + 1
				end
				return list
			end
			local i1 = table.find(f1, e.a)
			local runsAB = f1[i1 % #f1 + 1] == e.b
			local first = if runsAB then from(f1, e.b, e.a) else from(f1, e.a, e.b)
			local second = if runsAB then from(f2, e.a, e.b) else from(f2, e.b, e.a)
			local joined = table.clone(first)
			for _, vert in second do
				table.insert(joined, vert)
			end
			local tags = self.faces[faces[1]].tags
			self:removeFace(faces[2])
			self:replaceFace(faces[1], joined)
			for name in tags do
				self.faces[faces[1]].tags[name] = true
			end
		end
	end)
end

-- Merges vertices closer than `distance` (default 1e-4) into one.
function EditMesh:weld(distance)
	distance = distance or 1e-4
	local cell = math.max(distance * 4, 1e-6)
	local grid = {}
	local merged = 0
	for _, vert in sortedKeys(self.verts) do
		local v = self.verts[vert]
		if not v then
			continue
		end
		local p = v.position
		local cx, cy, cz = p[1] // cell, p[2] // cell, p[3] // cell
		local target = nil
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					for _, other in grid[`{cx + dx},{cy + dy},{cz + dz}`] or {} do
						if self.verts[other] and vec.length(vec.sub(self.verts[other].position, p)) <= distance then
							target = other
						end
					end
				end
			end
		end
		if target then
			self:mergeVertices(target, vert)
			merged += 1
		else
			local key = `{cx},{cy},{cz}`
			grid[key] = grid[key] or {}
			table.insert(grid[key], vert)
		end
	end
	return merged
end

-- A vertex in the middle of each face, joined to its corners (triangles).
function EditMesh:poke(faces)
	faces = asFaces(self, faces)
	local made = {}
	self:rebuilding(function()
		for _, face in sortedKeys(faces.ids) do
			local verts = table.clone(self.faces[face].verts)
			local c = self:faceCentre(face)
			local tags = self.faces[face].tags
			local middle = self:addVertex(c[1], c[2], c[3])
			self:removeFace(face)
			for index, vert in verts do
				local id = self:addFace({ vert, verts[index % #verts + 1], middle }, tags)
				made[id] = true
			end
		end
	end)
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- ---------------------------------------------------------------- reshaping

-- Moves every vertex (or the selection's) to `change(position) -> new`.
function EditMesh:transform(change, selection)
	for vert in asVerts(self, selection).ids do
		local p = self.verts[vert].position
		local q = change({ p[1], p[2], p[3] })
		self.verts[vert].position = q
	end
	return self
end

local AXES = { x = 1, y = 2, z = 3 }

-- Bends along `along` (the axis the shape runs on) towards `toward`, by
-- `degrees` over the whole length of the mesh (or selection), about its
-- low end. A strip along x bent 180 degrees toward z makes an arch.
function EditMesh:bend(degrees, along, toward, selection)
	local i, j = AXES[along or "x"], AXES[toward or "z"]
	local low, high = self:bounds()
	local length = high[i] - low[i]
	local angle = math.rad(degrees)
	if math.abs(angle) < 1e-9 or length <= 0 then
		return self
	end
	local radius = length / angle
	return self:transform(function(p)
		local theta = (p[i] - low[i]) / length * angle
		local r = radius - (p[j] - low[j])
		local q = table.clone(p)
		q[i] = low[i] + r * math.sin(theta)
		q[j] = low[j] + radius - r * math.cos(theta)
		return q
	end, selection)
end

-- Scales across `axis` from `from` at its low end to `to` at its high end.
function EditMesh:taper(axis, from, to, selection)
	local k = AXES[axis or "z"]
	local low, high = self:bounds()
	local centre = vec.lerp(low, high, 0.5)
	local length = math.max(1e-9, high[k] - low[k])
	return self:transform(function(p)
		local t = (p[k] - low[k]) / length
		local factor = from + (to - from) * t
		local q = table.clone(p)
		for axisIndex = 1, 3 do
			if axisIndex ~= k then
				q[axisIndex] = centre[axisIndex] + (p[axisIndex] - centre[axisIndex]) * factor
			end
		end
		return q
	end, selection)
end

-- Twists about `axis` through the middle, `degrees` from end to end.
function EditMesh:twist(axis, degrees, selection)
	local k = AXES[axis or "z"]
	local u, w = (k % 3) + 1, ((k + 1) % 3) + 1
	local low, high = self:bounds()
	local centre = vec.lerp(low, high, 0.5)
	local length = math.max(1e-9, high[k] - low[k])
	return self:transform(function(p)
		local angle = math.rad(degrees) * (p[k] - low[k]) / length
		local c, s = math.cos(angle), math.sin(angle)
		local du, dw = p[u] - centre[u], p[w] - centre[w]
		local q = table.clone(p)
		q[u] = centre[u] + du * c - dw * s
		q[w] = centre[w] + du * s + dw * c
		return q
	end, selection)
end

-- Relaxes vertices towards the average of their neighbours, `amount`
-- (0-1) each round. options.keepBorder leaves open edges where they are.
function EditMesh:smooth(selection, amount, rounds, options)
	options = options or {}
	local verts = asVerts(self, selection).ids
	for _ = 1, rounds or 1 do
		local moved = {}
		for vert in verts do
			local neighbours = self:neighbours(vert)
			if #neighbours == 0 then
				continue
			end
			if options.keepBorder then
				local border = false
				for edge in self.vertEdges[vert] do
					if self:count(self.edgeFaces[edge]) < 2 then
						border = true
					end
				end
				if border then
					continue
				end
			end
			local sum = { 0, 0, 0 }
			for _, other in neighbours do
				sum = vec.add(sum, self.verts[other].position)
			end
			moved[vert] = vec.lerp(self.verts[vert].position, vec.scale(sum, 1 / #neighbours), amount or 0.5)
		end
		for vert, p in moved do
			self.verts[vert].position = p
		end
	end
	return self
end

-- Moves vertices along their normals (negative to shrink).
function EditMesh:push(selection, distance)
	local moves = {}
	for vert in asVerts(self, selection).ids do
		moves[vert] = vec.add(self.verts[vert].position, vec.scale(self:vertexNormal(vert), distance))
	end
	for vert, p in moves do
		self.verts[vert].position = p
	end
	return self
end

-- Pulls a loop (or any set) of vertices round into a circle in their own
-- plane, about their middle, at their average distance from it.
function EditMesh:toCircle(selection, amount)
	local verts = sortedKeys(selection:verts().ids)
	local centre = { 0, 0, 0 }
	for _, vert in verts do
		centre = vec.add(centre, self.verts[vert].position)
	end
	centre = vec.scale(centre, 1 / #verts)
	-- The plane: the normal from summing cross products round the centre.
	local normal = { 0, 0, 0 }
	for index, vert in verts do
		local p = vec.sub(self.verts[vert].position, centre)
		local q = vec.sub(self.verts[verts[index % #verts + 1]].position, centre)
		local n = vec.cross(p, q)
		if vec.dot(n, normal) < 0 then
			n = vec.scale(n, -1)
		end
		normal = vec.add(normal, n)
	end
	normal = vec.unit(normal)
	local radius = 0
	for _, vert in verts do
		local d = vec.sub(self.verts[vert].position, centre)
		d = vec.sub(d, vec.scale(normal, vec.dot(d, normal)))
		radius += vec.length(d)
	end
	radius /= #verts
	for _, vert in verts do
		local p = self.verts[vert].position
		local d = vec.sub(p, centre)
		local inPlane = vec.sub(d, vec.scale(normal, vec.dot(d, normal)))
		local target = vec.add(centre, vec.scale(vec.unit(inPlane), radius))
		self.verts[vert].position = vec.lerp(p, target, amount or 1)
	end
	return selection
end

-- Pulls vertices towards a sphere about their middle (amount 1: all the
-- way), at their average distance from it, or `radius`.
function EditMesh:toSphere(selection, amount, radius)
	local verts = sortedKeys(asVerts(self, selection).ids)
	local centre = { 0, 0, 0 }
	for _, vert in verts do
		centre = vec.add(centre, self.verts[vert].position)
	end
	centre = vec.scale(centre, 1 / #verts)
	if not radius then
		radius = 0
		for _, vert in verts do
			radius += vec.length(vec.sub(self.verts[vert].position, centre))
		end
		radius /= #verts
	end
	for _, vert in verts do
		local p = self.verts[vert].position
		local target = vec.add(centre, vec.scale(vec.unit(vec.sub(p, centre)), radius))
		self.verts[vert].position = vec.lerp(p, target, amount or 1)
	end
	return self
end

-- ---------------------------------------------------------------- bevel

-- Bevels edges: each selected edge becomes a strip `width` wide on each of
-- its two faces, flat (segments 1) or rounded (more). Edges that meet at a
-- vertex aren't joined there: bevel one edge per corner at a time, or use
-- creases with smoothSubdivide, or a rounded box, to round every edge of a
-- block. Returns the strip faces.
function EditMesh:bevel(edges, width, segments)
	segments = segments or 1
	local made = {}
	for _, edge in sortedKeys(edges:edges().ids) do
		local e = self.edges[edge]
		if not e then
			continue
		end
		local faces = sortedKeys(self.edgeFaces[edge])
		if #faces ~= 2 then
			continue
		end
		local a, b = e.a, e.b
		local pa, pb = self.verts[a].position, self.verts[b].position
		-- In each face, the corner next to a and to b away from the edge.
		local function awayFrom(face, vert, other)
			local verts = self.faces[face].verts
			local index = table.find(verts, vert)
			local before, after = verts[(index - 2) % #verts + 1], verts[index % #verts + 1]
			return if before == other then after else before
		end
		local sides = {}
		for _, face in faces do
			local na, nb = awayFrom(face, a, b), awayFrom(face, b, a)
			local da = vec.unit(vec.sub(self.verts[na].position, pa))
			local db = vec.unit(vec.sub(self.verts[nb].position, pb))
			table.insert(sides, { face = face, da = da, db = db })
		end
		-- New corners: a1/b1 into face 1, a2/b2 into face 2.
		local a1p, b1p = vec.add(pa, vec.scale(sides[1].da, width)), vec.add(pb, vec.scale(sides[1].db, width))
		local a2p, b2p = vec.add(pa, vec.scale(sides[2].da, width)), vec.add(pb, vec.scale(sides[2].db, width))
		-- Rows across the strip from side 1 to side 2: straight for a chamfer,
		-- bowed out towards the old edge for a round.
		local rowsA, rowsB = {}, {}
		for k = 0, segments do
			local t = k / segments
			local qa = vec.lerp(a1p, a2p, t)
			local qb = vec.lerp(b1p, b2p, t)
			if segments > 1 then
				-- Quadratic Bezier with the old corner as the control point.
				local s = 1 - t
				qa = vec.add(vec.add(vec.scale(a1p, s * s), vec.scale(pa, 2 * s * t)), vec.scale(a2p, t * t))
				qb = vec.add(vec.add(vec.scale(b1p, s * s), vec.scale(pb, 2 * s * t)), vec.scale(b2p, t * t))
			end
			rowsA[k] = self:addVertex(qa[1], qa[2], qa[3])
			rowsB[k] = self:addVertex(qb[1], qb[2], qb[3])
		end
		self:rebuilding(function()
			-- Face 1 and 2 lose the old edge's corners for the strip's sides.
			for index, side in sides do
				local verts = table.clone(self.faces[side.face].verts)
				local edgeA = if index == 1 then rowsA[0] else rowsA[segments]
				local edgeB = if index == 1 then rowsB[0] else rowsB[segments]
				for i, vert in verts do
					if vert == a then
						verts[i] = edgeA
					elseif vert == b then
						verts[i] = edgeB
					end
				end
				self:replaceFace(side.face, verts)
			end
			-- Other faces at a and b take the strip's end rows in a's place.
			for _, pair in { { a, rowsA }, { b, rowsB } } do
				local vert, rows = pair[1], pair[2]
				for _, face in sortedKeys(self.vertFaces[vert] or {}) do
					local verts = self.faces[face].verts
					local index = table.find(verts, vert)
					local before, after = verts[(index - 2) % #verts + 1], verts[index % #verts + 1]
					-- The row runs from the end that touches `before`.
					local list = {}
					for k = 0, segments do
						table.insert(list, rows[k])
					end
					if self:edge(before, rows[segments]) or self:edge(rows[0], after) then
						local reversed = {}
						for k = #list, 1, -1 do
							table.insert(reversed, list[k])
						end
						list = reversed
					end
					local replaced = {}
					for i, v in verts do
						if v == vert then
							for _, r in list do
								table.insert(replaced, r)
							end
						else
							table.insert(replaced, v)
						end
					end
					self:replaceFace(face, replaced)
				end
			end
			-- The strip itself, wound to match face 1 (it runs rowsA[k] -> rowsB[k]
			-- the way face 1 ran a -> b).
			local verts1 = self.faces[sides[1].face].verts
			local i1 = table.find(verts1, rowsA[0])
			local forward = verts1[i1 % #verts1 + 1] == rowsB[0]
			for k = 0, segments - 1 do
				local quad = if forward
					then { rowsA[k + 1], rowsB[k + 1], rowsB[k], rowsA[k] }
					else { rowsB[k + 1], rowsA[k + 1], rowsA[k], rowsB[k] }
				local id = self:addFace(quad)
				made[id] = true
			end
		end)
		-- The old edge's corners belong to no face now.
		for _, vert in { a, b } do
			if self.verts[vert] and next(self.vertFaces[vert]) == nil then
				self.verts[vert] = nil
				self.vertFaces[vert] = nil
				self.vertEdges[vert] = nil
			end
		end
	end
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- ---------------------------------------------------------------- whole-mesh tools

-- Appends a copy of another mesh into this one. Returns the copy's faces.
function EditMesh:append(other)
	local map, made = {}, {}
	for _, vert in sortedKeys(other.verts) do
		local p = other.verts[vert].position
		map[vert] = self:addVertex(p[1], p[2], p[3])
	end
	for _, face in sortedKeys(other.faces) do
		local verts = {}
		for index, vert in other.faces[face].verts do
			verts[index] = map[vert]
		end
		made[self:addFace(verts, other.faces[face].tags)] = true
	end
	for _, edge in sortedKeys(other.edges) do
		local e = other.edges[edge]
		local mine = self:edge(map[e.a], map[e.b])
		if mine then
			self.edges[mine].crease = e.crease
		end
	end
	return setmetatable({ mesh = self, kind = "face", ids = made }, EditMesh.Selection)
end

-- Mirrors across the plane where `axis` (x, y or z) equals `at` (default
-- 0): adds a flipped copy and welds the seam, for shapes built one side at
-- a time. Faces lying on the plane should be removed first (the seam is
-- then an open rim the two halves close up).
function EditMesh:mirror(axis, at, distance)
	local k = AXES[axis or "x"]
	at = at or 0
	local half = self:copy()
	half:transform(function(p)
		p[k] = 2 * at - p[k]
		return p
	end)
	half:flip()
	local made = self:append(half)
	self:weld(distance or 1e-4)
	return made
end

-- Gives an open sheet thickness: an offset copy along the vertex normals
-- (inward for negative), turned over, joined to the sheet round its rims.
function EditMesh:solidify(thickness)
	local inner = self:copy()
	local normals = {}
	for vert in self.verts do
		normals[vert] = self:vertexNormal(vert)
	end
	local ids = sortedKeys(self.verts)
	local innerIds = sortedKeys(inner.verts)
	for index, vert in ids do
		local p = inner.verts[innerIds[index]].position
		inner.verts[innerIds[index]].position = vec.sub(p, vec.scale(normals[vert], thickness))
	end
	local rims = {}
	for edge, _ in self.edges do
		if self:count(self.edgeFaces[edge]) == 1 then
			rims[edge] = true
		end
	end
	inner:flip()
	local before = self.nextVert
	self:append(inner)
	-- Join each rim edge to its copy: vertices map by order of creation.
	local offset = {}
	for index, vert in ids do
		offset[vert] = before + index - 1
	end
	for edge in rims do
		local e = self.edges[edge]
		local face = sortedKeys(self.edgeFaces[edge])[1]
		local verts = self.faces[face].verts
		local i = table.find(verts, e.a)
		local a, b = e.a, e.b
		if verts[i % #verts + 1] ~= e.b then
			a, b = e.b, e.a
		end
		self:addFace({ b, a, offset[a], offset[b] })
	end
	return self
end

-- Adds `count - 1` copies, each `offset` ({x, y, z}) on from the last.
function EditMesh:array(count, offset, weldDistance)
	local base = self:copy()
	for k = 1, count - 1 do
		local piece = base:copy()
		piece:transform(function(p)
			return vec.add(p, vec.scale(offset, k))
		end)
		self:append(piece)
	end
	if weldDistance then
		self:weld(weldDistance)
	end
	return self
end
