--!strict
--[[
	CombatController

	The client half of combat: turns input into intent remotes and plays
	what the server reports back. It never decides a hit; CombatService does.

	Input (also bound as touch buttons on mobile):
		Click / R2          attack
		F / right-click     hold to block
		1, 2, ...           switch weapon (WeaponConfig.PLAYER_WEAPONS order);
		                    the held weapon's key puts it away

	Animations and sounds come from Assets and are skipped while their IDs
	are placeholders. Hit effects use a short-lived flash so hits read
	clearly with no art at all.

	Public API:
		CombatController.hitShown: Signal(model, outcome, damage, attacker)   -- for juice effects
		CombatController.toggleWeapon(weaponName)   -- equip it, or put it away if held
		CombatController.ownsWeapon(weaponName): boolean
]]

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Remotes = require(ReplicatedStorage.Shared.Combat.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local NotifyController = require(script.Parent.NotifyController)
local Sfx = require(script.Parent.Parent.Sfx)

local localPlayer = Players.LocalPlayer

local WEAPON_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local FLASH_SECONDS = 0.15
local FLASH_SIZE = 2.5

local OUTCOME_COLORS: { [string]: Color3 } = {
	Hit = Color3.fromRGB(255, 70, 70),
	Blocked = Color3.fromRGB(120, 180, 255),
	Parried = Color3.fromRGB(255, 230, 80),
	GuardBroken = Color3.fromRGB(255, 140, 40),
}

local CombatController = {}

CombatController.hitShown = Signal.new()

-- Loaded tracks per Animator, so each animation loads once per character.
local loadedTracks: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local blockTrack: AnimationTrack? = nil

local function animatorOf(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function playAnimation(model: Model, key: string): AnimationTrack?
	local id = (Assets.Animations :: any)[key]
	if not Assets.isSet(id) then
		return nil
	end
	local animator = animatorOf(model)
	if not animator then
		return nil
	end

	local tracks = loadedTracks[animator]
	if not tracks then
		tracks = {}
		loadedTracks[animator] = tracks
	end

	local track = tracks[key]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		track = animator:LoadAnimation(animation)
		tracks[key] = track
	end

	track:Play()
	return track
end

local function playSound(key: string, parent: Instance?)
	if parent then
		Sfx.play(key, parent)
	end
end

local function flash(model: Model, outcome: string)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * FLASH_SIZE
	part.Material = Enum.Material.Neon
	part.Color = OUTCOME_COLORS[outcome] or Color3.new(1, 1, 1)
	part.Transparency = 0.3
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = root.CFrame
	part.Parent = workspace
	Debris:AddItem(part, FLASH_SECONDS)
end

-- Animations a client plays on its own character replicate to everyone,
-- so other players' swings are animated by their own clients. NPCs are
-- animated locally by every client.
local function shouldAnimate(model: Model): boolean
	return model == localPlayer.Character or Players:GetPlayerFromCharacter(model) == nil
end

local function onPlaySwing(model: Model, weaponName: string, stepIndex: number)
	local weapon = WeaponConfig.Weapons[weaponName]
	local step = weapon and weapon.combo[stepIndex]
	if not step or typeof(model) ~= "Instance" then
		return
	end

	if shouldAnimate(model) then
		playAnimation(model, step.animation)
	end
	playSound(if weaponName == "Zap" then "Zap" else "Swing", model.PrimaryPart)
end

local function onHitEffect(model: Model, outcome: string, damage: number, attacker: Model?)
	if typeof(model) ~= "Instance" then
		return
	end

	flash(model, outcome)
	-- JuiceController plays the impact sound where the blow lands.
	CombatController.hitShown:fire(model, outcome, damage, attacker)
end

local function onKnockback(velocity: Vector3)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and typeof(velocity) == "Vector3" then
		root.AssemblyLinearVelocity += velocity
	end
end

local function onAttackInput(_action: string, state: Enum.UserInputState, _input: InputObject)
	if state == Enum.UserInputState.Begin then
		Remotes.Attack:FireServer()
	end

	return Enum.ContextActionResult.Pass
end

local function onBlockInput(_action: string, state: Enum.UserInputState, _input: InputObject)
	if state == Enum.UserInputState.Begin then
		Remotes.SetBlocking:FireServer(true)
		local character = localPlayer.Character
		blockTrack = if character then playAnimation(character, "Block") else nil
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		Remotes.SetBlocking:FireServer(false)
		if blockTrack then
			blockTrack:Stop()
			blockTrack = nil
		end
	end

	return Enum.ContextActionResult.Pass
end

-- Weapons this player owns, from the "Weapons" attribute ShopService keeps.
function CombatController.ownsWeapon(weaponName: string): boolean
	local owned = localPlayer:GetAttribute("Weapons")
	return type(owned) == "string" and table.find(string.split(owned, ","), weaponName) ~= nil
end

function CombatController.toggleWeapon(weaponName: string)
	if not CombatController.ownsWeapon(weaponName) then
		NotifyController.show(`Buy the {WeaponConfig.Weapons[weaponName].displayName} in the Shop first`)
		return
	end
	local character = localPlayer.Character
	if character and character:GetAttribute("Weapon") == weaponName then
		Remotes.UnequipWeapon:FireServer()
	else
		Remotes.EquipWeapon:FireServer(weaponName)
	end
end

local function bindWeaponKeys()
	for index, weaponName in WeaponConfig.PLAYER_WEAPONS do
		local key = WEAPON_KEYS[index]
		if not key then
			break
		end

		local action = `Equip{weaponName}`
		ContextActionService:BindAction(action, function(_action, state, _input)
			if state == Enum.UserInputState.Begin then
				CombatController.toggleWeapon(weaponName)
			end
			return Enum.ContextActionResult.Pass
		end, true, key)
		ContextActionService:SetTitle(action, WeaponConfig.Weapons[weaponName].displayName)
	end
end

function CombatController.init() end

function CombatController.start()
	Remotes.PlaySwing.OnClientEvent:Connect(onPlaySwing)
	Remotes.HitEffect.OnClientEvent:Connect(onHitEffect)
	Remotes.Knockback.OnClientEvent:Connect(onKnockback)

	ContextActionService:BindAction(
		"Attack",
		onAttackInput,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle("Attack", "Hit")

	ContextActionService:BindAction("Block", onBlockInput, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("Block", "Block")

	bindWeaponKeys()
end

return CombatController
