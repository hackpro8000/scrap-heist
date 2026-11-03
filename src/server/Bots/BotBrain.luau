--!strict
--[[
	BotBrain

	The scrap bot's decisions, with no Roblox objects involved:
	- decide(): the state machine Idle -> Chase -> Attack -> Retreat
	- pickTarget(): nearest player, pulled toward whoever has hurt it most
	- checkStuck(): notices a bot that has stopped making progress

	BotService feeds in what the bot can see and acts on the answers
	(pathfinding, MoveTo, swings).

	States:
		Idle     no target in range
		Chase    has a target, out of attack range
		Attack   target in attack range: stand and swing
		Retreat  badly hurt: back off for a few seconds, once per life

	Public API:
		BotBrain.newMemory(): Memory
		BotBrain.decide(state, memory, perception, botType, now): State
		BotBrain.pickTarget(position, candidates): any?
		BotBrain.checkStuck(memory, position, isMoving, now): "Fine" | "Jump" | "Hop"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)

local BotBrain = {}

export type State = "Idle" | "Chase" | "Attack" | "Retreat"

export type Memory = {
	retreatUntil: number,
	hasRetreated: boolean,
	-- Stuck tracking: where the bot was when it last made progress.
	progressPosition: Vector3?,
	progressAt: number,
}

export type Perception = {
	hasTarget: boolean,
	targetDistance: number,
	healthFraction: number,
}

export type Candidate = {
	id: any,
	position: Vector3,
	-- Damage this player has dealt to the bot recently.
	threat: number,
}

function BotBrain.newMemory(): Memory
	return {
		retreatUntil = 0,
		hasRetreated = false,
		progressPosition = nil,
		progressAt = 0,
	}
end

function BotBrain.decide(
	state: State,
	memory: Memory,
	perception: Perception,
	botType: BotsConfig.BotType,
	now: number
): State
	if state == "Retreat" and now < memory.retreatUntil then
		return "Retreat"
	end
	if not perception.hasTarget then
		return "Idle"
	end

	local hurtBadly = perception.healthFraction <= botType.retreatHealthFraction
	if hurtBadly and not memory.hasRetreated then
		memory.hasRetreated = true
		memory.retreatUntil = now + BotsConfig.RETREAT_SECONDS
		return "Retreat"
	end

	if perception.targetDistance <= botType.attackRange then
		return "Attack"
	end

	return "Chase"
end

-- Lowest score wins: distance, minus a discount for damage dealt. Players
-- beyond aggro range are ignored entirely.
function BotBrain.pickTarget(position: Vector3, candidates: { Candidate }): any?
	local bestId = nil
	local bestScore = math.huge
	for _, candidate in candidates do
		local distance = (candidate.position - position).Magnitude
		if distance <= BotsConfig.AGGRO_RANGE then
			local score = distance - candidate.threat * BotsConfig.THREAT_STUDS_PER_DAMAGE
			if score < bestScore then
				bestScore = score
				bestId = candidate.id
			end
		end
	end

	return bestId
end

function BotBrain.checkStuck(memory: Memory, position: Vector3, isMoving: boolean, now: number): "Fine" | "Jump" | "Hop"
	local last = memory.progressPosition
	if not isMoving or not last or (position - last).Magnitude >= BotsConfig.STUCK_DISTANCE then
		memory.progressPosition = position
		memory.progressAt = now
		return "Fine"
	end

	local stuckFor = now - memory.progressAt
	if stuckFor >= BotsConfig.UNSTICK_SECONDS then
		-- Reset so the hop gets a fresh chance before the next one.
		memory.progressAt = now
		return "Hop"
	elseif stuckFor >= BotsConfig.STUCK_SECONDS then
		return "Jump"
	end

	return "Fine"
end

return BotBrain
