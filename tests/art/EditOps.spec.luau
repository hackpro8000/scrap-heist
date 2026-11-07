--!strict
local Art = require("./Art")
local Test = require("../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local EditMesh = Art.load({ "EditMesh", "EditOps", "EditShapes" }, "EditMesh")

-- Signed volume: positive when every face points out.
local function volume(m): number
	local total = 0
	for _, face in m.faces do
		local p0 = m.verts[face.verts[1]].position
		for i = 2, #face.verts - 1 do
			local p1, p2 = m.verts[face.verts[i]].position, m.verts[face.verts[i + 1]].position
			total += (p0[1] * (p1[2] * p2[3] - p1[3] * p2[2]) - p0[2] * (p1[1] * p2[3] - p1[3] * p2[1]) + p0[3] * (p1[1] * p2[2] - p1[2] * p2[1])) / 6
		end
	end
	return total
end

local function healthy(m, options)
	local found = m:problems(options)
	if #found > 0 then
		error("problems: " .. table.concat(found, "; "), 2)
	end
	return true
end

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

local function faces(m): number
	local _, _, f = m:counts()
	return f
end

describe("EditShapes", function()
	it("makes boxes of quads, cut as asked", function()
		local m = EditMesh.box({ 2, 1, 1 }, { 2, 1, 3 })
		expect(healthy(m)).toBe(true)
		expect(faces(m)).toBe(2 * 2 * 1 + 2 * 2 * 3 + 2 * 1 * 3)
		expect(near(volume(m), 2)).toBe(true)
		expect(m:quadShare()).toBe(1)
	end)

	it("rounds a box's edges without changing its size", function()
		local m = EditMesh.roundedBox({ 2, 1, 1 }, 0.2, 3)
		expect(healthy(m)).toBe(true)
		expect(m:quadShare()).toBe(1)
		local low, high = m:bounds()
		expect(near(high[1] - low[1], 2) and near(high[2] - low[2], 1) and near(high[3] - low[3], 1)).toBe(true)
		expect(volume(m) < 2 and volume(m) > 1.85).toBe(true)
	end)

	it("makes round shapes of quads: cylinder, sphere, capsule, torus, tube", function()
		local cylinder = EditMesh.cylinder(1, 2, 16, 2)
		expect(healthy(cylinder)).toBe(true)
		expect(cylinder:quadShare()).toBe(1)
		expect(near(volume(cylinder), math.pi * 2, 0.3)).toBe(true)
		local sphere = EditMesh.sphere(1, 16)
		expect(healthy(sphere)).toBe(true)
		expect(sphere:quadShare()).toBe(1)
		for _, vert in sphere.verts do
			local p = vert.position
			expect(near(math.sqrt(p[1] ^ 2 + p[2] ^ 2 + p[3] ^ 2), 1, 1e-6)).toBe(true)
		end
		local capsule = EditMesh.capsule(0.5, 2, 16)
		expect(healthy(capsule)).toBe(true)
		local low, high = capsule:bounds()
		expect(near(high[3], 1.5) and near(low[3], -1.5)).toBe(true)
		local torus = EditMesh.torus(2, 0.5, 24, 12)
		expect(healthy(torus)).toBe(true)
		expect(near(volume(torus), 2 * math.pi ^ 2 * 2 * 0.25, 0.8)).toBe(true)
		local tube = EditMesh.tube(1, 0.8, 2, 16)
		expect(healthy(tube)).toBe(true)
		expect(volume(tube) > 0).toBe(true)
	end)

	it("makes cones, prisms, wedges and arches", function()
		local cone = EditMesh.cone(1, 0.3, 2, 16, 1)
		expect(healthy(cone)).toBe(true)
		expect(volume(cone) > 0).toBe(true)
		local prism = EditMesh.prism(6, 1, 1)
		expect(healthy(prism, { ngons = true })).toBe(true)
		expect(faces(prism)).toBe(8)
		expect(volume(prism) > 0).toBe(true)
		local wedge = EditMesh.wedge({ 2, 2, 1 })
		expect(healthy(wedge)).toBe(true)
		expect(near(volume(wedge), 2)).toBe(true)
		local arch = EditMesh.arch(2, 0.5, 1, 12)
		expect(healthy(arch)).toBe(true)
		expect(volume(arch) > 0).toBe(true)
		local low, high = arch:bounds()
		expect(near(low[3], 0) and near(high[3], 2.5) and near(high[1], 2.5) and near(low[1], -2.5)).toBe(true)
	end)

	it("makes flat sheets, disks and circles facing up", function()
		local grid = EditMesh.grid(2, 2, 4, 4)
		expect(healthy(grid, { open = true })).toBe(true)
		expect(grid:select("face", "facing", { 0, 0, 1 }):count()).toBe(16)
		local disk = EditMesh.disk(1, 16)
		expect(healthy(disk, { open = true })).toBe(true)
		expect(disk:select("face", "facing", { 0, 0, 1 }):count()).toBe(faces(disk))
		local circle = EditMesh.circle(1, 12)
		expect(healthy(circle, { open = true, ngons = true })).toBe(true)
	end)

	it("lathes, sweeps and winds coils", function()
		local vase = EditMesh.spin({ { 0, 0 }, { 1, 0 }, { 0.6, 1 }, { 0.8, 2 }, { 0, 2 } }, 16)
		expect(healthy(vase)).toBe(true)
		expect(volume(vase) > 0).toBe(true)
		local square = { { -0.1, -0.1 }, { 0.1, -0.1 }, { 0.1, 0.1 }, { -0.1, 0.1 } }
		local rail = EditMesh.sweep(square, { { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0.5 } })
		expect(healthy(rail)).toBe(true)
		expect(volume(rail) > 0).toBe(true)
		local spring = EditMesh.coil(1, 0.1, 3, 0.4, 8, 16)
		expect(healthy(spring, { ngons = true })).toBe(true)
		expect(volume(spring) > 0).toBe(true)
	end)
end)

describe("EditOps adding geometry", function()
	it("extrudes a face out, with sides", function()
		local m = EditMesh.box()
		local top = m:select("face", "facing", { 0, 0, 1 })
		local moved, sides = m:extrude(top, 1)
		expect(healthy(m)).toBe(true)
		expect(sides:count()).toBe(4)
		expect(near(m:position(moved:verts():first())[3], 1.5)).toBe(true)
		expect(near(volume(m), 2)).toBe(true)
	end)

	it("extrudes a region as one, or each face on its own", function()
		local m = EditMesh.box({ 2, 1, 1 }, { 2, 1, 1 })
		local _, sides = m:extrude(m:select("face", "facing", { 0, 0, 1 }), 0.5)
		expect(sides:count()).toBe(6)
		local each = EditMesh.box({ 2, 1, 1 }, { 2, 1, 1 })
		local _, eachSides = each:extrude(each:select("face", "facing", { 0, 0, 1 }), 0.5, { each = true })
		expect(eachSides:count()).toBe(8)
		expect(healthy(m) and healthy(each)).toBe(true)
	end)

	it("insets a face, raised or sunk", function()
		local m = EditMesh.box()
		local inner, ring = m:inset(m:select("face", "facing", { 0, 0, 1 }), 0.1, -0.2)
		expect(healthy(m)).toBe(true)
		expect(ring:count()).toBe(4)
		local low, high = m:select("face", "ids", inner:list()):verts():middle(), nil
		expect(near(low[3], 0.3)).toBe(true)
		local _ = high
		local p = m:position(inner:verts():first())
		expect(near(math.abs(p[1]), 0.4) and near(math.abs(p[2]), 0.4)).toBe(true)
		-- Sinking slopes the ring down to the inner face: a frustum comes out.
		local pit = 0.2 / 3 * (1 + 0.64 + 0.8)
		expect(near(volume(m), 1 - pit, 1e-6)).toBe(true)
	end)

	it("cuts loops round a ring of quads", function()
		local m = EditMesh.box()
		local vertical = m:select("edge", "where", function(p)
			return math.abs(p[3]) < 1e-9
		end):first()
		local cuts = m:loopCut(vertical, 2)
		expect(healthy(m)).toBe(true)
		expect(m:quadShare()).toBe(1)
		expect(cuts:count()).toBe(8)
		expect(faces(m)).toBe(14)
		expect(near(volume(m), 1)).toBe(true)
	end)

	it("subdivides flat, or smooth with creases kept sharp", function()
		local flat = EditMesh.box()
		flat:subdivide(1)
		expect(faces(flat)).toBe(24)
		expect(near(volume(flat), 1)).toBe(true)
		local smooth = EditMesh.box()
		smooth:smoothSubdivide(2)
		expect(healthy(smooth)).toBe(true)
		expect(faces(smooth)).toBe(96)
		local _, high = smooth:bounds()
		expect(high[1] < 0.5).toBe(true)
		local creased = EditMesh.box()
		creased:select("edge", "all"):crease(1)
		creased:smoothSubdivide(2)
		local _, sharp = creased:bounds()
		expect(near(sharp[1], 0.5)).toBe(true)
		expect(near(volume(creased), 1)).toBe(true)
	end)

	it("bridges two faces into a tunnel, and fills holes", function()
		local m = EditMesh.box({ 1, 2, 1 })
		local front = m:select("face", "facing", { 0, -1, 0 }):first()
		local back = m:select("face", "facing", { 0, 1, 0 }):first()
		m:inset({ front }, 0.2, 0)
		m:inset({ back }, 0.2, 0)
		local tunnel = m:bridgeFaces(front, back)
		expect(tunnel:count()).toBe(4)
		expect(healthy(m)).toBe(true)
		expect(near(volume(m), 2 - 0.6 * 0.6 * 2)).toBe(true)
		local open = EditMesh.box()
		open:removeFace(open:select("face", "facing", { 0, 0, 1 }):first())
		open:fill(open:select("edge", "where", function(p)
			return p[3] > 0.49
		end))
		expect(healthy(open)).toBe(true)
		expect(near(volume(open), 1)).toBe(true)
	end)

	it("bevels an edge flat or round", function()
		for _, segments in { 1, 3 } do
			local m = EditMesh.box()
			local edge = m:select("edge", "where", function(p)
				return p[2] < -0.49 and p[3] > 0.49
			end)
			local strip = m:bevel(edge, 0.2, segments)
			expect(strip:count()).toBe(segments)
			expect(healthy(m, { ngons = true })).toBe(true)
			expect(volume(m) < 1 and volume(m) > 0.97).toBe(true)
		end
	end)

	it("pokes a point into faces", function()
		local m = EditMesh.box()
		m:poke(m:select("face", "facing", { 0, 0, 1 }))
		expect(healthy(m)).toBe(true)
		expect(faces(m)).toBe(9)
	end)
end)

describe("EditOps reshaping", function()
	it("bends, tapers and twists", function()
		local strip = EditMesh.box({ 4, 1, 0.2 }, { 16, 1, 1 })
		strip:bend(90, "x", "z")
		expect(healthy(strip)).toBe(true)
		local low, high = strip:bounds()
		expect(high[3] - low[3] > 2).toBe(true)
		local post = EditMesh.box({ 1, 1, 2 }, { 1, 1, 4 })
		post:taper("z", 1, 0.5)
		local top = post:select("vertex", "where", function(p)
			return p[3] > 0.99
		end)
		expect(near(math.abs(post:position(top:first())[1]), 0.25)).toBe(true)
		local bar = EditMesh.box({ 1, 1, 4 }, { 1, 1, 8 })
		bar:twist("z", 90)
		expect(healthy(bar)).toBe(true)
	end)

	it("smooths, pushes along normals and pulls round", function()
		local m = EditMesh.box({ 1, 1, 1 }, { 3, 3, 3 })
		m:toSphere(nil, 1, 1)
		for _, vert in m.verts do
			local p = vert.position
			expect(near(math.sqrt(p[1] ^ 2 + p[2] ^ 2 + p[3] ^ 2), 1)).toBe(true)
		end
		m:push(nil, 0.5)
		for _, vert in m.verts do
			local p = vert.position
			expect(near(math.sqrt(p[1] ^ 2 + p[2] ^ 2 + p[3] ^ 2), 1.5, 0.02)).toBe(true)
		end
		local bumpy = EditMesh.grid(2, 2, 4, 4)
		local middle = bumpy:select("vertex", "where", function(p)
			return math.abs(p[1]) < 1e-9 and math.abs(p[2]) < 1e-9
		end)
		middle:move({ 0, 0, 1 })
		bumpy:smooth(nil, 0.5, 3, { keepBorder = true })
		expect(bumpy:position(middle:first())[3] < 0.5).toBe(true)
		local square = EditMesh.grid(2, 2, 2, 2)
		local rim = square:select("vertex", "where", function(p)
			return math.abs(p[1]) > 0.99 or math.abs(p[2]) > 0.99
		end)
		square:toCircle(rim)
		local first = square:position(rim:first())
		local r = math.sqrt(first[1] ^ 2 + first[2] ^ 2)
		for vert in rim.ids do
			local p = square:position(vert)
			expect(near(math.sqrt(p[1] ^ 2 + p[2] ^ 2), r)).toBe(true)
		end
	end)
end)

describe("EditOps cleanup and finishing", function()
	it("dissolves an edge and welds touching vertices", function()
		local sheet = EditMesh.grid(2, 1, 2, 1)
		local middle = sheet:select("edge", "where", function(p)
			return math.abs(p[1]) < 1e-9
		end)
		sheet:dissolve(middle)
		expect(faces(sheet)).toBe(1)
		expect(#sheet.faces[next(sheet.faces)].verts).toBe(6)
		local pair = EditMesh.box()
		local other = EditMesh.box()
		other:translate(1, 0, 0)
		pair:append(other)
		expect(pair:weld(1e-6)).toBe(4)
	end)

	it("mirrors half a shape into a whole one", function()
		local half = EditMesh.box()
		half:translate(0.5, 0, 0)
		half:removeFace(half:select("face", "facing", { -1, 0, 0 }):first())
		half:mirror("x")
		expect(healthy(half)).toBe(true)
		expect(near(volume(half), 2)).toBe(true)
		local low, high = half:bounds()
		expect(near(low[1], -1) and near(high[1], 1)).toBe(true)
	end)

	it("gives a sheet thickness and repeats shapes in a row", function()
		local sheet = EditMesh.grid(1, 1, 2, 2)
		sheet:solidify(0.1)
		expect(healthy(sheet)).toBe(true)
		expect(near(volume(sheet), 0.1)).toBe(true)
		local row = EditMesh.box()
		row:array(3, { 2, 0, 0 })
		expect(faces(row)).toBe(18)
		expect(near(volume(row), 3)).toBe(true)
	end)

	it("works fast enough for builds", function()
		local started = os.clock()
		local m = EditMesh.roundedBox({ 2, 1, 1 }, 0.2, 3)
		m:inset(m:select("face", "facing", { 0, 0, 1 }), 0.1, -0.1)
		m:smoothSubdivide(2)
		local recorder = Art.recorder()
		m:emit(recorder)
		local seconds = os.clock() - started
		expect(seconds < 2).toBe(true)
		expect(#recorder.faces > 1000).toBe(true)
	end)
end)
