--!strict
--[[
	RaidService

	Stealing scrap, and keeping thieves out.

	Crate raids: a raider walks into someone else's yard, grabs a bundle of
	scrap from their storage crate, and carries it home. Carrying slows
	them down; if they die on the way, the bundle drops where they fell and
	anyone can pick it up. The owner gets it straight back into their
	crate; another raider can carry it on. Reaching their own yard banks
	the bundle. In a blackout a grab takes twice the share.

	Every step is validated here from the server's view (Tycoon/RaidRules):
	in the yard, close to the crate, hands free, the yard not shielded, the
	crate worth raiding.

	Anti-grief (Config/Raid): a raided yard is shielded for a while, and
	while raiders are inside a yard its owner is alerted and takes less
	damage.

	Gates: each yard's gate has a barrier its owner can lock for a while
	(Config/Yard), then must wait before locking again. It stops everyone
	on the server; the owner's own client lets them through
	(PlotController). The blackout drops every barrier and keeps them down.
	The yard's model says until when it is locked (GateLockedUntil, in
	server time).

	Players carrying a bundle have the attribute CarryingScrap.

	Public API:
		RaidService.isCarrying(player): boolean
		RaidService.hasIntruders(yard): boolean
		RaidService.raidBanked: Signal(raider, scrap)
		RaidService.bundleRecovered: Signal(owner, scrap)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local RaidConfig = require(ReplicatedStorage.Shared.Config.Raid)
local Remotes = require(ReplicatedStorage.Shared.Net.Raid)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Storm = require(ReplicatedStorage.Shared.Config.Storm)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local YardConfig = require(ReplicatedStorage.Shared.Config.Yard)
local YardGrid = require(ReplicatedStorage.Shared.Yard.YardGrid)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RaidRules = require(script.Parent.Parent.Tycoon.RaidRules)
local ShopService = require(script.Parent.ShopService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RoundService = require(script.Parent.RoundService)

local SYSTEM = "Raid"
local BUNDLE_MODEL_NAME = "PartBundle"
local BUNDLE_COLOR = Color3.fromRGB(150, 120, 70)
local CARRY_SPEED_KEY = "CarryingBundle"
-- How full a dropped bundle counts as for its pickup burst (Juice.collectPieces).
local LOOT_BURST_FILL = 0.3
-- The gate barrier: how tall and thick it is, and its colour when locked.
local BARRIER_HEIGHT = 14
local BARRIER_THICKNESS = 1.5
local BARRIER_COLOR = Color3.fromRGB(255, 80, 60)
-- Where the gate's lock stands, in yard space: just inside, beside the opening.
local LOCK_OFFSET = Vector3.new(YardConfig.GATE_WIDTH / 2 + 2, 3, YardGrid.DEPTH / 2 - 3)

type Carry = {
	scrap: number,
	-- Where the scrap came from, so it can go back if never banked.
	fromUserId: number,
	-- How full the bundle looks, 0-1: its share of the crate it came from.
	fill: number,
	trove: Trove.Trove,
}

type Drop = {
	scrap: number,
	fromUserId: number,
	fill: number,
	part: BasePart,
}

type Gate = {
	barrier: BasePart,
	prompt: ProximityPrompt,
	-- os.clock() times.
	lockedUntil: number,
	readyAt: number,
}

local RaidService = {}

RaidService.raidBanked = Signal.new()
RaidService.bundleRecovered = Signal.new()

local carries: { [Player]: Carry } = {}
local drops: { [Drop]: boolean } = {}
-- Raiders currently inside each yard, by yard.
local intruders: { [any]: { [Player]: boolean } } = {}
local gates: { [PlotService.Yard]: Gate } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function playerByUserId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

-- Sends scrap back to the crate it was stolen from, if its owner is still
-- here. Otherwise it's gone; the owner left before getting it back.
local function returnToOwner(fromUserId: number, scrap: number)
	local owner = playerByUserId(fromUserId)
	if owner and PlotService.yardOf(owner) then
		PlotService.addToCrate(owner, scrap)
		RaidService.bundleRecovered:fire(owner, scrap)
	end
end

-- The sack for a bundle, from ServerStorage.PartBundle: a Model holding one
-- Sack_<n> model per fill level, emptiest first, each pivoted at its middle.
local function sackFor(fill: number): Model?
	local template = ServerStorage:FindFirstChild(BUNDLE_MODEL_NAME)
	if not (template and template:IsA("Model")) then
		return nil
	end
	local levels = #template:GetChildren()
	local level = math.clamp(math.ceil(fill * levels), 1, levels)
	local sack = template:FindFirstChild(`Sack_{level}`)
	return if sack and sack:IsA("Model") then sack:Clone() else nil
end

-- A bundle is one part, so it can be carried, dropped and picked up as a
-- unit: the sack art welded inside an invisible box, or a plain ball when
-- there's no art.
local function newBundlePart(fill: number): BasePart
	-- Bigger bundles look bigger, so a fat haul is worth chasing.
	local scale = 1.5 + math.clamp(fill, 0, 1) * 1.5

	local part = Instance.new("Part")
	part.Name = "Bundle"
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true

	local sack = sackFor(fill)
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
				-- A Weld holds the piece at this offset wherever the
				-- bundle is put; a WeldConstraint would let go of it each
				-- time the bundle's CFrame is set.
				local weld = Instance.new("Weld")
				weld.Part0 = part
				weld.Part1 = piece
				weld.C0 = part.CFrame:ToObjectSpace(piece.CFrame)
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
	player:SetAttribute("CarryingScrap", nil)
	if player.Character then
		CombatService.setSpeedMultiplier(player.Character, CARRY_SPEED_KEY, nil)
	end

	return carry
end

local spawnDrop: (position: Vector3, scrap: number, fromUserId: number, fill: number) -> ()

local function startCarrying(player: Player, scrap: number, fromUserId: number, fill: number)
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		returnToOwner(fromUserId, scrap)
		return
	end

	local trove = Trove.new()
	carries[player] = { scrap = scrap, fromUserId = fromUserId, fill = fill, trove = trove }
	player:SetAttribute("CarryingScrap", scrap)
	CombatService.setSpeedMultiplier(character, CARRY_SPEED_KEY, RaidConfig.CARRY_SPEED_MULTIPLIER)

	-- The bundle rides on the carrier's back so everyone can see who to chase.
	local bundle = newBundlePart(fill)
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
			spawnDrop(root.Position, carry.scrap, carry.fromUserId, carry.fill)
		end
	end)
end

spawnDrop = function(position: Vector3, scrap: number, fromUserId: number, fill: number)
	local part = newBundlePart(fill)
	part.Anchored = true
	part.CanQuery = true
	part.Position = position
	part.Parent = workspace

	local drop: Drop = { scrap = scrap, fromUserId = fromUserId, fill = fill, part = part }
	drops[drop] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = `{Format.short(scrap)} scrap`
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

		-- The bundle arcs into whoever picks it up.
		local from = part.Position
		if player.UserId == fromUserId then
			Notify.ScrapBurst:FireClient(player, from, scrap, LOOT_BURST_FILL)
			remove()
			returnToOwner(fromUserId, scrap)
			Notify.Message:FireClient(player, `Recovered {Format.short(scrap)} scrap`)
			Notify.Sound:FireClient(player, "Collect")
			return
		end

		if carries[player] or player:GetAttribute("CarryingCapsule") ~= nil or not PlotService.yardOf(player) then
			RemoteGuard.reject(SYSTEM, "CantPickUp")
			return
		end
		Notify.ScrapBurst:FireClient(player, from, scrap, LOOT_BURST_FILL)
		remove()
		startCarrying(player, scrap, fromUserId, fill)
	end)

	task.delay(RaidConfig.DROP_EXPIRE_SECONDS, function()
		if drops[drop] then
			remove()
			returnToOwner(fromUserId, scrap)
		end
	end)
end

local function bank(player: Player)
	local carry = stopCarrying(player)
	local data = DataService.getData(player)
	if not carry or not data then
		return
	end

	DataService.addScrap(player, carry.scrap)
	data.stats.raidsWon += 1
	Notify.Message:FireClient(player, `Banked {Format.short(carry.scrap)} scrap from your raid!`)
	Notify.Sound:FireClient(player, "Bank")
	RaidService.raidBanked:fire(player, carry.scrap)
end

local function onGrabTriggered(player: Player, yard: PlotService.Yard, crate: BasePart)
	local owner = yard.owner
	local ownerData = owner and DataService.getData(owner)
	local root = rootOf(player)
	if not owner or not ownerData or not root then
		RemoteGuard.reject(SYSTEM, "NoTarget")
		return
	end

	local now = os.time()
	local crateScrap = ownerData.yard.crateScrap
	local reason = RaidRules.canGrab({
		isOwner = owner == player,
		raiderHasYard = PlotService.yardOf(player) ~= nil,
		raiderInsideYard = PlotService.yardAt(root.Position) == yard,
		distance = (root.Position - crate.Position).Magnitude,
		alreadyCarrying = carries[player] ~= nil or player:GetAttribute("CarryingCapsule") ~= nil,
		crateScrap = crateScrap,
		crateCapacity = PlotService.crateCapacity(owner),
		ownerShieldUntil = ownerData.raidShieldUntil,
		now = now,
	})
	if reason then
		RemoteGuard.reject(SYSTEM, reason)
		Notify.Message:FireClient(player, RaidRules.REASON_TEXT[reason] or "You can't raid that")
		return
	end

	-- In the blackout the crate is unlocked: a grab takes twice the share.
	local multiplier = if RoundService.getPhase() == "Blackout" then Storm.BLACKOUT_RAID_MULTIPLIER else 1
	local taken = PlotService.takeFromCrate(owner, RaidRules.bundleSize(crateScrap, multiplier))
	if taken <= 0 then
		return
	end

	local shieldSeconds = RaidConfig.SHIELD_SECONDS
		* (if ShopService.hasPass(owner, "LongShield") then Shop.LONG_SHIELD else 1)
	ownerData.raidShieldUntil = math.max(ownerData.raidShieldUntil, RaidRules.shieldUntil(now, shieldSeconds))
	ShopService.syncShield(owner)
	ownerData.stats.timesRaided += 1
	startCarrying(player, taken, owner.UserId, taken / math.max(1, PlotService.crateCapacity(owner)))

	Remotes.Alert:FireClient(owner, "Grabbed", `{player.DisplayName} stole {Format.short(taken)} scrap! Stop them!`)
	Notify.Message:FireClient(player, `Grabbed {Format.short(taken)} scrap. Get it home!`)
	Notify.Sound:FireClient(player, "Grab")
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

function RaidService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function RaidService.hasIntruders(yard: PlotService.Yard): boolean
	return intruders[yard] ~= nil and next(intruders[yard]) ~= nil
end

local function showGate(yard: PlotService.Yard)
	local gate = gates[yard]
	local now = os.clock()
	local locked = now < gate.lockedUntil
	gate.barrier.CanCollide = locked
	gate.barrier.Transparency = if locked then 0.45 else 1
	-- Server time, so clients can count the lock down.
	local left = gate.lockedUntil - now
	yard.model:SetAttribute("GateLockedUntil", if locked then workspace:GetServerTimeNow() + left else 0)

	local blackout = RoundService.getPhase() == "Blackout"
	gate.prompt:SetAttribute("Available", not locked and not blackout and now >= gate.readyAt)
end

local function unlockGate(yard: PlotService.Yard)
	gates[yard].lockedUntil = 0
	showGate(yard)
end

local function onLockTriggered(player: Player, yard: PlotService.Yard)
	local gate = gates[yard]
	local now = os.clock()
	if yard.owner ~= player then
		RemoteGuard.reject(SYSTEM, "NotOwner")
		return
	end
	if RoundService.getPhase() == "Blackout" then
		Notify.Message:FireClient(player, "The power's out. The gate won't lock!")
		return
	end
	if now < gate.readyAt then
		Notify.Message:FireClient(player, `The lock needs {math.ceil(gate.readyAt - now)}s to recharge`)
		return
	end

	gate.lockedUntil = now + YardConfig.LOCK_SECONDS
	gate.readyAt = gate.lockedUntil + YardConfig.LOCK_COOLDOWN_SECONDS
	showGate(yard)
	Notify.Message:FireClient(player, `Gate locked for {YardConfig.LOCK_SECONDS}s`)
	Notify.Sound:FireClient(player, "Purchase")

	task.delay(YardConfig.LOCK_SECONDS, function()
		showGate(yard)
	end)
	task.delay(YardConfig.LOCK_SECONDS + YardConfig.LOCK_COOLDOWN_SECONDS, function()
		showGate(yard)
	end)
end

local function buildGate(yard: PlotService.Yard): Gate
	local turned = CFrame.Angles(0, yard.yaw, 0)
	local function at(offset: Vector3): CFrame
		return CFrame.new(YardGrid.toWorld(yard.origin, yard.yaw, offset)) * turned
	end

	local barrier = Instance.new("Part")
	barrier.Name = "GateBarrier"
	barrier.Size = Vector3.new(YardConfig.GATE_WIDTH, BARRIER_HEIGHT, BARRIER_THICKNESS)
	barrier.CFrame = at(YardGrid.GATE_OFFSET + Vector3.new(0, BARRIER_HEIGHT / 2, 0))
	barrier.Color = BARRIER_COLOR
	barrier.Material = Enum.Material.ForceField
	barrier.Anchored = true
	barrier.CanCollide = false
	barrier.CanQuery = false
	barrier.Transparency = 1
	barrier.Parent = yard.model

	local lock = Instance.new("Part")
	lock.Name = "GateLock"
	lock.Size = Vector3.new(1.5, 1.5, 1.5)
	lock.CFrame = at(LOCK_OFFSET)
	lock.Color = BARRIER_COLOR
	lock.Material = Enum.Material.Neon
	lock.Anchored = true
	lock.CanCollide = false
	lock.Parent = yard.model

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lock gate"
	prompt.ObjectText = `{YardConfig.LOCK_SECONDS}s`
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("OwnerOnly", true)
	prompt.Parent = lock
	prompt.Triggered:Connect(function(player: Player)
		onLockTriggered(player, yard)
	end)

	return { barrier = barrier, prompt = prompt, lockedUntil = 0, readyAt = 0 }
end

-- The crate gets a "Grab scrap" prompt for everyone but its owner.
local function onThingBuilt(yard: PlotService.Yard, object: PlotService.Object, model: Model)
	local hook = model.PrimaryPart
	if object.kind ~= "Crate" or not hook then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab scrap"
	prompt.ObjectText = "Raid"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = RaidConfig.GRAB_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	-- The client shows this one to everyone except the owner.
	prompt:SetAttribute("RaiderOnly", true)
	prompt.Parent = hook
	prompt.Triggered:Connect(function(player)
		onGrabTriggered(player, yard, hook)
	end)
end

function RaidService.init()
	for _, yard in PlotService.getYards() do
		gates[yard] = buildGate(yard)
		showGate(yard)
	end
end

function RaidService.start()
	PlotService.forEachThing(onThingBuilt)

	-- The blackout drops every gate; coming out of it the locks work again.
	RoundService.phaseChanged:connect(function(phase)
		for _, yard in PlotService.getYards() do
			if phase == "Blackout" then
				unlockGate(yard)
			else
				showGate(yard)
			end
		end
	end)
	-- A yard changing hands starts with its gate open and its lock ready.
	PlotService.yardReleased:connect(function(_player: Player, yard: PlotService.Yard)
		gates[yard].readyAt = 0
		unlockGate(yard)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local carry = stopCarrying(player)
		if carry then
			returnToOwner(carry.fromUserId, carry.scrap)
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
