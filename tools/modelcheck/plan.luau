--!strict
--[[
	Plan check for check.luau: compares the parts a model built with its part
	plan (art/src/items/<Name>.plan.luau or art/src/bots/<Name>/plan.luau):

	- planned parts that weren't built, built parts that aren't planned
	- counts: model.part calls named after the planned part, or after it plus
	  a numeric suffix (Leg1, Leg2), against `count` (1 when unset); a mirror
	  repeats its source's count
	- mirrors: built across X from their source, at the source's size
	- built box centre and size against `at` and `size`, flagged when off by
	  more than OFF of the planned size on any axis
	- clearance: the part's largest opening, the biggest rectangle you can see
	  straight through it along X or along Z, flagged when narrower or lower
	  than planned. Y is up. Only cells with the part on both sides in their
	  row count as inside, so the open side of an L is not an opening.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local OFF = 0.25
-- Smallest planned extent the tolerance is taken from, so a flat plate's
-- zero thickness doesn't flag every rounding error.
local MIN_EXTENT = 0.2
local CELL = 0.1
local MAX_CELLS = 400

export type Box = { number }
export type Built = { name: string, box: Box, verts: { { number } }, faces: { { number } } }

type PlannedPart = {
	name: string,
	level: string?,
	attaches: string?,
	at: { number }?,
	size: { number }?,
	mirror: string?,
	count: number?,
}
type Clearance = { part: string, width: number, height: number }
type Plan = { parts: { PlannedPart }, clearance: { Clearance }? }

local function path(name: string): string?
	for _, candidate in { `art/src/items/{name}.plan.luau`, `art/src/bots/{name}/plan.luau` } do
		if fs.isFile(candidate) then
			return candidate
		end
	end
	return nil
end

local function union(list: { Built }): Box
	local box = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
	for _, built in list do
		for axis = 1, 3 do
			box[axis] = math.min(box[axis], built.box[axis])
			box[axis + 3] = math.max(box[axis + 3], built.box[axis + 3])
		end
	end
	return box
end

local function vector(v: { number }): string
	return string.format("%.2g×%.2g×%.2g", v[1], v[2], v[3])
end

local function point(v: { number }): string
	return string.format("(%.2g, %.2g, %.2g)", v[1], v[2], v[3])
end

local function sizeOf(box: Box): { number }
	return { box[4] - box[1], box[5] - box[2], box[6] - box[3] }
end

local function centreOf(box: Box): { number }
	return { (box[1] + box[4]) / 2, (box[2] + box[5]) / 2, (box[3] + box[6]) / 2 }
end

-- Problems with one built box against a planned centre and size.
local function compare(label: string, box: Box, at: { number }?, size: { number }?, against: string, problems: { string })
	local builtSize, builtCentre = sizeOf(box), centreOf(box)
	if size then
		for axis = 1, 3 do
			if math.abs(builtSize[axis] - size[axis]) > OFF * math.max(size[axis], MIN_EXTENT) then
				table.insert(problems, `{label} is {vector(builtSize)}, {against} {vector(size)}`)
				break
			end
		end
	end
	if not at then
		return
	end
	local scale = size or builtSize
	for axis = 1, 3 do
		if math.abs(builtCentre[axis] - at[axis]) > OFF * math.max(scale[axis], MIN_EXTENT) then
			table.insert(problems, `{label} sits at {point(builtCentre)}, {against} {point(at)}`)
			return
		end
	end
end

-- Width and height of the biggest rectangle seen straight through the parts,
-- along X or along Z.
local function opening(list: { Built }): (number, number)
	local box = union(list)
	local bestWidth, bestHeight = 0, 0
	for _, through in { 1, 3 } do
		local across = if through == 1 then 3 else 1
		local width, height = box[across + 3] - box[across], box[5] - box[2]
		local cell = math.max(CELL, math.max(width, height) / MAX_CELLS)
		local cols, rows = math.max(1, math.ceil(width / cell)), math.max(1, math.ceil(height / cell))
		local filled: { boolean } = {}
		local function fill(a: { number }, b: { number }, c: { number })
			local ax, ay = a[across] - box[across], a[2] - box[2]
			local bx, by = b[across] - box[across], b[2] - box[2]
			local cx, cy = c[across] - box[across], c[2] - box[2]
			local area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
			if math.abs(area) < 1e-9 then
				return
			end
			local sign = if area > 0 then 1 else -1
			local c0 = math.max(0, math.floor(math.min(ax, bx, cx) / cell))
			local c1 = math.min(cols - 1, math.floor(math.max(ax, bx, cx) / cell))
			local r0 = math.max(0, math.floor(math.min(ay, by, cy) / cell))
			local r1 = math.min(rows - 1, math.floor(math.max(ay, by, cy) / cell))
			for r = r0, r1 do
				local py = (r + 0.5) * cell
				for col = c0, c1 do
					local px = (col + 0.5) * cell
					local e1 = ((bx - ax) * (py - ay) - (by - ay) * (px - ax)) * sign
					local e2 = ((cx - bx) * (py - by) - (cy - by) * (px - bx)) * sign
					local e3 = ((ax - cx) * (py - cy) - (ay - cy) * (px - cx)) * sign
					if e1 >= 0 and e2 >= 0 and e3 >= 0 then
						filled[r * cols + col] = true
					end
				end
			end
		end
		for _, built in list do
			for _, face in built.faces do
				local a = built.verts[face[1]]
				for k = 2, #face - 1 do
					fill(a, built.verts[face[k]], built.verts[face[k + 1]])
				end
			end
		end

		-- Largest rectangle of enclosed empty cells: per row, a histogram of
		-- how many enclosed cells run down from it, then a stack sweep.
		local runs = table.create(cols, 0)
		for r = rows - 1, 0, -1 do
			local first, last = cols, -1
			for col = 0, cols - 1 do
				if filled[r * cols + col] then
					first = math.min(first, col)
					last = col
				end
			end
			for col = 0, cols - 1 do
				local inside = col > first and col < last and not filled[r * cols + col]
				runs[col + 1] = if inside then runs[col + 1] + 1 else 0
			end
			local stack: { number } = {}
			for col = 1, cols + 1 do
				local run = if col <= cols then runs[col] else 0
				while #stack > 0 and runs[stack[#stack]] >= run do
					local top = table.remove(stack) :: number
					local left = if #stack > 0 then stack[#stack] else 0
					local w, h = (col - left - 1) * cell, runs[top] * cell
					if w * h > bestWidth * bestHeight then
						bestWidth, bestHeight = w, h
					end
				end
				if col <= cols then
					table.insert(stack, col)
				end
			end
		end
	end
	return bestWidth, bestHeight
end

-- Plan problems for the model `name`, which built `built`; none without a plan.
local function check(name: string, built: { Built }): { string }
	local planPath = path(name)
	if not planPath then
		return {}
	end
	local ok, loaded = pcall(function(): any
		local chunk = luau.load(fs.readFile(planPath), { debugName = planPath })
		return chunk()
	end)
	if not ok or type(loaded) ~= "table" or type(loaded.parts) ~= "table" then
		return { `plan {planPath} doesn't load: {if ok then "no parts list" else loaded}` }
	end
	local plan = loaded :: Plan

	local problems = {}
	local byName: { [string]: PlannedPart } = {}
	for _, planned in plan.parts do
		byName[planned.name] = planned
	end
	-- Which planned part each built part counts towards: its own name if
	-- planned, else the planned name it extends with a numeric suffix.
	local instances: { [string]: { Built } } = {}
	local unplanned, seenUnplanned = {}, {}
	for _, part in built do
		local owner = if byName[part.name] then part.name else nil
		-- A texture chunk (Name_x_y_z, from chunkedPart) counts towards its
		-- part, all of a part's chunks together as one built part.
		local chunkOf = string.match(part.name, "^(.-)_%-?%d+_%-?%d+_%-?%d+$")
		if not owner and chunkOf and byName[chunkOf] then
			local list = instances[chunkOf]
			if list and list[1] and list[1].chunked then
				list[1].box = union({ list[1], part })
			else
				instances[chunkOf] = { { name = chunkOf, box = part.box, chunked = true } }
			end
			continue
		end
		if not owner then
			local stem = string.match(part.name, "^(.-)%d+$")
			owner = if stem and byName[stem] then stem else nil
		end
		if owner then
			instances[owner] = instances[owner] or {}
			table.insert(instances[owner], part)
		elseif not seenUnplanned[part.name] then
			seenUnplanned[part.name] = true
			table.insert(unplanned, part.name)
		end
	end

	for _, planned in plan.parts do
		local list = instances[planned.name]
		local source = if planned.mirror then byName[planned.mirror] else nil
		if planned.mirror and not source then
			table.insert(problems, `plan: {planned.name} mirrors {planned.mirror}, which isn't planned`)
		end
		if not list then
			table.insert(problems, `planned {planned.name} wasn't built`)
			continue
		end
		local count = planned.count or (source and source.count) or 1
		if #list ~= count then
			table.insert(problems, `{planned.name} built {#list} times, plan says {count}`)
		end

		local at, size = planned.at, planned.size
		if source then
			size = size or source.size
			at = at or (if source.at then { -source.at[1], source.at[2], source.at[3] } else nil)
			local sourceList = instances[source.name]
			if sourceList then
				local mine, theirs = union(list), union(sourceList)
				local mirrored = { -centreOf(theirs)[1], centreOf(theirs)[2], centreOf(theirs)[3] }
				compare(planned.name, mine, mirrored, sizeOf(theirs), `{source.name} mirrored is`, problems)
			end
		end
		if count > 1 then
			-- Repeats sit in different places, so only their size is planned.
			for _, part in list do
				compare(part.name, part.box, nil, size, "plan says", problems)
			end
		else
			compare(planned.name, union(list), at, size, "plan says", problems)
		end
	end
	for _, partName in unplanned do
		table.insert(problems, `{partName} isn't in the plan`)
	end

	local clearances: { Clearance } = plan.clearance or {}
	for _, clearance in clearances do
		local list = instances[clearance.part]
		if not list then
			continue
		end
		local width, height = opening(list)
		if width < clearance.width or height < clearance.height then
			table.insert(
				problems,
				string.format(
					"%s opening is %.1f wide, %.1f high, plan needs %.1f by %.1f",
					clearance.part,
					width,
					height,
					clearance.width,
					clearance.height
				)
			)
		end
	end
	return problems
end

return { check = check }
