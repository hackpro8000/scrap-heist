--!strict
--[[
	Model check: runs assembled model scripts (art/models/<Name>/model.luau)
	with a stand-in for the engine's Mesh that records what they build, and
	reports, per model:

	- floating pieces: a piece is a run of faces sharing vertices; a group of
	  pieces that touch nothing else (by their bounding boxes, within TOUCH)
	  floats. Part names listed on a `-- floats: A, B` line of the item's
	  source may float.
	- holes: edges with one face (parts listed on `-- open: A, B` may have them)
	- fins: edges with more than two faces
	- flipped faces: neighbours running a shared edge the same way
	- pieces turned inside out: closed ones whose faces all point inward
	- for information: faces with more than four corners, and the share of
	  four-sided faces

	  lune run tools/modelcheck/check <Name>...

	Prints one line per model and exits 1 if any has a problem. No build:
	nothing is painted or written.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local TOUCH = 0.03

type Box = { number }

local function listed(source: string, key: string): { [string]: boolean }
	local names = {}
	for line in string.gmatch(source, "[^\n]+") do
		local list = string.match(line, "^%-%- " .. key .. ":%s*(.+)$")
		if list then
			for name in string.gmatch(list, "[%w_]+") do
				names[name] = true
			end
		end
	end
	return names
end

local function check(name: string): (boolean, string)
	local path = `art/models/{name}/model.luau`
	if not fs.isFile(path) then
		return false, `{name}: no assembled model (scripts/assemble-model.sh {name})`
	end
	local itemPath = `art/src/items/{name}.luau`
	local itemSource = if fs.isFile(itemPath) then fs.readFile(itemPath) else ""
	local mayFloat, mayOpen = listed(itemSource, "floats"), listed(itemSource, "open")

	local parts = {}
	local function newMesh()
		local mesh = { verts = {}, faces = {} }
		function mesh:vertex(x, y, z)
			table.insert(self.verts, { x, y, z })
			return #self.verts
		end
		function mesh:face(list)
			table.insert(self.faces, table.clone(list))
		end
		function mesh:setSmooth() end
		function mesh:unwrap()
			return 1
		end
		function mesh:paint() end
		function mesh:paintShading() end
		function mesh:weld() end
		return mesh
	end
	local env = setmetatable({
		Mesh = { new = newMesh },
		Image = { new = function()
			return {}
		end },
		model = { part = function(partName, mesh)
			table.insert(parts, { name = partName, mesh = mesh })
		end },
		TEXEL_SCALE = 1,
	}, { __index = _G })
	local ok, err = pcall(function()
		luau.load(fs.readFile(path), { debugName = path, environment = env })()
	end)
	if not ok then
		return false, `{name}: script error: {err}`
	end

	local problems = {}
	local quads, faces, ngons = 0, 0, 0
	local pieces = {}
	for _, part in parts do
		local mesh = part.mesh
		-- Helper shapes build each side from its own vertices; sides that meet
		-- at the same positions count as joined, as the engine welds them.
		local canonical, byPosition = {}, {}
		for index, p in mesh.verts do
			local key = string.format("%.5f,%.5f,%.5f", p[1], p[2], p[3])
			byPosition[key] = byPosition[key] or index
			canonical[index] = byPosition[key]
		end
		local welded = {}
		for _, face in mesh.faces do
			local list = {}
			for _, v in face do
				local c = canonical[v]
				if list[#list] ~= c then
					table.insert(list, c)
				end
			end
			if #list > 1 and list[1] == list[#list] then
				table.remove(list)
			end
			if #list >= 3 then
				table.insert(welded, list)
			end
		end
		mesh = { verts = mesh.verts, faces = welded }
		-- Edges: how many faces use each, and which way.
		local edgeUses = {}
		for _, face in mesh.faces do
			faces += 1
			if #face == 4 then
				quads += 1
			elseif #face > 4 then
				ngons += 1
			end
			for index, a in face do
				local b = face[index % #face + 1]
				local key = if a < b then `{a}:{b}` else `{b}:{a}`
				local use = edgeUses[key] or { count = 0, forward = 0 }
				use.count += 1
				if a < b then
					use.forward += 1
				end
				edgeUses[key] = use
			end
		end
		local holes, fins, flipped = 0, 0, 0
		for _, use in edgeUses do
			if use.count == 1 then
				holes += 1
			elseif use.count > 2 then
				fins += 1
			elseif use.forward ~= 1 then
				flipped += 1
			end
		end
		if holes > 0 and not mayOpen[part.name] then
			table.insert(problems, `{part.name} has {holes} open edges`)
		end
		if fins > 0 then
			table.insert(problems, `{part.name} has {fins} edges shared by 3+ faces`)
		end
		if flipped > 0 then
			table.insert(problems, `{part.name} has {flipped} edges between faces turned against each other`)
		end

		-- Pieces: faces joined through shared vertices, with their boxes.
		local parent = {}
		local function find(a)
			while parent[a] and parent[a] ~= a do
				a = parent[a]
			end
			return a
		end
		for i = 1, #mesh.verts do
			parent[i] = i
		end
		for _, face in mesh.faces do
			local root = find(face[1])
			for k = 2, #face do
				local other = find(face[k])
				if other ~= root then
					parent[other] = root
				end
			end
		end
		-- A closed piece whose faces all point inward has a negative volume
		-- and would show the camera its inside. (Open pieces have no inside,
		-- so only a part without holes is judged.)
		if holes == 0 then
			local volumes = {}
			for _, face in mesh.faces do
				local root = find(face[1])
				local a: { number } = mesh.verts[face[1]]
				for k = 2, #face - 1 do
					local b: { number }, c: { number } = mesh.verts[face[k]], mesh.verts[face[k + 1]]
					local triple = a[1] * (b[2] * c[3] - b[3] * c[2])
						- a[2] * (b[1] * c[3] - b[3] * c[1])
						+ a[3] * (b[1] * c[2] - b[2] * c[1])
					volumes[root] = (volumes[root] or 0) + triple / 6
				end
			end
			local insideOut = 0
			for _, volume in volumes do
				if volume < -1e-6 then
					insideOut += 1
				end
			end
			if insideOut > 0 then
				table.insert(problems, `{part.name} has {insideOut} pieces turned inside out`)
			end
		end

		local boxes = {}
		for _, face in mesh.faces do
			local root = find(face[1])
			local box = boxes[root]
			if not box then
				box = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
				boxes[root] = box
				table.insert(pieces, { box = box, part = part.name })
			end
			for _, v in face do
				local p = mesh.verts[v]
				for axis = 1, 3 do
					box[axis] = math.min(box[axis], p[axis])
					box[axis + 3] = math.max(box[axis + 3], p[axis])
				end
			end
		end
	end

	-- Group pieces that touch; every group but the biggest floats.
	local parent = {}
	local function find(a)
		while parent[a] ~= a do
			a = parent[a]
		end
		return a
	end
	for i = 1, #pieces do
		parent[i] = i
	end
	local function touch(a: Box, b: Box): boolean
		for k = 1, 3 do
			if a[k] > b[k + 3] + TOUCH or b[k] > a[k + 3] + TOUCH then
				return false
			end
		end
		return true
	end
	for i = 1, #pieces do
		for j = i + 1, #pieces do
			if touch(pieces[i].box, pieces[j].box) then
				local a, b = find(i), find(j)
				if a ~= b then
					parent[b] = a
				end
			end
		end
	end
	local groups = {}
	for i = 1, #pieces do
		local root = find(i)
		groups[root] = groups[root] or {}
		table.insert(groups[root], pieces[i])
	end
	local list = {}
	for _, group in groups do
		table.insert(list, group)
	end
	table.sort(list, function(a, b)
		return #a > #b
	end)
	for index = 2, #list do
		local names, seen, allowed = {}, {}, true
		for _, piece in list[index] do
			if not seen[piece.part] then
				seen[piece.part] = true
				table.insert(names, piece.part)
				if not mayFloat[piece.part] then
					allowed = false
				end
			end
		end
		if not allowed then
			table.insert(problems, `floating: {table.concat(names, ", ")}`)
		end
	end

	local share = if faces == 0 then 1 else quads / faces
	local summary = string.format("%d faces, %d%% quads, %d n-gons", faces, math.floor(share * 100 + 0.5), ngons)
	if #problems > 0 then
		return false, `FAIL {name} ({summary}): {table.concat(problems, "; ")}`
	end
	return true, `ok   {name} ({summary})`
end

local names = process.args
local failed = false
for _, name in names do
	local ok, line = check(name)
	print(line)
	failed = failed or not ok
end
process.exit(if failed then 1 else 0)
