--!strict
--[[
	Sfx

	Plays one of Assets.Sounds once, through the Effects sound group so the
	player's effects volume applies. Sounds whose IDs are still placeholders
	are skipped.

	Public API:
		Sfx.play(key, parent?)   -- parent gives the sound a place in the world;
		                         -- without one it plays flat, from the camera
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)

local Sfx = {}

function Sfx.play(key: string, parent: Instance?)
	local id = (Assets.Sounds :: any)[key]
	local holder = parent or Workspace.CurrentCamera
	if not Assets.isSet(id) or not holder then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundGroup = SoundService:FindFirstChild("Effects") :: SoundGroup?
	sound.SoundId = id
	sound.Parent = holder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

return Sfx
