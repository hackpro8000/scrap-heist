--!strict
--[[
	PlaceSky: run in Studio's command bar (edit mode, Rojo synced) to load
	the sky's uploaded models (Assets.Models.Sky*, from
	scripts/upload-model.sh) into ReplicatedStorage.SkyModels, where
	AtmosphereController reads them on each client.

	The models are only templates. A MeshPart can't be bigger than 2048
	studs, and the sky's bodies are far bigger, so the controller never
	clones these: it reads each MeshPart's mesh, texture and place in its
	model, and shows it as a SpecialMesh scaled up as far as it likes.
	Where the templates stand and which way they face doesn't matter.

	Re-running replaces the models. Save the place afterwards.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The command bar keeps what a module returned the first time it was
-- required, so require a fresh copy to pick up new uploads.
local Assets = require(ReplicatedStorage.Shared.Assets:Clone())

local MODELS = { "SkyIslands", "SkyCog", "SkyPlanet", "SkyMoons", "SkyWindmill" }
local FOLDER = "SkyModels"

local folder = ReplicatedStorage:FindFirstChild(FOLDER)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = ReplicatedStorage
end

local placed = 0
for _, name in MODELS do
	local id = Assets.Models[name]
	if not Assets.isSet(id) then
		warn(`PlaceSky: Assets.Models.{name} isn't uploaded yet`)
		continue
	end
	-- LoadAsset wraps the asset in a model; take what's inside.
	local container = InsertService:LoadAsset(tonumber(string.match(id, "%d+")) :: number)
	local model = container:FindFirstChildOfClass("Model") or container
	model.Name = name
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	if container ~= model then
		container:Destroy()
	end
	placed += 1
end

print(`PlaceSky: placed {placed} of {#MODELS} sky models in ReplicatedStorage.{FOLDER}`)
