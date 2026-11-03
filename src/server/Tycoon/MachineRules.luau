--!strict
--[[
	MachineRules

	Tycoon maths: what machines cost, what they produce, how full the crate
	gets and what a player earned while away. MachineService applies these
	to profiles; this module never touches a player.

	Machines are the profile's `yard.machines` table: { Pad1 = { level = 2 } }.

	Public API:
		MachineRules.buyCost(padName): number?
		MachineRules.upgradeCost(padName, currentLevel): number?   -- nil at max level
		MachineRules.rateOf(level): number                         -- parts per second
		MachineRules.incomePerSecond(machines): number
		MachineRules.produce(crateParts, machines, seconds): number
		MachineRules.offlineEarnings(machines, secondsAway): number
		MachineRules.yardLevel(machines): number
		MachineRules.crateFill(crateParts): number                 -- 0 to 1
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Game = require(ReplicatedStorage.Shared.Config.Game)

local MachineRules = {}

export type Machines = { [string]: { level: number } }

function MachineRules.buyCost(padName: string): number?
	local base = Economy.BUY_COSTS[padName]
	return if base then math.ceil(base * Game.COST_MULTIPLIER) else nil
end

function MachineRules.upgradeCost(padName: string, currentLevel: number): number?
	local base = Economy.BUY_COSTS[padName]
	local factor = Economy.UPGRADE_COST_FACTORS[currentLevel + 1]
	if not base or not factor or currentLevel >= Economy.MAX_LEVEL then
		return nil
	end

	return math.ceil(base * factor * Game.COST_MULTIPLIER)
end

function MachineRules.rateOf(level: number): number
	local rate = Economy.LEVEL_RATES[level] or 0
	return rate * Game.INCOME_MULTIPLIER
end

function MachineRules.incomePerSecond(machines: Machines): number
	local total = 0
	for padName, machine in machines do
		-- Ignore anything saved under a name that isn't a pad any more.
		if Economy.BUY_COSTS[padName] then
			total += MachineRules.rateOf(machine.level)
		end
	end

	return total
end

function MachineRules.produce(crateParts: number, machines: Machines, seconds: number): number
	local produced = MachineRules.incomePerSecond(machines) * seconds
	return math.min(Economy.CRATE_CAPACITY, crateParts + produced)
end

-- Paid as scrap straight into the balance, so it can't be raided. Capped
-- so a month away doesn't print a fortune, and at a reduced rate so
-- playing always beats staying away.
function MachineRules.offlineEarnings(machines: Machines, secondsAway: number): number
	if secondsAway <= 0 then
		return 0
	end

	local seconds = math.min(secondsAway, Economy.OFFLINE_CAP_SECONDS)
	local parts = MachineRules.incomePerSecond(machines) * seconds * Economy.OFFLINE_RATE

	return math.floor(parts * Economy.PART_VALUE)
end

-- A yard's level is the sum of its machine levels. It's what the raid
-- level-gap rule compares.
function MachineRules.yardLevel(machines: Machines): number
	local level = 0
	for padName, machine in machines do
		if Economy.BUY_COSTS[padName] then
			level += machine.level
		end
	end

	return level
end

function MachineRules.crateFill(crateParts: number): number
	return math.clamp(crateParts / Economy.CRATE_CAPACITY, 0, 1)
end

return MachineRules
