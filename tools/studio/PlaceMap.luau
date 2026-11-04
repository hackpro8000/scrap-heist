--!strict
--[[
	PlaceMap: run in Studio's command bar (edit mode, Rojo synced) to bring
	the uploaded map chunks into workspace.Map, each where it belongs.

	The map is too big for one Open Cloud upload, so `modelkit --chunks`
	splits it into several models (scripts/upload-chunks.sh uploads them and
	writes their IDs into Assets.MapChunks). Roblox may move, turn or scale a
	model when it converts the upload, so each chunk carries two anchor
	parts and where their middles must stand (Config.MapChunks). After
	loading a chunk this script scales it so the anchors are the right
	distance apart, turns it about the vertical so they line up, and moves
	it so the first anchor lands exactly in place.

	The upload chunks are only how the map travels. Once placed, every part
	is regrouped by its name into one model per object, so each is easy to
	select: "Pad1_Plaza_1_0_0" goes to Map > Pad1 > Plaza as "1_0_0" (the
	numbered pieces of a chunked mesh stay together), and "Yard1_Gate_Frame"
	to Map > Yard1 > Gate as "Frame".

	Then it hooks the map up to the game, rebuilding from the placed map the
	pieces the game's systems look for outside workspace.Map:
	- workspace.YardSpots: one part per plot, at its floor and turned so its
	  +Z faces the yard's gate (PlotService places and spawns yards there);
	- ServerStorage.YardTemplate: invisible Pad1-Pad4, Crate and PlotMarker
	  where Yard1's art has them, for PlotService and MachineService to hang
	  prompts and machines on, so the art is what players see;
	- workspace.Arena: an invisible disc on the drone's fight floor
	  (RoundService takes the arena's centre and size from it);
	- a SpawnLocation on the spawn pad round the beacon, for the moment
	  before PlotService moves a character home, or a player with no yard.

	Re-running rebuilds all of it from scratch. Save the place afterwards.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- The command bar keeps what a module returned the first time it was
-- required, even after Rojo syncs new source into it, so require fresh
-- copies to pick up chunks uploaded since.
local Assets = require(ReplicatedStorage.Shared.Assets:Clone())
local MapChunks = require(ReplicatedStorage.Shared.Config.MapChunks:Clone())

-- How far off an anchor may land, in studs, before the chunk is flagged.
local TOLERANCE = 0.05

-- Parts that nothing should bump into: the drone's propellers turn over
-- the gangway, and yard gates stand open so owners and raiders can walk
-- in and out. Matched against the part's full name before regrouping.
local NO_COLLIDE = { "^ArenaDrone_Prop", "_Gate_Doors", "_Gate_Padlock", "_Gate_Hardware" }

-- Radius of the drone's flat fight floor inside the ramps (ARENA_FLOOR in
-- art/src/layouts/ServerMap.luau).
local ARENA_FLOOR_RADIUS = 54
-- How far from the beacon's middle the spawn point stands: clear of the
-- 14-stud beacon plinth, on the 26-stud spawn pad round it.
local SPAWN_FROM_BEACON = 10
-- The yard pieces the game hangs its prompts and machines on.
local YARD_PIECES = { "Pad1", "Pad2", "Pad3", "Pad4", "Crate", "PlotMarker" }

type Anchor = { name: string, position: Vector3 }

-- Turn about the vertical, measured the way CFrame.Angles(0, a, 0) turns.
local function heading(vector: Vector3): number
	return math.atan2(-vector.Z, vector.X)
end

local function findAnchor(model: Model, anchor: Anchor): BasePart?
	local found = model:FindFirstChild(anchor.name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function place(model: Model, anchors: { Anchor }): (boolean, string)
	local first = findAnchor(model, anchors[1])
	if not first then
		return false, `anchor {anchors[1].name} not found`
	end
	local second = if anchors[2] then findAnchor(model, anchors[2]) else nil
	if anchors[2] and not second then
		return false, `anchor {anchors[2].name} not found`
	end

	if second then
		local expected = anchors[2].position - anchors[1].position
		local actual = second.Position - first.Position
		-- Undo any unit conversion the importer applied.
		local stretch = actual.Magnitude / expected.Magnitude
		if math.abs(stretch - 1) > 1e-4 then
			model:ScaleTo(model:GetScale() / stretch)
			actual = second.Position - first.Position
		end
		-- Undo any turn about the vertical, rotating about the world origin.
		local flatExpected = Vector3.new(expected.X, 0, expected.Z)
		local flatActual = Vector3.new(actual.X, 0, actual.Z)
		if flatExpected.Magnitude > 1e-3 and flatActual.Magnitude > 1e-3 then
			local turn = heading(flatExpected) - heading(flatActual)
			model:PivotTo(CFrame.Angles(0, turn, 0) * model:GetPivot())
		end
	end

	model:PivotTo(model:GetPivot() + (anchors[1].position - first.Position))

	for index, anchor in anchors do
		local part = if index == 1 then first else second
		local miss = part and (part.Position - anchor.position).Magnitude or math.huge
		if miss > TOLERANCE then
			return false, `anchor {anchor.name} is {string.format("%.2f", miss)} studs off`
		end
	end
	return true, "placed"
end

-- Anchors every part, turns collision off where NO_COLLIDE says, and lets
-- the see-through ones (the propeller blur discs) blend. The importer
-- gives most meshes a plain TextureID rather than a SurfaceAppearance, and
-- Roblox only blends a MeshPart texture's alpha once the part itself is a
-- little transparent.
local function prepare(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			for _, pattern in NO_COLLIDE do
				if string.find(descendant.Name, pattern) then
					descendant.CanCollide = false
					break
				end
			end
			if string.find(descendant.Name, "PropDisc", 1, true) then
				descendant.Transparency = 0.02
			end
		elseif descendant:IsA("SurfaceAppearance") then
			local parent = descendant.Parent
			if parent and string.find(parent.Name, "PropDisc", 1, true) then
				descendant.AlphaMode = Enum.AlphaMode.Transparency
			end
		end
	end
end

-- The model at `path` under `root`, made as needed.
local function modelAt(root: Instance, path: { string }): Instance
	local at = root
	for _, name in path do
		-- Only a model of that name: a part may share it.
		local child: Instance? = nil
		for _, candidate in at:GetChildren() do
			if candidate.Name == name and candidate:IsA("Model") then
				child = candidate
				break
			end
		end
		if not child then
			local made = Instance.new("Model")
			made.Name = name
			made.Parent = at
			child = made
		end
		at = child :: Instance
	end
	return at
end

-- Moves a part to its object's model: the name's words up to the last one
-- name the models, and the last word names the part; a run of trailing
-- numbers (a chunked mesh's grid position) is kept together as the part's
-- name, under a model named by the words before it.
local function file(root: Instance, part: BasePart)
	local words = string.split(part.Name, "_")
	local numbers = {}
	while #words > 1 and tonumber(words[#words]) do
		table.insert(numbers, 1, table.remove(words))
	end
	if #numbers > 0 then
		part.Name = table.concat(numbers, "_")
		part.Parent = modelAt(root, words)
	elseif #words > 1 then
		part.Name = table.remove(words) :: string
		part.Parent = modelAt(root, words)
	else
		part.Parent = root
	end
end

-- An invisible part the game only reads or hangs things on: nothing
-- bumps into it, touches it or hits it with a raycast.
local function hookPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	return part
end

-- Swaps in `new` for whatever stands under `parent` by that name.
local function replace(parent: Instance, new: Instance)
	local existing = parent:FindFirstChild(new.Name)
	if existing then
		existing:Destroy()
	end
	new.Parent = parent
end

-- One spot per plot, at the plot's floor, turned (as PlotService and
-- YardLayout read it) so the yard's +Z points at its gate.
local function buildYardSpots(map: Instance): Folder
	local spots = Instance.new("Folder")
	spots.Name = "YardSpots"
	for _, plot in map:GetChildren() do
		local index = string.match(plot.Name, "^Plot(%d+)$")
		local yard = if index then map:FindFirstChild(`Yard{index}`) else nil
		local gate = if yard then yard:FindFirstChild("Gate") else nil
		if not (plot:IsA("Model") and gate and gate:IsA("Model")) then
			continue
		end
		local plotCFrame, plotSize = plot:GetBoundingBox()
		local floor = plotCFrame.Position + Vector3.new(0, plotSize.Y / 2, 0)
		local toGate = gate:GetBoundingBox().Position - floor
		local yaw = math.atan2(toGate.X, toGate.Z)
		hookPart(`Yard{index}`, Vector3.new(4, 0.2, 4), CFrame.new(floor) * CFrame.Angles(0, yaw, 0), spots)
	end
	return spots
end

-- Yard1's pieces as invisible parts, placed relative to its spot, so the
-- template lands on every yard's art the same way.
local function buildYardTemplate(map: Instance, spots: Folder): Model?
	local yard = map:FindFirstChild("Yard1")
	local spot = spots:FindFirstChild("Yard1") :: BasePart?
	if not (yard and spot) then
		return nil
	end
	local template = Instance.new("Model")
	template.Name = "YardTemplate"
	for _, name in YARD_PIECES do
		local piece = yard:FindFirstChild(name)
		if not (piece and piece:IsA("Model")) then
			warn(`PlaceMap: Yard1 has no {name}; YardTemplate left as it was`)
			return nil
		end
		local cframe, size = piece:GetBoundingBox()
		hookPart(name, size, spot.CFrame:ToObjectSpace(cframe), template)
	end
	template.WorldPivot = CFrame.new()
	return template
end

-- The drone's fight floor, found by dropping a ray onto it between the
-- beacon and the ramps.
local function buildArena(map: Instance): Part?
	local drone = map:FindFirstChild("ArenaDrone")
	if not (drone and drone:IsA("Model")) then
		return nil
	end
	local centre = drone:GetBoundingBox().Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { drone }
	local probe = Vector3.new(centre.X + ARENA_FLOOR_RADIUS / 2, centre.Y + 100, centre.Z)
	local hit = workspace:Raycast(probe, Vector3.new(0, -200, 0), params)
	if not hit then
		return nil
	end
	local floor = Vector3.new(centre.X, hit.Position.Y, centre.Z)
	return hookPart(
		"Arena",
		Vector3.new(ARENA_FLOOR_RADIUS * 2, 1, ARENA_FLOOR_RADIUS * 2),
		CFrame.new(floor - Vector3.new(0, 0.5, 0)),
		workspace
	)
end

-- A neutral SpawnLocation on the spawn pad, beside the beacon.
local function buildSpawn(map: Instance): SpawnLocation?
	local pad = map:FindFirstChild("Spawn")
	if not (pad and pad:IsA("Model")) then
		return nil
	end
	local cframe, size = pad:GetBoundingBox()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MapSpawn"
	spawn.Size = Vector3.new(4, 0.2, 4)
	spawn.CFrame = CFrame.new(cframe.Position + Vector3.new(0, size.Y / 2 - 0.1, SPAWN_FROM_BEACON))
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	return spawn
end

local old = workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Map"
folder.Parent = workspace

local placed, failed = 0, 0
for _, chunk in MapChunks do
	local id = (Assets.MapChunks :: any)[chunk.key]
	if not Assets.isSet(id) then
		warn(`PlaceMap: {chunk.key} has no asset ID in Assets.MapChunks; skipped`)
		failed += 1
		continue
	end
	local ok, container = pcall(InsertService.LoadAsset, InsertService, tonumber(string.match(id, "%d+")))
	if not ok then
		warn(`PlaceMap: {chunk.key} failed to load: {container}`)
		failed += 1
		continue
	end
	-- LoadAsset wraps the asset in a model; gather what's inside into one.
	local model = Instance.new("Model")
	model.Name = chunk.key
	for _, child in container:GetChildren() do
		child.Parent = model
	end
	container:Destroy()

	local done, message = place(model, chunk.anchors)
	prepare(model)
	if done then
		placed += 1
	else
		warn(`PlaceMap: {chunk.key}: {message}; left where it loaded, check it by eye`)
		failed += 1
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			file(folder, descendant)
		end
	end
	model:Destroy()
end
print(`PlaceMap: {placed} chunks placed, {failed} need attention`)

-- Pin every object's pivot to its middle. Left unset, a model works its
-- pivot out from whatever parts it has, which on a streaming client is
-- only the ones streamed in (PropellerController turns propellers about
-- the drone's).
for _, descendant in folder:GetDescendants() do
	if descendant:IsA("Model") then
		descendant.WorldPivot = descendant:GetBoundingBox()
	end
end

local spots = buildYardSpots(folder)
replace(workspace, spots)
local template = buildYardTemplate(folder, spots)
if template then
	replace(ServerStorage, template)
end
local arena = buildArena(folder)
if arena then
	replace(workspace, arena)
end
local spawn = buildSpawn(folder)
if spawn then
	replace(workspace, spawn)
end
print(
	`PlaceMap: hooked up {#spots:GetChildren()} yard spots, `
		.. `{if template then "the yard template" else "NO yard template"}, `
		.. `{if arena then "the arena" else "NO arena"} and {if spawn then "the spawn" else "NO spawn"}`
)
