--!strict
--[[
	StormRules

	Pure maths for storms: what a parts pickup pays, and who lightning aims
	at. Randomness comes in as rolls from 0 to 1.

	Public API:
		StormRules.partsFor(rank): number
		StormRules.pickTarget(carrierRoll, pickRoll, carriers, others): T?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Storm = require(ReplicatedStorage.Shared.Config.Storm)

local StormRules = {}

-- What one parts pickup pays a player of `rank`.
function StormRules.partsFor(rank: number): number
	return math.floor(Storm.PART_DROP_PARTS * (1 + Storm.PARTS_PER_RANK * rank) + 0.5)
end

-- Who a strike aims at, from the players out on the Line: usually one
-- carrying a capsule, when anyone is. Returns nil when nobody is out, and
-- the strike then lands somewhere at random.
function StormRules.pickTarget<T>(carrierRoll: number, pickRoll: number, carriers: { T }, others: { T }): T?
	local pool = others
	if #carriers > 0 and (carrierRoll < Storm.CARRIER_CHANCE or #others == 0) then
		pool = carriers
	end
	if #pool == 0 then
		return nil
	end

	return pool[math.min(#pool, math.floor(pickRoll * #pool) + 1)]
end

return StormRules
