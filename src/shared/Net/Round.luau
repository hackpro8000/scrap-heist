--!strict
--[[
	Round remotes

	Client to server:
		RequestRoundState()   -- on join, so mid-round joiners get the state

	Server to client:
		RoundState(state)     -- { phase, round, endsAt }
		                      -- round counts storms started; the next storm
		                      -- during Calm/Warning is round + 1
		                      -- endsAt is in workspace:GetServerTimeNow() time
]]

local Net = require(script.Parent.Net)

local SYSTEM = "Round"

return {
	RequestRoundState = Net.event(SYSTEM, "RequestRoundState"),
	RoundState = Net.event(SYSTEM, "RoundState"),
}
