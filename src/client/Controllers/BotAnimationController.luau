--!strict
--[[
	BotAnimationController

	Plays the bots' clips on this client by setting their Bones' Transform
	every frame. The clips are data, not uploaded Animation assets: modelkit
	writes one module per rigged bot into Shared/Animations (listed in
	CLIP_SETS by BotType), holding every frame of each moving bone.

	A bot loops Move while its root is moving and Idle while it stands. When
	the server reports a swing (Remotes.PlaySwing) it plays Attack once,
	sped up or slowed down to last the combo step's windup and recovery, so
	the blow lands as the hit is checked. Changing clip blends over
	BLEND_TIME so poses don't snap. Bots further than MAX_DISTANCE from the
	camera aren't animated.

	The place streams and bots are pooled out of workspace between waves,
	so each bot is picked up when it appears in workspace.Bots and dropped
	when it leaves.

	Public API: none.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Combat.Remotes)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

-- Studs per second of ground speed that counts as moving.
local MOVE_SPEED = 0.5
local BLEND_TIME = 0.15
local MAX_DISTANCE = 200
-- Numbers per frame in a track: x, y, z, qx, qy, qz, qw.
local FRAME_SIZE = 7

type Clip = { length: number, tracks: { [string]: { number } } }
type ClipSet = { fps: number, clips: { [string]: Clip } }

-- Each rigged bot's clips, by its BotType attribute. A new bot's module
-- (written by scripts/build-model.sh) goes here too.
local CLIP_SETS: { [string]: ClipSet } = {
	Scrapper = require(ReplicatedStorage.Shared.Animations.Scrapper) :: any,
	Bruiser = require(ReplicatedStorage.Shared.Animations.Bruiser) :: any,
	Zapper = require(ReplicatedStorage.Shared.Animations.Zapper) :: any,
}

type Playing = {
	name: string,
	clip: Clip,
	startedAt: number,
	-- Clip seconds per real second.
	speed: number,
	looped: boolean,
}

type Bot = {
	model: Model,
	clips: ClipSet,
	bones: { [string]: Bone },
	playing: Playing?,
	-- The clip being blended out of, until BLEND_TIME after `playing` began.
	fading: Playing?,
	connections: { RBXScriptConnection },
}

local BotAnimationController = {}

local bots: { [Model]: Bot } = {}

local function frameAt(track: { number }, frame: number): CFrame
	local at = frame * FRAME_SIZE
	return CFrame.new(
		track[at + 1],
		track[at + 2],
		track[at + 3],
		track[at + 4],
		track[at + 5],
		track[at + 6],
		track[at + 7]
	)
end

-- Where `playing` has got to, in clip seconds.
local function clipTime(playing: Playing, now: number): number
	local elapsed = (now - playing.startedAt) * playing.speed
	if playing.looped then
		return elapsed % playing.clip.length
	end
	return math.min(elapsed, playing.clip.length)
end

local function finished(playing: Playing, now: number): boolean
	return not playing.looped and (now - playing.startedAt) * playing.speed >= playing.clip.length
end

-- A bone's Transform in `playing` at `now`; bones the clip doesn't move
-- rest where they are.
local function pose(playing: Playing, fps: number, boneName: string, now: number): CFrame
	local track = playing.clip.tracks[boneName]
	if not track then
		return CFrame.identity
	end
	local frames = #track // FRAME_SIZE
	local position = clipTime(playing, now) * fps
	local frame = math.clamp(math.floor(position), 0, frames - 1)
	local nextFrame = math.min(frame + 1, frames - 1)
	return frameAt(track, frame):Lerp(frameAt(track, nextFrame), math.clamp(position - frame, 0, 1))
end

local function play(bot: Bot, name: string, looped: boolean, speed: number)
	local clip = bot.clips.clips[name]
	if not clip then
		return
	end
	local playing = bot.playing
	if looped and playing and playing.name == name then
		return
	end
	local started: Playing = { name = name, clip = clip, startedAt = os.clock(), speed = speed, looped = looped }
	bot.fading = playing
	bot.playing = started
end

local function addBone(bot: Bot, instance: Instance)
	if instance:IsA("Bone") then
		bot.bones[instance.Name] = instance
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or bots[model] then
		return
	end
	local botType = model:GetAttribute("BotType")
	local clips = if typeof(botType) == "string" then CLIP_SETS[botType] else nil
	if not clips then
		return
	end
	local bot: Bot = { model = model, clips = clips, bones = {}, playing = nil, fading = nil, connections = {} }
	for _, descendant in model:GetDescendants() do
		addBone(bot, descendant)
	end
	table.insert(
		bot.connections,
		model.DescendantAdded:Connect(function(descendant)
			addBone(bot, descendant)
		end)
	)
	table.insert(
		bot.connections,
		model.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("Bone") and bot.bones[descendant.Name] == descendant then
				bot.bones[descendant.Name] = nil
			end
		end)
	)
	bots[model] = bot
end

local function untrack(model: Instance)
	local bot = bots[model :: Model]
	if not bot then
		return
	end
	for _, connection in bot.connections do
		connection:Disconnect()
	end
	bots[model :: Model] = nil
end

local function onSwing(model: any, weaponName: any, stepIndex: any)
	local bot = bots[model]
	local weapon = bot and WeaponConfig.Weapons[weaponName]
	local step = weapon and weapon.combo[stepIndex]
	local clip = bot and bot.clips.clips.Attack
	if not (bot and step and clip) then
		return
	end
	play(bot, "Attack", false, clip.length / math.max(step.windup + step.recovery, 0.05))
end

local function animate()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	for _, bot in bots do
		local root = bot.model.PrimaryPart
		if not root or (camera and (camera.CFrame.Position - root.Position).Magnitude > MAX_DISTANCE) then
			continue
		end

		local playing = bot.playing
		if not playing or playing.looped or finished(playing, now) then
			local moving = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > MOVE_SPEED
			play(bot, if moving then "Move" else "Idle", true, 1)
			playing = bot.playing
		end
		if not playing then
			continue
		end

		local fps = bot.clips.fps
		local fading = bot.fading
		local blend = math.clamp((now - playing.startedAt) / BLEND_TIME, 0, 1)
		if blend >= 1 then
			bot.fading = nil
			fading = nil
		end
		for name, bone in bot.bones do
			local target = pose(playing, fps, name, now)
			if fading then
				target = pose(fading, fps, name, now):Lerp(target, blend)
			end
			bone.Transform = target
		end
	end
end

function BotAnimationController.init() end

function BotAnimationController.start()
	Remotes.PlaySwing.OnClientEvent:Connect(onSwing)
	RunService.RenderStepped:Connect(animate)
	-- Waits off the boot thread: BotService makes the folder at server start,
	-- but it replicates after the client boots.
	task.spawn(function()
		local folder = workspace:WaitForChild("Bots")
		for _, model in folder:GetChildren() do
			track(model)
		end
		folder.ChildAdded:Connect(track)
		folder.ChildRemoved:Connect(untrack)
	end)
end

return BotAnimationController
