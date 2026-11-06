--!strict
--[[
	Storm config

	A storm is weather: it makes the belt richer and the Line dangerous,
	and its last stretch, the blackout, takes every yard's defences down.
	The phases and their lengths are in Config/Rounds and Config/Game.
]]

local Storm = {}

-- Parts rain: a pickup lands every PART_DROP_SECONDS somewhere on the
-- Line's walkways, worth PART_DROP_PARTS, and lies for PART_DROP_LIFETIME.
-- A player who stays out collects about 25 x (1 + 0.15 x rank) a storm:
-- a pickup pays its taker PART_DROP_PARTS x (1 + PARTS_PER_RANK x rank).
Storm.PART_DROP_SECONDS = 1.5
Storm.PART_DROP_PARTS = 2
Storm.PART_DROP_LIFETIME = 20
Storm.PARTS_PER_RANK = 0.15
-- Studs: how close a player must come to take a pickup.
Storm.PART_PICKUP_RADIUS = 5

-- Where parts rain and lightning strikes: the Line's deck, as half its
-- length (along X) and half its width, and the height of its top.
Storm.LINE_HALF_LENGTH = 260
Storm.LINE_HALF_WIDTH = 52
Storm.LINE_HEIGHT = 2

-- Lightning: a strike every STRIKE_SECONDS. A warning ring STRIKE_RADIUS
-- across its middle shows for STRIKE_WARNING seconds, then the bolt lands:
-- anyone inside is knocked down for STRIKE_STUN seconds and drops their
-- capsule. CARRIER_CHANCE of strikes aim at a player carrying one.
Storm.STRIKE_SECONDS = 4
Storm.STRIKE_RADIUS = 5
Storm.STRIKE_WARNING = 1
Storm.STRIKE_STUN = 2
Storm.STRIKE_DAMAGE = 15
Storm.CARRIER_CHANCE = 0.6
-- A strike aimed at a player lands within this many studs of them.
Storm.STRIKE_SCATTER = 6

-- In the blackout a crate raider takes this many times the usual share.
Storm.BLACKOUT_RAID_MULTIPLIER = 2

return Storm
