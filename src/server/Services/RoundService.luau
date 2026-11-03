--!strict
--[[
	RoundService

	Runs the storm cycle for the whole server forever:
		Calm -> Warning -> Storm -> Results -> Calm ...

	The phase is always worked out from one start time (Rounds/RoundClock),
	never counted down, so the cycle can't drift or overlap. Every phase
	change is broadcast with its end time in server-clock time
	(workspace:GetServerTimeNow), so every client's countdown agrees.
	Players who join mid-round ask for the current state when they start.

	During a storm:
	- everyone alive is a participant; dying knocks you out
	- in "Arena" mode participants are moved to the arena, and home after
	- raiding is paused (RaidService listens to phaseChanged)
	- bots spawn (BotService) and never chase anyone standing in a yard
	When it ends, participants still alive and outside a yard are the
	survivors; LootService rewards them.

	Public API:
		RoundService.getPhase(): Phase
		RoundService.getRound(): number          -- storms started so far
		RoundService.isParticipant(player): boolean
		RoundService.arenaCenter(): Vector3
		RoundService.skipTo(phase)               -- showcase / debug
		RoundService.phaseChanged: Signal(phase, round)
		RoundService.stormEnded: Signal(survivors, round)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local Remotes = require(ReplicatedStorage.Shared.Net.Round)
local Rounds = require(ReplicatedStorage.Shared.Config.Rounds)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RoundClock = require(script.Parent.Parent.Rounds.RoundClock)

local SYSTEM = "Round"
local REQUEST_RATE = 1
local ARENA_COLOR = Color3.fromRGB(85, 80, 75)
-- Participants are spread on a circle this fraction of the arena radius.
local ARENA_SPAWN_FRACTION = 0.6

local RoundService = {}

RoundService.phaseChanged = Signal.new()
RoundService.stormEnded = Signal.new()

local cycleStartedAt = 0
local current: RoundClock.State? = nil
local round = 0
local participants: { [Player]: boolean } = {}
local stormTrove = Trove.new()
local arenaCenter = Rounds.ARENA_CENTER
local arenaRadius = Rounds.ARENA_RADIUS

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function countParticipants(): number
	local count = 0
	for _ in participants do
		count += 1
	end

	return count
end

local function stateMessage(): { [string]: any }
	local state = current :: RoundClock.State
	return {
		phase = state.phase,
		round = round,
		-- os.clock differs per machine, so convert to the shared server clock.
		endsAt = workspace:GetServerTimeNow() + (state.phaseEndsAt - os.clock()),
		survivorsLeft = if state.phase == "Storm" then countParticipants() else 0,
	}
end

local function broadcast()
	if current then
		Remotes.RoundState:FireAllClients(stateMessage())
	end
end

local function ensureArena()
	local existing = workspace:FindFirstChild("Arena")
	if existing and existing:IsA("BasePart") then
		arenaCenter = existing.Position + Vector3.new(0, existing.Size.Y / 2, 0)
		arenaRadius = math.min(existing.Size.X, existing.Size.Z) / 2
		return
	end

	-- A cylinder lies along X, so turn it to stand flat like a disc.
	local disc = Instance.new("Part")
	disc.Name = "Arena"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(1, arenaRadius * 2, arenaRadius * 2)
	disc.CFrame = CFrame.new(arenaCenter - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = ARENA_COLOR
	disc.Anchored = true
	disc.TopSurface = Enum.SurfaceType.Smooth
	disc.Parent = workspace
end

local function arenaSpot(index: number, count: number): CFrame
	local angle = (index - 1) / math.max(1, count) * math.pi * 2
	local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * arenaRadius * ARENA_SPAWN_FRACTION
	local position = arenaCenter + offset + Vector3.new(0, 3, 0)

	return CFrame.lookAt(position, Vector3.new(arenaCenter.X, position.Y, arenaCenter.Z))
end

local function startStorm()
	participants = {}
	stormTrove:clean()

	local moving: { Player } = {}
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and DataService.isLoaded(player) then
			participants[player] = true
			table.insert(moving, player)
			stormTrove:connect(humanoid.Died, function()
				if participants[player] then
					participants[player] = nil
					broadcast()
				end
			end)
		end
	end

	if Rounds.ARENA_MODE == "Arena" then
		for index, player in moving do
			local character = player.Character
			if character then
				character:PivotTo(arenaSpot(index, #moving))
			end
		end
	end
end

local function endStorm()
	local survivors: { Player } = {}
	for player in participants do
		local root = aliveRoot(player)
		-- Hiding in a yard keeps you safe but doesn't count as surviving.
		if player.Parent == Players and root and PlotService.yardAt(root.Position) == nil then
			table.insert(survivors, player)
		end
	end
	participants = {}
	stormTrove:clean()

	if Rounds.ARENA_MODE == "Arena" then
		for _, player in Players:GetPlayers() do
			local yard = PlotService.yardOf(player)
			if yard and aliveRoot(player) and player.Character then
				player.Character:PivotTo(PlotService.spawnCFrame(yard))
			end
		end
	end

	RoundService.stormEnded:fire(survivors, round)
end

local function transition(state: RoundClock.State)
	local previous = current and current.phase
	current = state

	if state.phase == "Storm" then
		-- Counted at the storm itself, not the warning, so jumping straight
		-- to a storm (showcase mode) still gets a fresh round number.
		round += 1
		startStorm()
	elseif previous == "Storm" then
		endStorm()
	end

	RoundService.phaseChanged:fire(state.phase, round)
	broadcast()
end

local function tick()
	local state = RoundClock.stateAt(cycleStartedAt, os.clock(), Game.ROUND_DURATIONS, Rounds.PHASE_ORDER)
	if not current or state.phase ~= current.phase or state.cycle ~= current.cycle then
		transition(state)
	end
end

function RoundService.getPhase(): Rounds.Phase
	return (if current then current.phase else "Calm") :: Rounds.Phase
end

function RoundService.getRound(): number
	return round
end

function RoundService.isParticipant(player: Player): boolean
	return participants[player] == true
end

function RoundService.arenaCenter(): Vector3
	return arenaCenter
end

function RoundService.skipTo(phase: Rounds.Phase)
	cycleStartedAt = RoundClock.startForPhase(phase, os.clock(), Game.ROUND_DURATIONS, Rounds.PHASE_ORDER)
	tick()
end

function RoundService.init()
	ensureArena()

	DebugService.register("storm", "/storm", function()
		RoundService.skipTo("Storm")
		return "Storm started"
	end)
	DebugService.register("phase", "/phase <Calm|Warning|Storm|Results>", function(_player, args)
		local phase = args[1]
		if not table.find(Rounds.PHASE_ORDER, phase) then
			return "Usage: /phase Calm|Warning|Storm|Results"
		end
		RoundService.skipTo(phase :: Rounds.Phase)
		return `Now in {phase}`
	end)
end

function RoundService.start()
	RemoteGuard.listen(SYSTEM, Remotes.RequestRoundState, REQUEST_RATE, function(player: Player)
		if current then
			Remotes.RoundState:FireClient(player, stateMessage())
		end
		return nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		if participants[player] then
			participants[player] = nil
			broadcast()
		end
	end)

	cycleStartedAt = os.clock()
	task.spawn(function()
		while true do
			tick()
			task.wait(Rounds.TICK_SECONDS)
		end
	end)
end

return RoundService
