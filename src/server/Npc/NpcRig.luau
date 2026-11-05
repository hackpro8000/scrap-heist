--!strict
--[[
	NpcRig

	Builds the character model for an NPC (bots and the training dummy).

	If a model named after the NPC is in ServerStorage.NpcModels (for
	example ServerStorage.NpcModels.Bruiser), that model is cloned. It needs
	a Humanoid and a HumanoidRootPart. tools/studio/PlaceModels.luau puts the
	bots there from their uploaded art.
	Otherwise a gray-block placeholder is built, so every system works before
	any art exists.

	Public API:
		NpcRig.build(name, look): Model
]]

local ServerStorage = game:GetService("ServerStorage")

local NPC_MODELS_FOLDER = "NpcModels"

local NpcRig = {}

export type Look = {
	-- Size of the placeholder body block.
	size: Vector3,
	color: Color3,
	maxHealth: number,
	-- Grows the whole rig, art or placeholder, this many times its size.
	scale: number?,
}

local function buildPlaceholder(look: Look): Model
	local model = Instance.new("Model")

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = look.size
	root.Color = look.color
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	-- A Humanoid shows its name and health bar over a part called Head.
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(look.size.X * 0.6, 1, look.size.Z * 0.8)
	head.Color = look.color:Lerp(Color3.new(1, 1, 1), 0.3)
	head.CFrame = root.CFrame * CFrame.new(0, look.size.Y / 2 + 0.5, 0)
	head.CanCollide = false
	head.Massless = true
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	-- R15 floats the root at HipHeight above the floor, so a single block
	-- with no legs stands upright instead of tipping over.
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.1
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	model.PrimaryPart = root

	return model
end

function NpcRig.build(name: string, look: Look): Model
	local folder = ServerStorage:FindFirstChild(NPC_MODELS_FOLDER)
	local template = folder and folder:FindFirstChild(name)

	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = buildPlaceholder(look)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `NpcRig: {name} model needs a Humanoid`)
	if look.scale and look.scale ~= 1 then
		model:ScaleTo(look.scale)
	end
	humanoid.MaxHealth = look.maxHealth
	humanoid.Health = look.maxHealth

	model.Name = name

	return model
end

return NpcRig
