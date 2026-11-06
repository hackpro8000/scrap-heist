--!strict
--[[
	BeltRules

	Pure maths for the capsule belt: how often a capsule drops, what it
	holds, and where a capsule that has ridden some distance is. Randomness
	comes in as rolls from 0 to 1, so tests can pick them.

	Public API:
		BeltRules.spawnSeconds(playerCount, isStorm): number
		BeltRules.speed(isStorm): number                     -- studs per second
		BeltRules.lapLength(): number                        -- studs
		BeltRules.pointAt(distance): (x, z, headingX, headingZ)
		BeltRules.rollTier(roll, zone, rank, isStorm): string
		BeltRules.rollCapsule(rolls, zone, rank, isStorm): Capsule
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Belt = require(ReplicatedStorage.Shared.Config.Belt)
local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)

local BeltRules = {}

export type Capsule = {
	junkrot: string,
	tier: string,
	limited: boolean,
	-- Rolled in a storm, one tier higher.
	storm: boolean,
}

-- A storm lifts capsules one tier, but never into the two chase tiers.
local HIGHEST_STORM_LIFT = "Prototype"

function BeltRules.spawnSeconds(playerCount: number, isStorm: boolean): number
	local seconds = if playerCount >= Belt.CROWD_PLAYERS
		then Belt.SPAWN_SECONDS_CROWD
		elseif playerCount == 2 then Belt.SPAWN_SECONDS_PAIR
		else Belt.SPAWN_SECONDS_SOLO

	return if isStorm then seconds / Belt.STORM_SPEED else seconds
end

function BeltRules.lapLength(): number
	return 4 * Belt.STRAIGHT_HALF_LENGTH + 2 * math.pi * Belt.TURN_RADIUS
end

function BeltRules.speed(isStorm: boolean): number
	local speed = BeltRules.lapLength() / Belt.LAP_SECONDS
	return if isStorm then speed * Belt.STORM_SPEED else speed
end

-- Where the belt is `distance` studs along from the crane's drop point,
-- and which way it runs there. The lap starts at the west end of the north
-- straight and runs east, round the east turn, back west and round again.
function BeltRules.pointAt(distance: number): (number, number, number, number)
	local half, radius = Belt.STRAIGHT_HALF_LENGTH, Belt.TURN_RADIUS
	local straight, turn = 2 * half, math.pi * radius
	local along = distance % BeltRules.lapLength()

	if along < straight then
		return -half + along, -radius, 1, 0
	end
	along -= straight
	if along < turn then
		local angle = along / radius
		return half + math.sin(angle) * radius, -math.cos(angle) * radius, math.cos(angle), math.sin(angle)
	end
	along -= turn
	if along < straight then
		return half - along, radius, -1, 0
	end
	along -= straight
	local angle = along / radius
	return -half - math.sin(angle) * radius, math.cos(angle) * radius, -math.cos(angle), -math.sin(angle)
end

function BeltRules.rollTier(roll: number, zone: number, rank: number, isStorm: boolean): string
	local odds = Belt.ODDS[zone] or Belt.ODDS[1]
	local luck = 1 + Belt.LUCK_PER_RANK * rank

	local total = 0
	local weights = {}
	for index, tier in Junkrots.TIERS do
		local weight = (odds[tier] or 0) * (if index > 1 then luck else 1)
		weights[index] = weight
		total += weight
	end

	local picked = 1
	local remaining = math.clamp(roll, 0, 1) * total
	for index, weight in weights do
		if weight > 0 then
			picked = index
			if remaining < weight then
				break
			end
			remaining -= weight
		end
	end

	if isStorm and picked < Junkrots.tierIndex(HIGHEST_STORM_LIFT) then
		picked += 1
	end

	return Junkrots.TIERS[picked]
end

-- `rolls` gives the next random number from 0 to 1 each time it's called.
function BeltRules.rollCapsule(rolls: () -> number, zone: number, rank: number, isStorm: boolean): Capsule
	local tier = BeltRules.rollTier(rolls(), zone, rank, isStorm)
	local cast = Junkrots.BY_TIER[tier]
	local junkrot = cast[math.min(#cast, math.floor(rolls() * #cast) + 1)]

	return {
		junkrot = junkrot.id,
		tier = tier,
		limited = rolls() < 1 / Belt.LIMITED_ONE_IN,
		storm = isStorm,
	}
end

return BeltRules
