--!strict
--[[
	RoundController

	The storm round UI:
	- the raid strip at the top: a plank with the bots still standing (the
	  survivors during a storm, everyone in the server otherwise) beside a
	  plank with the live countdown to the next phase, and a third with
	  your yard's raid shield while it lasts
	- the results window with your rewards when a storm ends
	- warning/storm sounds and a darker sky during storms

	The countdown is computed locally from the phase's end time in
	server-clock time (workspace:GetServerTimeNow), so it stays smooth and
	agrees across clients without the server sending a tick every second.

	Public API:
		RoundController.phaseChanged: Signal(phase, round)
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Round)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ItemText = require(script.Parent.Parent.UI.ItemText)
local Kit = require(script.Parent.Parent.UI.Kit)
local ResultsScreen = require(script.Parent.Parent.UI.Screens.Results)
local RoundScreen = require(script.Parent.Parent.UI.Screens.Round)
local Windows = require(script.Parent.Parent.UI.Windows)

local REFRESH_SECONDS = 0.2
local RESULTS_SECONDS = 12
local STORM_BRIGHTNESS = 0.6
local SKY_TWEEN = TweenInfo.new(3)
local RESULTS = "Results"

local PHASE_SOUNDS: { [string]: string } = {
	Warning = "StormWarning",
	Storm = "StormStart",
	Results = "StormEnd",
}

type RoundState = {
	phase: string,
	round: number,
	endsAt: number,
	survivorsLeft: number,
}

local RoundController = {}

RoundController.phaseChanged = Signal.new()

local state: RoundState? = nil
local stripRoot: Kit.Root
local resultsRoot: Kit.Root
local results: { [string]: any }? = nil
local loot: { ResultsScreen.Loot } = {}
local closesAt = 0
local calmBrightness = Lighting.Brightness

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- The strip: bots standing, time to the next phase, and the raid shield
-- while the server's ShieldUntil (os.time) is ahead.
local function renderStrip()
	local now = workspace:GetServerTimeNow()
	local shieldUntil = Players.LocalPlayer:GetAttribute("ShieldUntil")
	local shieldLeft = if type(shieldUntil) == "number" then shieldUntil - now else 0
	stripRoot.render(React.createElement(RoundScreen, {
		count = if state
			then tostring(if state.phase == "Storm" then state.survivorsLeft else #Players:GetPlayers())
			else "-",
		timer = if state then formatTime(state.endsAt - now) else "-",
		shield = if shieldLeft > 0 then formatTime(shieldLeft) else nil,
	}))
end

local function renderResults()
	resultsRoot.render(React.createElement(ResultsScreen, {
		results = results,
		loot = loot,
		closesIn = closesAt - os.clock(),
		onClose = function()
			Windows.close(RESULTS)
		end,
	}))
end

local function playSound(key: string?)
	local id = key and (Assets.Sounds :: any)[key]
	if not Assets.isSet(id) then
		return
	end

	local sound = Instance.new("Sound")
	-- Effects volume comes from the player's settings.
	sound.SoundGroup = SoundService:FindFirstChild("Effects") :: SoundGroup?
	sound.SoundId = id
	sound.Parent = workspace.CurrentCamera
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function setStormSky(isStorm: boolean)
	local brightness = if isStorm then calmBrightness * STORM_BRIGHTNESS else calmBrightness
	TweenService:Create(Lighting, SKY_TWEEN, { Brightness = brightness }):Play()
end

local function onRoundState(newState: RoundState)
	if type(newState) ~= "table" then
		return
	end

	local previousPhase = state and state.phase
	state = newState
	renderStrip()

	if newState.phase ~= previousPhase then
		playSound(PHASE_SOUNDS[newState.phase])
		setStormSky(newState.phase == "Storm")
		RoundController.phaseChanged:fire(newState.phase, newState.round)
	end
end

-- Same items from different loot rolls show as one stack, rarest first.
local function mergedLoot(rewards: { any }): { ResultsScreen.Loot }
	local counts: { [string]: number } = {}
	for _, reward in rewards do
		if type(reward) == "table" and type(reward.itemId) == "string" then
			counts[reward.itemId] = (counts[reward.itemId] or 0) + (tonumber(reward.count) or 1)
		end
	end
	local merged = {}
	for _, itemId in ItemText.sortedStackIds(counts) do
		table.insert(merged, { itemId = itemId, count = counts[itemId] })
	end
	return merged
end

local function showResults(newResults: { [string]: any })
	results = newResults
	loot = mergedLoot(newResults.rewards or {})
	for _, entry in loot do
		local definition = Items.get(entry.itemId)
		if definition and (definition.rarity == "Rare" or definition.rarity == "Legendary") then
			playSound("LootRare")
			break
		end
	end
	closesAt = os.clock() + RESULTS_SECONDS
	renderResults()
	Windows.open(RESULTS)
end

function RoundController.init()
	stripRoot = Kit.mount("Round")
	resultsRoot = Kit.mount("Results", 10)
	renderStrip()
	renderResults()
end

function RoundController.start()
	Remotes.RoundState.OnClientEvent:Connect(onRoundState)
	Remotes.RoundResults.OnClientEvent:Connect(function(newResults)
		if type(newResults) == "table" then
			showResults(newResults)
		end
	end)
	-- Joining mid-round: ask for the current phase instead of waiting.
	Remotes.RequestRoundState:FireServer()

	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			renderStrip()
			-- The results window counts down, then closes itself.
			if Windows.isOpen(RESULTS) then
				if os.clock() >= closesAt then
					Windows.close(RESULTS)
				else
					renderResults()
				end
			end
		end
	end)
end

return RoundController
