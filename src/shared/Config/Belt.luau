--!strict
--[[
	Belt config

	The capsule belt on the Line: where it runs, how often the crane drops a
	capsule on it, and what the capsules hold. Numbers follow
	docs/plans/gameplay-content.md.
]]

local Belt = {}

-- The belt loops round the Line's bed as a stadium: two straights joined
-- by half circles, centred on the map's origin, the straights along X.
-- Studs. HEIGHT is the belt's top, where capsules ride.
Belt.STRAIGHT_HALF_LENGTH = 200
Belt.TURN_RADIUS = 16
Belt.HEIGHT = 2.6
-- How wide the placeholder belt is drawn when the map has no belt art.
Belt.WIDTH = 6

-- Seconds a capsule rides before the crusher takes it: one lap.
Belt.LAP_SECONDS = 90

-- Seconds between capsules, by how many players are on the server.
Belt.SPAWN_SECONDS_SOLO = 20
Belt.SPAWN_SECONDS_PAIR = 15
Belt.SPAWN_SECONDS_CROWD = 10
Belt.CROWD_PLAYERS = 3

-- In a storm the belt runs this many times faster and drops capsules this
-- many times as often, each rolled one tier higher.
Belt.STORM_SPEED = 2

-- Percent chance of each tier, by zone tier. Only the hub (zone 1) is
-- built so far.
Belt.ODDS = {
	[1] = { Scrap = 72, Salvaged = 22, Refurbished = 5.2, Factory = 0.75, Precision = 0.05, Prototype = 0, Secret = 0.002 },
	[2] = { Scrap = 30, Salvaged = 42, Refurbished = 22, Factory = 5.4, Precision = 0.6, Prototype = 0.03, Secret = 0.002 },
	[3] = { Scrap = 8, Salvaged = 30, Refurbished = 38, Factory = 20, Precision = 4, Prototype = 0.1, Secret = 0.002 },
} :: { [number]: { [string]: number } }

-- Every rebirth rank multiplies the weights of Salvaged and up by
-- 1 + LUCK_PER_RANK * rank. The belt is shared, so it uses the highest
-- rank on the server.
Belt.LUCK_PER_RANK = 0.04

-- One capsule in this many is a Limited Edition: its junkrot earns
-- LIMITED_MULTIPLIER times as much.
Belt.LIMITED_ONE_IN = 500
Belt.LIMITED_MULTIPLIER = 3

-- Studs: how close a player must be to buy a capsule off the belt or pick
-- one up off the ground.
Belt.BUY_DISTANCE = 12
Belt.PICKUP_DISTANCE = 10

-- Walk speed multiplier while carrying a capsule.
Belt.CARRY_SPEED_MULTIPLIER = 0.75

-- Seconds a dropped capsule lies on the ground before it is lost, and how
-- long after dropping before anyone can pick it up.
Belt.DROP_EXPIRE_SECONDS = 45
Belt.DROP_PICKUP_DELAY = 0.75

return Belt
