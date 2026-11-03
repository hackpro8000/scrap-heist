--!strict
--[[
	Raid config

	How raiding works and the anti-grief rules that keep it fair.
]]

local Raid = {}

-- A grab takes this fraction of the target crate, between the min and max.
Raid.BUNDLE_FRACTION = 0.25
Raid.BUNDLE_MIN = 20
Raid.BUNDLE_MAX = 500

-- A crate holding fewer parts than this can't be raided at all.
Raid.MIN_CRATE_PARTS = 20

-- Walk speed multiplier while carrying a bundle.
Raid.CARRY_SPEED_MULTIPLIER = 0.7

-- Studs: how close a raider must be to the crate (checked on the server).
Raid.GRAB_DISTANCE = 12
-- Studs: how close a player must be to pick up a dropped bundle.
Raid.PICKUP_DISTANCE = 10

-- Seconds a dropped bundle lies on the ground before it returns to the
-- crate it came from.
Raid.DROP_EXPIRE_SECONDS = 30

-- Anti-grief.
-- Seconds a yard can't be raided again after a grab.
Raid.SHIELD_SECONDS = 5 * 60
-- Can't raid a yard this many levels (sum of machine levels) below yours.
Raid.MAX_LEVEL_GAP = 4
-- Damage the yard owner takes while raiders are inside their yard.
Raid.OWNER_DAMAGE_TAKEN_MULTIPLIER = 0.7

-- Seconds between checks for who is standing in which yard.
Raid.YARD_CHECK_INTERVAL = 0.25

return Raid
