--!strict
--[[
	RebirthRules

	Whether a player may take the next rank ("Scrap the Yard") and what a
	rank is worth. Pure: RebirthService gathers the facts and asks here.

	Public API:
		RebirthRules.incomeMultiplier(rank): number
		RebirthRules.next(rank): Rank?                      -- nil at the top
		RebirthRules.missing(rank, objects): { Need }       -- needs not yet met
		RebirthRules.canRebirth(rank, scrap, objects): reason?
		RebirthRules.describe(need): string
		RebirthRules.REASON_TEXT: { [reason]: string }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local YardGrid = require(ReplicatedStorage.Shared.Yard.YardGrid)

local RebirthRules = {}

RebirthRules.REASON_TEXT = {
	TopRank = "You're at the top rank.",
	NotEnoughScrap = "You need more scrap.",
	MissingJunkrots = "You're missing junkrots this rank needs.",
} :: { [string]: string }

function RebirthRules.incomeMultiplier(rank: number): number
	return 1 + Rebirth.INCOME_PER_RANK * rank
end

function RebirthRules.next(rank: number): Rebirth.Rank?
	return Rebirth.LADDER[rank + 1]
end

local function meets(placed: { id: string, stars: number, limited: boolean? }, need: Rebirth.Need): boolean
	local junkrot = Junkrots.BY_ID[placed.id]
	if not junkrot or placed.stars < need.stars then
		return false
	end
	if need.limited and not placed.limited then
		return false
	end
	if need.id then
		return placed.id == need.id
	end

	return junkrot.tier == need.tier
end

-- Each junkrot counts toward one need only. Needs are filled in order,
-- each taking the lowest-starred junkrots that meet it, so a high-starred
-- one is left for a later need that asks for more stars.
function RebirthRules.missing(rank: number, objects: { YardGrid.Object }): { Rebirth.Need }
	local step = Rebirth.LADDER[rank + 1]
	if not step then
		return {}
	end

	local placed = {}
	for _, object in objects do
		if object.kind == "Pad" and object.junkrot then
			table.insert(placed, object.junkrot)
		end
	end
	table.sort(placed, function(a, b)
		return a.stars < b.stars
	end)

	local used: { [number]: boolean } = {}
	local missing = {}
	for _, need in step.needs do
		local found = 0
		for index, junkrot in placed do
			if found < need.count and not used[index] and meets(junkrot, need) then
				used[index] = true
				found += 1
			end
		end
		if found < need.count then
			local short = table.clone(need)
			short.count = need.count - found
			table.insert(missing, short)
		end
	end

	return missing
end

function RebirthRules.canRebirth(rank: number, scrap: number, objects: { YardGrid.Object }): string?
	local step = Rebirth.LADDER[rank + 1]
	if not step then
		return "TopRank"
	end
	if #RebirthRules.missing(rank, objects) > 0 then
		return "MissingJunkrots"
	end
	if scrap < step.cost then
		return "NotEnoughScrap"
	end

	return nil
end

function RebirthRules.describe(need: Rebirth.Need): string
	local junkrot = if need.id then Junkrots.BY_ID[need.id] else nil
	local what = if junkrot then junkrot.name else `any {need.tier}`
	if need.limited then
		what = `Limited Edition {what}`
	end
	if need.stars > 1 then
		what ..= ` ★{need.stars}`
	end

	return if need.count > 1 then `{need.count} x {what}` else what
end

return RebirthRules
