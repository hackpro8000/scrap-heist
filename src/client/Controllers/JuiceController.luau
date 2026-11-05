--!strict
--[[
	JuiceController

	Makes hits feel good, on this client only: screen shake (harder for
	heavy hits) and a camera push-back when you hit or get hit, a tiny hit
	pause on your own animations when your hit lands, hitstop on both
	fighters, a one-frame white flash on the struck body, sparks and the
	impact sound (with a low thump under landed hits) where the blow lands,
	a red flash at the screen edge when you're hit, and floating damage
	numbers over every target. Each effect has its own switch in
	Config/Juice.

	Listens to CombatController.hitShown, so effects follow exactly what the
	server confirmed.

	Public API: none.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local CombatController = require(script.Parent.CombatController)
local Sfx = require(script.Parent.Parent.Sfx)

local localPlayer = Players.LocalPlayer

local SHAKE_BIND_NAME = "JuiceShake"
local NUMBER_RISE_STUDS = 3
-- How far in front of the target's centre, towards the attacker, a blow lands.
local IMPACT_REACH = 1.2
local RED_EDGE_WIDTH = 0.12
local SPARK_COLOR = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 140, 40))

local OUTCOME_SOUNDS: { [string]: string } = {
	Hit = "Hit",
	Blocked = "Block",
	Parried = "Parry",
	GuardBroken = "GuardBreak",
}

local OUTCOME_COLORS: { [string]: Color3 } = {
	Hit = Theme.Colors.Text,
	Blocked = Color3.fromRGB(150, 200, 255),
	Parried = Theme.Colors.Warning,
	GuardBroken = Theme.Colors.Accent,
}

local JuiceController = {}

local shakeStrength = 0
local shakeSeconds = Juice.SHAKE_SECONDS
local shakeEndsAt = 0
local nudgeEndsAt = 0
local redEdge: { Frame } = {}

local function shake(strength: number, seconds: number)
	if not Juice.SCREEN_SHAKE then
		return
	end

	-- A stronger shake takes over; a weaker one while it plays is lost in it.
	local remaining = shakeEndsAt - os.clock()
	local current = if remaining > 0 then shakeStrength * remaining / shakeSeconds else 0
	if strength >= current then
		shakeStrength, shakeSeconds = strength, seconds
		shakeEndsAt = os.clock() + seconds
	end
end

local function nudge()
	nudgeEndsAt = os.clock() + Juice.NUDGE_SECONDS
end

local function moveCamera()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local offset = Vector3.zero

	local remaining = shakeEndsAt - now
	if remaining > 0 then
		-- Fades out over the shake's length.
		local strength = shakeStrength * (remaining / shakeSeconds)
		offset += Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 2 * strength
	end

	local nudgeLeft = nudgeEndsAt - now
	if nudgeLeft > 0 then
		-- Pushed straight back, easing in to rest. +Z is behind the camera.
		local alpha = nudgeLeft / Juice.NUDGE_SECONDS
		offset += Vector3.new(0, 0, Juice.CAMERA_NUDGE * alpha * alpha)
	end

	if offset ~= Vector3.zero then
		camera.CFrame *= CFrame.new(offset)
	end
end

-- Where the blow lands: the front of the target, towards the attacker.
local function impactPoint(target: Model, attacker: Model?): Vector3?
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local from = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	local toward = if from then (from.Position - root.Position) * Vector3.new(1, 0, 1) else Vector3.zero
	local point = root.Position + Vector3.new(0, 0.5, 0)
	return if toward.Magnitude > 0.01 then point + toward.Unit * IMPACT_REACH else point
end

local function whiteFlash(target: Model)
	if not Juice.HIT_FLASH then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = target
	-- One rendered frame, then gone.
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	highlight:Destroy()
end

local function sparks(point: Vector3)
	if Juice.HIT_SPARKS <= 0 then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = point
	holder.Parent = workspace.Terrain

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = SPARK_COLOR
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 6
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Parent = holder
	emitter:Emit(Juice.HIT_SPARKS)
	Debris:AddItem(holder, 1)
end

local function hitStop(models: { Model? })
	local speeds: { [AnimationTrack]: number } = {}
	for _, model in models do
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				speeds[track] = track.Speed
				track:AdjustSpeed(0)
			end
		end
	end
	task.delay(Juice.HIT_STOP_SECONDS, function()
		for track, speed in speeds do
			track:AdjustSpeed(speed)
		end
	end)
end

local function flashRedEdge()
	local info = TweenInfo.new(Juice.RED_EDGE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, strip in redEdge do
		strip.BackgroundTransparency = 0
		TweenService:Create(strip, info, { BackgroundTransparency = 1 }):Play()
	end
end

-- Four red strips along the screen's edges, each fading out towards the
-- middle. Hidden until a hit fades them in and out.
local function buildRedEdge(): { Frame }
	local gui = Instance.new("ScreenGui")
	gui.Name = "HitEdge"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local strips = {}
	local edges = {
		{ UDim2.fromScale(1, RED_EDGE_WIDTH), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, RED_EDGE_WIDTH), UDim2.fromScale(0, 1 - RED_EDGE_WIDTH), -90 },
		{ UDim2.fromScale(RED_EDGE_WIDTH, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(RED_EDGE_WIDTH, 1), UDim2.fromScale(1 - RED_EDGE_WIDTH, 0), 180 },
	}
	for _, edge in edges do
		local strip = Instance.new("Frame")
		strip.BorderSizePixel = 0
		strip.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
		strip.BackgroundTransparency = 1
		strip.Size = edge[1]
		strip.Position = edge[2]
		strip.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge[3]
		gradient.Transparency = NumberSequence.new(0.2, 1)
		gradient.Parent = strip
		table.insert(strips, strip)
	end

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return strips
end

local function hitPause()
	if not Juice.HIT_PAUSE then
		return
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local tracks = animator:GetPlayingAnimationTracks()
	local speeds = {}
	for _, track in tracks do
		speeds[track] = track.Speed
		track:AdjustSpeed(0)
	end

	task.delay(Juice.HIT_PAUSE_SECONDS, function()
		for track, speed in speeds do
			track:AdjustSpeed(speed)
		end
	end)
end

local function damageNumber(target: Model, outcome: string, damage: number)
	if not Juice.DAMAGE_NUMBERS then
		return
	end

	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(4, 0, 1.5, 0)
	gui.StudsOffset = Vector3.new(math.random() - 0.5, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = root
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = OUTCOME_COLORS[outcome] or Theme.Colors.Text
	label.Text = if outcome == "Parried" then "PARRY" else tostring(math.floor(damage + 0.5))
	label.Parent = gui

	local info = TweenInfo.new(Juice.DAMAGE_NUMBER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, NUMBER_RISE_STUDS, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(Juice.DAMAGE_NUMBER_SECONDS, function()
		gui:Destroy()
	end)
end

local function onHit(target: Model, outcome: string, damage: number, attacker: Model?)
	local character = localPlayer.Character
	local landed = outcome == "Hit" or outcome == "GuardBroken"
	local heavy = outcome == "GuardBroken" or damage >= Juice.HEAVY_DAMAGE
	damageNumber(target, outcome, damage)

	local point = impactPoint(target, attacker)
	if point then
		Sfx.playAt(OUTCOME_SOUNDS[outcome] or "Hit", point)
		if landed then
			-- A deep, short thump under the blow.
			Sfx.playAt("Hit", point, { speed = 0.45, volume = 0.9 })
		end
		if outcome ~= "Blocked" then
			sparks(point)
		end
	end

	if landed then
		task.spawn(whiteFlash, target)
		hitStop({ target, attacker })
	end

	local involved = character ~= nil and (target == character or attacker == character)
	if involved and landed then
		nudge()
	end
	if heavy and involved then
		shake(Juice.SHAKE_HEAVY, Juice.HEAVY_SHAKE_SECONDS)
	elseif character and target == character then
		shake(Juice.SHAKE_WHEN_HIT, Juice.SHAKE_SECONDS)
	elseif character and attacker == character then
		shake(Juice.SHAKE_WHEN_HITTING, Juice.SHAKE_SECONDS)
		hitPause()
	end

	if character and target == character and damage > 0 then
		flashRedEdge()
	end
end

function JuiceController.init() end

function JuiceController.start()
	redEdge = buildRedEdge()
	CombatController.hitShown:connect(onHit)
	-- Runs after the camera scripts, so the shake isn't overwritten.
	RunService:BindToRenderStep(SHAKE_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, moveCamera)
end

return JuiceController
