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
	{ name = "HeldWeaponService", module = require(Services.HeldWeaponService) },
	{ name = "DummyService", module = require(Services.DummyService) },
	{ name = "ShopService", module = require(Services.ShopService) },
	{ name = "PlotService", module = require(Services.PlotService) },
	{ name = "RoundService", module = require(Services.RoundService) },
	{ name = "JunkrotService", module = require(Services.JunkrotService) },
	{ name = "CapsuleService", module = require(Services.CapsuleService) },
	{ name = "BeltService", module = require(Services.BeltService) },
	{ name = "RaidService", module = require(Services.RaidService) },
	{ name = "BuildService", module = require(Services.BuildService) },
	{ name = "RebirthService", module = require(Services.RebirthService) },
	{ name = "StormService", module = require(Services.StormService) },
	{ name = "RewardsService", module = require(Services.RewardsService) },
	{ name = "SettingsService", module = require(Services.SettingsService) },
	{ name = "LeaderboardService", module = require(Services.LeaderboardService) },
	{ name = "ShowcaseService", module = require(Services.ShowcaseService) },
}

Boot.run("Server", SERVICES)
