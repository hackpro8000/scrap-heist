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

Juice.DAMAGE_NUMBERS = true
Juice.DAMAGE_NUMBER_SECONDS = 0.8

-- Panels pop open instead of appearing instantly.
Juice.UI_TWEENS = true
Juice.POP_SECONDS = 0.15

return Juice
