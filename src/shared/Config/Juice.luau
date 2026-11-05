--!strict
--[[
	Juice config

	Feel-good effects on the client. Each one can be switched off on its
	own, for players who prefer less motion and for clean debug clips.
]]

local Juice = {}

Juice.SCREEN_SHAKE = true
-- Studs of camera shake when you're hit, and when you land a hit.
Juice.SHAKE_WHEN_HIT = 0.5
Juice.SHAKE_WHEN_HITTING = 0.15
Juice.SHAKE_SECONDS = 0.2

-- Freezes your own animations for a moment when your hit lands, so hits
-- feel solid.
Juice.HIT_PAUSE = true
Juice.HIT_PAUSE_SECONDS = 0.06
-- Landed hits also freeze the attacker and the target for a few frames
-- (hitstop), on every client.
Juice.HIT_STOP_SECONDS = 0.08

-- A heavy hit (a guard break, or damage at or over HEAVY_DAMAGE) shakes
-- harder and for longer.
Juice.HEAVY_DAMAGE = 25
Juice.SHAKE_HEAVY = 0.9
Juice.HEAVY_SHAKE_SECONDS = 0.3

-- Studs the camera is pushed back when you hit or are hit, settling over
-- NUDGE_SECONDS.
Juice.CAMERA_NUDGE = 2.5
Juice.NUDGE_SECONDS = 0.2

-- The struck body flashes white, sparks fly where the blow lands, and the
-- screen edge flashes red when you're the one hit.
Juice.HIT_FLASH = true
Juice.HIT_SPARKS = 14
Juice.RED_EDGE_SECONDS = 0.35

Juice.DAMAGE_NUMBERS = true
Juice.DAMAGE_NUMBER_SECONDS = 0.8

-- Scrap flying out of the crate into the player when they collect it: a
-- few pieces from a nearly empty crate, up to COLLECT_PIECES_MAX from a
-- full one, launched COLLECT_PIECE_GAP seconds apart.
Juice.COLLECT_PIECES_MIN = 3
Juice.COLLECT_PIECES_MAX = 20
Juice.COLLECT_PIECE_GAP = 0.06

function Juice.collectPieces(fill: number): number
	local span = Juice.COLLECT_PIECES_MAX - Juice.COLLECT_PIECES_MIN
	return Juice.COLLECT_PIECES_MIN + math.floor(math.clamp(fill, 0, 1) * span + 0.5)
end

-- Panels pop open instead of appearing instantly.
Juice.UI_TWEENS = true
Juice.POP_SECONDS = 0.15

return Juice
