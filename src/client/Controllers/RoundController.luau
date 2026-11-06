--!strict
--[[
	RoundController

	Shows the storm round the server is running (RoundService): the strip
	at the top with the players on the server, the time to the next phase
	and the raid shield, plus each phase's sound and the darkened sky of a
	storm, darker still in the blackout.

	Public API:
		RoundController.phaseChanged: Signal(phase, round)
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Round)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Sfx = require(script.Parent.Parent.Sfx)
local Kit = require(script.Parent.Parent.UI.Kit)
local RoundScreen = require(script.Parent.Parent.UI.Screens.Round)

local REFRESH_SECONDS = 0.2
local SKY_TWEEN = TweenInfo.new(3)
-- How bright the sky is in each phase, as a share of a calm day.
local SKY_BRIGHTNESS: { [string]: number } = {
	Storm = 0.6,
	Blackout = 0.25,
}

local PHASE_SOUNDS: { [string]: string } = {
	Warning = "StormWarning",
	Storm = "StormStart",
	Blackout = "StormWarning",
	Calm = "StormEnd",
}

type RoundState = {
	phase: string,
	round: number,
	endsAt: number,
}

local RoundController = {}

RoundController.phaseChanged = Signal.new()

local state: RoundState? = nil
local stripRoot: Kit.Root
local calmBrightness = Lighting.Brightness

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- The strip: players on the server, time to the next phase, and the raid
-- shield while the server's ShieldUntil (os.time) is ahead.
local function renderStrip()
	local now = workspace:GetServerTimeNow()
	local shieldUntil = Players.LocalPlayer:GetAttribute("ShieldUntil")
	local shieldLeft = if type(shieldUntil) == "number" then shieldUntil - now else 0
	stripRoot.render(React.createElement(RoundScreen, {
		count = tostring(#Players:GetPlayers()),
		timer = if state then formatTime(state.endsAt - now) else "-",
		shield = if shieldLeft > 0 then formatTime(shieldLeft) else nil,
	}))
end

local function onRoundState(newState: RoundState)
	if type(newState) ~= "table" then
		return
	end

	local previousPhase = state and state.phase
	state = newState
	renderStrip()

	if newState.phase ~= previousPhase then
		-- Joining in a calm isn't the end of a storm.
		local sound = PHASE_SOUNDS[newState.phase]
		if sound and not (newState.phase == "Calm" and previousPhase == nil) then
			Sfx.play(sound)
		end
		local brightness = calmBrightness * (SKY_BRIGHTNESS[newState.phase] or 1)
		TweenService:Create(Lighting, SKY_TWEEN, { Brightness = brightness }):Play()
		RoundController.phaseChanged:fire(newState.phase, newState.round)
	end
end

function RoundController.init()
	stripRoot = Kit.mount("Round")
	renderStrip()
end

function RoundController.start()
	Remotes.RoundState.OnClientEvent:Connect(onRoundState)
	-- Joining mid-round: ask for the current phase instead of waiting.
	Remotes.RequestRoundState:FireServer()

	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			renderStrip()
		end
	end)
end

return RoundController
