--!strict
--[[
	PlayerPoseController

	Animates player characters' combat poses on this client by bending
	their R15 joints (the shoulders, the waist and the neck). The poses are
	keyframes in code, not uploaded Animation assets, so they work with no
	art and on every client: each client poses every character it sees.

	- Swing: when the server reports a swing (Remotes.PlaySwing) for a
	  player, the weapon's combo step plays a pose sequence timed to its
	  windup and recovery, so the blow lands as the hit is checked.
	- Block: arms up across the chest while the character's Blocking
	  attribute is true.
	- Carry: hands gripping the straps of the bundle on the back while the player's CarryingParts
	  attribute is set.
	- Stagger: a short lean back when guard-broken, or when parried as the
	  attacker.

	Each frame, after the Animator has posed a joint (its Transform), the
	offset is laid on top, so the walk and idle keep playing underneath.
	Offsets are blended a little
	each frame so poses never snap. Characters further than MAX_DISTANCE
	from the camera aren't posed.

	Public API: none.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Combat.Remotes)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local MAX_DISTANCE = 200
-- How fast a joint closes on its target pose, per second.
local BLEND_RATE = 22
local STAGGER_SECONDS = 0.45

-- Joint name -> the part holding it (a Motor6D, or the AnimationConstraint
-- newer avatars are rigged with).
local JOINTS: { [string]: string } = {
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	Waist = "UpperTorso",
	Neck = "Head",
}

-- A pose: degrees about x, y, z per joint; joints left out rest.
type Pose = { [string]: Vector3 }
-- A keyframe: time as a fraction of the sequence, and the pose there.
type Key = { t: number, pose: Pose }

local REST: Pose = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Each sequence has a `strike` key at fraction "hit"; it is moved to land
-- at the step's windup / (windup + recovery).
local SEQUENCES: { [string]: { Key } } = {
	-- Forehand: wind the arm out and back, then sweep it across.
	Forehand = {
		{ t = 0, pose = REST },
		{ t = -1, pose = { RightShoulder = v(70, 0, 80), Waist = v(0, 40, 0), Neck = v(0, -25, 0) } },
		{ t = -2, pose = { RightShoulder = v(80, 0, -40), Waist = v(0, -45, 0), Neck = v(0, 30, 0) } },
		{ t = 1, pose = REST },
	},
	-- Backhand: the forehand mirrored, coming back across.
	Backhand = {
		{ t = 0, pose = REST },
		{ t = -1, pose = { RightShoulder = v(80, 0, -50), Waist = v(0, -40, 0), Neck = v(0, 25, 0) } },
		{ t = -2, pose = { RightShoulder = v(70, 0, 85), Waist = v(0, 45, 0), Neck = v(0, -30, 0) } },
		{ t = 1, pose = REST },
	},
	-- Overhead: raise it high, leaning back, and bring it down hard.
	Overhead = {
		{ t = 0, pose = REST },
		{
			t = -1,
			pose = {
				RightShoulder = v(165, 0, 10),
				LeftShoulder = v(150, 0, -10),
				Waist = v(-15, 0, 0),
				Neck = v(-15, 0, 0),
			},
		},
		{
			t = -2,
			pose = { RightShoulder = v(40, 0, 0), LeftShoulder = v(35, 0, 0), Waist = v(25, 0, 0), Neck = v(10, 0, 0) },
		},
		{ t = 1, pose = REST },
	},
	-- Thrust: pull back, then drive it straight ahead.
	Thrust = {
		{ t = 0, pose = REST },
		{ t = -1, pose = { RightShoulder = v(20, 0, 20), Waist = v(0, 30, 0) } },
		{ t = -2, pose = { RightShoulder = v(95, 0, 0), LeftShoulder = v(60, 0, 0), Waist = v(10, -25, 0) } },
		{ t = 1, pose = REST },
	},
	-- Point: arm out straight ahead, kicking up as it fires.
	Point = {
		{ t = 0, pose = REST },
		{ t = -1, pose = { RightShoulder = v(90, 0, 0), Waist = v(0, -10, 0) } },
		{ t = -2, pose = { RightShoulder = v(105, 0, 0), Waist = v(-5, -10, 0) } },
		{ t = 1, pose = REST },
	},
}

-- Which sequence each combo animation plays.
local ANIMATION_SEQUENCES: { [string]: string } = {
	BatSwing1 = "Forehand",
	BatSwing2 = "Backhand",
	BatSwing3 = "Overhead",
	SpannerSwing1 = "Forehand",
	SpannerSwing2 = "Overhead",
	SawSwing1 = "Thrust",
	ZapperShot1 = "Point",
}

local BLOCK: Pose = { RightShoulder = v(95, 0, -45), LeftShoulder = v(95, 0, 45), Neck = v(10, 0, 0) }
-- Hands up at the chest, gripping the straps of the bundle on the back.
local CARRY: Pose = { RightShoulder = v(35, 0, -25), LeftShoulder = v(35, 0, 25), Waist = v(10, 0, 0) }
local STAGGER: Pose =
	{ Waist = v(-25, 0, 0), Neck = v(-20, 0, 0), RightShoulder = v(-20, 0, 30), LeftShoulder = v(-20, 0, -30) }

-- `animated` is the Transform the Animator last left on the joint, and
-- `written` what this controller put there on top of it: a joint no clip
-- moves keeps the written Transform, which mustn't be built on again.
type Joint = { joint: Motor6D | AnimationConstraint, animated: CFrame, written: CFrame?, current: Vector3 }

type Posed = {
	joints: { [string]: Joint },
	-- The swing playing: its keys (strike moved into place) and timing.
	swing: { keys: { Key }, startedAt: number, length: number }?,
	staggerUntil: number,
}

local posed: { [Model]: Posed } = {}

local function smooth(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

local function jointsOf(model: Model): { [string]: Joint }?
	local joints: { [string]: Joint } = {}
	for name, partName in JOINTS do
		local part = model:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(name)
		if not (joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint"))) then
			return nil
		end
		local animated = (joint :: any).Transform :: CFrame
		joints[name] = { joint = joint :: any, animated = animated, written = nil, current = Vector3.zero }
	end
	return joints
end

local function track(model: Model): Posed?
	local entry = posed[model]
	if entry then
		return entry
	end
	local joints = jointsOf(model)
	if not joints then
		return nil
	end
	entry = { joints = joints, swing = nil, staggerUntil = 0 }
	posed[model] = entry
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			posed[model] = nil
		end
	end)
	return entry
end

-- The sequence's keys with the wind (-1) and strike (-2) placeholders
-- moved so the strike lands at `hit`.
local function placeKeys(sequence: { Key }, hit: number): { Key }
	local keys = {}
	for index, key in sequence do
		local t = key.t
		if t == -1 then
			t = hit * 0.7
		elseif t == -2 then
			t = hit
		end
		keys[index] = { t = t, pose = key.pose }
	end
	return keys
end

local function sample(keys: { Key }, alpha: number, joint: string): Vector3
	for index = 2, #keys do
		local before, after = keys[index - 1], keys[index]
		if alpha <= after.t then
			local span = after.t - before.t
			local blend = if span > 0 then smooth((alpha - before.t) / span) else 1
			local from = before.pose[joint] or Vector3.zero
			local to = after.pose[joint] or Vector3.zero
			return from:Lerp(to, blend)
		end
	end
	return Vector3.zero
end

-- Where each joint should be now, in degrees.
local function targetOf(model: Model, entry: Posed, now: number, joint: string): Vector3
	if now < entry.staggerUntil then
		return STAGGER[joint] or Vector3.zero
	end
	local swing = entry.swing
	if swing then
		local alpha = (now - swing.startedAt) / swing.length
		if alpha < 1 then
			return sample(swing.keys, alpha, joint)
		end
		entry.swing = nil
	end
	if model:GetAttribute("Blocking") == true then
		return BLOCK[joint] or Vector3.zero
	end
	local player = Players:GetPlayerFromCharacter(model)
	if player and player:GetAttribute("CarryingParts") ~= nil then
		return CARRY[joint] or Vector3.zero
	end
	return Vector3.zero
end

local function isPlayerCharacter(model: Model): boolean
	return typeof(model) == "Instance" and Players:GetPlayerFromCharacter(model) ~= nil
end

local function onSwing(model: Model, weaponName: string, stepIndex: number)
	if not isPlayerCharacter(model) then
		return
	end
	local weapon = WeaponConfig.Weapons[weaponName]
	local step = weapon and weapon.combo[stepIndex]
	local sequence = step and SEQUENCES[ANIMATION_SEQUENCES[step.animation] or "Forehand"]
	local entry = sequence and track(model)
	if not (step and sequence and entry) then
		return
	end
	local length = step.windup + step.recovery
	entry.swing = {
		keys = placeKeys(sequence, step.windup / length),
		startedAt = os.clock(),
		length = length,
	}
end

local function stagger(model: Model?)
	if not (model and isPlayerCharacter(model)) then
		return
	end
	local entry = track(model)
	if entry then
		entry.staggerUntil = os.clock() + STAGGER_SECONDS
		entry.swing = nil
	end
end

local function onHitEffect(model: Model, outcome: string, _damage: number, attacker: Model?)
	if outcome == "GuardBroken" then
		stagger(model)
	elseif outcome == "Parried" then
		stagger(attacker)
	end
end

local function step(deltaTime: number)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local blend = 1 - math.exp(-BLEND_RATE * deltaTime)

	-- Pick up characters that need a held pose.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if
			character
			and not posed[character]
			and (character:GetAttribute("Blocking") == true or player:GetAttribute("CarryingParts") ~= nil)
		then
			track(character)
		end
	end

	for model, entry in posed do
		local root = model.PrimaryPart
		if camera and root and (root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
			continue
		end
		local resting = true
		for name, joint in entry.joints do
			if not joint.joint.Parent then
				continue
			end
			local target = targetOf(model, entry, now, name)
			joint.current = joint.current:Lerp(target, blend)
			local degrees = joint.current
			if degrees.Magnitude > 0.05 or target ~= Vector3.zero then
				resting = false
			end
			local transform = joint.joint.Transform
			if transform ~= joint.written then
				joint.animated = transform
			end
			local written = joint.animated
				* CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
			joint.joint.Transform = written
			joint.written = written
		end
		-- Back at rest with nothing to hold: stop posing it.
		if resting and not entry.swing then
			for _, joint in entry.joints do
				if joint.joint.Transform == joint.written then
					joint.joint.Transform = joint.animated
				end
			end
			posed[model] = nil
		end
	end
end

local PlayerPoseController = {}

function PlayerPoseController.init() end

function PlayerPoseController.start()
	Remotes.PlaySwing.OnClientEvent:Connect(onSwing)
	Remotes.HitEffect.OnClientEvent:Connect(onHitEffect)
	-- After the Animator's step, so the offsets land on this frame's pose.
	RunService.PreSimulation:Connect(step)
end

return PlayerPoseController
