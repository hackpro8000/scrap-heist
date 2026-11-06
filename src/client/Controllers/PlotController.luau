--!strict
--[[
	PlotController

	The yard UI:
	- Shows each yard prompt only to the right players: buy, upgrade and
	  collect (OwnerOnly) to the owner when the server marks them
	  Available, "Grab parts" (RaiderOnly) to everyone else. This is
	  tidiness only; the server checks every press.
	- A red sign that drops in under the raid strip when someone raids your
	  yard ("ROOK IS RAIDING!"), hazard signs wobbling at its ends, and a
	  green one once it's safe.
	- A "carrying" bar while you haul a stolen bundle or a capsule home.
	- Lets you through your own locked gate.

	The scrap counter lives in HudController.

	Public API: none.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Raid)

local NotifyController = require(script.Parent.NotifyController)
local Kit = require(script.Parent.Parent.UI.Kit)
local PlotScreen = require(script.Parent.Parent.UI.Screens.Plot)

local localPlayer = Players.LocalPlayer

local ALERT_SECONDS = 6
local GATE_BARRIER_NAME = "GateBarrier"

-- Matches the sign's spot under the raid strip in UI/Screens/Plot.
local ALERT_BOTTOM = 66 + 50

local PlotController = {}

local root: Kit.Root
local alert: PlotScreen.Alert? = nil
local alertCount = 0

-- What the player is hauling, as the bar at the bottom says it.
local function carryText(): string?
	local scrap = localPlayer:GetAttribute("CarryingScrap")
	local capsule = localPlayer:GetAttribute("CarryingCapsule")
	if type(scrap) == "number" then
		return `Carrying {Format.short(scrap)} scrap. Get back to your yard!`
	elseif type(capsule) == "string" then
		return `Carrying a {capsule} capsule. Get it to your build bay!`
	end

	return nil
end

local function render()
	root.render(React.createElement(PlotScreen, {
		alert = alert,
		carrying = carryText(),
	}))
end

local function yardOwnerOf(prompt: ProximityPrompt): number?
	local node: Instance? = prompt.Parent
	while node and node ~= workspace do
		local owner = node:GetAttribute("OwnerUserId")
		if owner ~= nil then
			return owner :: number
		end
		node = node.Parent
	end

	return nil
end

local function filterPrompt(prompt: ProximityPrompt)
	local ownerOnly = prompt:GetAttribute("OwnerOnly")
	local raiderOnly = prompt:GetAttribute("RaiderOnly")
	if not ownerOnly and not raiderOnly then
		return
	end

	local owner = yardOwnerOf(prompt)
	local isMine = owner == localPlayer.UserId
	local hasOwner = owner ~= nil and owner ~= 0

	if ownerOnly then
		-- Available is the server saying there's something to do here.
		prompt.Enabled = isMine and prompt:GetAttribute("Available") ~= false
	else
		prompt.Enabled = hasOwner and not isMine
	end
end

local function watchPrompt(prompt: ProximityPrompt)
	filterPrompt(prompt)
	prompt:GetAttributeChangedSignal("Available"):Connect(function()
		filterPrompt(prompt)
	end)
end

local function refreshYard(yard: Instance)
	for _, descendant in yard:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			filterPrompt(descendant)
		end
	end
end

-- A locked gate stops everyone on the server; its owner walks through,
-- because their own client stops it colliding for them.
local function passOwnGate(yard: Instance, barrier: BasePart)
	local function pass()
		if yard:GetAttribute("OwnerUserId") == localPlayer.UserId and barrier.CanCollide then
			barrier.CanCollide = false
		end
	end
	barrier:GetPropertyChangedSignal("CanCollide"):Connect(pass)
	yard:GetAttributeChangedSignal("OwnerUserId"):Connect(pass)
	pass()
end

local function watchYard(yard: Instance)
	local function watch(descendant: Instance)
		if descendant:IsA("ProximityPrompt") then
			watchPrompt(descendant)
		elseif descendant.Name == GATE_BARRIER_NAME and descendant:IsA("BasePart") then
			passOwnGate(yard, descendant)
		end
	end
	for _, descendant in yard:GetDescendants() do
		watch(descendant)
	end
	yard.DescendantAdded:Connect(watch)
	yard:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refreshYard(yard)
	end)
end

local function hideAlert()
	alert = nil
	render()
	NotifyController.setTop(nil)
end

local function showAlert(kind: string, text: string)
	alertCount += 1
	local id = alertCount
	alert = { id = id, kind = kind, text = text }
	render()
	-- Messages drop below the sign while it hangs there.
	NotifyController.setTop(ALERT_BOTTOM + 10)

	if kind ~= "Clear" and Assets.isSet(Assets.Sounds.RaidAlert) then
		local sound = Instance.new("Sound")
		-- Effects volume comes from the player's settings.
		sound.SoundGroup = SoundService:FindFirstChild("Effects") :: SoundGroup?
		sound.SoundId = Assets.Sounds.RaidAlert
		sound.Parent = workspace.CurrentCamera
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end

	task.delay(if kind == "Clear" then 2 else ALERT_SECONDS, function()
		if alert and alert.id == id then
			hideAlert()
		end
	end)
end

function PlotController.init()
	root = Kit.mount("Plot")
	render()
end

function PlotController.start()
	local yardsFolder = workspace:WaitForChild("Yards")
	for _, yard in yardsFolder:GetChildren() do
		watchYard(yard)
	end
	yardsFolder.ChildAdded:Connect(watchYard)

	Remotes.Alert.OnClientEvent:Connect(function(kind: string, text: string)
		if type(kind) == "string" and type(text) == "string" then
			showAlert(kind, text)
		end
	end)

	localPlayer:GetAttributeChangedSignal("CarryingScrap"):Connect(render)
	localPlayer:GetAttributeChangedSignal("CarryingCapsule"):Connect(render)
end

return PlotController
