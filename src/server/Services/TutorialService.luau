--!strict
--[[
	TutorialService

	Walks new players through the game with short prompts: buy a machine,
	collect the crate, learn about raiding, then about storms when the
	first one is coming. Action steps finish when the server sees the
	player do the thing; tips finish when dismissed. Progress is saved in
	profile.tutorial, so it never repeats.

	Public API: none (driven by other services' signals).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Tutorial)

local DataService = require(script.Parent.DataService)
local MachineService = require(script.Parent.MachineService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RoundService = require(script.Parent.RoundService)
local TutorialRules = require(script.Parent.Parent.Tutorial.TutorialRules)

local SYSTEM = "Tutorial"
local DISMISS_RATE = 2

local TutorialService = {}

local function sendStep(player: Player)
	local data = DataService.getData(player)
	if not data then
		return
	end

	local step = TutorialRules.currentStep(data.tutorial, RoundService.getPhase())
	if step then
		Remotes.Step:FireClient(player, step.name, step.kind, step.text)
	else
		Remotes.Step:FireClient(player, nil)
	end
end

local function complete(player: Player, stepName: string)
	local data = DataService.getData(player)
	if not data or data.tutorial[stepName] then
		return
	end

	data.tutorial[stepName] = true
	sendStep(player)
end

function TutorialService.init() end

function TutorialService.start()
	RemoteGuard.listen(SYSTEM, Remotes.DismissTip, DISMISS_RATE, function(player: Player, stepName: any)
		local data = DataService.getData(player)
		if not data then
			return "NotLoaded"
		end
		if not TutorialRules.canDismiss(data.tutorial, RoundService.getPhase(), stepName) then
			return "NotCurrentTip"
		end

		complete(player, stepName)
		return nil
	end)

	DataService.forEachLoaded(function(player)
		sendStep(player)
	end)
	MachineService.machineChanged:connect(function(player)
		complete(player, "BuyMachine")
	end)
	MachineService.crateCollected:connect(function(player)
		complete(player, "CollectCrate")
	end)
	-- Phase-tied tips appear and disappear with the round.
	RoundService.phaseChanged:connect(function()
		for _, player in Players:GetPlayers() do
			sendStep(player)
		end
	end)
end

return TutorialService
