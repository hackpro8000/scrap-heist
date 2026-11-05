--!strict
--[[
	Sfx

	Plays one of Assets.Sounds once, through the Effects sound group so the
	player's effects volume applies. Sounds whose IDs are still placeholders
	are skipped.

	Public API:
		Sfx.play(key, parent?, options?)     -- parent gives the sound a place in the world;
		                                     -- without one it plays flat, from the camera
		Sfx.playAt(key, position, options?)  -- plays from a point in the world
		Options: { volume: number?, speed: number? } (speed also shifts pitch)
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)

export type Options = { volume: number?, speed: number? }

local Sfx = {}

function Sfx.play(key: string, parent: Instance?, options: Options?)
	local id = (Assets.Sounds :: any)[key]
	local holder = parent or Workspace.CurrentCamera
	if not Assets.isSet(id) or not holder then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundGroup = SoundService:FindFirstChild("Effects") :: SoundGroup?
	sound.SoundId = id
	sound.Volume = options and options.volume or 0.5
	sound.PlaybackSpeed = options and options.speed or 1
	sound.Parent = holder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

function Sfx.playAt(key: string, position: Vector3, options: Options?)
	local point = Instance.new("Attachment")
	point.WorldPosition = position
	point.Parent = Workspace.Terrain
	Sfx.play(key, point, options)
	Debris:AddItem(point, 5)
end

return Sfx
