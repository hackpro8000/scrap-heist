--!strict
--[[
	JuiceController

	Makes hits feel good, on this client only: screen shake when you hit or
	get hit, a tiny hit pause on your own animations when your hit lands,
	and floating damage numbers over every target. Each effect has its own
	switch in Config/Juice.

	Listens to CombatController.hitShown, so effects follow exactly what the
	server confirmed.

	Public API: none.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local CombatController = require(script.Parent.CombatController)

local localPlayer = Players.LocalPlayer

local SHAKE_BIND_NAME = "JuiceShake"
local NUMBER_RISE_STUDS = 3

local OUTCOME_COLORS: { [string]: Color3 } = {
	Hit = Theme.Colors.Text,
	Blocked = Color3.fromRGB(150, 200, 255),
	Parried = Theme.Colors.Warning,
	GuardBroken = Theme.Colors.Accent,
}

local JuiceController = {}

local shakeStrength = 0
local shakeEndsAt = 0

local function shake(strength: number)
	if not Juice.SCREEN_SHAKE then
		return
	end

	shakeStrength = math.max(shakeStrength, strength)
	shakeEndsAt = os.clock() + Juice.SHAKE_SECONDS
end

local function applyShake()
	local remaining = shakeEndsAt - os.clock()
	if remaining <= 0 then
		shakeStrength = 0
		return
	end

	-- Fades out over the shake's length.
	local strength = shakeStrength * (remaining / Juice.SHAKE_SECONDS)
	local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 2 * strength
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.new(offset)
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
	damageNumber(target, outcome, damage)

	if character and target == character then
		shake(Juice.SHAKE_WHEN_HIT)
	elseif character and attacker == character then
		shake(Juice.SHAKE_WHEN_HITTING)
		hitPause()
	end
end

function JuiceController.init() end

function JuiceController.start()
	CombatController.hitShown:connect(onHit)
	-- Runs after the camera scripts, so the shake isn't overwritten.
	RunService:BindToRenderStep(SHAKE_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, applyShake)
end

return JuiceController
