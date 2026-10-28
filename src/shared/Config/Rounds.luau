--!strict
--[[
	Rounds config

	The storm round cycle: Calm -> Warning -> Storm -> Results -> Calm.
	Phase lengths are in Config/Game.ROUND_DURATIONS.

	During a storm, raiding is paused and yards are safe: bots never chase
	anyone standing in a yard. Only players fighting outside a yard when the
	storm ends count as survivors, so hiding at home is safe but earns no
	loot.

	ARENA_MODE:
		"Arena"     storm participants are moved to the arena and back
		"WholeMap"  nobody is moved; bots spawn at the arena and roam
]]

local Rounds = {}

export type Phase = "Calm" | "Warning" | "Storm" | "Results"

Rounds.PHASE_ORDER = { "Calm", "Warning", "Storm", "Results" } :: { Phase }

Rounds.ARENA_MODE = "Arena" :: "Arena" | "WholeMap"

-- Placeholder arena, used when the map has no part named Arena.
Rounds.ARENA_CENTER = Vector3.new(0, 1, 0)
Rounds.ARENA_RADIUS = 50

-- Seconds between round-state checks on the server.
Rounds.TICK_SECONDS = 0.2

return Rounds
