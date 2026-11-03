--!strict
--[[
	DummyService

	Training dummies: NPC fighters that stand still and swing at the nearest
	player in range on a slow, steady beat. They prove combat works against
	NPC humanoids (the same path bots use) and give a target to practise
	blocking and parrying on. A dummy that dies respawns where it stood.

	In Studio one dummy spawns automatically; showcase mode can spawn more.

	Public API:
		DummyService.spawnDummy(position): Model
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local CombatService = require(script.Parent.CombatService)
local NpcRig = require(script.Parent.Parent.Npc.NpcRig)

local DUMMY = WeaponConfig.Dummy
local STUDIO_DUMMY_POSITION = Vector3.new(0, 5, -20)
local DUMMY_LOOK: NpcRig.Look = {
	size = Vector3.new(2, 5, 1.5),
	color = Color3.fromRGB(150, 120, 90),
	maxHealth = DUMMY.health,
}

local DummyService = {}

local function nearestCharacter(position: Vector3, range: number): Model?
	local nearest: Model? = nil
	local nearestDistance = range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance < nearestDistance then
				nearest = character
				nearestDistance = distance
			end
		end
	end

	return nearest
end

function DummyService.spawnDummy(position: Vector3): Model
	local model = NpcRig.build("TrainingDummy", DUMMY_LOOK)
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.AutoRotate = false

	model:PivotTo(CFrame.new(position))
	model.Parent = workspace
	-- The server simulates the dummy, so its position can be trusted for
	-- hit checks, like every NPC.
	root:SetNetworkOwner(nil)

	CombatService.register(model, DUMMY.weapon)

	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			task.wait(DUMMY.swingInterval)
			local target = nearestCharacter(root.Position, DUMMY.aggroRange)
			local targetRoot = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetRoot and humanoid.Health > 0 then
				local flatTarget = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
				root.CFrame = CFrame.lookAt(root.Position, flatTarget)
				CombatService.attack(model)
			end
		end
	end)

	humanoid.Died:Once(function()
		task.delay(DUMMY.respawnDelay, function()
			model:Destroy()
			DummyService.spawnDummy(position)
		end)
	end)

	return model
end

function DummyService.init() end

function DummyService.start()
	if RunService:IsStudio() then
		DummyService.spawnDummy(STUDIO_DUMMY_POSITION)
	end
end

return DummyService
