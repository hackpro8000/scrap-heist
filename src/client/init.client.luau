--!strict
--[[
	Client entry point

	The only client LocalScript. Requires every controller in boot order and
	hands them to Boot, which calls all init()s and then all start()s.

	To add a controller: require it below and add it to CONTROLLERS in the
	spot where its dependencies have already booted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boot = require(ReplicatedStorage.Shared.Util.Boot)

local Controllers = script.Controllers

local CONTROLLERS: { Boot.Entry } = {
	{ name = "NotifyController", module = require(Controllers.NotifyController) },
	{ name = "HudController", module = require(Controllers.HudController) },
	{ name = "InventoryController", module = require(Controllers.InventoryController) },
	{ name = "TradeController", module = require(Controllers.TradeController) },
	{ name = "PlotController", module = require(Controllers.PlotController) },
	{ name = "RoundController", module = require(Controllers.RoundController) },
	{ name = "BeltController", module = require(Controllers.BeltController) },
	{ name = "BuildController", module = require(Controllers.BuildController) },
	{ name = "ShowcaseController", module = require(Controllers.ShowcaseController) },
	{ name = "CombatController", module = require(Controllers.CombatController) },
	{ name = "JuiceController", module = require(Controllers.JuiceController) },
	{ name = "HotbarController", module = require(Controllers.HotbarController) },
	{ name = "PlayerPoseController", module = require(Controllers.PlayerPoseController) },
	{ name = "ScrapFxController", module = require(Controllers.ScrapFxController) },
	{ name = "AtmosphereController", module = require(Controllers.AtmosphereController) },
	{ name = "PromptController", module = require(Controllers.PromptController) },
	{ name = "LeaderboardController", module = require(Controllers.LeaderboardController) },
	{ name = "SettingsController", module = require(Controllers.SettingsController) },
	{ name = "ShopController", module = require(Controllers.ShopController) },
	{ name = "RewardsController", module = require(Controllers.RewardsController) },
}

Boot.run("Client", CONTROLLERS)
