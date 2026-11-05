--!strict
--[[
	ScrapFxController

	Scrap you can see, on this client only:

	- Collecting (Notify.ScrapBurst): pieces of scrap arc from where they
	  were collected into your character, each with a sparkle trail, more
	  of them the fuller the source was (Juice.collectPieces). Every piece
	  that lands chimes a little higher than the last while pickups keep
	  coming, and a "+N" floats up over you when the first lands.
	- Machine cycles: every CYCLE_SECONDS each salvage machine near the
	  camera finishes a cycle, if its yard's crate is filling: a puff of
	  scrap-colored bits from its output, a metallic clink and one pulse of
	  its output light.

	Public API: none.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Sfx = require(script.Parent.Parent.Sfx)

local localPlayer = Players.LocalPlayer

local SCRAP_COLORS = {
	Color3.fromRGB(176, 120, 72),
	Color3.fromRGB(140, 146, 152),
	Color3.fromRGB(200, 160, 90),
	Color3.fromRGB(110, 96, 84),
}
local SPARKLE_COLOR = Color3.fromRGB(255, 225, 120)
local PIECE_SECONDS = 0.5
local ARC_HEIGHT = 7
-- Pickups closer together than this count as one streak for the chime.
local STREAK_GAP = 1.5
local CHIME_STEP = 0.05
local CHIME_MAX_SPEED = 2
local FLOAT_SECONDS = 1

local CYCLE_SECONDS = 6
local CYCLE_DISTANCE = 150
local CYCLE_BITS = 8

local streak = 0
local lastPickupAt = 0

local function rootOf(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function chime()
	local now = os.clock()
	streak = if now - lastPickupAt <= STREAK_GAP then streak + 1 else 0
	lastPickupAt = now
	Sfx.play("Collect", nil, { volume = 0.35, speed = math.min(1 + streak * CHIME_STEP, CHIME_MAX_SPEED) })
end

local function floatAmount(amount: number)
	local root = rootOf()
	if not root then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(5, 0, 1.6, 0)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = root
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font
	label.TextScaled = true
	label.TextColor3 = SPARKLE_COLOR
	label.TextStrokeTransparency = 0.2
	label.Text = `+{amount}`
	label.Parent = gui

	local info = TweenInfo.new(FLOAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 6.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, FLOAT_SECONDS)
end

local function newPiece(from: Vector3): BasePart
	local piece = Instance.new("Part")
	piece.Size = Vector3.one * (0.45 + math.random() * 0.35)
	piece.Color = SCRAP_COLORS[math.random(#SCRAP_COLORS)]
	piece.Material = Enum.Material.Metal
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.CFrame = CFrame.new(from)

	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(0, 0.2, 0)
	tail.Parent = piece
	local head = Instance.new("Attachment")
	head.Position = Vector3.new(0, -0.2, 0)
	head.Parent = piece
	local trail = Instance.new("Trail")
	trail.Attachment0 = tail
	trail.Attachment1 = head
	trail.Color = ColorSequence.new(SPARKLE_COLOR)
	trail.LightEmission = 1
	trail.Lifetime = 0.25
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.FaceCamera = true
	trail.Parent = piece

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(SPARKLE_COLOR)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.25, 0)
	sparkle.Lifetime = NumberRange.new(0.2, 0.4)
	sparkle.Rate = 30
	sparkle.Speed = NumberRange.new(0.5, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = piece

	piece.Parent = Workspace
	return piece
end

-- Flies one piece along an arc to the character, following it as it moves.
local function flyPiece(from: Vector3, onLanded: () -> ())
	local piece = newPiece(from)
	local spin = Vector3.new(math.random(), math.random(), math.random()) * 12
	local sideways = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 6
	local startedAt = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local root = rootOf()
		local alpha = math.min((os.clock() - startedAt) / PIECE_SECONDS, 1)
		if not root or alpha >= 1 then
			connection:Disconnect()
			piece:Destroy()
			if root then
				onLanded()
			end
			return
		end
		-- A quadratic arc through a raised, slightly scattered midpoint.
		local to = root.Position
		local middle = (from + to) / 2 + Vector3.new(0, ARC_HEIGHT, 0) + sideways
		local eased = alpha * alpha * (3 - 2 * alpha)
		local position = from:Lerp(middle, eased):Lerp(middle:Lerp(to, eased), eased)
		piece.CFrame = CFrame.new(position) * CFrame.Angles(spin.X * alpha, spin.Y * alpha, spin.Z * alpha)
	end)
end

local function onScrapBurst(from: Vector3, amount: number, fill: number)
	if typeof(from) ~= "Vector3" or type(amount) ~= "number" or type(fill) ~= "number" then
		return
	end

	local pieces = Juice.collectPieces(fill)
	local floated = false
	for index = 1, pieces do
		task.delay((index - 1) * Juice.COLLECT_PIECE_GAP, flyPiece, from + Vector3.new(0, 2, 0), function()
			chime()
			if not floated then
				floated = true
				floatAmount(amount)
			end
		end)
	end
end

-- Machine cycles ---------------------------------------------------------

type Machine = { model: Model, crate: BasePart?, lastParts: number, nextCycleAt: number }

local machines: { [Model]: Machine } = {}

-- The crate of the yard the machine stands in: the first ancestor that
-- holds one.
local function crateOf(model: Model): BasePart?
	local ancestor = model.Parent
	while ancestor and ancestor ~= Workspace do
		local crate = ancestor:FindFirstChild("Crate", true)
		if crate and crate:IsA("BasePart") then
			return crate
		end
		ancestor = ancestor.Parent
	end
	return nil
end

-- Where a machine's output is: a part named Output, else the top of it.
local function outputOf(model: Model): Vector3
	local output = model:FindFirstChild("Output", true)
	if output and output:IsA("BasePart") then
		return output.Position
	end
	local box, size = model:GetBoundingBox()
	return (box * CFrame.new(0, size.Y / 2, 0)).Position
end

local function finishCycle(model: Model)
	local point = Instance.new("Attachment")
	point.WorldPosition = outputOf(model)
	point.Parent = Workspace.Terrain
	Debris:AddItem(point, 2)

	local bits = Instance.new("ParticleEmitter")
	bits.Enabled = false
	bits.Color = ColorSequence.new(SCRAP_COLORS[1], SCRAP_COLORS[3])
	bits.Size = NumberSequence.new(0.3, 0.1)
	bits.Lifetime = NumberRange.new(0.5, 0.9)
	bits.Speed = NumberRange.new(8, 14)
	bits.SpreadAngle = Vector2.new(35, 35)
	bits.EmissionDirection = Enum.NormalId.Top
	bits.Acceleration = Vector3.new(0, -50, 0)
	bits.RotSpeed = NumberRange.new(-300, 300)
	bits.Parent = point
	bits:Emit(CYCLE_BITS)

	local light = Instance.new("PointLight")
	light.Color = SPARKLE_COLOR
	light.Range = 10
	light.Brightness = 0
	light.Parent = point
	local up = TweenService:Create(light, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Brightness = 5 })
	up.Completed:Once(function()
		TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	end)
	up:Play()

	Sfx.play("Block", point, { speed = 1.8, volume = 0.3 })
end

local function watchMachine(model: Model)
	if machines[model] then
		return
	end
	local crate = crateOf(model)
	machines[model] = {
		model = model,
		crate = crate,
		lastParts = if crate then (crate:GetAttribute("Parts") :: number?) or 0 else 0,
		-- Spread machines out so they don't all clink together.
		nextCycleAt = os.clock() + math.random() * CYCLE_SECONDS,
	}
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			machines[model] = nil
		end
	end)
end

local function onDescendantAdded(instance: Instance)
	if instance.Name == "SalvageMachine" and instance:IsA("Model") then
		-- Its parts may still be streaming in.
		task.defer(watchMachine, instance)
	end
end

local function cycleMachines()
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	for model, machine in machines do
		if now < machine.nextCycleAt then
			continue
		end
		machine.nextCycleAt = now + CYCLE_SECONDS

		-- Only a crate that filled since the last cycle means it produced.
		local parts = if machine.crate then (machine.crate:GetAttribute("Parts") :: number?) or 0 else 0
		local produced = machine.crate == nil or parts > machine.lastParts
		machine.lastParts = parts
		local near = camera and (model:GetPivot().Position - camera.CFrame.Position).Magnitude <= CYCLE_DISTANCE
		if produced and near then
			finishCycle(model)
		end
	end
end

local ScrapFxController = {}

function ScrapFxController.init() end

function ScrapFxController.start()
	Notify.ScrapBurst.OnClientEvent:Connect(onScrapBurst)

	Workspace.DescendantAdded:Connect(onDescendantAdded)
	for _, instance in Workspace:GetDescendants() do
		onDescendantAdded(instance)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			cycleMachines()
		end
	end)
end

return ScrapFxController
