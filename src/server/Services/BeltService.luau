--!strict
--[[
	BeltService

	The capsule belt on the Line. The crane drops a capsule on the belt
	every so often (more often on a busy server, and twice as often in a
	storm); each rides one lap and is crushed if nobody buys it. A player
	standing by the belt buys one with scrap and walks off carrying it
	(CapsuleService).

	What a capsule holds is rolled when it drops (Shared/Belt/BeltRules),
	with the luck of the highest-ranked player on the server. Its tier shows
	in its look and label; the junkrot inside doesn't.

	Capsules are anchored parts in workspace.Belt.Capsules. The server moves
	them a few times a second, which is all the buying checks need. Each
	carries its distance along the belt, when that was true and its speed as
	attributes (Distance, DistanceAt in server time, Speed), so clients can
	slide it smoothly in between (BeltController).

	When the map has no belt art (workspace.Map.Belt), a plain placeholder
	belt is laid along the path so the capsules have something to ride.

	Public API:
		BeltService.capsuleBought: Signal(player, capsule)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Belt = require(ReplicatedStorage.Shared.Config.Belt)
local BeltRules = require(ReplicatedStorage.Shared.Belt.BeltRules)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Rounds = require(ReplicatedStorage.Shared.Config.Rounds)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local CapsuleService = require(script.Parent.CapsuleService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local JunkrotRules = require(script.Parent.Parent.Tycoon.JunkrotRules)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RoundService = require(script.Parent.RoundService)

local SYSTEM = "Belt"
-- Only the hub's belt exists so far.
local ZONE = 1
-- Seconds between moves of the capsules on the server.
local MOVE_INTERVAL = 0.2
local BELT_COLOR = Color3.fromRGB(45, 45, 50)
local BELT_THICKNESS = 0.6
-- Pieces in each half-circle turn of the placeholder belt.
local TURN_PIECES = 10

type Riding = {
	capsule: CapsuleService.Capsule,
	body: BasePart,
	distance: number,
	price: number,
}

local BeltService = {}

BeltService.capsuleBought = Signal.new()

local riding: { [Riding]: boolean } = {}
local capsulesFolder: Folder
local random = Random.new()
local sinceSpawn = 0

local function isStorm(): boolean
	return Rounds.isStorm(RoundService.getPhase())
end

local function highestRank(): number
	local rank = 0
	for _, player in Players:GetPlayers() do
		local data = DataService.getData(player)
		if data then
			rank = math.max(rank, data.rank)
		end
	end

	return rank
end

local function beltCFrame(distance: number, height: number): CFrame
	local x, z, headingX, headingZ = BeltRules.pointAt(distance)
	local position = Vector3.new(x, height, z)
	return CFrame.lookAt(position, position + Vector3.new(headingX, 0, headingZ))
end

local function stamp(ride: Riding)
	ride.body:SetAttribute("Distance", ride.distance)
	ride.body:SetAttribute("DistanceAt", workspace:GetServerTimeNow())
	ride.body:SetAttribute("Speed", BeltRules.speed(isStorm()))
end

local function remove(ride: Riding)
	riding[ride] = nil
	ride.body:Destroy()
end

local function onBuyTriggered(player: Player, ride: Riding)
	if not riding[ride] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- SECURITY: re-check distance; prompt presses can be faked.
	if
		not root
		or not root:IsA("BasePart")
		or (root.Position - ride.body.Position).Magnitude > Belt.BUY_DISTANCE + 8
	then
		RemoteGuard.reject(SYSTEM, "TooFar")
		return
	end
	if not CapsuleService.canCarry(player) then
		Notify.Message:FireClient(player, "Your hands are full")
		return
	end
	if not DataService.trySpend(player, ride.price) then
		Notify.Message:FireClient(player, `You need {Format.short(ride.price)} scrap`)
		return
	end

	-- DUPE-SAFE: off the belt before it is in the buyer's hands, so two
	-- presses in one frame can't both take it.
	remove(ride)
	if not CapsuleService.give(player, ride.capsule) then
		DataService.addScrap(player, ride.price)
		return
	end
	Notify.Sound:FireClient(player, "Purchase")
	Notify.Message:FireClient(player, "Carry it to your build bay. Don't get hit!")
	BeltService.capsuleBought:fire(player, ride.capsule)
end

local function drop(capsule: CapsuleService.Capsule)
	local body = CapsuleService.newBody(capsule)
	body.Anchored = true
	body.CFrame = beltCFrame(0, Belt.HEIGHT + body.Size.Y / 2)

	local ride: Riding = {
		capsule = capsule,
		body = body,
		distance = 0,
		price = JunkrotRules.capsulePrice(capsule.junkrot),
	}
	riding[ride] = true
	stamp(ride)

	local text = body:FindFirstChild("Text", true) :: TextLabel
	local info = Junkrots.TIER_INFO[capsule.tier]
	local limited = if capsule.limited then "LIMITED " else ""
	text.Text = `{limited}{capsule.tier}\n{Format.short(ride.price)} scrap`

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = `{info.capsule} · {Format.short(ride.price)} scrap`
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = Belt.BUY_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = body
	prompt.Triggered:Connect(function(player: Player)
		onBuyTriggered(player, ride)
	end)

	body.Parent = capsulesFolder

	if capsule.tier == "Secret" then
		for _, player in Players:GetPlayers() do
			Notify.Message:FireClient(player, "Something unmarked just dropped onto the belt...")
		end
	elseif capsule.tier == "Prototype" or capsule.limited then
		for _, player in Players:GetPlayers() do
			Notify.Message:FireClient(player, `A {limited}{capsule.tier} capsule is on the belt!`)
		end
	end
end

local function dropRolled()
	drop(BeltRules.rollCapsule(function()
		return random:NextNumber()
	end, ZONE, highestRank(), isStorm()))
end

local function move(deltaTime: number)
	local speed = BeltRules.speed(isStorm())
	local lap = BeltRules.lapLength()
	for ride in riding do
		ride.distance += speed * deltaTime
		if ride.distance >= lap then
			-- Nobody bought it: the crusher at the end of the lap takes it.
			remove(ride)
		else
			ride.body.CFrame = beltCFrame(ride.distance, Belt.HEIGHT + ride.body.Size.Y / 2)
		end
	end
end

local function beltPiece(length: number, cframe: CFrame, parent: Instance)
	local piece = Instance.new("Part")
	piece.Name = "Belt"
	piece.Size = Vector3.new(Belt.WIDTH, BELT_THICKNESS, length)
	piece.CFrame = cframe
	piece.Color = BELT_COLOR
	piece.Material = Enum.Material.DiamondPlate
	piece.Anchored = true
	piece.Parent = parent
end

-- A plain belt along the path: a long piece per straight and short ones
-- round the turns.
local function buildPlaceholderBelt(parent: Instance)
	local height = Belt.HEIGHT - BELT_THICKNESS / 2
	local straight = 2 * Belt.STRAIGHT_HALF_LENGTH
	local turn = math.pi * Belt.TURN_RADIUS
	local step = turn / TURN_PIECES

	beltPiece(straight, beltCFrame(straight / 2, height), parent)
	beltPiece(straight, beltCFrame(straight + turn + straight / 2, height), parent)
	for _, start in { straight, 2 * straight + turn } do
		for piece = 1, TURN_PIECES do
			-- A little overlap hides the wedge gaps on the outside of the turn.
			beltPiece(step * 1.35, beltCFrame(start + (piece - 0.5) * step, height), parent)
		end
	end
end

function BeltService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Belt"
	folder.Parent = workspace

	capsulesFolder = Instance.new("Folder")
	capsulesFolder.Name = "Capsules"
	capsulesFolder.Parent = folder

	local map = workspace:FindFirstChild("Map")
	if not (map and map:FindFirstChild("Belt")) then
		buildPlaceholderBelt(folder)
	end

	DebugService.register("drop", "/drop [junkrot id]", function(_player, args)
		local junkrot = Junkrots.BY_ID[args[1] or ""]
		if junkrot then
			drop({ junkrot = junkrot.id, tier = junkrot.tier, limited = args[2] == "limited", storm = false })
		else
			dropRolled()
		end
		return "Dropped a capsule on the belt"
	end)
end

function BeltService.start()
	-- A storm changes the belt's speed: tell clients where every capsule
	-- is now, at the new speed.
	RoundService.phaseChanged:connect(function()
		for ride in riding do
			stamp(ride)
		end
	end)

	local sinceMove = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceMove += deltaTime
		sinceSpawn += deltaTime
		if sinceMove >= MOVE_INTERVAL then
			move(sinceMove)
			sinceMove = 0
		end

		local players = #Players:GetPlayers()
		if players > 0 and sinceSpawn >= BeltRules.spawnSeconds(players, isStorm()) then
			sinceSpawn = 0
			dropRolled()
		end
	end)
end

return BeltService
