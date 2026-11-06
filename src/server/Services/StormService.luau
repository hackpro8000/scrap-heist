--!strict
--[[
	StormService

	What a storm does out on the Line (Config/Storm), for as long as
	RoundService says it is Storm or Blackout:

	- Parts rain: pickups land on the walkways. Walking into one takes it;
	  it pays more at higher ranks. Parts buy junkrot stars.
	- Lightning: a warning ring shows on the ground, then the bolt lands.
	  Anyone in the ring is stunned, hurt a little, and drops their capsule.
	  Strikes aim at players out on the Line, mostly those carrying a
	  capsule. Yards are safe.

	The storm's other halves live with what they change: BeltService runs
	the belt fast and rich, and RaidService drops the gates and doubles
	crate grabs in the blackout. This service also tells players what is
	coming as each phase starts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Rounds = require(ReplicatedStorage.Shared.Config.Rounds)
local Storm = require(ReplicatedStorage.Shared.Config.Storm)

local CapsuleService = require(script.Parent.CapsuleService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RoundService = require(script.Parent.RoundService)
local StormRules = require(script.Parent.Parent.Rounds.StormRules)

local PART_COLOR = Color3.fromRGB(120, 220, 255)
local WARNING_COLOR = Color3.fromRGB(255, 230, 90)
local BOLT_COLOR = Color3.fromRGB(235, 245, 255)
local BOLT_HEIGHT = 120
local BOLT_SECONDS = 0.25
-- How far below a character's middle the ground is.
local ROOT_HEIGHT = 3
-- Parts rain on the walkways, clear of the belt's bed down the middle.
local BED_HALF_WIDTH = 28

local PHASE_MESSAGES = {
	Warning = "A scrap storm is coming! The belt is about to run rich",
	Storm = "SCRAP STORM! Better capsules, parts from the sky. Watch for lightning!",
	Blackout = "BLACKOUT! Every gate is open and crates give double",
	Calm = "The storm has passed",
} :: { [string]: string }

local StormService = {}

local folder: Folder
local random = Random.new()
local sinceDrop = 0
local sinceStrike = 0

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function randomLineSpot(): Vector3
	local side = if random:NextNumber() < 0.5 then -1 else 1
	return Vector3.new(
		random:NextNumber(-Storm.LINE_HALF_LENGTH, Storm.LINE_HALF_LENGTH),
		Storm.LINE_HEIGHT,
		side * random:NextNumber(BED_HALF_WIDTH, Storm.LINE_HALF_WIDTH)
	)
end

local function dropParts()
	local pickup = Instance.new("Part")
	pickup.Name = "PartsPickup"
	pickup.Shape = Enum.PartType.Ball
	pickup.Size = Vector3.one * 1.6
	pickup.Position = randomLineSpot() + Vector3.new(0, 1.2, 0)
	pickup.Color = PART_COLOR
	pickup.Material = Enum.Material.Neon
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Parent = folder

	local taken = false
	pickup.Touched:Connect(function(hit: BasePart)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local root = player and aliveRoot(player)
		local data = player and DataService.getData(player)
		-- SECURITY: Touched can be faked by the toucher's client, so the
		-- server checks they are really there.
		if
			taken
			or not player
			or not root
			or not data
			or (root.Position - pickup.Position).Magnitude > Storm.PART_PICKUP_RADIUS + 4
		then
			return
		end

		taken = true
		pickup:Destroy()
		data.parts += StormRules.partsFor(data.rank)
		player:SetAttribute("Parts", data.parts)
		Notify.Sound:FireClient(player, "Collect")
	end)

	task.delay(Storm.PART_DROP_LIFETIME, function()
		pickup:Destroy()
	end)
end

-- Players out on the Line, split into those carrying a capsule and the rest.
local function targets(): ({ Player }, { Player })
	local carriers, others = {}, {}
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root and PlotService.yardAt(root.Position) == nil then
			table.insert(if CapsuleService.isCarrying(player) then carriers else others, player)
		end
	end

	return carriers, others
end

local function land(ground: Vector3)
	local bolt = Instance.new("Part")
	bolt.Name = "Bolt"
	bolt.Size = Vector3.new(1.2, BOLT_HEIGHT, 1.2)
	bolt.Position = ground + Vector3.new(0, BOLT_HEIGHT / 2, 0)
	bolt.Color = BOLT_COLOR
	bolt.Material = Enum.Material.Neon
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.Parent = folder
	task.delay(BOLT_SECONDS, function()
		bolt:Destroy()
	end)

	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		local character = player.Character
		if not root or not character then
			continue
		end
		local offset = root.Position - ground
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		-- Yards are safe, even at the edge of a ring.
		if flat <= Storm.STRIKE_RADIUS and PlotService.yardAt(root.Position) == nil then
			CombatService.stun(character, Storm.STRIKE_STUN)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(Storm.STRIKE_DAMAGE)
			end
			CapsuleService.knock(player)
			Notify.Message:FireClient(player, "Struck by lightning!")
		end
	end
end

local function strike()
	local carriers, others = targets()
	local target = StormRules.pickTarget(random:NextNumber(), random:NextNumber(), carriers, others)
	local root = target and aliveRoot(target)

	local ground: Vector3
	if root then
		local angle = random:NextNumber(0, math.pi * 2)
		local scatter = random:NextNumber(0, Storm.STRIKE_SCATTER)
		ground = root.Position + Vector3.new(math.cos(angle) * scatter, -ROOT_HEIGHT, math.sin(angle) * scatter)
	else
		ground = randomLineSpot()
	end

	-- A cylinder lies along X, so turn it to lie flat as a ring on the ground.
	local ring = Instance.new("Part")
	ring.Name = "StrikeWarning"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, Storm.STRIKE_RADIUS * 2, Storm.STRIKE_RADIUS * 2)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = WARNING_COLOR
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.45
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = folder

	task.delay(Storm.STRIKE_WARNING, function()
		ring:Destroy()
		if Rounds.isStorm(RoundService.getPhase()) then
			land(ground)
		end
	end)
end

function StormService.init()
	folder = Instance.new("Folder")
	folder.Name = "Storm"
	folder.Parent = workspace
end

function StormService.start()
	RoundService.phaseChanged:connect(function(phase: Rounds.Phase)
		local message = PHASE_MESSAGES[phase]
		-- The first Calm of a server isn't the end of any storm.
		if message and not (phase == "Calm" and RoundService.getRound() == 0) then
			for _, player in Players:GetPlayers() do
				Notify.Message:FireClient(player, message)
			end
		end
		if not Rounds.isStorm(phase) then
			folder:ClearAllChildren()
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		if not Rounds.isStorm(RoundService.getPhase()) then
			sinceDrop, sinceStrike = 0, 0
			return
		end

		sinceDrop += deltaTime
		sinceStrike += deltaTime
		if sinceDrop >= Storm.PART_DROP_SECONDS then
			sinceDrop = 0
			dropParts()
		end
		if sinceStrike >= Storm.STRIKE_SECONDS then
			sinceStrike = 0
			strike()
		end
	end)
end

return StormService
