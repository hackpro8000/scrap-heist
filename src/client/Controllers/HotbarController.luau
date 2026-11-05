--!strict
--[[
	HotbarController

	The bottom-centre hotbar: a health bar over a row of numbered wooden
	slots. The first slots hold the player's weapons in hotkey order
	(WeaponConfig.PLAYER_WEAPONS, the same keys CombatController binds); the
	rest are empty for now. The slot of the weapon the server says you're
	holding (the character's "Weapon" attribute) is ringed and popped.
	Clicking a weapon's slot equips it, or puts it away if it's held. The
	bar itself is UI/Screens/Hotbar.

	Public API: none.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local React = require(ReplicatedStorage.Packages.React)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local CombatController = require(script.Parent.CombatController)
local HotbarScreen = require(script.Parent.Parent.UI.Screens.Hotbar)
local Kit = require(script.Parent.Parent.UI.Kit)

local localPlayer = Players.LocalPlayer

local SLOT_COUNT = 6

local HotbarController = {}

local root: Kit.Root
local health = 1
local held: string? = nil
local characterConnections: { RBXScriptConnection } = {}

local function render()
	local slots: { HotbarScreen.SlotSpec } = {}
	for index = 1, SLOT_COUNT do
		local weapon = WeaponConfig.PLAYER_WEAPONS[index]
		slots[index] = {
			name = if weapon then WeaponConfig.Weapons[weapon].displayName else nil,
			owned = weapon ~= nil and CombatController.ownsWeapon(weapon),
			held = weapon ~= nil and weapon == held,
		}
	end
	root.render(React.createElement(HotbarScreen, {
		health = health,
		slots = slots,
		onSlot = function(index: number)
			local weapon = WeaponConfig.PLAYER_WEAPONS[index]
			if weapon then
				CombatController.toggleWeapon(weapon)
			end
		end,
	}))
end

local function watchCharacter(character: Model)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function refresh()
		health = humanoid.Health / math.max(humanoid.MaxHealth, 1)
		held = character:GetAttribute("Weapon") :: string?
		render()
	end
	refresh()
	characterConnections = {
		humanoid.HealthChanged:Connect(refresh),
		character:GetAttributeChangedSignal("Weapon"):Connect(refresh),
	}
end

function HotbarController.init()
	-- This bar replaces Roblox's own health bar and backpack.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
	root = Kit.mount("Hotbar")
	render()
end

function HotbarController.start()
	if localPlayer.Character then
		task.spawn(watchCharacter, localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(watchCharacter)
	-- A weapon bought lights up in its slot.
	localPlayer:GetAttributeChangedSignal("Weapons"):Connect(render)
end

return HotbarController
