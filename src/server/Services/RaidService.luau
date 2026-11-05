--!strict
--[[
	RaidService

	The steal mechanic. A raider walks into someone else's yard, grabs a
	bundle of parts from their storage crate, and carries it home. Carrying
	slows them down; if they die on the way, the bundle drops where they
	fell and anyone can pick it up. The owner gets it straight back into
	their crate; another raider can carry it on. Reaching their own yard
	banks the bundle as scrap.

	Every step is validated here from the server's view (Tycoon/RaidRules):
	in the yard, close to the crate, not already carrying, the yard not
	shielded, the level gap fair, raids not paused for a storm.

	Anti-grief (Config/Raid): a raided yard is shielded for a while, players
	can't raid yards far below their level, and while raiders are inside a
	yard its owner is alerted and takes less damage.

	Showcase mode can stage a fake raid: an NPC raider walks to a player's
	crate, grabs a bundle and runs for the gate, so the defend-and-recover
	loop can be recorded solo.

	Public API:
		RaidService.startFakeRaid(owner): reason?
		RaidService.setPaused(paused)          -- also paused automatically during storms
		RaidService.isCarrying(player): boolean
		RaidService.raidBanked: Signal(raider, parts)
		RaidService.bundleRecovered: Signal(owner, parts)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local RaidConfig = require(ReplicatedStorage.Shared.Config.Raid)
local Remotes = require(ReplicatedStorage.Shared.Net.Raid)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local MachineRules = require(script.Parent.Parent.Tycoon.MachineRules)
local NpcRig = require(script.Parent.Parent.Npc.NpcRig)
local PlotService = require(script.Parent.PlotService)
local RaidRules = require(script.Parent.Parent.Tycoon.RaidRules)
local ShopService = require(script.Parent.ShopService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RoundService = require(script.Parent.RoundService)
local YardLayout = require(script.Parent.Parent.Tycoon.YardLayout)

local SYSTEM = "Raid"
local BUNDLE_MODEL_NAME = "PartBundle"
local BUNDLE_COLOR = Color3.fromRGB(150, 120, 70)
local CARRY_SPEED_KEY = "CarryingBundle"

-- Fake raid (showcase mode).
local FAKE_RAIDER_LOOK: NpcRig.Look = {
	size = Vector3.new(2, 5, 1.5),
	color = Color3.fromRGB(190, 60, 60),
	maxHealth = 100,
}
local FAKE_RAIDER_WEAPON = "Bat"
local FAKE_RAID_SECONDS = 40
-- Parts put in an empty crate so a fake raid always has something to take.
local FAKE_RAID_CRATE_PARTS = 400
-- Yard-space offsets: where the raider appears, and where it runs to.
local FAKE_RAIDER_START = Vector3.new(0, 3, 26)
local FAKE_RAIDER_ESCAPE = Vector3.new(0, 3, 60)
local FAKE_RAID_STEP_SECONDS = 0.25

type Carry = {
	parts: number,
	-- Where the parts came from, so they can go back if never banked.
	fromUserId: number,
	trove: Trove.Trove,
}

type Drop = {
	parts: number,
	fromUserId: number,
	part: BasePart,
}

local RaidService = {}

RaidService.raidBanked = Signal.new()
RaidService.bundleRecovered = Signal.new()

local paused = false
local carries: { [Player]: Carry } = {}
local drops: { [Drop]: boolean } = {}
-- Raiders currently inside each yard, by yard.
local intruders: { [any]: { [Player]: boolean } } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function playerByUserId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function yardLevelOf(player: Player): number
	local data = DataService.getData(player)
	return if data then MachineRules.yardLevel(data.yard.machines) else 0
end

-- Sends parts back to the crate they were stolen from, if its owner is
-- still here. Otherwise they're gone; the owner's crate was already empty
-- of them and they left before getting them back.
local function returnToOwner(fromUserId: number, parts: number)
	local owner = playerByUserId(fromUserId)
	if owner and PlotService.yardOf(owner) then
		PlotService.addToCrate(owner, parts)
		RaidService.bundleRecovered:fire(owner, parts)
	end
end

-- The sack for `parts`, from ServerStorage.PartBundle: a Model holding one
-- Sack_<n> model per fill level, emptiest first, each pivoted at its middle.
local function sackFor(parts: number): Model?
	local template = ServerStorage:FindFirstChild(BUNDLE_MODEL_NAME)
	if not (template and template:IsA("Model")) then
		return nil
	end
	local levels = #template:GetChildren()
	local level = math.clamp(math.ceil(parts / RaidConfig.BUNDLE_MAX * levels), 1, levels)
	local sack = template:FindFirstChild(`Sack_{level}`)
	return if sack and sack:IsA("Model") then sack:Clone() else nil
end

-- A bundle is one part, so it can be carried, dropped and picked up as a
-- unit: the sack art welded inside an invisible box, or a plain ball when
-- there's no art.
local function newBundlePart(parts: number): BasePart
	-- Bigger bundles look bigger, so a fat haul is worth chasing.
	local scale = 1.5 + math.min(1.5, parts / RaidConfig.BUNDLE_MAX * 1.5)

	local part = Instance.new("Part")
	part.Name = "Bundle"
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true

	local sack = sackFor(parts)
	if sack then
		local _, size = sack:GetBoundingBox()
		sack:ScaleTo(sack:GetScale() * scale / math.max(size.X, size.Z))
		local _, scaled = sack:GetBoundingBox()
		part.Size = scaled
		part.Transparency = 1
		sack:PivotTo(part.CFrame)
		for _, piece in sack:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = false
				piece.CanCollide = false
				piece.CanQuery = false
				piece.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = piece
				weld.Parent = piece
			end
		end
		sack.Parent = part
	else
		part.Shape = Enum.PartType.Ball
		part.Color = BUNDLE_COLOR
		part.Material = Enum.Material.Fabric
		part.Size = Vector3.one * scale
	end

	return part
end

local function stopCarrying(player: Player): Carry?
	local carry = carries[player]
	if not carry then
		return nil
	end

	carries[player] = nil
	carry.trove:destroy()
	player:SetAttribute("CarryingParts", nil)
	if player.Character then
		CombatService.setSpeedMultiplier(player.Character, CARRY_SPEED_KEY, nil)
	end

	return carry
end

local spawnDrop: (position: Vector3, parts: number, fromUserId: number) -> ()

local function startCarrying(player: Player, parts: number, fromUserId: number)
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		returnToOwner(fromUserId, parts)
		return
	end

	local trove = Trove.new()
	carries[player] = { parts = parts, fromUserId = fromUserId, trove = trove }
	player:SetAttribute("CarryingParts", parts)
	CombatService.setSpeedMultiplier(character, CARRY_SPEED_KEY, RaidConfig.CARRY_SPEED_MULTIPLIER)

	-- The bundle rides on the carrier's back so everyone can see who to chase.
	local bundle = newBundlePart(parts)
	bundle.CFrame = root.CFrame * CFrame.new(0, 0.5, root.Size.Z / 2 + bundle.Size.Z / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bundle
	weld.Parent = bundle
	bundle.Parent = character
	trove:add(bundle)

	trove:connect(humanoid.Died, function()
		local carry = stopCarrying(player)
		if carry then
			spawnDrop(root.Position, carry.parts, carry.fromUserId)
		end
	end)
end

spawnDrop = function(position: Vector3, parts: number, fromUserId: number)
	local part = newBundlePart(parts)
	part.Anchored = true
	part.CanQuery = true
	part.Position = position
	part.Parent = workspace

	local drop: Drop = { parts = parts, fromUserId = fromUserId, part = part }
	drops[drop] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = `{parts} parts`
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = RaidConfig.PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = part

	local function remove()
		drops[drop] = nil
		part:Destroy()
	end

	prompt.Triggered:Connect(function(player: Player)
		if not drops[drop] then
			return
		end
		local root = rootOf(player)
		-- SECURITY: re-check distance; prompt presses can be faked.
		if not root or (root.Position - part.Position).Magnitude > RaidConfig.PICKUP_DISTANCE + 4 then
			RemoteGuard.reject(SYSTEM, "PickupTooFar")
			return
		end

		if player.UserId == fromUserId then
			remove()
			returnToOwner(fromUserId, parts)
			Notify.Message:FireClient(player, `Recovered {parts} parts`)
			return
		end

		if carries[player] or paused or not PlotService.yardOf(player) then
			RemoteGuard.reject(SYSTEM, "CantPickUp")
			return
		end
		remove()
		startCarrying(player, parts, fromUserId)
	end)

	task.delay(RaidConfig.DROP_EXPIRE_SECONDS, function()
		if drops[drop] then
			remove()
			returnToOwner(fromUserId, parts)
		end
	end)
end

local function bank(player: Player)
	local carry = stopCarrying(player)
	local data = DataService.getData(player)
	if not carry or not data then
		return
	end

	local scrap = carry.parts * Economy.PART_VALUE
	DataService.addScrap(player, scrap)
	data.stats.raidsWon += 1
	Notify.Message:FireClient(player, `Banked {scrap} scrap from your raid!`)
	RaidService.raidBanked:fire(player, carry.parts)
end

local function onGrabTriggered(player: Player, yard: PlotService.Yard)
	local owner = yard.owner
	local ownerData = owner and DataService.getData(owner)
	local root = rootOf(player)
	if not owner or not ownerData or not root then
		RemoteGuard.reject(SYSTEM, "NoTarget")
		return
	end

	local now = os.time()
	local reason = RaidRules.canGrab({
		isOwner = owner == player,
		raiderHasYard = PlotService.yardOf(player) ~= nil,
		raiderInsideYard = PlotService.yardAt(root.Position) == yard,
		distance = (root.Position - yard.crate.Position).Magnitude,
		alreadyCarrying = carries[player] ~= nil,
		raidsPaused = paused,
		crateParts = ownerData.yard.crateParts,
		raiderLevel = yardLevelOf(player),
		ownerLevel = yardLevelOf(owner),
		ownerShieldUntil = ownerData.raidShieldUntil,
		now = now,
	})
	if reason then
		RemoteGuard.reject(SYSTEM, reason)
		Notify.Message:FireClient(player, RaidRules.REASON_TEXT[reason] or "You can't raid that")
		return
	end

	local taken = PlotService.takeFromCrate(owner, RaidRules.bundleSize(ownerData.yard.crateParts))
	if taken <= 0 then
		return
	end

	local shieldSeconds = RaidConfig.SHIELD_SECONDS
		* (if ShopService.hasPass(owner, "LongShield") then Shop.LONG_SHIELD else 1)
	ownerData.raidShieldUntil = math.max(ownerData.raidShieldUntil, RaidRules.shieldUntil(now, shieldSeconds))
	ShopService.syncShield(owner)
	ownerData.stats.timesRaided += 1
	startCarrying(player, taken, owner.UserId)

	Remotes.Alert:FireClient(owner, "Grabbed", `{player.DisplayName} stole {taken} parts! Stop them!`)
	Notify.Message:FireClient(player, `Grabbed {taken} parts. Get them home!`)
end

local function setOwnerBuff(owner: Player, active: boolean)
	local character = owner.Character
	if character then
		local multiplier = if active then RaidConfig.OWNER_DAMAGE_TAKEN_MULTIPLIER else 1
		CombatService.setDamageTakenMultiplier(character, multiplier)
	end
end

-- Who is standing where: raises intruder alerts and owner buffs, and banks
-- bundles for carriers who made it home.
local function checkYards()
	local current: { [any]: { [Player]: boolean } } = {}

	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local yard = root and PlotService.yardAt(root.Position)
		if yard then
			if yard.owner and yard.owner ~= player then
				current[yard] = current[yard] or {}
				current[yard][player] = true
			end
			if carries[player] and PlotService.yardOf(player) == yard then
				bank(player)
			end
		end
	end

	for _, yard in PlotService.getYards() do
		local owner = yard.owner
		local had = intruders[yard] ~= nil and next(intruders[yard]) ~= nil
		local has = current[yard] ~= nil
		if owner and has and not had then
			local name = next(current[yard]) :: Player
			Remotes.Alert:FireClient(owner, "Intruder", `{name.DisplayName} is in your yard!`)
			setOwnerBuff(owner, true)
		elseif owner and had and not has then
			Remotes.Alert:FireClient(owner, "Clear", "Your yard is clear")
			setOwnerBuff(owner, false)
		end
	end

	intruders = current
end

local function walkUntil(humanoid: Humanoid, root: BasePart, goal: Vector3, closeEnough: number, deadline: number)
	while humanoid.Health > 0 and os.clock() < deadline and (root.Position - goal).Magnitude > closeEnough do
		humanoid:MoveTo(goal)
		task.wait(FAKE_RAID_STEP_SECONDS)
	end
end

function RaidService.startFakeRaid(owner: Player): string?
	local yard = PlotService.yardOf(owner)
	if not yard then
		return "You need a yard"
	end
	if PlotService.getCrateParts(owner) < RaidConfig.MIN_CRATE_PARTS then
		PlotService.setCrateParts(owner, FAKE_RAID_CRATE_PARTS)
	end

	local model = NpcRig.build("FakeRaider", FAKE_RAIDER_LOOK)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart
	model:PivotTo(CFrame.new(YardLayout.toWorld(yard.origin, yard.yaw, FAKE_RAIDER_START)))
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	CombatService.register(model, FAKE_RAIDER_WEAPON)

	Remotes.Alert:FireClient(owner, "Intruder", "A raider is heading for your crate!")

	task.spawn(function()
		local deadline = os.clock() + FAKE_RAID_SECONDS
		walkUntil(humanoid, root, yard.crate.Position, RaidConfig.GRAB_DISTANCE - 2, deadline)

		local carried = 0
		if humanoid.Health > 0 and os.clock() < deadline then
			carried = PlotService.takeFromCrate(owner, RaidRules.bundleSize(PlotService.getCrateParts(owner)))
			local bundle = newBundlePart(carried)
			bundle.CFrame = root.CFrame * CFrame.new(0, 0.5, root.Size.Z / 2 + bundle.Size.Z / 2)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = bundle
			weld.Parent = bundle
			bundle.Parent = model
			CombatService.setSpeedMultiplier(model, CARRY_SPEED_KEY, RaidConfig.CARRY_SPEED_MULTIPLIER)
			Remotes.Alert:FireClient(owner, "Grabbed", `A raider stole {carried} parts! Stop them!`)

			local escape = YardLayout.toWorld(yard.origin, yard.yaw, FAKE_RAIDER_ESCAPE)
			walkUntil(humanoid, root, escape, 4, deadline)
		end

		if carried > 0 then
			if humanoid.Health <= 0 then
				spawnDrop(root.Position, carried, owner.UserId)
			else
				-- It's only a showcase: an escaped fake raider gives the parts back.
				returnToOwner(owner.UserId, carried)
				Notify.Message:FireClient(owner, "The raider got away (showcase: parts returned)")
			end
		end

		task.wait(2)
		model:Destroy()
	end)

	return nil
end

function RaidService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function RaidService.setPaused(isPaused: boolean)
	paused = isPaused
	if not isPaused then
		return
	end

	-- Storms make yards safe: every bundle in flight goes home.
	for player, carry in carries do
		stopCarrying(player)
		returnToOwner(carry.fromUserId, carry.parts)
	end
	for drop in drops do
		drops[drop] = nil
		drop.part:Destroy()
		returnToOwner(drop.fromUserId, drop.parts)
	end
end

function RaidService.init()
	DebugService.register("fakeraid", "/fakeraid", function(player)
		return RaidService.startFakeRaid(player) or "Fake raid started"
	end)

	for _, yard in PlotService.getYards() do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab parts"
		prompt.ObjectText = "Raid"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = RaidConfig.GRAB_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		-- The client shows this one to everyone except the owner.
		prompt:SetAttribute("RaiderOnly", true)
		prompt.Parent = yard.crate
		prompt.Triggered:Connect(function(player)
			onGrabTriggered(player, yard)
		end)
	end
end

function RaidService.start()
	RoundService.phaseChanged:connect(function(phase)
		RaidService.setPaused(phase == "Storm")
	end)

	Players.PlayerRemoving:Connect(function(player)
		local carry = stopCarrying(player)
		if carry then
			returnToOwner(carry.fromUserId, carry.parts)
		end
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceCheck += deltaTime
		if sinceCheck >= RaidConfig.YARD_CHECK_INTERVAL then
			sinceCheck = 0
			checkYards()
		end
	end)
end

return RaidService
