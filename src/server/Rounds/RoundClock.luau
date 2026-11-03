--!strict
--[[
	RoundClock

	Works out which round phase it is from one fixed start time. Nothing is
	counted down or added up tick by tick, so the cycle can't drift: phase
	boundaries always land exactly where the durations say, however long
	the server runs or however late a tick fires. And since there's only one
	start time, two rounds can never overlap.

	Public API:
		RoundClock.cycleLength(durations, order): number
		RoundClock.stateAt(cycleStartedAt, now, durations, order): State
		RoundClock.startForPhase(phase, now, durations, order): number
]]

local RoundClock = {}

export type State = {
	phase: string,
	-- Which pass through the cycle this is, starting at 1.
	cycle: number,
	phaseStartedAt: number,
	phaseEndsAt: number,
}

function RoundClock.cycleLength(durations: { [string]: number }, order: { string }): number
	local total = 0
	for _, phase in order do
		total += durations[phase]
	end

	return total
end

function RoundClock.stateAt(
	cycleStartedAt: number,
	now: number,
	durations: { [string]: number },
	order: { string }
): State
	local length = RoundClock.cycleLength(durations, order)
	assert(length > 0, "RoundClock: phase durations must add up to more than zero")

	local elapsed = math.max(0, now - cycleStartedAt)
	local cycleIndex = math.floor(elapsed / length)
	local cycleStart = cycleStartedAt + cycleIndex * length
	local intoCycle = elapsed - cycleIndex * length

	local phaseStart = cycleStart
	for _, phase in order do
		local phaseEnd = phaseStart + durations[phase]
		if intoCycle < phaseEnd - cycleStart then
			return {
				phase = phase,
				cycle = cycleIndex + 1,
				phaseStartedAt = phaseStart,
				phaseEndsAt = phaseEnd,
			}
		end
		phaseStart = phaseEnd
	end

	-- Floating point can land exactly on the cycle end; that's the next
	-- cycle's first phase.
	local first = order[1]
	return {
		phase = first,
		cycle = cycleIndex + 2,
		phaseStartedAt = cycleStart + length,
		phaseEndsAt = cycleStart + length + durations[first],
	}
end

-- The cycle start time that makes `now` the very start of `phase`. Used to
-- jump straight to a phase (showcase mode's "storm now").
function RoundClock.startForPhase(
	phase: string,
	now: number,
	durations: { [string]: number },
	order: { string }
): number
	local offset = 0
	for _, name in order do
		if name == phase then
			return now - offset
		end
		offset += durations[name]
	end

	error(`RoundClock: unknown phase {phase}`)
end

return RoundClock
