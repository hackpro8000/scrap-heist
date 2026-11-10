--!strict
--[[
	PlaceMap: run in Studio's command bar (edit mode, Rojo synced) to bring
	the uploaded map into workspace.Map, every piece where it belongs.

	The map travels as objects (scripts/export-objects.py), uploaded in
	bundles of many objects (tools/coordinator/bundle.py): a model placed
	eight times is uploaded once. Assets.MapChunks holds each object's
	bundle's asset ID and Config.MapChunks every placement: which object,
	the label its parts take, how far to turn it from the way it was
	uploaded, and one or two anchor parts with where their middles must
	stand. Roblox may move or scale a model when it converts the upload, so
	after copying an object for a placement this script lines it up by its
	anchors: with two, it scales the copy so they are the right distance
	apart and turns it about the vertical so they line up; with one, it
	turns the copy by the placement's turn. Then it moves the copy so the
	first anchor lands exactly in place.

	Once placed, every part takes its placement's label in front of its
	name and is regrouped by that name into one model per object, so each
	is easy to select: "Line_Walk_1_0_0" goes to Map > Line > Walk as
	"1_0_0" (the numbered pieces of a chunked mesh stay together), and
	"Yard1_Gate_Frame" to Map > Yard1 > Gate as "Frame".

	Then it hooks the map up to the game, rebuilding from the placed map the
	pieces the game's systems look for outside workspace.Map:
	- workspace.YardSpots: one part per plot, at its floor and turned so its
	  +Z faces the yard's gate (PlotService places and spawns yards there);
	- the kit: the layout builds one of each model the game places itself
	  under the label Kit (Kit_PadKitchen, Kit_CapsuleScrap, ...). They are
	  taken out of the map and filed where the game clones them from:
	  Capsule<Tier> to ServerStorage.Capsules as <Tier>, Junkrot<Id> to
	  ServerStorage.Junkrots as <Id>, and the rest (pads, bay, crate, mound,
	  press) to ServerStorage.YardKit under their own names;
	- a SpawnLocation in the middle of the spawn ring on the hub's west
	  plaza, for the moment before PlotService moves a character home, or a
	  player with no yard.

	Re-running rebuilds all of it from scratch. Save the place afterwards.
]]

local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- The command bar keeps what a module returned the first time it was
-- required, even after Rojo syncs new source into it, so require fresh
-- copies to pick up objects uploaded since.
local Assets = require(ReplicatedStorage.Shared.Assets:Clone())
local MapChunks = require(ReplicatedStorage.Shared.Config.MapChunks:Clone())

-- How far off an anchor may land, in studs, before the placement is flagged.
local TOLERANCE = 0.05

-- Parts that nothing should bump into: yard gates stand open so owners
-- and raiders can walk in and out, and the belt's capsules ride through
-- its sorter. Matched against the part's full name before regrouping.
local NO_COLLIDE = { "_Gate_Doors", "_Gate_Padlock", "_Gate_Hardware", "^Kit_Capsule", "^Kit_Junkrot" }

-- Asset IDs are long; an "ID" below this is a texture slot the importer
-- failed to swap for an asset.
local REAL_ASSET_IDS_FROM = 1e6

-- Where each kind of kit model goes: a name prefix, the ServerStorage
-- folder, and whether the prefix is dropped from the model's name there.
local KIT_NAME = "Kit"
local KIT_FOLDERS = {
	{ prefix = "Capsule", folder = "Capsules", strip = true },
	{ prefix = "Junkrot", folder = "Junkrots", strip = true },
	-- Test pieces of the modelling tools, kept apart from the game's models.
	{ prefix = "Proof", folder = "Proofs", strip = true },
	{ prefix = "", folder = "YardKit", strip = false },
}

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

local function place(model: Model, anchors: { Anchor }, turn: number): (boolean, string)
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
			local offBy = heading(flatExpected) - heading(flatActual)
			model:PivotTo(CFrame.Angles(0, offBy, 0) * model:GetPivot())
		end
	elseif turn ~= 0 then
		-- One anchor can't give a heading, so trust the placement's turn.
		model:PivotTo(CFrame.Angles(0, math.rad(turn), 0) * model:GetPivot())
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

-- Ground shade sheets (the tight contact shadows painted on see-through
-- sheets just above the ground) come through as a mesh with a plain
-- texture. At Transparency 0 Roblox draws the sheet opaque; a touch of
-- transparency makes it blend the texture's alpha as painted.
local GROUND_SHADE = "GroundShade"
local GROUND_SHADE_TRANSPARENCY = 0.02

-- Anchors every part, turns collision off where NO_COLLIDE says, lets the
-- ground shade sheets blend, and mends the glow of glowing parts:
-- the importer leaves their emissive mask pointing at a texture slot in
-- the upload ("rbxassetid://19") instead of an asset, so the part's own
-- colour map stands in for it.
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
			if descendant.Name == GROUND_SHADE or descendant.Parent.Name == GROUND_SHADE then
				descendant.Transparency = GROUND_SHADE_TRANSPARENCY
			end
		elseif descendant:IsA("SurfaceAppearance") then
			local mask = tonumber(string.match(descendant.EmissiveMaskContent.Uri or "", "%d+$"))
			if mask and mask < REAL_ASSET_IDS_FROM then
				descendant.EmissiveMaskContent = Content.fromUri(descendant.ColorMap)
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

-- Takes the kit out of the map and files each model where the game
-- clones it from, replacing what was there. Returns how many were filed.
local function fileKit(map: Instance): number
	local kit = map:FindFirstChild(KIT_NAME)
	if not kit then
		return 0
	end

	local folders: { [string]: Folder } = {}
	local count = 0
	for _, model in kit:GetChildren() do
		for _, kind in KIT_FOLDERS do
			if string.sub(model.Name, 1, #kind.prefix) == kind.prefix then
				local folder = folders[kind.folder]
				if not folder then
					folder = Instance.new("Folder")
					folder.Name = kind.folder
					folders[kind.folder] = folder
				end
				if kind.strip then
					model.Name = string.sub(model.Name, #kind.prefix + 1)
				end
				model.Parent = folder
				count += 1
				break
			end
		end
	end
	kit:Destroy()
	for _, folder in folders do
		replace(ServerStorage, folder)
	end
	return count
end

-- A neutral SpawnLocation in the middle of the spawn ring.
local function buildSpawn(map: Instance): SpawnLocation?
	local pad = map:FindFirstChild("Spawn")
	if not (pad and pad:IsA("Model")) then
		return nil
	end
	local cframe, size = pad:GetBoundingBox()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MapSpawn"
	spawn.Size = Vector3.new(4, 0.2, 4)
	spawn.CFrame = CFrame.new(cframe.Position + Vector3.new(0, size.Y / 2 - 0.1, 0))
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

-- Every asset loads at once, each on its own thread, since a load is
-- mostly waiting on the network. Objects are uploaded in bundles, so many
-- share one asset: it loads once, and each object is the bundle's child
-- named by its id (an asset from before bundling is the object itself).
-- (AssetService loads objects uploaded with an API key, which
-- InsertService:LoadAsset refuses.)
local placed, failed = 0, 0
local loaded: { [string]: Instance } = {}
local bundles: { [number]: Instance | false } = {}
local loading = 0
for _, placement in MapChunks do
	local id = (Assets.MapChunks :: any)[placement.asset]
	if not Assets.isSet(id) then
		warn(`PlaceMap: object {placement.asset} ({placement.label}) has no asset ID in Assets.MapChunks; skipped`)
		continue
	end
	local number = tonumber(string.match(id, "%d+")) :: number
	if bundles[number] ~= nil then
		continue
	end
	bundles[number] = false
	loading += 1
	task.spawn(function()
		local ok, container = pcall(AssetService.LoadAssetAsync, AssetService, number)
		if ok then
			bundles[number] = container
		else
			warn(`PlaceMap: asset {number} (holding {placement.label}) failed to load: {container}`)
		end
		loading -= 1
	end)
end
while loading > 0 do
	task.wait()
end
for _, placement in MapChunks do
	if loaded[placement.asset] then
		continue
	end
	local id = (Assets.MapChunks :: any)[placement.asset]
	local container = Assets.isSet(id) and bundles[tonumber(string.match(id, "%d+")) :: number]
	if container then
		loaded[placement.asset] = container:FindFirstChild(placement.asset, true) or container
	end
end

for index, placement in MapChunks do
	local container = loaded[placement.asset]
	if not container then
		failed += 1
		continue
	end
	-- The load wraps the asset in a model; copy what's inside into one,
	-- dropping the suffix a bundle gives every name ("Pupils__3").
	local model = Instance.new("Model")
	model.Name = placement.label
	for _, child in container:GetChildren() do
		child:Clone().Parent = model
	end
	for _, descendant in model:GetDescendants() do
		descendant.Name = (string.gsub(descendant.Name, "__%d+", ""))
	end

	local done, message = place(model, placement.anchors, placement.turn)
	if done then
		placed += 1
	else
		warn(`PlaceMap: {placement.label}: {message}; left where it loaded, check it by eye`)
		failed += 1
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Name = `{placement.label}_{descendant.Name}`
		end
	end
	prepare(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			file(folder, descendant)
		end
	end
	model:Destroy()
	-- Let Studio breathe every so often.
	if index % 25 == 0 then
		task.wait()
	end
end
for _, bundle in bundles do
	if typeof(bundle) == "Instance" then
		bundle:Destroy()
	end
end
print(`PlaceMap: {placed} placements made, {failed} need attention`)

-- Pin every object's pivot to its middle. Left unset, a model works its
-- pivot out from whatever parts it has, which on a streaming client is
-- only the ones streamed in.
for _, descendant in folder:GetDescendants() do
	if descendant:IsA("Model") then
		descendant.WorldPivot = descendant:GetBoundingBox()
	end
end

local spots = buildYardSpots(folder)
replace(workspace, spots)
local kitCount = fileKit(folder)
local spawn = buildSpawn(folder)
if spawn then
	replace(workspace, spawn)
end
print(
	`PlaceMap: hooked up {#spots:GetChildren()} yard spots, filed {kitCount} kit models `
		.. `and {if spawn then "placed the spawn" else "found NO spawn"}`
)

-- Wait for the placed meshes and textures to load, by Roblox's own load
-- callback (one call per asset as it finishes), not a fixed delay, so
-- whatever comes next (a screenshot) sees the map as players will.
local toLoad = {}
for _, root in { folder, ServerStorage } do
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("MeshPart") or descendant:IsA("SurfaceAppearance") then
			table.insert(toLoad, descendant)
		end
	end
end
local loaded, failedLoads, started = 0, 0, os.clock()
ContentProvider:PreloadAsync(toLoad, function(_content, status)
	if status == Enum.AssetFetchStatus.Success then
		loaded += 1
	else
		failedLoads += 1
	end
end)
print(string.format("PlaceMap: %d assets loaded, %d failed, in %.0fs", loaded, failedLoads, os.clock() - started))
