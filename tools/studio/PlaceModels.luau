--!strict
--[[
	PlaceModels: run in Studio's command bar (edit mode, Rojo synced) to load
	the uploaded models (Assets.Models, from scripts/upload-model.sh) into
	the ServerStorage folders the game clones them from. Roblox turns an
	upload 180 degrees about the vertical, so the art's front faces the
	model's forward (-Z).

	Bots go to ServerStorage.NpcModels, for NpcRig. Roblox imports a rigged
	model as an AnimationController, a RootPart at the model's origin (its
	ground) holding the Bones, and every mesh joined to the RootPart by a
	Motor6D and skinned to its bone. Each becomes what NpcRig and the
	Humanoid need:
	- the RootPart becomes an invisible HumanoidRootPart around the mesh,
	  raised so its bottom sits HIP_HEIGHT over the ground, with the Bones
	  and Motor6Ds moved down to match, so nothing visible moves;
	- a Humanoid (with an Animator) replaces the AnimationController;
	- an invisible Head over the top, where the Humanoid shows the bot's
	  name and health;
	- the meshes are massless and don't collide, so only the root does.
	BotAnimationController plays the clips on the Bones in game.

	The salvage machine's three tiers go to ServerStorage.MachineModels as
	SalvageMachine1-3, for MachineService. Each is pivoted at its art centre,
	halfway up, which MachineService stands on the pad's top.

	Weapons go to ServerStorage.WeaponModels, named after the weapon in
	WeaponConfig, for HeldWeaponService: welded together round the part the
	hand holds, which carries a "Grip" attachment where the hand closes,
	with the weapon running along its Y axis.

	The storage crate's heaps of scrap go to ServerStorage.CrateFills as
	Fill_1-Fill_6, for PlotService. They're lined up on Yard1's crate in the
	placed map (run PlaceMap first), matching its scale, and each is pivoted
	where the YardTemplate's Crate stands there, so PlotService can pivot a
	heap onto any yard's crate.

	The part bundle goes to ServerStorage.PartBundle with its fill levels,
	Sack_1-Sack_6, each pivoted at its middle, for RaidService.

	Re-running replaces the models. Save the place afterwards.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- The command bar keeps what a module returned the first time it was
-- required, so require a fresh copy to pick up new uploads.
local Assets = require(ReplicatedStorage.Shared.Assets:Clone())

local BOTS = { "Scrapper", "Bruiser", "Zapper" }
-- Gap between a bot root's bottom and the ground; the Humanoid keeps it.
local HIP_HEIGHT = 0.1
local HEAD_SIZE = 1

local MACHINE = "SalvageMachine"
local MACHINE_TIERS = 3
-- How far apart the art stands its tiers along X, tier 2 in the middle
-- (SPACING in art/models/SalvageMachine/model.luau).
local MACHINE_SPACING = 6

local BUNDLE = "PartBundle"
local CRATE = "StorageCrate"

-- Weapon (WeaponConfig name) to the art that shows it.
local WEAPONS: { [string]: string } = { Bat = "StarterWeapon", Spanner = "BigSpanner" }
-- Where the hand closes on a weapon with no "Grip" part: this far up from
-- the handle's end (the bat's knob).
local GRIP_FROM_END = 0.35

local function folderNamed(name: string): Instance
	local existing = ServerStorage:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = ServerStorage
	return folder
end

local function replaceIn(folder: Instance, model: Model)
	local old = folder:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = folder
end

-- The uploaded model, out of the container InsertService wraps it in.
local function load(name: string): Model?
	local id = Assets.Models[name]
	if not Assets.isSet(id) then
		warn(`PlaceModels: Assets.Models.{name} isn't uploaded yet`)
		return nil
	end
	local container = InsertService:LoadAsset(tonumber(string.match(id, "%d+")) :: number)
	local model = container:FindFirstChildOfClass("Model")
	if model then
		model.Parent = nil
	end
	container:Destroy()
	return model
end

local function meshBounds(model: Instance): (Vector3, Vector3)
	local low = Vector3.one * math.huge
	local high = -low
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			local half = part.Size / 2
			low = low:Min(part.Position - half)
			high = high:Max(part.Position + half)
		end
	end
	return low, high
end

local function buildBot(name: string): Model?
	local model = load(name)
	local root = model and model:FindFirstChild("RootPart")
	if not (model and root and root:IsA("BasePart")) then
		warn(`PlaceModels: {name} has no RootPart; is it a rigged model?`)
		return nil
	end

	local meshes: { [MeshPart]: CFrame } = {}
	for _, part in model:GetChildren() do
		if part:IsA("MeshPart") then
			meshes[part] = part.CFrame
		end
	end

	local low, high = meshBounds(model)
	local bottom = low.Y + HIP_HEIGHT
	local lift = (bottom + high.Y) / 2 - root.Position.Y
	local down = CFrame.new(0, -lift, 0)
	root.CFrame += Vector3.new(0, lift, 0)
	-- The root is centred on X and Z, so it covers the mesh both ways.
	local reach = Vector3.new(math.max(-low.X, high.X), 0, math.max(-low.Z, high.Z)) * 2
	root.Size = Vector3.new(reach.X, high.Y - bottom, reach.Z)
	for _, child in root:GetChildren() do
		if child:IsA("Bone") then
			child.CFrame = down * child.CFrame
		end
	end
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 == root then
			joint.C0 = down * joint.C0
		end
	end
	for part, cframe in meshes do
		part.CFrame = cframe
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
	end

	root.Name = "HumanoidRootPart"
	root.Transparency = 1
	root.Anchored = false
	root.CanCollide = true

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.one * HEAD_SIZE
	head.Transparency = 1
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.Massless = true
	head.CFrame = CFrame.new(root.Position.X, high.Y - HEAD_SIZE / 2, root.Position.Z)
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = head

	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		controller:Destroy()
	end
	local humanoid = Instance.new("Humanoid")
	-- R15 floats the root at HipHeight over the floor, so a body with no
	-- legs stands upright.
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	model.Name = name
	model.PrimaryPart = root
	print(`PlaceModels: {name}, root {root.Size}`)
	return model
end

-- The tiers, each moved so its art centre stands at the origin.
local function buildMachineTiers(): { Model }
	local art = load(MACHINE)
	if not art then
		return {}
	end
	local tiers = {}
	for tier = 1, MACHINE_TIERS do
		local group = art:FindFirstChild(`Tier_{tier}`)
		if not (group and group:IsA("Model")) then
			warn(`PlaceModels: {MACHINE} has no Tier_{tier}`)
			continue
		end
		-- Turned with the rest of the upload, so the tiers run along -X.
		local centre = Vector3.new(-(tier - 2) * MACHINE_SPACING, 0, 0)
		for _, part in group:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame -= centre
				part.Anchored = true
			end
		end
		local low, high = meshBounds(group)
		group.WorldPivot = CFrame.new(0, (low.Y + high.Y) / 2, 0)
		group.Name = `{MACHINE}{tier}`
		group.Parent = nil
		table.insert(tiers, group)
	end
	art:Destroy()
	return tiers
end

-- The crate's heaps, lined up on Yard1's crate art and pivoted at the
-- template's Crate as it stands in Yard1.
local function buildCrateFills(): { Model }
	local map = workspace:FindFirstChild("Map")
	local yardCrate = map and map:FindFirstChild("Yard1") and map.Yard1:FindFirstChild("Crate")
	local mapBody = yardCrate and yardCrate:FindFirstChild("Body", true)
	local spot = workspace:FindFirstChild("YardSpots") and workspace.YardSpots:FindFirstChild("Yard1")
	local template = ServerStorage:FindFirstChild("YardTemplate")
	local hook = template and template:FindFirstChild("Crate")
	if
		not (mapBody and mapBody:IsA("BasePart") and spot and spot:IsA("BasePart") and hook and hook:IsA("BasePart"))
	then
		warn("PlaceModels: crate fills need the placed map (Yard1's crate) and its YardTemplate; run PlaceMap first")
		return {}
	end
	local art = load(CRATE)
	local body = art and art:FindFirstChild("Body", true)
	if not (art and body and body:IsA("BasePart")) then
		warn(`PlaceModels: {CRATE} has no Body`)
		return {}
	end

	art:ScaleTo(mapBody.Size.X / body.Size.X)
	local onMap = mapBody.CFrame * body.CFrame:Inverse()
	local hookInYard1 = spot.CFrame * hook.CFrame
	local fills = {}
	for _, fill in art:GetChildren() do
		if not (fill:IsA("Model") and string.match(fill.Name, "^Fill_%d+$")) then
			continue
		end
		fill:PivotTo(onMap * fill:GetPivot())
		for _, part in fill:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
			end
		end
		fill.WorldPivot = hookInYard1
		fill.Parent = nil
		table.insert(fills, fill)
	end
	art:Destroy()
	print(`PlaceModels: {CRATE}, {#fills} fill levels`)
	return fills
end

-- The bundle's fill levels, as the Sack_<n> models RaidService picks from.
local function buildBundle(): Model?
	local art = load(BUNDLE)
	if not art then
		return nil
	end
	for _, sack in art:GetChildren() do
		if not sack:IsA("Model") then
			sack:Destroy()
			continue
		end
		for _, part in sack:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
			end
		end
		local centre = sack:GetBoundingBox()
		sack.WorldPivot = centre
	end
	art.Name = BUNDLE
	print(`PlaceModels: {BUNDLE}, {#art:GetChildren()} fill levels`)
	return art
end

local function buildWeapon(weaponName: string, artName: string): Model?
	local art = load(artName)
	if not art then
		return nil
	end
	local parts: { MeshPart } = {}
	for _, part in art:GetDescendants() do
		if part:IsA("MeshPart") then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		warn(`PlaceModels: {artName} has no meshes`)
		return nil
	end

	-- One flat model of meshes, all hanging off the handle.
	local model = Instance.new("Model")
	model.Name = weaponName
	local handle = parts[1]
	for _, part in parts do
		if part.Name == "Grip" then
			handle = part
		end
	end
	local low, high = meshBounds(art)
	for _, part in parts do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = model
		if part ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	art:Destroy()

	local gripAt = if handle.Name == "Grip"
		then handle.Position
		else Vector3.new((low.X + high.X) / 2, low.Y + GRIP_FROM_END, (low.Z + high.Z) / 2)
	local grip = Instance.new("Attachment")
	grip.Name = "Grip"
	-- The art stands its weapons up along +Y.
	grip.CFrame = handle.CFrame:ToObjectSpace(CFrame.new(gripAt))
	grip.Parent = handle
	model.PrimaryPart = handle
	print(`PlaceModels: {weaponName} ({artName}), {#parts} parts`)
	return model
end

local placed = 0
local npcFolder = folderNamed("NpcModels")
for _, name in BOTS do
	local model = buildBot(name)
	if model then
		replaceIn(npcFolder, model)
		placed += 1
	end
end

local machineFolder = folderNamed("MachineModels")
for _, tier in buildMachineTiers() do
	replaceIn(machineFolder, tier)
	placed += 1
end

local weaponFolder = folderNamed("WeaponModels")
for weaponName, artName in WEAPONS do
	local model = buildWeapon(weaponName, artName)
	if model then
		replaceIn(weaponFolder, model)
		placed += 1
	end
end

local fillFolder = folderNamed("CrateFills")
for _, fill in buildCrateFills() do
	replaceIn(fillFolder, fill)
	placed += 1
end

local bundle = buildBundle()
if bundle then
	replaceIn(ServerStorage, bundle)
	placed += 1
end

print(`PlaceModels: placed {placed} models`)
