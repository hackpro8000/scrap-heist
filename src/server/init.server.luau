--!strict
--[[
	Server entry point

	The only server Script. Requires every service in boot order and hands
	them to Boot, which calls all init()s and then all start()s.

	To add a service: require it below and add it to SERVICES in the spot
	where its dependencies have already booted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boot = require(ReplicatedStorage.Shared.Util.Boot)

local Services = script.Services

local SERVICES: { Boot.Entry } = {
	{ name = "DataService", module = require(Services.DataService) },
	{ name = "DebugService", module = require(Services.DebugService) },
	{ name = "InventoryService", module = require(Services.InventoryService) },
	{ name = "TradeService", module = require(Services.TradeService) },
	{ name = "CombatService", module = require(Services.CombatService) },
	{ name = "DummyService", module = require(Services.DummyService) },
	{ name = "PlotService", module = require(Services.PlotService) },
	{ name = "MachineService", module = require(Services.MachineService) },
	{ name = "RoundService", module = require(Services.RoundService) },
	{ name = "RaidService", module = require(Services.RaidService) },
	{ name = "BotService", module = require(Services.BotService) },
	{ name = "LootService", module = require(Services.LootService) },
	{ name = "TutorialService", module = require(Services.TutorialService) },
	{ name = "LeaderboardService", module = require(Services.LeaderboardService) },
}

Boot.run("Server", SERVICES)
