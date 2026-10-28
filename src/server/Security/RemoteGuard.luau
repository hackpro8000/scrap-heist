--!strict
--[[
	RemoteGuard

	The one way services listen to client-to-server remotes. It rate-limits
	every remote and counts rejected calls, so no handler can forget the
	rate limit, and the debug overlay can show how often exploit-style calls
	are being turned away.

	Handlers return nil when they accept a call, or a short reason string
	("NotOwner", "TooFar") when they reject it. Rejections are counted per
	system and reason; nothing is sent back to the client, since an
	exploiter shouldn't learn which check stopped them.

	Public API:
		RemoteGuard.listen(system, remote, perSecond, handler)
		RemoteGuard.reject(system, reason)       -- count a rejection made elsewhere
		RemoteGuard.rejectionCounts(): { [string]: number }   -- "System.Reason" -> count
		RemoteGuard.rejected: Signal(system, reason)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local RemoteGuard = {}

export type Handler = (player: Player, ...any) -> string?

local counts: { [string]: number } = {}

RemoteGuard.rejected = Signal.new()

function RemoteGuard.reject(system: string, reason: string)
	local key = `{system}.{reason}`
	counts[key] = (counts[key] or 0) + 1
	RemoteGuard.rejected:fire(system, reason)
end

function RemoteGuard.listen(system: string, remote: RemoteEvent, perSecond: number, handler: Handler)
	-- Allow a short burst of twice the rate so honest fast input (a quick
	-- combo, double clicks) isn't dropped, while sustained spam is.
	local limiter = RateLimiter.new(perSecond, perSecond * 2)

	remote.OnServerEvent:Connect(function(player: Player, ...)
		-- SECURITY: rate limit before any other work, so spamming a remote
		-- can't make the server do expensive checks thousands of times.
		if not limiter:check(player) then
			RemoteGuard.reject(system, "RateLimited")
			return
		end

		local reason = handler(player, ...)
		if reason then
			RemoteGuard.reject(system, reason)
		end
	end)
end

function RemoteGuard.rejectionCounts(): { [string]: number }
	return table.clone(counts)
end

return RemoteGuard
