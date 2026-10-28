--!strict
--[[
	WaveRules

	How many bots of each type a storm wave spawns. Waves grow with the
	round number (later storms are harder) and with each wave inside a
	storm, and never push the bot count past the cap.

	Public API:
		WaveRules.composition(round, wave, roomLeft): { [botType]: count }
		WaveRules.total(composition): number
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)

local WaveRules = {}

-- Spawn order when the cap cuts a wave short: cheapest bots go first so a
-- full arena still gets a few of everything over time.
local TYPE_ORDER = { "Scrapper", "Zapper", "Bruiser" }

function WaveRules.composition(round: number, wave: number, roomLeft: number): { [string]: number }
	local wanted: { [string]: number } = {}
	for _, typeName in TYPE_ORDER do
		local growth = BotsConfig.WAVE_GROWTH[typeName]
		if growth then
			local count = growth.base + growth.perRound * (round - 1) + growth.perWave * (wave - 1)
			wanted[typeName] = math.max(0, math.floor(count))
		end
	end

	-- Fill round-robin until the room runs out, so a capped wave stays mixed.
	local result: { [string]: number } = {}
	local room = math.max(0, roomLeft)
	local added = true
	while room > 0 and added do
		added = false
		for _, typeName in TYPE_ORDER do
			local have = result[typeName] or 0
			if room > 0 and have < (wanted[typeName] or 0) then
				result[typeName] = have + 1
				room -= 1
				added = true
			end
		end
	end

	return result
end

function WaveRules.total(composition: { [string]: number }): number
	local total = 0
	for _, count in composition do
		total += count
	end

	return total
end

return WaveRules
