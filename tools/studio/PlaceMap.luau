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

	Re-running rebuilds workspace.Map from scratch. Save the place afterwards.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local MapChunks = require(ReplicatedStorage.Shared.Config.MapChunks)

-- How far off an anchor may land, in studs, before the chunk is flagged.
local TOLERANCE = 0.05

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

-- Anchors every part, and lets the see-through ones (the propeller blur
-- discs) blend. The importer gives most meshes a plain TextureID rather
-- than a SurfaceAppearance, and Roblox only blends a MeshPart texture's
-- alpha once the part itself is a little transparent.
local function prepare(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
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
