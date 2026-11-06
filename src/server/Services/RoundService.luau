--!strict
--[[
	RoundService

	Runs the storm round cycle on the server: Calm -> Warning -> Storm ->
	Blackout -> Calm (Config/Rounds). It only keeps the clock and tells
	everyone what phase it is; what a storm does lives in the services that
	listen (StormService rains parts and lightning, BeltService speeds the
	belt, RaidService opens the gates in the blackout).

	Clients get RoundState on every change and when they ask on joining.

	Public API:
		RoundService.getPhase(): Phase
		RoundService.getRound(): number        -- storms started so far
		RoundService.skipTo(phase)             -- debug: jump the clock
		RoundService.phaseChanged: Signal(phase, round)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local Remotes = require(ReplicatedStorage.Shared.Net.Round)
local Rounds = require(ReplicatedStorage.Shared.Config.Rounds)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DebugService = require(script.Parent.DebugService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RoundClock = require(script.Parent.Parent.Rounds.RoundClock)

local SYSTEM = "Round"
local REQUEST_RATE = 1

local RoundService = {}

RoundService.phaseChanged = Signal.new()

local cycleStartedAt = 0
local current: RoundClock.State? = nil
local round = 0

local function stateMessage(): { [string]: any }
	local state = current :: RoundClock.State
	return {
		phase = state.phase,
		round = round,
		-- os.clock differs per machine, so convert to the shared server clock.
		endsAt = workspace:GetServerTimeNow() + (state.phaseEndsAt - os.clock()),
	}
end

local function broadcast()
	if current then
		Remotes.RoundState:FireAllClients(stateMessage())
	end
end

local function transition(state: RoundClock.State)
	current = state
	if state.phase == "Storm" then
		-- Counted at the storm itself, not the warning, so jumping straight
		-- to a storm still gets a fresh round number.
		round += 1
	end

	RoundService.phaseChanged:fire(state.phase, round)
	broadcast()
end

local function tick()
	local state = RoundClock.stateAt(cycleStartedAt, os.clock(), Game.ROUND_DURATIONS, Rounds.PHASE_ORDER)
	if not current or state.phase ~= current.phase or state.cycle ~= current.cycle then
		transition(state)
	end
end

function RoundService.getPhase(): Rounds.Phase
	return (if current then current.phase else "Calm") :: Rounds.Phase
end

function RoundService.getRound(): number
	return round
end

function RoundService.skipTo(phase: Rounds.Phase)
	cycleStartedAt = RoundClock.startForPhase(phase, os.clock(), Game.ROUND_DURATIONS, Rounds.PHASE_ORDER)
	tick()
end

function RoundService.init()
	DebugService.register("storm", "/storm", function()
		RoundService.skipTo("Storm")
		return "Storm started"
	end)
	DebugService.register("phase", "/phase <Calm|Warning|Storm|Blackout>", function(_player, args)
		local phase = args[1]
		if not table.find(Rounds.PHASE_ORDER, phase) then
			return "Usage: /phase Calm|Warning|Storm|Blackout"
		end
		RoundService.skipTo(phase :: Rounds.Phase)
		return `Now in {phase}`
	end)
end

function RoundService.start()
	RemoteGuard.listen(SYSTEM, Remotes.RequestRoundState, REQUEST_RATE, function(player: Player)
		if current then
			Remotes.RoundState:FireClient(player, stateMessage())
		end
		return nil
	end)

	cycleStartedAt = os.clock()
	task.spawn(function()
		while true do
			tick()
			task.wait(Rounds.TICK_SECONDS)
		end
	end)
end

return RoundService
