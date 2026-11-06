--!strict
--[[
	BuildRules

	What a player may build in their yard and where. The server checks every
	build request against these; the client runs the same checks to colour
	the ghost in build mode, so what looks allowed is allowed.

	The rules:
	- everything stands on the plot, on cleared land, and nothing overlaps;
	- the doorstep inside the gate stays clear;
	- every pad, bay, crate, mound and press can be walked to from the gate
	  along a way a player fits through, so nothing can be walled in;
	- a yard holds only as many pads and bays as its owner's rank allows,
	  and exactly one crate, mound and press.

	Public API:
		BuildRules.canPlace(objects, cleared, candidate): reason?
		    -- `candidate` replaces the object with its id, if there is one
		BuildRules.canAdd(objects, rank, kind): reason?
		BuildRules.unreachable(objects): { Object }
		BuildRules.allowance(rank): { [kind]: number }
		BuildRules.count(objects, kind): number
		BuildRules.clearedParcels(rank): { number }
		BuildRules.starterObjects(): { Object }
		BuildRules.REASON_TEXT: { [reason]: string }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Yard = require(ReplicatedStorage.Shared.Config.Yard)

local YardGrid = require(script.Parent.YardGrid)

local BuildRules = {}

type Object = YardGrid.Object

BuildRules.REASON_TEXT = {
	OffPlot = "That's over the fence.",
	NotCleared = "That land is still under rubble.",
	Doorstep = "Keep the doorstep clear.",
	Overlap = "Something is already there.",
	WalledIn = "That would wall something in.",
	TooMany = "You can't place any more of those yet.",
	UnknownKind = "That can't be built.",
} :: { [string]: string }

local function cellIndex(x: number, z: number): number
	return z * Yard.COLUMNS + x
end

-- Marks every cell the objects cover. Returns nil if two overlap.
local function occupancy(objects: { Object }): { [number]: boolean }?
	local taken = {}
	for _, object in objects do
		local width, depth = YardGrid.footprint(object.kind, object.turn)
		for z = object.z, object.z + depth - 1 do
			for x = object.x, object.x + width - 1 do
				local index = cellIndex(x, z)
				if taken[index] then
					return nil
				end
				taken[index] = true
			end
		end
	end

	return taken
end

-- Whether a player can stand with their corner at cell (x, z): every cell
-- they cover is on the plot and free.
local function canStand(taken: { [number]: boolean }, x: number, z: number): boolean
	if x < 0 or z < 0 or x + Yard.WALK_CELLS > Yard.COLUMNS or z + Yard.WALK_CELLS > Yard.ROWS then
		return false
	end
	for dz = 0, Yard.WALK_CELLS - 1 do
		for dx = 0, Yard.WALK_CELLS - 1 do
			if taken[cellIndex(x + dx, z + dz)] then
				return false
			end
		end
	end

	return true
end

-- Everywhere a player can stand, walking in from the doorstep.
local function walkable(taken: { [number]: boolean }): { [number]: boolean }
	local reached = {}
	local startX = Yard.DOORSTEP.x + math.floor((Yard.DOORSTEP.width - Yard.WALK_CELLS) / 2)
	local startZ = Yard.ROWS - Yard.WALK_CELLS
	if not canStand(taken, startX, startZ) then
		return reached
	end

	local queue = { { startX, startZ } }
	reached[cellIndex(startX, startZ)] = true
	local head = 1
	while head <= #queue do
		local x, z = queue[head][1], queue[head][2]
		head += 1
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nextX, nextZ = x + step[1], z + step[2]
			local index = cellIndex(nextX, nextZ)
			if not reached[index] and canStand(taken, nextX, nextZ) then
				reached[index] = true
				table.insert(queue, { nextX, nextZ })
			end
		end
	end

	return reached
end

-- Whether a player can stand right against the object, on any side.
local function isReached(object: Object, reached: { [number]: boolean }): boolean
	local width, depth = YardGrid.footprint(object.kind, object.turn)
	local walk = Yard.WALK_CELLS
	-- Standing spots whose square touches the object's edge: a ring one
	-- player's width out from its corner cell.
	for z = object.z - walk, object.z + depth do
		for x = object.x - walk, object.x + width do
			local besideX = x == object.x - walk or x == object.x + width
			local besideZ = z == object.z - walk or z == object.z + depth
			-- Touching a side, not just a corner.
			if besideX ~= besideZ and x >= 0 and z >= 0 and reached[cellIndex(x, z)] then
				return true
			end
		end
	end

	return false
end

function BuildRules.unreachable(objects: { Object }): { Object }
	local taken = occupancy(objects)
	if not taken then
		return objects
	end

	local reached = walkable(taken)
	local cut = {}
	for _, object in objects do
		if Yard.MUST_REACH[object.kind] and not isReached(object, reached) then
			table.insert(cut, object)
		end
	end

	return cut
end

function BuildRules.count(objects: { Object }, kind: string): number
	local count = 0
	for _, object in objects do
		if object.kind == kind then
			count += 1
		end
	end

	return count
end

function BuildRules.allowance(rank: number): { [string]: number }
	local bays = 1
	for _, bayRank in Yard.BAY_RANKS do
		if rank >= bayRank then
			bays += 1
		end
	end

	return {
		Pad = math.min(Yard.MAX_PADS, Yard.STARTING_PADS + rank),
		Bay = bays,
		Crate = 1,
		Mound = 1,
		Press = 1,
	}
end

function BuildRules.clearedParcels(rank: number): { number }
	local cleared = table.clone(Yard.STARTING_PARCELS)
	for index, clearRank in Yard.CLEAR_RANKS do
		if rank >= clearRank then
			table.insert(cleared, Yard.CLEAR_ORDER[index])
		end
	end

	return cleared
end

function BuildRules.canPlace(objects: { Object }, cleared: { number }, candidate: Object): string?
	if not Yard.FOOTPRINTS[candidate.kind] then
		return "UnknownKind"
	end

	local width, depth = YardGrid.footprint(candidate.kind, candidate.turn)
	if
		candidate.x < 0
		or candidate.z < 0
		or candidate.x + width > Yard.COLUMNS
		or candidate.z + depth > Yard.ROWS
		or candidate.x % 1 ~= 0
		or candidate.z % 1 ~= 0
	then
		return "OffPlot"
	end

	-- A rectangle no bigger than a parcel lies on cleared land if its four
	-- corners do.
	for _, corner in { { 0, 0 }, { width - 1, 0 }, { 0, depth - 1 }, { width - 1, depth - 1 } } do
		local parcel = YardGrid.parcelOf(candidate.x + corner[1], candidate.z + corner[2])
		if not table.find(cleared, parcel) then
			return "NotCleared"
		end
	end

	local step = Yard.DOORSTEP
	if
		candidate.x < step.x + step.width
		and candidate.x + width > step.x
		and candidate.z < step.z + step.depth
		and candidate.z + depth > step.z
	then
		return "Doorstep"
	end

	local after = {}
	for _, object in objects do
		if object.id ~= candidate.id then
			table.insert(after, object)
		end
	end
	table.insert(after, candidate)

	if not occupancy(after) then
		return "Overlap"
	end
	if #BuildRules.unreachable(after) > 0 then
		return "WalledIn"
	end

	return nil
end

-- Whether a yard at `rank` has room for one more of `kind`.
function BuildRules.canAdd(objects: { Object }, rank: number, kind: string): string?
	local allowed = BuildRules.allowance(rank)[kind]
	if not allowed then
		return "UnknownKind"
	end
	if BuildRules.count(objects, kind) >= allowed then
		return "TooMany"
	end

	return nil
end

function BuildRules.starterObjects(): { Object }
	local objects = {}
	for id, spot in Yard.STARTER_LAYOUT do
		table.insert(objects, {
			id = id,
			kind = spot.kind,
			family = spot.family,
			x = spot.x,
			z = spot.z,
			turn = spot.turn,
		})
	end

	return objects
end

return BuildRules
