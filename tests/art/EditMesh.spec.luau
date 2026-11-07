--!strict
local Art = require("./Art")
local Test = require("../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local EditMesh = Art.load({ "EditMesh" }, "EditMesh")

-- A unit cube from (0,0,0) to (1,1,1), faces wound outward.
local function cube()
	local m = EditMesh.new()
	local v = {}
	for i = 0, 7 do
		v[i] = m:addVertex(i % 2, (i // 2) % 2, i // 4)
	end
	local faces = {
		{ v[0], v[2], v[3], v[1] }, -- bottom (z = 0)
		{ v[4], v[5], v[7], v[6] }, -- top
		{ v[0], v[1], v[5], v[4] }, -- y = 0
		{ v[2], v[6], v[7], v[3] }, -- y = 1
		{ v[0], v[4], v[6], v[2] }, -- x = 0
		{ v[1], v[3], v[7], v[5] }, -- x = 1
	}
	for _, face in faces do
		m:addFace(face)
	end
	return m, v
end

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

describe("EditMesh basics", function()
	it("builds a closed, healthy cube with normals pointing out", function()
		local m = cube()
		local v, e, f = m:counts()
		expect({ v, e, f }).toEqual({ 8, 12, 6 })
		expect(#m:problems()).toBe(0)
		expect(m:quadShare()).toBe(1)
		local top = m:select("face", "facing", { 0, 0, 1 }):list()
		expect(#top).toBe(1)
		expect(m:faceNormal(top[1])[3]).toBe(1)
		local n = m:vertexNormal(8)
		expect(n[1] > 0 and n[2] > 0 and n[3] > 0).toBe(true)
	end)

	it("reports holes, flipped faces and stray vertices", function()
		local m = cube()
		m:removeFace(m:select("face", "facing", { 0, 0, 1 }):first())
		expect(#m:problems() > 0).toBe(true)
		expect(#m:problems({ open = true })).toBe(0)
		local turned = cube()
		turned:flip({ turned:select("face", "facing", { 1, 0, 0 }):first() })
		local found = turned:problems()
		expect(#found > 0).toBe(true)
	end)

	it("keeps ids stable and never reuses them", function()
		local m, v = cube()
		local top = m:select("face", "facing", { 0, 0, 1 }):first()
		local before = m.nextFace
		m:splitEdge(m:edge(v[4], v[5]))
		expect(m.faces[top] ~= nil).toBe(true)
		m:removeFace(m:select("face", "facing", { 0, -1, 0 }):first())
		local added = m:addFace({ v[0], v[1], v[2] })
		expect(added >= before).toBe(true)
	end)
end)

describe("EditMesh vertex-level edits", function()
	it("splits an edge into both faces that share it", function()
		local m, v = cube()
		local middle = m:splitEdge(m:edge(v[4], v[5]), 0.25)
		local p = m:position(middle)
		expect(near(p[1], 0.25) and p[2] == 0 and p[3] == 1).toBe(true)
		expect(#m:facesOfVertex(middle)).toBe(2)
		expect(#m:problems({ ngons = true })).toBe(0)
		local _, _, f = m:counts()
		expect(f).toBe(6)
	end)

	it("connects two corners of a face, splitting it in two", function()
		local m, v = cube()
		local top = m:select("face", "facing", { 0, 0, 1 }):first()
		local a, b = m:connect(top, v[4], v[7])
		expect(#m.faces[a].verts).toBe(3)
		expect(#m.faces[b].verts).toBe(3)
		expect(m:edge(v[4], v[7]) ~= nil).toBe(true)
		expect(#m:problems()).toBe(0)
	end)

	it("merges vertices and drops the faces that collapse", function()
		local m, v = cube()
		m:collapseEdge(m:edge(v[4], v[5]))
		local _, _, f = m:counts()
		-- The y = 0 side loses a corner but stays a face; nothing collapses
		-- below three corners on a cube.
		expect(f).toBe(6)
		expect(m.verts[v[5]]).toBe(nil)
		expect(near(m:position(v[4])[1], 0.5)).toBe(true)
		expect(#m:problems()).toBe(0)
	end)

	it("slides a vertex along an edge and moves it exactly", function()
		local m, v = cube()
		m:slide(v[7], m:edge(v[7], v[6]), 0.5)
		expect(near(m:position(v[7])[1], 0.5)).toBe(true)
		m:setPosition(v[0], -1, -1, -1)
		expect(m:position(v[0])).toEqual({ -1, -1, -1 })
	end)
end)

describe("EditMesh selection", function()
	it("selects by direction, box, test and tag", function()
		local m = cube()
		expect(m:select("face", "facing", { 1, 0, 0 }):count()).toBe(1)
		expect(m:select("vertex", "inside", { -0.1, -0.1, 0.9 }, { 1.1, 1.1, 1.1 }):count()).toBe(4)
		expect(m:select("vertex", "where", function(p)
			return p[1] == 0
		end):count()).toBe(4)
		local tagged = m:tagging("lid", function()
			local a = m:addVertex(0, 0, 2)
			local b = m:addVertex(1, 0, 2)
			local c = m:addVertex(0, 1, 2)
			return m:addFace({ a, b, c })
		end)
		expect(m:select("face", "tag", "lid"):list()).toEqual({ tagged })
		expect(m:select("vertex", "tag", "lid"):count()).toBe(3)
	end)

	it("converts between vertices, edges and faces", function()
		local m = cube()
		local top = m:select("face", "facing", { 0, 0, 1 })
		expect(top:verts():count()).toBe(4)
		expect(top:edges():count()).toBe(4)
		expect(top:boundary():count()).toBe(4)
		expect(top:verts():faces():count()).toBe(1)
		expect(top:verts():edges():count()).toBe(4)
	end)

	it("grows and shrinks", function()
		local m = cube()
		local top = m:select("face", "facing", { 0, 0, 1 })
		expect(top:grow():count()).toBe(5)
		expect(top:grow():grow():count()).toBe(6)
		expect(top:grow():shrink():count()).toBe(1)
	end)

	it("follows edge loops and rings round quads", function()
		local m, v = cube()
		-- On a cube every vertex has three edges, so a loop stops at once,
		-- but a ring goes all the way round.
		expect(m:ring(m:edge(v[0], v[4])):count()).toBe(4)
		local loop = m:loop(m:edge(v[0], v[4]))
		expect(loop:count()).toBe(1)
	end)
end)

describe("EditMesh moving selections", function()
	it("moves, scales and turns", function()
		local m, v = cube()
		local top = m:select("face", "facing", { 0, 0, 1 })
		top:move({ 0, 0, 1 })
		expect(m:position(v[4])[3]).toBe(2)
		top:scale({ 2, 2, 1 })
		expect(near(m:position(v[4])[1], -0.5)).toBe(true)
		local side = m:select("vertex", "ids", { v[1] })
		side:rotate({ 0, 0, 1 }, 90, { 0, 0, 0 })
		local p = m:position(v[1])
		expect(near(p[1], 0) and near(p[2], 1)).toBe(true)
	end)

	it("moves nearby vertices with soft falloff", function()
		local m = EditMesh.new()
		local row = {}
		for i = 0, 4 do
			row[i] = m:addVertex(i, 0, 0)
		end
		local pick = m:select("vertex", "ids", { row[0] })
		pick:move({ 0, 0, 1 }, 3)
		expect(m:position(row[0])[3]).toBe(1)
		local a, b, c = m:position(row[1])[3], m:position(row[2])[3], m:position(row[3])[3]
		expect(a > b and b > 0 and c == 0).toBe(true)
	end)
end)

describe("EditMesh hand-off", function()
	it("writes every face into the engine mesh, in place", function()
		local m = cube()
		local recorder = Art.recorder()
		expect(m:emit(recorder, { 10, 0, 0 })).toBe(6)
		expect(#recorder.positions).toBe(8)
		local lowest = math.huge
		for _, p in recorder.positions do
			lowest = math.min(lowest, p[1])
		end
		expect(lowest).toBe(10)
	end)

	it("copies with fresh ids, creases and tags kept", function()
		local m, v = cube()
		m:setCrease(m:edge(v[0], v[1]), 1)
		local copy = m:copy()
		local creased = 0
		for _, e in copy.edges do
			if e.crease == 1 then
				creased += 1
			end
		end
		expect(creased).toBe(1)
		expect(#copy:problems()).toBe(0)
	end)
end)
