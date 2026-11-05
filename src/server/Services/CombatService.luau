--!strict
--[[
	CombatService

	Runs every fight on the server: player characters, bots and the training
	dummy are all "fighters" here, using the same rules. Clients only send
	intent (Attack, SetBlocking, EquipWeapon, UnequipWeapon); this service decides whether a
	swing starts, checks the hitbox itself after the windup, and applies
	damage, stuns and knockback.

	The rules themselves (combos, blocks, parries, posture) live in
	Combat/CombatRules.luau; this file handles characters, remotes, timing
	and the spatial hitbox query.

	Other services use it to:
	- register NPCs as fighters (BotService, DummyService),
	- start NPC swings with CombatService.attack,
	- slow fighters down (RaidService slows bundle carriers),
	- buff defenders (RaidService's raid defense buff),
	- react to hits through hitLanded (LootService counts damage).

	Public API:
		CombatService.register(model, weaponName)
		CombatService.unregister(model)
		CombatService.isFighter(model): boolean
		CombatService.getCombatant(model): Combatant?
		CombatService.attack(model): reason?
		CombatService.setBlocking(model, wantsBlock): reason?
		CombatService.equip(model, weaponName): reason?
		CombatService.setSpeedMultiplier(model, key, multiplier?)
		CombatService.setDamageTakenMultiplier(model, multiplier)
		CombatService.hitLanded: Signal(attackerModel, targetModel, HitResult)
		CombatService.swingChecked: Signal(boxCFrame, boxSize)   -- for the debug overlay
		CombatService.weaponChanged: Signal(model, weaponName?)   -- nil when put away
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Combat.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local CombatRules = require(script.Parent.Parent.Combat.CombatRules)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local ShopService = require(script.Parent.ShopService)

local SYSTEM = "Combat"

-- Remote calls allowed per second, per player.
local ATTACK_RATE = 8
local BLOCK_RATE = 10
local EQUIP_RATE = 2

-- Seconds between walk speed updates. Fast enough to feel instant, slow
-- enough not to touch every Humanoid every frame.
local SPEED_UPDATE_INTERVAL = 0.1

type Fighter = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	combatant: CombatRules.Combatant,
	speedMultipliers: { [string]: number },
	trove: Trove.Trove,
}

local CombatService = {}

CombatService.hitLanded = Signal.new()
CombatService.swingChecked = Signal.new()
CombatService.weaponChanged = Signal.new()

local fighters: { [Model]: Fighter } = {}
-- The weapon each player last chose, kept across respawns.
local equippedWeapons: { [Player]: string } = {}

local function isAlive(fighter: Fighter): boolean
	return fighter.humanoid.Health > 0 and fighters[fighter.model] == fighter
end

-- Walks up from a touched part to the fighter it belongs to, so hitting an
-- arm, a hat or a tool all count as hitting that character.
local function fighterFromPart(part: BasePart): Fighter?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local fighter = fighters[model]
		if fighter then
			return fighter
		end
		model = model:FindFirstAncestorOfClass("Model")
	end

	return nil
end

local function canHit(attacker: Fighter, target: Fighter): boolean
	if not isAlive(target) then
		return false
	end
	-- Bots never hurt each other; a crowd of bots swinging into the same
	-- player shouldn't wipe itself out.
	if attacker.model:GetAttribute("IsBot") and target.model:GetAttribute("IsBot") then
		return false
	end

	return true
end

local function applyHit(attacker: Fighter, target: Fighter, attack: CombatRules.AttackStart, now: number)
	local result = CombatRules.resolveHit(
		attacker.combatant,
		target.combatant,
		attack.step,
		attacker.root.Position,
		target.root.Position,
		target.root.CFrame.LookVector,
		now
	)

	if result.damage > 0 then
		-- TakeDamage respects ForceFields, so spawn protection still works.
		target.humanoid:TakeDamage(result.damage)
	end

	if result.knockback > 0 then
		local velocity = CombatRules.knockbackVelocity(attacker.root.Position, target.root.Position, result.knockback)
		local targetPlayer = Players:GetPlayerFromCharacter(target.model)
		if targetPlayer then
			-- A player's client simulates their own character, so a push set
			-- here would be overwritten. Their client applies it instead.
			Remotes.Knockback:FireClient(targetPlayer, velocity)
		else
			target.root.AssemblyLinearVelocity = velocity
		end
	end

	target.model:SetAttribute("Blocking", target.combatant.blocking)
	Remotes.HitEffect:FireAllClients(target.model, result.outcome, result.damage, attacker.model)
	CombatService.hitLanded:fire(attacker.model, target.model, result)
end

local function resolveSwing(fighter: Fighter, attack: CombatRules.AttackStart)
	-- The fighter may have died, respawned or been stunned during the windup.
	if not isAlive(fighter) or CombatRules.wasInterrupted(fighter.combatant, attack) then
		return
	end

	local rootCFrame = fighter.root.CFrame
	local look = rootCFrame.LookVector
	local center, size = CombatRules.hitbox(rootCFrame.Position, look, attack.step)
	local boxCFrame = CFrame.lookAt(center, center + Vector3.new(look.X, 0, look.Z))

	-- SECURITY: the hitbox is checked on the server, from the server's view
	-- of where everyone stands. A client claiming "I hit them" counts for
	-- nothing; the client never even says who it was aiming at.
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fighter.model }
	local parts = workspace:GetPartBoundsInBox(boxCFrame, size, params)
	CombatService.swingChecked:fire(boxCFrame, size)

	local now = os.clock()
	local alreadyHit: { [Fighter]: boolean } = {}
	for _, part in parts do
		local target = fighterFromPart(part)
		if target and not alreadyHit[target] and canHit(fighter, target) then
			alreadyHit[target] = true
			applyHit(fighter, target, attack, now)
		end
	end
end

function CombatService.register(model: Model, weaponName: string)
	CombatService.unregister(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(
		humanoid and root and root:IsA("BasePart"),
		`CombatService: {model.Name} needs a Humanoid and HumanoidRootPart`
	)

	local fighter: Fighter = {
		model = model,
		humanoid = humanoid,
		root = root :: BasePart,
		combatant = CombatRules.newCombatant(weaponName),
		speedMultipliers = {},
		trove = Trove.new(),
	}
	fighters[model] = fighter

	fighter.trove:connect(humanoid.Died, function()
		CombatService.unregister(model)
	end)
	fighter.trove:connect(model.Destroying, function()
		CombatService.unregister(model)
	end)

	model:SetAttribute("Weapon", weaponName)
	model:SetAttribute("Blocking", false)
	CombatService.weaponChanged:fire(model, weaponName)
end

function CombatService.unregister(model: Model)
	local fighter = fighters[model]
	if not fighter then
		return
	end

	fighters[model] = nil
	fighter.trove:destroy()
	model:SetAttribute("Blocking", nil)
end

function CombatService.isFighter(model: Model): boolean
	return fighters[model] ~= nil
end

function CombatService.getCombatant(model: Model): CombatRules.Combatant?
	local fighter = fighters[model]
	return if fighter then fighter.combatant else nil
end

function CombatService.attack(model: Model): string?
	local fighter = fighters[model]
	if not fighter then
		return "NotFighter"
	end
	if not isAlive(fighter) then
		return "Dead"
	end

	local attack, reason = CombatRules.tryStartAttack(fighter.combatant, os.clock())
	if not attack then
		return reason
	end

	Remotes.PlaySwing:FireAllClients(model, fighter.combatant.weaponName, attack.index)
	task.delay(attack.step.windup, resolveSwing, fighter, attack)

	return nil
end

function CombatService.setBlocking(model: Model, wantsBlock: boolean): string?
	local fighter = fighters[model]
	if not fighter or not isAlive(fighter) then
		return "NotFighter"
	end

	local reason = CombatRules.setBlocking(fighter.combatant, wantsBlock, os.clock())
	model:SetAttribute("Blocking", fighter.combatant.blocking)

	return reason
end

function CombatService.equip(model: Model, weaponName: string): string?
	local fighter = fighters[model]
	if not fighter then
		return "NotFighter"
	end

	local reason = CombatRules.equip(fighter.combatant, weaponName, os.clock())
	if not reason then
		model:SetAttribute("Weapon", weaponName)
		CombatService.weaponChanged:fire(model, weaponName)
	end

	return reason
end

function CombatService.unequip(model: Model): string?
	local fighter = fighters[model]
	if not fighter then
		return "NotFighter"
	end

	local reason = CombatRules.unequip(fighter.combatant, os.clock())
	if not reason then
		model:SetAttribute("Weapon", nil)
		model:SetAttribute("Blocking", false)
		CombatService.weaponChanged:fire(model, nil)
	end

	return reason
end

-- Multipliers from different systems stack, each under its own key, so
-- raiding's slow and a future speed boost can't overwrite each other.
-- Pass nil to remove one.
function CombatService.setSpeedMultiplier(model: Model, key: string, multiplier: number?)
	local fighter = fighters[model]
	if fighter then
		fighter.speedMultipliers[key] = multiplier
	end
end

function CombatService.setDamageTakenMultiplier(model: Model, multiplier: number)
	local fighter = fighters[model]
	if fighter then
		fighter.combatant.damageTakenMultiplier = multiplier
	end
end

local function updateWalkSpeeds()
	local now = os.clock()
	for _, fighter in fighters do
		local speed = CombatRules.walkSpeed(fighter.combatant, now)
		for _, multiplier in fighter.speedMultipliers do
			speed *= multiplier
		end
		-- Writing WalkSpeed replicates, so only write when it changes.
		if math.abs(fighter.humanoid.WalkSpeed - speed) > 0.01 then
			fighter.humanoid.WalkSpeed = speed
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- Characters arrive before all their parts do; wait for the root.
	character:WaitForChild("HumanoidRootPart")
	if character.Parent == nil then
		return
	end

	CombatService.register(character, equippedWeapons[player] or WeaponConfig.DEFAULT_PLAYER_WEAPON)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function CombatService.init() end

function CombatService.start()
	RemoteGuard.listen(SYSTEM, Remotes.Attack, ATTACK_RATE, function(player: Player)
		local character = player.Character
		if not character then
			return "NoCharacter"
		end

		return CombatService.attack(character)
	end)

	RemoteGuard.listen(SYSTEM, Remotes.SetBlocking, BLOCK_RATE, function(player: Player, wantsBlock: any)
		-- SECURITY: arguments come from the client and can be anything.
		if type(wantsBlock) ~= "boolean" then
			return "BadArgument"
		end
		local character = player.Character
		if not character then
			return "NoCharacter"
		end

		return CombatService.setBlocking(character, wantsBlock)
	end)

	RemoteGuard.listen(SYSTEM, Remotes.EquipWeapon, EQUIP_RATE, function(player: Player, weaponName: any)
		-- SECURITY: only player weapons; a client asking for a bot's weapon
		-- (or any made-up name) is refused.
		if not WeaponConfig.isPlayerWeapon(weaponName) then
			return "NotPlayerWeapon"
		end
		-- SECURITY: and only weapons this player has bought.
		if not ShopService.ownsWeapon(player, weaponName) then
			return "NotOwned"
		end
		local character = player.Character
		if not character then
			return "NoCharacter"
		end

		local reason = CombatService.equip(character, weaponName)
		if not reason then
			equippedWeapons[player] = weaponName
		end

		return reason
	end)

	RemoteGuard.listen(SYSTEM, Remotes.UnequipWeapon, EQUIP_RATE, function(player: Player)
		local character = player.Character
		if not character then
			return "NoCharacter"
		end

		return CombatService.unequip(character)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		equippedWeapons[player] = nil
	end)

	local sinceUpdate = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceUpdate += deltaTime
		if sinceUpdate >= SPEED_UPDATE_INTERVAL then
			sinceUpdate = 0
			updateWalkSpeeds()
		end
	end)
end

return CombatService
