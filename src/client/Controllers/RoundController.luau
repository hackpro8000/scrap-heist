--!strict
--[[
	RoundController

	The storm round UI:
	- a banner at the top with the phase and a live countdown
	- the survivor count during a storm
	- the results screen with your rewards when a storm ends
	- warning/storm sounds and a darker sky during storms

	The countdown is computed locally from the phase's end time in
	server-clock time (workspace:GetServerTimeNow), so it stays smooth and
	agrees across clients without the server sending a tick every second.

	Public API:
		RoundController.phaseChanged: Signal(phase, round)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Remotes = require(ReplicatedStorage.Shared.Net.Round)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local ItemText = require(script.Parent.Parent.UI.ItemText)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local REFRESH_SECONDS = 0.2
local RESULTS_SECONDS = 12
local STORM_BRIGHTNESS = 0.6
local SKY_TWEEN = TweenInfo.new(3)

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
local banner: TextLabel
local resultsPanel: Frame
local resultsList: ScrollingFrame
local resultsToken = 0
local calmBrightness = Lighting.Brightness

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function bannerText(current: RoundState): string
	local left = formatTime(current.endsAt - workspace:GetServerTimeNow())
	if current.phase == "Calm" then
		return `Calm. Storm {current.round + 1} in {left}`
	elseif current.phase == "Warning" then
		return `STORM INCOMING {left}`
	elseif current.phase == "Storm" then
		return `STORM {current.round}  {left}  |  {current.survivorsLeft} surviving`
	end

	return `Storm over. Next calm in {left}`
end

local function bannerColor(phase: string): Color3
	if phase == "Warning" then
		return Theme.Colors.Warning
	elseif phase == "Storm" then
		return Theme.Colors.Bad
	end

	return Theme.Colors.Background
end

local function playSound(key: string?)
	local id = key and (Assets.Sounds :: any)[key]
	if not Assets.isSet(id) then
		return
	end

	local sound = Instance.new("Sound")
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
	banner.BackgroundColor3 = bannerColor(newState.phase)
	banner.Text = bannerText(newState)

	if newState.phase ~= previousPhase then
		playSound(PHASE_SOUNDS[newState.phase])
		setStormSky(newState.phase == "Storm")
		RoundController.phaseChanged:fire(newState.phase, newState.round)
	end
end

local function showResults(results: { [string]: any })
	Widgets.clear(resultsList)

	local order = 0
	local function line(text: string, color: Color3?)
		order += 1
		local label = Widgets.label(text, {
			TextColor3 = color or Theme.Colors.Text,
			LayoutOrder = order,
		})
		label.Parent = resultsList
	end

	if results.survived then
		line("You survived the storm!", Theme.Colors.Good)
	else
		line("You didn't make it through this storm.", Theme.Colors.TextDim)
	end
	if results.topRank then
		line(`#{results.topRank} damage dealer ({results.damage} damage)`, Theme.Colors.Accent)
	elseif (results.damage or 0) > 0 then
		line(`{results.damage} damage dealt`, Theme.Colors.TextDim)
	end
	if (results.scrap or 0) > 0 then
		line(`+{results.scrap} scrap`, Theme.Colors.Accent)
	end

	local foundRare = false
	for _, reward in results.rewards or {} do
		line(`+ {ItemText.stackLine(reward.itemId, reward.count)}`, ItemText.color(reward.itemId))
		local definition = Items.get(reward.itemId)
		if definition and (definition.rarity == "Rare" or definition.rarity == "Legendary") then
			foundRare = true
		end
	end
	if foundRare then
		playSound("LootRare")
	end

	resultsPanel.Visible = true
	resultsToken += 1
	local token = resultsToken
	task.delay(RESULTS_SECONDS, function()
		if resultsToken == token then
			resultsPanel.Visible = false
		end
	end)
end

function RoundController.init()
	local screen = Widgets.screen("Round")

	banner = Widgets.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(0.55, 0, 0, 36),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Theme.Colors.Background,
		Font = Theme.Font,
	})
	banner.Parent = screen

	resultsPanel = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.45, 0.5),
	})
	resultsPanel.Parent = screen
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(280, 240)
	sizeLimit.MaxSize = Vector2.new(460, 480)
	sizeLimit.Parent = resultsPanel

	local title = Widgets.label("Storm results", { Font = Theme.Font, Size = UDim2.new(1, -50, 0, 32) })
	title.Parent = resultsPanel

	local close = Widgets.button("X", function()
		resultsPanel.Visible = false
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 40, 0, 32) })
	close.Parent = resultsPanel

	resultsList = Widgets.scrollList({ Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 1, -40) })
	resultsList.Parent = resultsPanel
end

function RoundController.start()
	Remotes.RoundState.OnClientEvent:Connect(onRoundState)
	Remotes.RoundResults.OnClientEvent:Connect(function(results)
		if type(results) == "table" then
			showResults(results)
		end
	end)
	-- Joining mid-round: ask for the current phase instead of waiting.
	Remotes.RequestRoundState:FireServer()

	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			if state then
				banner.Text = bannerText(state)
			end
		end
	end)
end

return RoundController
