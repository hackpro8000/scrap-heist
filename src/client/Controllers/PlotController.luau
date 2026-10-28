--!strict
--[[
	PlotController

	The yard UI:
	- Shows each yard prompt only to the right players: buy, upgrade and
	  collect (OwnerOnly) to the owner, "Grab parts" (RaiderOnly) to
	  everyone else. This is tidiness only; the server checks every press.
	- A red banner when someone raids your yard, cleared when it's safe.
	- A "carrying" bar while you haul a stolen bundle home.

	The scrap counter lives in HudController.

	Public API: none.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Remotes = require(ReplicatedStorage.Shared.Net.Raid)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Widgets = require(script.Parent.Parent.UI.Widgets)

local localPlayer = Players.LocalPlayer

local ALERT_SECONDS = 6

local PlotController = {}

local alertBanner: TextLabel
local carryLabel: TextLabel
local alertToken = 0

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

	-- The server decides whether owner prompts are enabled at all (a maxed
	-- machine has nothing to buy), so only ever switch them off here.
	if ownerOnly then
		prompt.Enabled = prompt.Enabled and isMine
	else
		prompt.Enabled = hasOwner and not isMine
	end
end

local function refreshYard(yard: Instance)
	for _, descendant in yard:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			filterPrompt(descendant)
		end
	end
end

local function watchYard(yard: Instance)
	refreshYard(yard)
	yard:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refreshYard(yard)
	end)
	yard.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			filterPrompt(descendant)
		end
	end)
	-- The server re-enables owner prompts as machines change; filter again.
	for _, descendant in yard:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant:GetPropertyChangedSignal("Enabled"):Connect(function()
				if descendant:GetAttribute("OwnerOnly") and yardOwnerOf(descendant) ~= localPlayer.UserId then
					descendant.Enabled = false
				end
			end)
		end
	end
end

local function showAlert(kind: string, text: string)
	alertToken += 1
	local token = alertToken

	alertBanner.Text = text
	alertBanner.BackgroundColor3 = if kind == "Clear" then Theme.Colors.Good else Theme.Colors.Bad
	alertBanner.Visible = true

	if kind ~= "Clear" and Assets.isSet(Assets.Sounds.RaidAlert) then
		local sound = Instance.new("Sound")
		sound.SoundId = Assets.Sounds.RaidAlert
		sound.Parent = workspace.CurrentCamera
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end

	task.delay(if kind == "Clear" then 2 else ALERT_SECONDS, function()
		if alertToken == token then
			alertBanner.Visible = false
		end
	end)
end

local function refreshCarry()
	local parts = localPlayer:GetAttribute("CarryingParts")
	carryLabel.Visible = type(parts) == "number"
	if type(parts) == "number" then
		carryLabel.Text = `Carrying {parts} parts. Get back to your yard!`
	end
end

function PlotController.init()
	local screen = Widgets.screen("Plot")

	alertBanner = Widgets.label("", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.6, 0, 0, 44),
		BackgroundTransparency = 0.1,
		Font = Theme.Font,
	})
	alertBanner.Parent = screen

	carryLabel = Widgets.label("", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.6, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.2,
		TextColor3 = Theme.Colors.Accent,
		Font = Theme.Font,
	})
	carryLabel.Parent = screen
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

	refreshCarry()
	localPlayer:GetAttributeChangedSignal("CarryingParts"):Connect(refreshCarry)
end

return PlotController
