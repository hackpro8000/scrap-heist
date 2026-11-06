--!strict
--[[
	JunkrotRules

	Pure maths for capsules and the junkrots that hatch from them: what a
	capsule costs and takes to hatch, what a junkrot earns, what its next
	star costs, and which pad a newly hatched one goes on. No services, no
	instances, so everything here runs in unit tests.

	Public API:
		JunkrotRules.capsulePrice(junkrotId): number
		JunkrotRules.hatchSeconds(junkrotId): number
		JunkrotRules.hatchProgress(seconds, isWhacked): number
		JunkrotRules.rate(placed, padFamily?): number          -- scrap/s, before rank
		JunkrotRules.yardIncome(objects, multiplier): number   -- scrap/s
		JunkrotRules.crateCapacity(income): number
		JunkrotRules.earn(crate, income, seconds, capacity): number
		JunkrotRules.offlineEarnings(income, secondsAway): number
		JunkrotRules.starCost(junkrotId, stars): number?       -- parts; nil at most stars
		JunkrotRules.refund(junkrotId): number
		JunkrotRules.choosePad(objects, junkrotId, limited): (pad?, replaced?)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Belt = require(ReplicatedStorage.Shared.Config.Belt)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)
local Yard = require(ReplicatedStorage.Shared.Config.Yard)
local YardGrid = require(ReplicatedStorage.Shared.Yard.YardGrid)

local JunkrotRules = {}

export type Placed = { id: string, stars: number, limited: boolean? }

local function infoOf(junkrotId: string): (Junkrots.Junkrot, Junkrots.TierInfo)
	local junkrot = Junkrots.BY_ID[junkrotId]
	assert(junkrot, `JunkrotRules: no junkrot has the id {junkrotId}`)
	return junkrot, Junkrots.TIER_INFO[junkrot.tier]
end

function JunkrotRules.capsulePrice(junkrotId: string): number
	local junkrot, tier = infoOf(junkrotId)
	return math.ceil(junkrot.rate * tier.priceSeconds * Game.COST_MULTIPLIER)
end

function JunkrotRules.hatchSeconds(junkrotId: string): number
	local _, tier = infoOf(junkrotId)
	return tier.hatchSeconds
end

-- How much of a capsule's hatch time `seconds` of real time gets done.
function JunkrotRules.hatchProgress(seconds: number, isWhacked: boolean): number
	return if isWhacked then seconds else seconds / Junkrots.UNATTENDED_HATCH_FACTOR
end

-- A saved junkrot whose id no longer exists earns nothing.
function JunkrotRules.rate(placed: Placed, padFamily: string?): number
	local junkrot = Junkrots.BY_ID[placed.id]
	if not junkrot then
		return 0
	end

	local stars = math.clamp(placed.stars, 1, Junkrots.MAX_STARS)
	local rate = junkrot.rate * 2 ^ (stars - 1)
	if placed.limited then
		rate *= Belt.LIMITED_MULTIPLIER
	end
	if padFamily == junkrot.family then
		rate *= 1 + Junkrots.FAMILY_BONUS
	end

	return rate
end

-- What every junkrot standing in the yard earns together. `multiplier` is
-- the owner's own: their rank, boosts and passes.
function JunkrotRules.yardIncome(objects: { YardGrid.Object }, multiplier: number): number
	local total = 0
	for _, object in objects do
		if object.kind == "Pad" and object.junkrot then
			total += JunkrotRules.rate(object.junkrot, object.family)
		end
	end

	return total * multiplier * Game.INCOME_MULTIPLIER
end

function JunkrotRules.crateCapacity(income: number): number
	return math.max(Yard.CRATE_MIN, math.floor(income * Yard.CRATE_SECONDS))
end

-- The crate after `seconds` of income. A full crate stops earning.
function JunkrotRules.earn(crate: number, income: number, seconds: number, capacity: number): number
	return math.max(crate, math.min(capacity, crate + income * seconds))
end

function JunkrotRules.offlineEarnings(income: number, secondsAway: number, capSeconds: number?): number
	local seconds = math.clamp(secondsAway, 0, capSeconds or Economy.OFFLINE_CAP_SECONDS)
	return math.floor(income * Economy.OFFLINE_RATE * seconds)
end

function JunkrotRules.starCost(junkrotId: string, stars: number): number?
	local base = Junkrots.STAR_PARTS[stars]
	local junkrot = Junkrots.BY_ID[junkrotId]
	if not base or not junkrot or stars >= Junkrots.MAX_STARS then
		return nil
	end

	return base * Junkrots.STAR_TIER_FACTOR ^ (Junkrots.tierIndex(junkrot.tier) - 1)
end

function JunkrotRules.refund(junkrotId: string): number
	return math.floor(JunkrotRules.capsulePrice(junkrotId) * Junkrots.SCRAP_REFUND)
end

-- Where a newly hatched junkrot goes: an empty pad of its own family, else
-- any empty pad. With every pad full it takes the place of the yard's
-- weakest earner, if it out-earns it there; that one is returned too.
-- Returns nothing when the newcomer is the weakest: it is scrapped instead.
function JunkrotRules.choosePad(
	objects: { YardGrid.Object },
	junkrotId: string,
	limited: boolean?
): (YardGrid.Object?, Placed?)
	local junkrot = Junkrots.BY_ID[junkrotId]
	if not junkrot then
		return nil, nil
	end

	local empty: YardGrid.Object? = nil
	local weakest: YardGrid.Object? = nil
	local weakestRate = math.huge
	for _, object in objects do
		if object.kind ~= "Pad" then
			continue
		end
		if not object.junkrot then
			if object.family == junkrot.family then
				return object, nil
			end
			empty = empty or object
		else
			local rate = JunkrotRules.rate(object.junkrot, object.family)
			if rate < weakestRate then
				weakest, weakestRate = object, rate
			end
		end
	end
	if empty then
		return empty, nil
	end

	local newcomer: Placed = { id = junkrotId, stars = 1, limited = limited }
	if weakest and JunkrotRules.rate(newcomer, weakest.family) > weakestRate then
		return weakest, weakest.junkrot
	end

	return nil, nil
end

return JunkrotRules
