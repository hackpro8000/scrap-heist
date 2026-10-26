--!strict
--[[
	HudController

	Owns the Hud screen and feeds it. Health comes straight from the local
	Humanoid. Scrap, round phase, survivors and raid alerts will come from
	DataService, RoundService and RaidService once those exist (phases 2, 4
	and 5); until then the Hud shows its defaults.

	Public API:
		HudController:init()
		HudController:start()
		HudController.hud: Hud?   -- for other controllers to push values
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local Hud = require(script.Parent.Parent.UI.Hud)

local HudController = {}
HudController.hud = nil :: Hud.Hud?

local _characterTrove = Trove.new()

local function watchHealth(character: Model)
	_characterTrove:clean()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function update()
		local hud = HudController.hud
		if not hud then
			return
		end
		hud:setHealth(if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0)
	end
	_characterTrove:connect(humanoid.HealthChanged, update)
	update()
end

function HudController:init()
	local player = Players.LocalPlayer
	HudController.hud = Hud.new(player:WaitForChild("PlayerGui"))
end

function HudController:start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		watchHealth(player.Character)
	end
end

return HudController
