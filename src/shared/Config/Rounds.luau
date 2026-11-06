--!strict
--[[
	Rounds config

	The storm round cycle: Calm -> Warning -> Storm -> Blackout -> Calm.
	Phase lengths are in Config/Game.ROUND_DURATIONS. What a storm does is
	in Config/Storm.

	Storm and Blackout are both "the storm": the belt runs rich and fast,
	parts rain and lightning strikes. The Blackout is its last stretch,
	when every yard's gate opens and crates give double.
]]

local Rounds = {}

export type Phase = "Calm" | "Warning" | "Storm" | "Blackout"

Rounds.PHASE_ORDER = { "Calm", "Warning", "Storm", "Blackout" } :: { Phase }

-- Seconds between round-state checks on the server.
Rounds.TICK_SECONDS = 0.2

function Rounds.isStorm(phase: Phase): boolean
	return phase == "Storm" or phase == "Blackout"
end

return Rounds
