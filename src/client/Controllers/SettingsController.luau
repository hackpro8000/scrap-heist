--!strict
--[[
	SettingsController

	The settings window, opened from the cog at the bottom left: music and
	sound volume sliders, and switches for screen shake, damage numbers and
	hit pause. Settings apply at once on this client and are saved to the
	player's profile (SettingsService), so they follow them to any server.

	Volumes drive two SoundGroups in SoundService, "Music" and "Effects";
	every sound the game plays goes in one of them. The switches set the
	matching Config/Juice flags, which the effects read each time they run.

	Public API: none.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Settings)

local Kit = require(script.Parent.Parent.UI.Kit)
local SettingsScreen = require(script.Parent.Parent.UI.Screens.Settings)

type Settings = {
	music: number,
	sounds: number,
	screenShake: boolean,
	damageNumbers: boolean,
	hitPause: boolean,
}

local ROWS: { SettingsScreen.Row } = {
	{ key = "music", label = "MUSIC", kind = "Volume" },
	{ key = "sounds", label = "SOUNDS", kind = "Volume" },
	{ key = "screenShake", label = "SCREEN SHAKE", kind = "Switch" },
	{ key = "damageNumbers", label = "DAMAGE NUMBERS", kind = "Switch" },
	{ key = "hitPause", label = "HIT PAUSE", kind = "Switch" },
}

local SettingsController = {}

local settings: Settings = {
	music = 0.6,
	sounds = 0.85,
	screenShake = Juice.SCREEN_SHAKE,
	damageNumbers = Juice.DAMAGE_NUMBERS,
	hitPause = Juice.HIT_PAUSE,
}
local root: Kit.Root

local function soundGroup(name: string): SoundGroup
	local group = SoundService:FindFirstChild(name)
	if group and group:IsA("SoundGroup") then
		return group
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Parent = SoundService
	return created
end

local render: () -> ()

local function apply()
	soundGroup("Music").Volume = settings.music
	soundGroup("Effects").Volume = settings.sounds
	-- The player's choice overrides the config's default on this client.
	Juice.SCREEN_SHAKE = settings.screenShake
	Juice.DAMAGE_NUMBERS = settings.damageNumbers
	Juice.HIT_PAUSE = settings.hitPause
	render()
end

local function onChange(key: string, value: any)
	(settings :: any)[key] = value
	apply()
end

local function save()
	Remotes.SaveSettings:FireServer(settings)
end

function render()
	root.render(React.createElement(SettingsScreen, {
		rows = ROWS,
		values = settings,
		onChange = onChange,
		onCommit = save,
	}))
end

function SettingsController.init()
	root = Kit.mount("Settings", 10)
	apply()
end

function SettingsController.start()
	Remotes.SettingsLoaded.OnClientEvent:Connect(function(saved: any)
		if type(saved) ~= "table" then
			return
		end
		for _, row in ROWS do
			local value = saved[row.key]
			if type(value) == (if row.kind == "Volume" then "number" else "boolean") then
				(settings :: any)[row.key] = value
			end
		end
		apply()
	end)
	Remotes.RequestSettings:FireServer()
end

return SettingsController
