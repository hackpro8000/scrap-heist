--!strict
--[[
	CapsuleService

	Everything that happens to a capsule once it leaves the belt.

	Carry: the buyer (BeltService hands it over with give) carries the
	capsule in front of them, slowed. A landed blow knocks it out of their
	hands, as does dying, leaving, or lightning (StormService calls knock).

	Drop: a knocked-out capsule lies where it fell. Anyone with a yard can
	pick it up after a moment; left too long it is lost.

	Bay: a carrier who walks up to an empty build bay in their own yard
	loads the capsule into it. It hatches there over time, faster while the
	owner whacks it, and is saved with the yard until it does. Until then a
	raider standing in the yard can steal it out of the bay.

	Hatch: the junkrot inside goes to JunkrotService.place.

	Players carrying a capsule have the attribute CarryingCapsule (its tier).

	Public API:
		CapsuleService.newBody(capsule): BasePart   -- one part, to carry or stand
		CapsuleService.give(player, capsule): boolean
		CapsuleService.canCarry(player): boolean
		CapsuleService.isCarrying(player): boolean
		CapsuleService.knock(player): boolean       -- true if they dropped one
		CapsuleService.capsuleStolen: Signal(thief, owner, capsule)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Belt = require(ReplicatedStorage.Shared.Config.Belt)
local BeltRules = require(ReplicatedStorage.Shared.Belt.BeltRules)
local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local RaidRemotes = require(ReplicatedStorage.Shared.Net.Raid)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local JunkrotRules = require(script.Parent.Parent.Tycoon.JunkrotRules)
local JunkrotService = require(script.Parent.JunkrotService)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)

local SYSTEM = "Capsule"
local MODELS_FOLDER = "Capsules"
local CARRY_SPEED_KEY = "CarryingCapsule"
local BODY_SIZE = 3
local GOLD = Color3.fromRGB(255, 205, 70)
-- Seconds between checks on carriers and hatching capsules.
local CHECK_INTERVAL = 0.25
-- Studs from a bay's middle within which a carrier loads it.
local LOAD_DISTANCE = 11
-- Seconds one whack keeps a capsule hatching at full speed.
local WHACK_SECONDS = 1.2
local WHACK_COOLDOWN = 0.2
local STEAL_HOLD_SECONDS = 1.5
local STEAL_DISTANCE = 12
-- How far below a character's middle the ground is.
local ROOT_HEIGHT = 3

export type Capsule = BeltRules.Capsule

type Carry = {
	capsule: Capsule,
	trove: Trove.Trove,
	-- So "your bay is busy" is said once per trip home, not every check.
	toldBusy: boolean,
}

type Drop = {
	capsule: Capsule,
	body: BasePart,
}

local CapsuleService = {}

CapsuleService.capsuleStolen = Signal.new()

local carries: { [Player]: Carry } = {}
local drops: { [Drop]: boolean } = {}
-- os.clock() until which each bay's capsule counts as being whacked, and
-- when it was last whacked, by the bay's saved object.
local whackedUntil: { [PlotService.Object]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastWhackAt: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function describe(capsule: Capsule): string
	local name = Junkrots.TIER_INFO[capsule.tier].capsule
	return if capsule.limited then `Limited Edition {name}` else name
end

-- A capsule is one part, so it can ride the belt, be carried, lie on the
-- ground and stand in a bay as a unit: the tier's art from
-- ServerStorage.Capsules welded inside an invisible box, or a plain block
-- in the tier's colour when there's no art.
function CapsuleService.newBody(capsule: Capsule): BasePart
	local info = Junkrots.TIER_INFO[capsule.tier]

	local body = Instance.new("Part")
	body.Name = "Capsule"
	body.Size = Vector3.one * BODY_SIZE
	body.CanCollide = false
	body.Massless = true
	body:SetAttribute("Tier", capsule.tier)
	body:SetAttribute("Limited", capsule.limited)

	local folder = ServerStorage:FindFirstChild(MODELS_FOLDER)
	local template = folder and folder:FindFirstChild(capsule.tier)
	if template and template:IsA("Model") then
		local art = template:Clone()
		local _, size = art:GetBoundingBox()
		body.Size = size
		body.Transparency = 1
		art:PivotTo(body.CFrame * art:GetBoundingBox():ToObjectSpace(art:GetPivot()))
		for _, piece in art:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = false
				piece.CanCollide = false
				piece.CanQuery = false
				piece.Massless = true
				-- A Weld holds the piece at this offset wherever the body
				-- is put; a WeldConstraint would let go of it each time
				-- the body's CFrame is set.
				local weld = Instance.new("Weld")
				weld.Part0 = body
				weld.Part1 = piece
				weld.C0 = body.CFrame:ToObjectSpace(piece.CFrame)
				weld.Parent = piece
			end
		end
		art.Parent = body
	else
		body.Color = info.color
		body.Material = if capsule.limited then Enum.Material.Foil else Enum.Material.Metal
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(7, 0, 1.6, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 1.4, 0)
	gui.MaxDistance = 70
	gui.Adornee = body
	gui.Parent = body
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = if capsule.limited then GOLD else Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Text = `{capsule.tier}\n{describe(capsule)}`
	text.Parent = gui

	return body
end

function CapsuleService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

-- A player needs a yard to take a capsule to, and free hands.
function CapsuleService.canCarry(player: Player): boolean
	return carries[player] == nil
		and player:GetAttribute("CarryingScrap") == nil
		and PlotService.yardOf(player) ~= nil
		and rootOf(player) ~= nil
end

local function stopCarrying(player: Player): Capsule?
	local carry = carries[player]
	if not carry then
		return nil
	end

	carries[player] = nil
	carry.trove:destroy()
	player:SetAttribute("CarryingCapsule", nil)
	if player.Character then
		CombatService.setSpeedMultiplier(player.Character, CARRY_SPEED_KEY, nil)
	end

	return carry.capsule
end

local function spawnDrop(position: Vector3, capsule: Capsule)
	local body = CapsuleService.newBody(capsule)
	body.Anchored = true
	body.Position = position
	body.Parent = workspace

	local drop: Drop = { capsule = capsule, body = body }
	drops[drop] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = describe(capsule)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = Belt.PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Enabled = false
	prompt.Parent = body
	-- A moment's grace, so the one who knocked it loose can't grab it in
	-- the same breath.
	task.delay(Belt.DROP_PICKUP_DELAY, function()
		prompt.Enabled = true
	end)

	prompt.Triggered:Connect(function(player: Player)
		if not drops[drop] then
			return
		end
		local root = rootOf(player)
		-- SECURITY: re-check distance; prompt presses can be faked.
		if not root or (root.Position - body.Position).Magnitude > Belt.PICKUP_DISTANCE + 4 then
			RemoteGuard.reject(SYSTEM, "PickupTooFar")
			return
		end
		if not CapsuleService.canCarry(player) then
			RemoteGuard.reject(SYSTEM, "CantPickUp")
			Notify.Message:FireClient(player, "Your hands are full")
			return
		end

		drops[drop] = nil
		body:Destroy()
		CapsuleService.give(player, capsule)
		Notify.Sound:FireClient(player, "Grab")
	end)

	task.delay(Belt.DROP_EXPIRE_SECONDS, function()
		if drops[drop] then
			drops[drop] = nil
			body:Destroy()
		end
	end)
end

function CapsuleService.knock(player: Player): boolean
	local root = rootOf(player)
	local capsule = stopCarrying(player)
	if not capsule then
		return false
	end
	if root then
		spawnDrop(root.Position - Vector3.new(0, ROOT_HEIGHT - BODY_SIZE / 2, 0), capsule)
	end
	Notify.Message:FireClient(player, "You dropped your capsule!")

	return true
end

function CapsuleService.give(player: Player, capsule: Capsule): boolean
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or not CapsuleService.canCarry(player) then
		return false
	end

	local trove = Trove.new()
	carries[player] = { capsule = capsule, trove = trove, toldBusy = false }
	player:SetAttribute("CarryingCapsule", capsule.tier)
	CombatService.setSpeedMultiplier(character, CARRY_SPEED_KEY, Belt.CARRY_SPEED_MULTIPLIER)
	-- Hands full: the weapon goes away.
	CombatService.unequip(character)

	-- Held out in front, so everyone can see who to chase.
	local body = CapsuleService.newBody(capsule)
	body.CanQuery = false
	body.CFrame = root.CFrame * CFrame.new(0, 0.3, -(root.Size.Z / 2 + body.Size.Z / 2 + 0.4))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	body.Parent = character
	trove:add(body)

	trove:connect(humanoid.Died, function()
		CapsuleService.knock(player)
	end)

	return true
end

local function emptyBayNear(player: Player, yard: PlotService.Yard, position: Vector3): (PlotService.Object?, boolean)
	local anyBay = false
	for _, object in PlotService.objectsOf(player) do
		if object.kind == "Bay" then
			local distance = (PlotService.objectCFrame(yard, object).Position - position).Magnitude
			if distance <= LOAD_DISTANCE then
				anyBay = true
				if not object.capsule then
					return object, true
				end
			end
		end
	end

	return nil, anyBay
end

-- Loads carriers' capsules into their bays when they reach one.
local function checkCarriers()
	for player, carry in carries do
		local root = rootOf(player)
		local yard = PlotService.yardOf(player)
		if not root or not yard or PlotService.yardAt(root.Position) ~= yard then
			carry.toldBusy = false
			continue
		end

		local bay, nearBay = emptyBayNear(player, yard, root.Position)
		if bay then
			local capsule = stopCarrying(player) :: Capsule
			bay.capsule = { junkrot = capsule.junkrot, limited = if capsule.limited then true else nil, progress = 0 }
			PlotService.rebuildThing(yard, bay)
			Notify.Message:FireClient(player, "Capsule loaded. Whack it to hatch it faster!")
			Notify.Sound:FireClient(player, "Collect")
		elseif nearBay and not carry.toldBusy then
			carry.toldBusy = true
			Notify.Message:FireClient(player, "That build bay is busy. Hatch what's in it first")
		end
	end
end

local function hatch(player: Player, yard: PlotService.Yard, bay: PlotService.Object)
	local held = bay.capsule
	if not held then
		return
	end

	-- DUPE-SAFE: the capsule leaves the bay before its junkrot is placed.
	bay.capsule = nil
	PlotService.rebuildThing(yard, bay)
	JunkrotService.place(player, held.junkrot, held.limited == true)
end

local function checkBays(deltaTime: number)
	local now = os.clock()
	for _, yard in PlotService.getYards() do
		local owner = yard.owner
		if not owner then
			continue
		end
		for _, object in PlotService.objectsOf(owner) do
			local held = if object.kind == "Bay" then object.capsule else nil
			if not held then
				continue
			end
			-- A capsule whose junkrot was removed from the game hatches at once.
			local needed = if Junkrots.BY_ID[held.junkrot] then JunkrotRules.hatchSeconds(held.junkrot) else 0
			held.progress += JunkrotRules.hatchProgress(deltaTime, now < (whackedUntil[object] or 0))
			if held.progress >= needed then
				hatch(owner, yard, object)
			else
				local thing = PlotService.thingOf(yard, object.id)
				if thing then
					thing:SetAttribute("Hatch", held.progress / needed)
				end
			end
		end
	end
end

local function onStealTriggered(player: Player, yard: PlotService.Yard, objectId: number)
	local owner = yard.owner
	local root = rootOf(player)
	local bay = owner and PlotService.objectOf(owner, objectId)
	local thing = PlotService.thingOf(yard, objectId)
	local held = bay and bay.capsule
	if not owner or owner == player or not root or not bay or not held or not thing then
		RemoteGuard.reject(SYSTEM, "NoCapsule")
		return
	end
	-- SECURITY: the thief must be standing in the yard, at the bay, with
	-- free hands and a yard of their own, by the server's own reckoning.
	if PlotService.yardAt(root.Position) ~= yard then
		RemoteGuard.reject(SYSTEM, "NotInYard")
		return
	end
	if (root.Position - thing:GetPivot().Position).Magnitude > STEAL_DISTANCE + 6 then
		RemoteGuard.reject(SYSTEM, "TooFar")
		return
	end
	if not CapsuleService.canCarry(player) then
		Notify.Message:FireClient(player, "Your hands are full")
		return
	end

	local junkrot = Junkrots.BY_ID[held.junkrot]
	local capsule: Capsule = {
		junkrot = held.junkrot,
		tier = if junkrot then junkrot.tier else Junkrots.TIERS[1],
		limited = held.limited == true,
		storm = false,
	}
	-- DUPE-SAFE: out of the owner's save before it is in the thief's hands.
	bay.capsule = nil
	PlotService.rebuildThing(yard, bay)
	if not CapsuleService.give(player, capsule) then
		spawnDrop(root.Position, capsule)
	end

	local thiefData = DataService.getData(player)
	if thiefData then
		thiefData.stats.capsulesStolen += 1
	end
	RaidRemotes.Alert:FireClient(owner, "Grabbed", `{player.DisplayName} stole your {describe(capsule)}! Stop them!`)
	Notify.Message:FireClient(player, `Stole a {describe(capsule)}. Get it home!`)
	Notify.Sound:FireClient(player, "Grab")
	CapsuleService.capsuleStolen:fire(player, owner, capsule)
end

-- A bay holding a capsule shows it, with how far along it is, a "Whack"
-- prompt for the owner and a "Steal" prompt for everyone else.
local function onThingBuilt(yard: PlotService.Yard, object: PlotService.Object, model: Model)
	local held = if object.kind == "Bay" then object.capsule else nil
	local hook = model.PrimaryPart
	if not held or not hook then
		return
	end

	local junkrot = Junkrots.BY_ID[held.junkrot]
	local capsule: Capsule = {
		junkrot = held.junkrot,
		tier = if junkrot then junkrot.tier else Junkrots.TIERS[1],
		limited = held.limited == true,
		storm = false,
	}
	local body = CapsuleService.newBody(capsule)
	body.Anchored = true
	-- Its front (the body's -Z) turned to the gate.
	body.CFrame = PlotService.seatOf(model) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, body.Size.Y / 2, 0)
	body.Parent = model

	local text = body:FindFirstChild("Text", true) :: TextLabel
	local function show()
		local done = math.clamp(model:GetAttribute("Hatch") :: number? or 0, 0, 1)
		text.Text = `{describe(capsule)}\nHatching {math.floor(done * 100)}%`
	end
	model:GetAttributeChangedSignal("Hatch"):Connect(show)
	show()

	local whack = Instance.new("ProximityPrompt")
	whack.ActionText = "Whack"
	whack.ObjectText = describe(capsule)
	whack.HoldDuration = 0
	whack.MaxActivationDistance = STEAL_DISTANCE
	whack.RequiresLineOfSight = false
	whack.Style = Enum.ProximityPromptStyle.Custom
	whack:SetAttribute("OwnerOnly", true)
	whack.Parent = body
	whack.Triggered:Connect(function(player: Player)
		if yard.owner ~= player then
			RemoteGuard.reject(SYSTEM, "NotOwner")
			return
		end
		local now = os.clock()
		if now - (lastWhackAt[player] or 0) < WHACK_COOLDOWN then
			return
		end
		lastWhackAt[player] = now
		whackedUntil[object] = now + WHACK_SECONDS
		Notify.Sound:FireClient(player, "Block")
	end)

	local steal = Instance.new("ProximityPrompt")
	steal.ActionText = "Steal"
	steal.ObjectText = describe(capsule)
	steal.HoldDuration = STEAL_HOLD_SECONDS
	steal.MaxActivationDistance = STEAL_DISTANCE
	steal.RequiresLineOfSight = false
	steal.Style = Enum.ProximityPromptStyle.Custom
	-- The client shows this one to everyone except the owner.
	steal:SetAttribute("RaiderOnly", true)
	steal.Parent = body
	steal.Triggered:Connect(function(player: Player)
		onStealTriggered(player, yard, object.id)
	end)
end

function CapsuleService.init()
	DebugService.register("capsule", "/capsule [junkrot id]", function(player, args)
		local junkrot = Junkrots.BY_ID[args[1] or ""] or Junkrots.LIST[1]
		local capsule: Capsule = { junkrot = junkrot.id, tier = junkrot.tier, limited = false, storm = false }
		return if CapsuleService.give(player, capsule) then `Carrying a {describe(capsule)}` else "Your hands are full"
	end)
end

function CapsuleService.start()
	PlotService.forEachThing(onThingBuilt)

	-- A landed blow knocks the capsule out of a carrier's hands.
	CombatService.hitLanded:connect(function(_attacker: Model, target: Model, result: any)
		local player = Players:GetPlayerFromCharacter(target)
		if player and carries[player] and (result.outcome == "Hit" or result.outcome == "GuardBroken") then
			CapsuleService.knock(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastWhackAt[player] = nil
		CapsuleService.knock(player)
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceCheck += deltaTime
		if sinceCheck >= CHECK_INTERVAL then
			checkCarriers()
			checkBays(sinceCheck)
			sinceCheck = 0
		end
	end)
end

return CapsuleService
