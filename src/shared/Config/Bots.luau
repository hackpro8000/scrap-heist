--!strict
--[[
	Bots config

	Scrap bot types (matching the bot art: Scrapper, Bruiser, Zapper), how
	waves grow with the round number, and AI tuning. Each bot type fights
	with a weapon from WeaponConfig, so bots use the same combat rules as
	players.
]]

local Bots = {}

export type BotType = {
	weapon: string,
	maxHealth: number,
	walkSpeed: number,
	-- Placeholder body size; also sizes the pathfinding agent.
	size: Vector3,
	color: Color3,
	-- Studs: swings when the target is this close.
	attackRange: number,
	-- Below this fraction of health the bot retreats once (0 = never).
	retreatHealthFraction: number,
}

Bots.Types = {
	-- Fast and weak: rushes in, dies quickly.
	Scrapper = {
		weapon = "Saw",
		maxHealth = 40,
		walkSpeed = 20,
		size = Vector3.new(2, 2.5, 2),
		color = Color3.fromRGB(170, 90, 60),
		attackRange = 4.5,
		retreatHealthFraction = 0,
	},
	-- Slow tank with big, parryable slams.
	Bruiser = {
		weapon = "Slam",
		maxHealth = 220,
		walkSpeed = 10,
		size = Vector3.new(4, 5, 3),
		color = Color3.fromRGB(110, 90, 70),
		attackRange = 6.5,
		retreatHealthFraction = 0,
	},
	-- Ranged: zaps from a distance, backs off when hurt.
	Zapper = {
		weapon = "Zap",
		maxHealth = 60,
		walkSpeed = 14,
		size = Vector3.new(2, 4.5, 2),
		color = Color3.fromRGB(80, 120, 170),
		attackRange = 26,
		retreatHealthFraction = 0.35,
	},
} :: { [string]: BotType }

-- Most bots alive at once.
Bots.MAX_ACTIVE = 30
-- Bots built up front so the first wave doesn't stutter.
Bots.POOL_PREWARM = 12

-- Waves: one at storm start, then every WAVE_INTERVAL seconds.
Bots.WAVE_INTERVAL = 20
-- Counts per wave are base + perRound * (round - 1) + perWave * (wave - 1).
Bots.WAVE_GROWTH = {
	Scrapper = { base = 4, perRound = 1, perWave = 1 },
	Bruiser = { base = 0, perRound = 0.5, perWave = 0.5 },
	Zapper = { base = 1, perRound = 0.5, perWave = 0.5 },
} :: { [string]: { base: number, perRound: number, perWave: number } }

-- AI tuning.
Bots.THINK_INTERVAL = 0.2
-- Studs: bots ignore players further than this.
Bots.AGGRO_RANGE = 150
-- Each point of damage a player deals to a bot counts as this many studs
-- closer when the bot picks a target, so bots turn on whoever hurts them.
Bots.THREAT_STUDS_PER_DAMAGE = 1.5
-- Threat fades by this fraction per second.
Bots.THREAT_DECAY_PER_SECOND = 0.1
Bots.RETREAT_SECONDS = 4
-- Within this range and with a clear line, chase directly without a path.
Bots.DIRECT_CHASE_RANGE = 14
-- Seconds between path recomputes per bot, at most.
Bots.PATH_RECOMPUTE_INTERVAL = 1
-- Studs the target must move before a fresh path is worth computing.
Bots.PATH_TARGET_MOVE_THRESHOLD = 6
-- Studs to a waypoint that count as reached.
Bots.WAYPOINT_REACHED_DISTANCE = 3
-- Stuck handling: moved less than STUCK_DISTANCE in STUCK_SECONDS -> jump
-- and repath; still stuck after UNSTICK_SECONDS -> hop forward.
Bots.STUCK_DISTANCE = 1
Bots.STUCK_SECONDS = 1.5
Bots.UNSTICK_SECONDS = 4

-- Studs from the arena centre where waves spawn.
Bots.SPAWN_RADIUS = 40

return Bots
