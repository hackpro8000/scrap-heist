--!strict
--[[
	BotService

	Scrap bots for storm rounds: spawning in waves, thinking, moving and
	fighting, and cleaning up when the storm ends.

	- Pooled: bot models are built once and reused. A "dead" bot goes back
	  to the pool instead of being destroyed, so waves don't stutter from
	  building models mid-fight. Humanoid death is switched off on bots for
	  this; BotService handles health reaching zero itself.
	- Capped at Bots.MAX_ACTIVE alive at once.
	- Brain: Bots/BotBrain decides Idle -> Chase -> Attack -> Retreat and
	  picks targets by distance and threat (damage dealt to it).
	- Movement: PathfindingService, recomputed at most once a second per
	  bot and only when the target has moved; direct chase when close.
	  Stuck bots jump and repath, then hop forward.
	- Fighting: bots are CombatService fighters and swing with the same
	  combat rules as players.
	- Yards are safe: bots ignore anyone standing in a yard.

	Public API:
		BotService.spawn(typeName, position): Model?
		BotService.clearAll()
		BotService.activeCount(): number
		BotService.botDestroyed: Signal(model, typeName)
		BotService.pathComputed: Signal(model, waypoints)   -- debug overlay
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local WeaponConfig = require(ReplicatedStorage.Shared.Combat.WeaponConfig)

local BotBrain = require(script.Parent.Parent.Bots.BotBrain)
local CombatService = require(script.Parent.CombatService)
local DebugService = require(script.Parent.DebugService)
local NpcRig = require(script.Parent.Parent.Npc.NpcRig)
local PlotService = require(script.Parent.PlotService)
local RoundService = require(script.Parent.RoundService)
local WaveRules = require(script.Parent.Parent.Bots.WaveRules)

local SPEED_KEY = "BotType"
-- Studs a retreating bot aims to put between itself and its target.
local RETREAT_DISTANCE = 20
-- Studs a stuck bot hops toward its next waypoint.
local HOP_DISTANCE = 4

type Bot = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	typeName: string,
	botType: BotsConfig.BotType,
	state: BotBrain.State,
	memory: BotBrain.Memory,
	threat: { [Player]: number },
	waypoints: { PathWaypoint }?,
	waypointIndex: number,
	lastPathAt: number,
	lastPathTarget: Vector3?,
	computingPath: boolean,
	trove: Trove.Trove,
}

local BotService = {}

BotService.botDestroyed = Signal.new()
BotService.pathComputed = Signal.new()

local active: { [Model]: Bot } = {}
local pools: { [string]: { Model } } = {}
local poolFolder: Folder
local activeFolder: Folder
local agentParams: { [string]: { [string]: any } } = {}
local stormToken = 0

local function count(): number
	local total = 0
	for _ in active do
		total += 1
	end

	return total
end

local function buildBot(typeName: string): Model
	local botType = BotsConfig.Types[typeName]
	local model = NpcRig.build(typeName, {
		size = botType.size,
		color = botType.color,
		maxHealth = botType.maxHealth,
	})
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	-- Pooled bots must never truly die: a Humanoid that enters the Dead
	-- state can't be revived. BotService treats 0 health as death instead.
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	model:SetAttribute("IsBot", true)
	model:SetAttribute("BotType", typeName)
	model.Parent = poolFolder

	return model
end

local function acquire(typeName: string): Model
	local pool = pools[typeName]
	if pool and #pool > 0 then
		return table.remove(pool) :: Model
	end

	return buildBot(typeName)
end

local function release(bot: Bot)
	if active[bot.model] ~= bot then
		return
	end

	active[bot.model] = nil
	bot.trove:destroy()
	CombatService.unregister(bot.model)
	bot.model:SetAttribute("BotState", nil)
	bot.model.Parent = poolFolder

	pools[bot.typeName] = pools[bot.typeName] or {}
	table.insert(pools[bot.typeName], bot.model)
end

function BotService.spawn(typeName: string, position: Vector3): Model?
	local botType = BotsConfig.Types[typeName]
	if not botType or count() >= BotsConfig.MAX_ACTIVE then
		return nil
	end

	local model = acquire(typeName)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.Health = humanoid.MaxHealth

	model:PivotTo(CFrame.new(position + Vector3.new(0, botType.size.Y / 2 + 1, 0)))
	model.Parent = activeFolder
	-- SECURITY: the server simulates bots, so no client can move them.
	root:SetNetworkOwner(nil)

	CombatService.register(model, botType.weapon)
	CombatService.setSpeedMultiplier(model, SPEED_KEY, botType.walkSpeed / WeaponConfig.Combat.walkSpeed.normal)

	local bot: Bot = {
		model = model,
		humanoid = humanoid,
		root = root,
		typeName = typeName,
		botType = botType,
		state = "Idle",
		memory = BotBrain.newMemory(),
		threat = {},
		waypoints = nil,
		waypointIndex = 1,
		lastPathAt = 0,
		lastPathTarget = nil,
		computingPath = false,
		trove = Trove.new(),
	}
	active[model] = bot

	bot.trove:connect(humanoid.HealthChanged, function(health)
		if health <= 0 then
			release(bot)
			BotService.botDestroyed:fire(model, typeName)
		end
	end)

	return model
end

function BotService.clearAll()
	for _, bot in active do
		release(bot)
	end
end

function BotService.activeCount(): number
	return count()
end

local function candidatesFor(bot: Bot): { BotBrain.Candidate }
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- Yards are safe during storms: bots ignore anyone standing in one.
		if humanoid and humanoid.Health > 0 and root and PlotService.yardAt(root.Position) == nil then
			table.insert(candidates, {
				id = player,
				position = root.Position,
				threat = bot.threat[player] or 0,
			})
		end
	end

	return candidates
end

local function requestPath(bot: Bot, target: Vector3, now: number)
	if bot.computingPath or now - bot.lastPathAt < BotsConfig.PATH_RECOMPUTE_INTERVAL then
		return
	end
	local last = bot.lastPathTarget
	if bot.waypoints and last and (last - target).Magnitude < BotsConfig.PATH_TARGET_MOVE_THRESHOLD then
		return
	end

	bot.computingPath = true
	bot.lastPathAt = now
	bot.lastPathTarget = target

	task.spawn(function()
		local path = PathfindingService:CreatePath(agentParams[bot.typeName])
		local ok = pcall(function()
			path:ComputeAsync(bot.root.Position, target)
		end)
		bot.computingPath = false
		if active[bot.model] ~= bot then
			return
		end

		if ok and path.Status == Enum.PathStatus.Success then
			bot.waypoints = path:GetWaypoints()
			-- Waypoint 1 is where the bot already stands.
			bot.waypointIndex = 2
			BotService.pathComputed:fire(bot.model, bot.waypoints)
		else
			bot.waypoints = nil
		end
	end)
end

local function followPath(bot: Bot, target: Vector3)
	local waypoints = bot.waypoints
	local waypoint = waypoints and waypoints[bot.waypointIndex]
	if not waypoint then
		-- No path (yet, or it failed): head straight for the target.
		bot.humanoid:MoveTo(target)
		return
	end

	local flat = Vector3.new(1, 0, 1)
	if ((waypoint.Position - bot.root.Position) * flat).Magnitude <= BotsConfig.WAYPOINT_REACHED_DISTANCE then
		bot.waypointIndex += 1
		waypoint = (waypoints :: { PathWaypoint })[bot.waypointIndex]
		if not waypoint then
			bot.humanoid:MoveTo(target)
			return
		end
	end

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		bot.humanoid.Jump = true
	end
	bot.humanoid:MoveTo(waypoint.Position)
end

local function unstick(bot: Bot, target: Vector3, now: number)
	local result = BotBrain.checkStuck(bot.memory, bot.root.Position, bot.state == "Chase", now)
	if result == "Jump" then
		bot.humanoid.Jump = true
		-- Force a fresh path next think.
		bot.lastPathAt = 0
		bot.waypoints = nil
	elseif result == "Hop" then
		local waypoints = bot.waypoints
		local next = waypoints and waypoints[bot.waypointIndex]
		local toward = if next then next.Position else target
		local direction = (toward - bot.root.Position) * Vector3.new(1, 0, 1)
		if direction.Magnitude > 0.1 then
			bot.root.CFrame += direction.Unit * HOP_DISTANCE + Vector3.new(0, 2, 0)
		end
	end
end

local function faceToward(bot: Bot, target: Vector3)
	local position = bot.root.Position
	bot.root.CFrame = CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
end

local function think(bot: Bot, now: number, deltaTime: number)
	-- Old grudges fade, so bots don't chase one player forever.
	local decay = math.max(0, 1 - BotsConfig.THREAT_DECAY_PER_SECOND * deltaTime)
	for player, threat in bot.threat do
		bot.threat[player] = if player.Parent then threat * decay else nil
	end

	local targetPlayer = BotBrain.pickTarget(bot.root.Position, candidatesFor(bot)) :: Player?
	local targetRoot = targetPlayer
		and targetPlayer.Character
		and targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetPosition = if targetRoot then targetRoot.Position else bot.root.Position
	local distance = (targetPosition - bot.root.Position).Magnitude

	bot.state = BotBrain.decide(bot.state, bot.memory, {
		hasTarget = targetRoot ~= nil,
		targetDistance = distance,
		healthFraction = bot.humanoid.Health / bot.humanoid.MaxHealth,
	}, bot.botType, now)
	bot.model:SetAttribute("BotState", bot.state)

	if bot.state == "Idle" then
		bot.humanoid:MoveTo(bot.root.Position)
	elseif bot.state == "Attack" then
		bot.humanoid:MoveTo(bot.root.Position)
		faceToward(bot, targetPosition)
		CombatService.attack(bot.model)
	elseif bot.state == "Retreat" then
		local away = (bot.root.Position - targetPosition) * Vector3.new(1, 0, 1)
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
		bot.humanoid:MoveTo(bot.root.Position + direction * RETREAT_DISTANCE)
	elseif bot.state == "Chase" then
		if distance <= BotsConfig.DIRECT_CHASE_RANGE then
			bot.waypoints = nil
			bot.humanoid:MoveTo(targetPosition)
		else
			requestPath(bot, targetPosition, now)
			followPath(bot, targetPosition)
		end
		unstick(bot, targetPosition, now)
	end
end

local function spawnWave(stormRound: number, wave: number)
	local composition = WaveRules.composition(stormRound, wave, BotsConfig.MAX_ACTIVE - count())
	local center = RoundService.arenaCenter()
	for typeName, amount in composition do
		for _ = 1, amount do
			local angle = math.random() * math.pi * 2
			local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * BotsConfig.SPAWN_RADIUS
			BotService.spawn(typeName, center + offset)
		end
	end
end

local function onPhaseChanged(phase: string, stormRound: number)
	-- Any phase change ends the previous wave loop.
	stormToken += 1
	if phase ~= "Storm" then
		BotService.clearAll()
		return
	end

	local token = stormToken
	task.spawn(function()
		local wave = 1
		while stormToken == token do
			spawnWave(stormRound, wave)
			wave += 1
			task.wait(BotsConfig.WAVE_INTERVAL)
		end
	end)
end

function BotService.init()
	poolFolder = Instance.new("Folder")
	poolFolder.Name = "BotPool"
	poolFolder.Parent = ServerStorage

	activeFolder = Instance.new("Folder")
	activeFolder.Name = "Bots"
	activeFolder.Parent = workspace

	for typeName, botType in BotsConfig.Types do
		agentParams[typeName] = {
			AgentRadius = math.max(botType.size.X, botType.size.Z) / 2 + 0.5,
			AgentHeight = botType.size.Y + 1,
			AgentCanJump = true,
		}
	end

	DebugService.register("spawnbots", "/spawnbots <Scrapper|Bruiser|Zapper> [count]", function(player, args)
		local typeName = args[1]
		local amount = math.clamp(tonumber(args[2]) or 1, 1, BotsConfig.MAX_ACTIVE)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not BotsConfig.Types[typeName] or not root then
			return "Usage: /spawnbots Scrapper|Bruiser|Zapper [count]"
		end

		local spawned = 0
		for index = 1, amount do
			local angle = index / amount * math.pi * 2
			local position = root.Position + Vector3.new(math.sin(angle), 0, math.cos(angle)) * 15
			if BotService.spawn(typeName, position) then
				spawned += 1
			end
		end
		return `Spawned {spawned} {typeName}`
	end)

	DebugService.register("clearbots", "/clearbots", function()
		BotService.clearAll()
		return "Bots cleared"
	end)
end

function BotService.start()
	-- Build a few of each type now, so the first wave reuses them.
	local typeNames = {}
	for typeName in BotsConfig.Types do
		table.insert(typeNames, typeName)
	end
	for index = 1, BotsConfig.POOL_PREWARM do
		local typeName = typeNames[(index - 1) % #typeNames + 1]
		pools[typeName] = pools[typeName] or {}
		table.insert(pools[typeName], buildBot(typeName))
	end

	CombatService.hitLanded:connect(function(attackerModel: Model, targetModel: Model, result)
		local bot = active[targetModel]
		local player = Players:GetPlayerFromCharacter(attackerModel)
		if bot and player then
			bot.threat[player] = (bot.threat[player] or 0) + result.damage
		end
	end)

	RoundService.phaseChanged:connect(onPhaseChanged)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(BotsConfig.THINK_INTERVAL)
			local now = os.clock()
			local deltaTime = now - last
			last = now
			for _, bot in active do
				think(bot, now, deltaTime)
			end
		end
	end)
end

return BotService
