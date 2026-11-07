-- Edit Mesh: a mesh that can be edited after it's made, down to every
-- vertex, edge and face, then handed to the engine as one part
-- (`m:emit(mesh)` inside a part's build function). Include it with
-- `-- include: EditMesh`.
--
-- Every vertex, edge and face has an id that never changes and is never
-- reused, so a step can name what an earlier step made. Faces list their
-- vertices counter-clockwise seen from outside (the engine's winding), and
-- the mesh knows which faces share each edge and meet at each vertex, so
-- edge loops and rings can be followed and edits keep the surface closed.
--
-- What to edit is chosen by rule (m:select), not by clicking: faces facing
-- a direction, everything inside a box, an edge loop, a tag a step left.
-- A selection can be moved, turned and scaled, with soft falloff.
-- Operations (extrude, inset, bevel, loop cut, subdivide...) live in
-- shared/EditOps.luau on top of this.
--
-- Positions are z-up studs, as everywhere in the art.

local EditMesh = {}
EditMesh.__index = EditMesh

EditMesh.Selection = {}
EditMesh.Selection.__index = EditMesh.Selection

-- Vectors are plain {x, y, z} tables.
EditMesh.vec = {
	add = function(a, b)
		return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
	end,
	sub = function(a, b)
		return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
	end,
	scale = function(a, k)
		return { a[1] * k, a[2] * k, a[3] * k }
	end,
	dot = function(a, b)
		return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	end,
	cross = function(a, b)
		return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
	end,
	length = function(a)
		return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
	end,
	unit = function(a)
		local length = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
		if length < 1e-12 then
			return { 0, 0, 0 }
		end
		return { a[1] / length, a[2] / length, a[3] / length }
	end,
	lerp = function(a, b, t)
		return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
	end,
}

local function edgeKey(a, b)
	if a < b then
		return a .. ":" .. b
	end
	return b .. ":" .. a
end

function EditMesh.new()
	return setmetatable({
		verts = {}, -- id -> { position = {x, y, z}, tags = {} }
		edges = {}, -- id -> { a, b, crease, tags }
		faces = {}, -- id -> { verts = {ids, counter-clockwise}, tags = {} }
		edgeByKey = {}, -- "a:b" -> edge id
		vertFaces = {}, -- vertex id -> { [face id] = true }
		vertEdges = {}, -- vertex id -> { [edge id] = true }
		edgeFaces = {}, -- edge id -> { [face id] = true }
		nextVert = 1,
		nextEdge = 1,
		nextFace = 1,
		-- Tags put on whatever the next steps make (EditMesh:tagging).
		stamp = nil,
	}, EditMesh)
end

-- ---------------------------------------------------------------- building

function EditMesh:addVertex(x, y, z)
	local id = self.nextVert
	self.nextVert += 1
	self.verts[id] = { position = { x, y, z }, tags = {} }
	self.vertFaces[id] = {}
	self.vertEdges[id] = {}
	if self.stamp then
		self.verts[id].tags[self.stamp] = true
	end
	return id
end

local function addEdge(self, a, b)
	local key = edgeKey(a, b)
	local id = self.edgeByKey[key]
	if id then
		return id
	end
	id = self.nextEdge
	self.nextEdge += 1
	self.edges[id] = { a = math.min(a, b), b = math.max(a, b), crease = 0, tags = {} }
	if self.stamp then
		self.edges[id].tags[self.stamp] = true
	end
	self.edgeByKey[key] = id
	self.edgeFaces[id] = {}
	self.vertEdges[a][id] = true
	self.vertEdges[b][id] = true
	return id
end

-- Adds a face over existing vertices, listed counter-clockwise seen from
-- outside. Returns its id.
function EditMesh:addFace(verts, tags)
	assert(#verts >= 3, "EditMesh: a face needs at least three vertices")
	local id = self.nextFace
	self.nextFace += 1
	local face = { verts = table.clone(verts), tags = {} }
	for name in tags or {} do
		face.tags[name] = true
	end
	if self.stamp then
		face.tags[self.stamp] = true
	end
	self.faces[id] = face
	for index, vert in verts do
		assert(self.verts[vert], `EditMesh: face uses missing vertex {vert}`)
		self.vertFaces[vert][id] = true
		local nextVert = verts[index % #verts + 1]
		self.edgeFaces[addEdge(self, vert, nextVert)][id] = true
	end
	return id
end

-- Removes a face, and any edge or vertex left belonging to no face.
function EditMesh:removeFace(id)
	local face = self.faces[id]
	if not face then
		return
	end
	self.faces[id] = nil
	for index, vert in face.verts do
		self.vertFaces[vert][id] = nil
		local edge = self.edgeByKey[edgeKey(vert, face.verts[index % #face.verts + 1])]
		if edge then
			self.edgeFaces[edge][id] = nil
			if next(self.edgeFaces[edge]) == nil then
				local e = self.edges[edge]
				self.edges[edge] = nil
				self.edgeFaces[edge] = nil
				self.edgeByKey[edgeKey(e.a, e.b)] = nil
				self.vertEdges[e.a][edge] = nil
				self.vertEdges[e.b][edge] = nil
			end
		end
	end
	for _, vert in face.verts do
		if self.verts[vert] and next(self.vertFaces[vert]) == nil then
			self.verts[vert] = nil
			self.vertFaces[vert] = nil
			self.vertEdges[vert] = nil
		end
	end
end

-- Runs `body` with every vertex position remembered, so faces can be
-- rebuilt over vertices a removeFace would otherwise forget.
function EditMesh:rebuilding(body)
	self.ghosts = {}
	for id, vert in self.verts do
		self.ghosts[id] = vert
	end
	local results = table.pack(body())
	self.ghosts = nil
	return table.unpack(results, 1, results.n)
end

-- Removes a vertex and every face using it.
function EditMesh:removeVertex(id)
	for face in table.clone(self.vertFaces[id] or {}) do
		self:removeFace(face)
	end
end

-- Removes an edge and every face using it.
function EditMesh:removeEdge(id)
	for face in table.clone(self.edgeFaces[id] or {}) do
		self:removeFace(face)
	end
end

-- Puts `tag` on every vertex, edge and face made while `body` runs.
function EditMesh:tagging(tag, body)
	local outer = self.stamp
	self.stamp = tag
	local results = table.pack(body())
	self.stamp = outer
	return table.unpack(results, 1, results.n)
end

-- ---------------------------------------------------------------- reading

function EditMesh:position(id)
	return self.verts[id].position
end

function EditMesh:setPosition(id, x, y, z)
	self.verts[id].position = { x, y, z }
end

function EditMesh:edge(a, b)
	return self.edgeByKey[edgeKey(a, b)]
end

function EditMesh:edgeVerts(id)
	local edge = self.edges[id]
	return edge.a, edge.b
end

local function keys(set)
	local list = {}
	for key in set do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

function EditMesh:facesOfVertex(id)
	return keys(self.vertFaces[id])
end

function EditMesh:facesOfEdge(id)
	return keys(self.edgeFaces[id])
end

function EditMesh:edgesOfVertex(id)
	return keys(self.vertEdges[id])
end

function EditMesh:neighbours(id)
	local list = {}
	for edge in self.vertEdges[id] do
		local e = self.edges[edge]
		table.insert(list, if e.a == id then e.b else e.a)
	end
	table.sort(list)
	return list
end

function EditMesh:faceNormal(id)
	-- Newell's method, as the engine works it out.
	local verts = self.faces[id].verts
	local n = { 0, 0, 0 }
	for index, vert in verts do
		local p = self.verts[vert].position
		local q = self.verts[verts[index % #verts + 1]].position
		n[1] += (p[2] - q[2]) * (p[3] + q[3])
		n[2] += (p[3] - q[3]) * (p[1] + q[1])
		n[3] += (p[1] - q[1]) * (p[2] + q[2])
	end
	return EditMesh.vec.unit(n)
end

function EditMesh:faceCentre(id)
	local verts = self.faces[id].verts
	local sum = { 0, 0, 0 }
	for _, vert in verts do
		sum = EditMesh.vec.add(sum, self.verts[vert].position)
	end
	return EditMesh.vec.scale(sum, 1 / #verts)
end

function EditMesh:faceArea(id)
	local verts = self.faces[id].verts
	local n = { 0, 0, 0 }
	local first = self.verts[verts[1]].position
	for index = 2, #verts - 1 do
		local a = EditMesh.vec.sub(self.verts[verts[index]].position, first)
		local b = EditMesh.vec.sub(self.verts[verts[index + 1]].position, first)
		n = EditMesh.vec.add(n, EditMesh.vec.cross(a, b))
	end
	return EditMesh.vec.length(n) / 2
end

-- Average of the normals of the faces around a vertex, weighted by area.
function EditMesh:vertexNormal(id)
	local n = { 0, 0, 0 }
	for face in self.vertFaces[id] do
		n = EditMesh.vec.add(n, EditMesh.vec.scale(self:faceNormal(face), self:faceArea(face)))
	end
	return EditMesh.vec.unit(n)
end

function EditMesh:counts()
	local v, e, f = 0, 0, 0
	for _ in self.verts do
		v += 1
	end
	for _ in self.edges do
		e += 1
	end
	for _ in self.faces do
		f += 1
	end
	return v, e, f
end

function EditMesh:bounds()
	local low, high = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, vert in self.verts do
		for axis = 1, 3 do
			low[axis] = math.min(low[axis], vert.position[axis])
			high[axis] = math.max(high[axis], vert.position[axis])
		end
	end
	return low, high
end

-- ---------------------------------------------------------------- vertex-level edits

-- Puts a new vertex on an edge, `t` of the way from its lower id to its
-- higher, into every face that uses the edge. Returns the new vertex.
function EditMesh:splitEdge(id, t)
	local edge = self.edges[id]
	local a, b = edge.a, edge.b
	local p = EditMesh.vec.lerp(self.verts[a].position, self.verts[b].position, t or 0.5)
	local crease, edgeTags = edge.crease, table.clone(edge.tags)
	local middle = self:addVertex(p[1], p[2], p[3])
	return self:rebuilding(function()
		for _, face in keys(self.edgeFaces[id]) do
			local verts = table.clone(self.faces[face].verts)
			for index, vert in verts do
				local nextVert = verts[index % #verts + 1]
				if (vert == a and nextVert == b) or (vert == b and nextVert == a) then
					table.insert(verts, index + 1, middle)
					break
				end
			end
			self:replaceFace(face, verts)
		end
		for _, half in { self:edge(a, middle), self:edge(middle, b) } do
			if half then
				self.edges[half].crease = crease
				for name in edgeTags do
					self.edges[half].tags[name] = true
				end
			end
		end
		return middle
	end)
end

-- Swaps a face's vertices for `verts`, keeping its id and tags. For edits
-- that change a face in place (splitting an edge, merging vertices).
function EditMesh:replaceFace(id, verts)
	local tags = self.faces[id].tags
	local ghosts = self.ghosts
	if not ghosts then
		return self:rebuilding(function()
			return self:replaceFace(id, verts)
		end)
	end
	self:removeFace(id)
	for _, vert in verts do
		if not self.verts[vert] then
			self.verts[vert] = ghosts[vert]
			self.vertFaces[vert] = {}
			self.vertEdges[vert] = {}
		end
	end
	-- Same id: put the face back where it was.
	local face = { verts = table.clone(verts), tags = tags }
	self.faces[id] = face
	for index, vert in verts do
		self.vertFaces[vert][id] = true
		self.edgeFaces[addEdge(self, vert, verts[index % #verts + 1])][id] = true
	end
	return id
end

-- Merges vertex `b` into `a` (`a` stays, at `position` if given). Faces
-- that collapse below three corners go.
function EditMesh:mergeVertices(a, b, position)
	if position then
		self.verts[a].position = { position[1], position[2], position[3] }
	end
	self:rebuilding(function()
		for _, face in keys(self.vertFaces[b]) do
			local merged = {}
			for _, vert in self.faces[face].verts do
				local use = if vert == b then a else vert
				if merged[#merged] ~= use then
					table.insert(merged, use)
				end
			end
			if #merged > 1 and merged[1] == merged[#merged] then
				table.remove(merged)
			end
			if #merged < 3 then
				self:removeFace(face)
			else
				self:replaceFace(face, merged)
			end
		end
	end)
	if self.verts[b] and next(self.vertFaces[b]) == nil then
		self.verts[b] = nil
		self.vertFaces[b] = nil
		self.vertEdges[b] = nil
	end
	return a
end

-- Collapses an edge to its middle (or `t` along it). Returns the vertex kept.
function EditMesh:collapseEdge(id, t)
	local edge = self.edges[id]
	local p = EditMesh.vec.lerp(self.verts[edge.a].position, self.verts[edge.b].position, t or 0.5)
	return self:mergeVertices(edge.a, edge.b, p)
end

-- Splits a face in two with a new edge between two of its vertices that
-- aren't neighbours. Returns the two faces (the first keeps the old id).
function EditMesh:connect(face, a, b)
	local verts = self.faces[face].verts
	local ia, ib = table.find(verts, a), table.find(verts, b)
	assert(ia and ib, "EditMesh: connect needs two vertices of the face")
	local count = #verts
	assert((ia % count) + 1 ~= ib and (ib % count) + 1 ~= ia, "EditMesh: those vertices already share an edge")
	local first, second = {}, {}
	local index = ia
	while true do
		table.insert(first, verts[index])
		if index == ib then
			break
		end
		index = index % count + 1
	end
	index = ib
	while true do
		table.insert(second, verts[index])
		if index == ia then
			break
		end
		index = index % count + 1
	end
	local tags = table.clone(self.faces[face].tags)
	return self:rebuilding(function()
		self:replaceFace(face, first)
		return face, self:addFace(second, tags)
	end)
end

-- Slides a vertex along one of its edges, `t` of the way to the far end.
function EditMesh:slide(vert, edge, t)
	local e = self.edges[edge]
	local far = if e.a == vert then e.b else e.a
	local p = EditMesh.vec.lerp(self.verts[vert].position, self.verts[far].position, t)
	self.verts[vert].position = p
end

function EditMesh:setCrease(edge, weight)
	self.edges[edge].crease = math.clamp(weight, 0, 1)
end

-- Turns every face over (for a shape built inside out).
function EditMesh:flip(faces)
	self:rebuilding(function()
		for _, face in faces or keys(self.faces) do
			local verts = self.faces[face].verts
			local flipped = {}
			for index = #verts, 1, -1 do
				table.insert(flipped, verts[index])
			end
			self:replaceFace(face, flipped)
		end
	end)
end

-- ---------------------------------------------------------------- selection

-- A set of vertex, edge or face ids from one mesh. Made by m:select; most
-- methods return a selection, so steps chain.
local function selection(mesh, kind, ids)
	return setmetatable({ mesh = mesh, kind = kind, ids = ids }, EditMesh.Selection)
end

local function elements(self, kind)
	if kind == "vertex" then
		return self.verts
	elseif kind == "edge" then
		return self.edges
	end
	return self.faces
end

local function centreOf(self, kind, id)
	if kind == "vertex" then
		return self.verts[id].position
	elseif kind == "edge" then
		local e = self.edges[id]
		return EditMesh.vec.lerp(self.verts[e.a].position, self.verts[e.b].position, 0.5)
	end
	return self:faceCentre(id)
end

-- m:select(kind, rule, ...) with kind "vertex", "edge" or "face", and rule:
--   "all"
--   "ids", { ids }
--   "tag", name                     made inside m:tagging(name, ...)
--   "facing", {x, y, z}, [degrees]  faces whose normal is within degrees
--                                   (default 30) of the direction
--   "inside", {lo}, {hi}            centres inside the box
--   "where", function(position, id) centres the function accepts
function EditMesh:select(kind, rule, a, b)
	kind = kind or "face"
	local ids = {}
	for id, element in elements(self, kind) do
		local keep
		if rule == nil or rule == "all" then
			keep = true
		elseif rule == "ids" then
			keep = table.find(a, id) ~= nil
		elseif rule == "tag" then
			keep = element.tags[a] == true
		elseif rule == "facing" then
			assert(kind == "face", "EditMesh: facing selects faces")
			local limit = math.cos(math.rad(b or 30))
			keep = EditMesh.vec.dot(self:faceNormal(id), EditMesh.vec.unit(a)) >= limit
		elseif rule == "inside" then
			local p = centreOf(self, kind, id)
			keep = p[1] >= a[1] and p[1] <= b[1] and p[2] >= a[2] and p[2] <= b[2] and p[3] >= a[3] and p[3] <= b[3]
		elseif rule == "where" then
			keep = a(centreOf(self, kind, id), id) == true
		else
			error(`EditMesh: no selection rule {rule}`)
		end
		if keep then
			ids[id] = true
		end
	end
	return selection(self, kind, ids)
end

local Selection = EditMesh.Selection

function Selection:list()
	return keys(self.ids)
end

function Selection:count()
	local count = 0
	for _ in self.ids do
		count += 1
	end
	return count
end

function Selection:first()
	return self:list()[1]
end

function Selection:union(other)
	assert(other.kind == self.kind, "EditMesh: union of different kinds")
	local ids = table.clone(self.ids)
	for id in other.ids do
		ids[id] = true
	end
	return selection(self.mesh, self.kind, ids)
end

function Selection:minus(other)
	local ids = table.clone(self.ids)
	for id in other.ids do
		ids[id] = nil
	end
	return selection(self.mesh, self.kind, ids)
end

-- Keeps only the members `keep(position, id)` accepts.
function Selection:filter(keep)
	local ids = {}
	for id in self.ids do
		if keep(centreOf(self.mesh, self.kind, id), id) then
			ids[id] = true
		end
	end
	return selection(self.mesh, self.kind, ids)
end

-- The vertices the selection touches.
function Selection:verts()
	local mesh, ids = self.mesh, {}
	for id in self.ids do
		if self.kind == "vertex" then
			ids[id] = true
		elseif self.kind == "edge" then
			ids[mesh.edges[id].a] = true
			ids[mesh.edges[id].b] = true
		else
			for _, vert in mesh.faces[id].verts do
				ids[vert] = true
			end
		end
	end
	return selection(mesh, "vertex", ids)
end

-- The edges the selection touches (for faces: their outlines and insides).
function Selection:edges()
	local mesh, ids = self.mesh, {}
	if self.kind == "edge" then
		return self
	end
	if self.kind == "vertex" then
		for id in self.ids do
			for edge in mesh.vertEdges[id] do
				local e = mesh.edges[edge]
				if self.ids[e.a] and self.ids[e.b] then
					ids[edge] = true
				end
			end
		end
	else
		for id in self.ids do
			local verts = mesh.faces[id].verts
			for index, vert in verts do
				ids[mesh:edge(vert, verts[index % #verts + 1])] = true
			end
		end
	end
	return selection(mesh, "edge", ids)
end

-- The faces whose every vertex is in the selection.
function Selection:faces()
	local mesh, verts, ids = self.mesh, self:verts().ids, {}
	if self.kind == "face" then
		return self
	end
	for id, face in mesh.faces do
		local all = true
		for _, vert in face.verts do
			if not verts[vert] then
				all = false
				break
			end
		end
		if all then
			ids[id] = true
		end
	end
	return selection(mesh, "face", ids)
end

-- The edges round the outside of a face selection.
function Selection:boundary()
	assert(self.kind == "face", "EditMesh: boundary of faces")
	local mesh, ids = self.mesh, {}
	for edge in self:edges().ids do
		local inside = 0
		for face in mesh.edgeFaces[edge] do
			if self.ids[face] then
				inside += 1
			end
		end
		if inside == 1 then
			ids[edge] = true
		end
	end
	return selection(mesh, "edge", ids)
end

-- One step out: every element sharing a vertex with the selection.
function Selection:grow()
	local mesh, ids, verts = self.mesh, table.clone(self.ids), self:verts().ids
	for vert in verts do
		if self.kind == "vertex" then
			for _, other in mesh:neighbours(vert) do
				ids[other] = true
			end
		elseif self.kind == "edge" then
			for edge in mesh.vertEdges[vert] do
				ids[edge] = true
			end
		else
			for face in mesh.vertFaces[vert] do
				ids[face] = true
			end
		end
	end
	return selection(mesh, self.kind, ids)
end

-- One step in: drops members that touch anything outside the selection.
function Selection:shrink()
	local mesh, outside, ids = self.mesh, {}, {}
	local inVerts = self:verts().ids
	for vert in inVerts do
		if self.kind == "face" then
			for face in mesh.vertFaces[vert] do
				if not self.ids[face] then
					outside[vert] = true
				end
			end
		else
			for _, other in mesh:neighbours(vert) do
				if not inVerts[other] then
					outside[vert] = true
				end
			end
		end
	end
	for id in self.ids do
		local touches = false
		for vert in selection(mesh, self.kind, { [id] = true }):verts().ids do
			if outside[vert] then
				touches = true
			end
		end
		if not touches then
			ids[id] = true
		end
	end
	return selection(mesh, self.kind, ids)
end

-- ---------------------------------------------------------------- loops and rings

-- In a quad, the edge across from `edge`.
local function opposite(mesh, face, edge)
	local verts = mesh.faces[face].verts
	if #verts ~= 4 then
		return nil
	end
	local e = mesh.edges[edge]
	for index, vert in verts do
		local nextVert = verts[index % 4 + 1]
		if (vert == e.a and nextVert == e.b) or (vert == e.b and nextVert == e.a) then
			return mesh:edge(verts[(index + 1) % 4 + 1], verts[(index + 2) % 4 + 1])
		end
	end
	return nil
end

-- The ring of edges across quads from `edge`: each the one opposite the
-- last in the next quad, until it comes round or meets a non-quad.
function EditMesh:ring(edge)
	local ids = { [edge] = true }
	for face in self.edgeFaces[edge] do
		local current, from = edge, face
		while from do
			local across = opposite(self, from, current)
			if not across or ids[across] then
				break
			end
			ids[across] = true
			local nextFace = nil
			for other in self.edgeFaces[across] do
				if other ~= from then
					nextFace = other
				end
			end
			current, from = across, nextFace
		end
	end
	return selection(self, "edge", ids)
end

-- The loop of edges through `edge`: from each end, on through the vertex to
-- the edge that shares no face with the last, while the vertex has four
-- edges (a regular quad grid point).
function EditMesh:loop(edge)
	local ids = { [edge] = true }
	local e = self.edges[edge]
	for _, start in { e.a, e.b } do
		local current, vert = edge, start
		while true do
			if self:count(self.vertEdges[vert]) ~= 4 then
				break
			end
			local sharing = {}
			for face in self.edgeFaces[current] do
				sharing[face] = true
			end
			local nextEdge = nil
			for candidate in self.vertEdges[vert] do
				if candidate ~= current then
					local shares = false
					for face in self.edgeFaces[candidate] do
						if sharing[face] then
							shares = true
						end
					end
					if not shares then
						nextEdge = candidate
					end
				end
			end
			if not nextEdge or ids[nextEdge] then
				break
			end
			ids[nextEdge] = true
			local n = self.edges[nextEdge]
			current, vert = nextEdge, if n.a == vert then n.b else n.a
		end
	end
	return selection(self, "edge", ids)
end

function EditMesh:count(set)
	local count = 0
	for _ in set do
		count += 1
	end
	return count
end

-- ---------------------------------------------------------------- moving selections

-- Moves each selected vertex by `change(position, id) -> new position`.
-- With `radius`, vertices outside the selection within that distance of it
-- follow too, eased from full at the edge to none at `radius` (soft
-- selection): position + (new - position) * falloff.
function Selection:reshape(change, radius)
	local mesh, chosen = self.mesh, self:verts().ids
	local moves = {}
	for vert in chosen do
		moves[vert] = { weight = 1, from = mesh.verts[vert].position }
	end
	if radius and radius > 0 then
		for id, vert in mesh.verts do
			if not chosen[id] then
				local nearest = math.huge
				for other in chosen do
					nearest = math.min(nearest, EditMesh.vec.length(EditMesh.vec.sub(vert.position, mesh.verts[other].position)))
				end
				if nearest < radius then
					local t = 1 - nearest / radius
					moves[id] = { weight = t * t * (3 - 2 * t), from = vert.position }
				end
			end
		end
	end
	for id, move in moves do
		local target = change(move.from, id)
		mesh.verts[id].position = EditMesh.vec.lerp(move.from, target, move.weight)
	end
	return self
end

function Selection:move(offset, radius)
	return self:reshape(function(p)
		return EditMesh.vec.add(p, offset)
	end, radius)
end

-- Scales about `pivot` (default: the selection's middle) by {sx, sy, sz}.
function Selection:scale(factors, pivot, radius)
	pivot = pivot or self:middle()
	if type(factors) == "number" then
		factors = { factors, factors, factors }
	end
	return self:reshape(function(p)
		return {
			pivot[1] + (p[1] - pivot[1]) * factors[1],
			pivot[2] + (p[2] - pivot[2]) * factors[2],
			pivot[3] + (p[3] - pivot[3]) * factors[3],
		}
	end, radius)
end

-- Turns about `axis` ({x, y, z}, through `pivot`) by `degrees`.
function Selection:rotate(axis, degrees, pivot, radius)
	pivot = pivot or self:middle()
	local k = EditMesh.vec.unit(axis)
	local angle = math.rad(degrees)
	local c, s = math.cos(angle), math.sin(angle)
	return self:reshape(function(p)
		-- Rodrigues' rotation.
		local v = EditMesh.vec.sub(p, pivot)
		local cross = EditMesh.vec.cross(k, v)
		local along = EditMesh.vec.scale(k, EditMesh.vec.dot(k, v) * (1 - c))
		local turned = EditMesh.vec.add(EditMesh.vec.add(EditMesh.vec.scale(v, c), EditMesh.vec.scale(cross, s)), along)
		return EditMesh.vec.add(pivot, turned)
	end, radius)
end

-- The middle of the selection's vertices.
function Selection:middle()
	local sum, count = { 0, 0, 0 }, 0
	for vert in self:verts().ids do
		sum = EditMesh.vec.add(sum, self.mesh.verts[vert].position)
		count += 1
	end
	return EditMesh.vec.scale(sum, 1 / math.max(1, count))
end

function Selection:tag(name)
	local all = elements(self.mesh, self.kind)
	for id in self.ids do
		all[id].tags[name] = true
	end
	return self
end

function Selection:crease(weight)
	for edge in self:edges().ids do
		self.mesh:setCrease(edge, weight)
	end
	return self
end

-- ---------------------------------------------------------------- checks

-- What's wrong with the mesh, as a list of short descriptions: edges with
-- one face (holes), edges with more than two (fins), faces turned against
-- their neighbours, faces with more than four corners (unless allowed),
-- sliver faces, and loose vertices.
function EditMesh:problems(options)
	options = options or {}
	local found = {}
	local function note(text)
		if #found < 20 then
			table.insert(found, text)
		end
	end
	for edge, e in self.edges do
		local faces = self:count(self.edgeFaces[edge])
		if faces == 1 and not options.open then
			note(`hole at edge {edge} ({e.a}-{e.b})`)
		elseif faces > 2 then
			note(`edge {edge} is shared by {faces} faces`)
		elseif faces == 2 then
			-- Neighbours must run the shared edge in opposite directions.
			local runs = {}
			for face in self.edgeFaces[edge] do
				local verts = self.faces[face].verts
				for index, vert in verts do
					if vert == e.a and verts[index % #verts + 1] == e.b then
						table.insert(runs, 1)
					elseif vert == e.b and verts[index % #verts + 1] == e.a then
						table.insert(runs, -1)
					end
				end
			end
			if runs[1] == runs[2] then
				note(`faces at edge {edge} are turned against each other`)
			end
		end
	end
	for face, f in self.faces do
		if #f.verts > 4 and not options.ngons then
			note(`face {face} has {#f.verts} corners`)
		end
		if self:faceArea(face) < (options.sliver or 1e-6) then
			note(`face {face} has almost no area`)
		end
	end
	for vert in self.verts do
		if next(self.vertFaces[vert]) == nil then
			note(`vertex {vert} belongs to no face`)
		end
	end
	return found
end

-- The share of faces with four corners, 0-1.
function EditMesh:quadShare()
	local quads, all = 0, 0
	for _, face in self.faces do
		all += 1
		if #face.verts == 4 then
			quads += 1
		end
	end
	return if all == 0 then 1 else quads / all
end

-- ---------------------------------------------------------------- to the engine

-- Writes the mesh into an engine Mesh (the `mesh` a part's build function
-- gets), optionally moved by `offset`. Returns how many faces it wrote.
function EditMesh:emit(mesh, offset)
	local engineIds = {}
	local dx, dy, dz = 0, 0, 0
	if offset then
		dx, dy, dz = offset[1], offset[2], offset[3]
	end
	for _, id in keys(self.verts) do
		local p = self.verts[id].position
		engineIds[id] = mesh:vertex(p[1] + dx, p[2] + dy, p[3] + dz)
	end
	local written = 0
	for _, id in keys(self.faces) do
		local verts = {}
		for index, vert in self.faces[id].verts do
			verts[index] = engineIds[vert]
		end
		mesh:face(verts)
		written += 1
	end
	return written
end

-- A copy with fresh ids, for making variants of a shape.
function EditMesh:copy()
	local other = EditMesh.new()
	local map = {}
	for _, id in keys(self.verts) do
		local p = self.verts[id].position
		map[id] = other:addVertex(p[1], p[2], p[3])
		for name in self.verts[id].tags do
			other.verts[map[id]].tags[name] = true
		end
	end
	for _, id in keys(self.faces) do
		local verts = {}
		for index, vert in self.faces[id].verts do
			verts[index] = map[vert]
		end
		other:addFace(verts, self.faces[id].tags)
	end
	for _, id in keys(self.edges) do
		local e = self.edges[id]
		local mine = other:edge(map[e.a], map[e.b])
		other.edges[mine].crease = e.crease
		for name in e.tags do
			other.edges[mine].tags[name] = true
		end
	end
	return other
end
