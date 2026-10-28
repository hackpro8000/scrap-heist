--!strict
--[[
	RateLimiter

	Caps how often each player may trigger something, usually a remote.
	Exploiters can fire remotes thousands of times per second, so every
	client-to-server remote checks a RateLimiter before doing any work.

	Uses a token bucket: each player has up to `burst` tokens, refilled at
	`perSecond` tokens per second. Each call spends one token. This allows
	short natural bursts (a quick combo) while capping the sustained rate.

	Public API:
		RateLimiter.new(perSecond, burst?, clock?): RateLimiter
		limiter:check(player): boolean   -- true if allowed (spends a token)
		limiter:forget(player)           -- drop a player's state on leave
		limiter:destroy()

	State for leaving players is dropped automatically.

	`clock` defaults to os.clock. Unit tests pass a fake clock so they can
	step time forward instead of waiting in real time.
]]

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = {
	check: (self: RateLimiter, player: Player) -> boolean,
	forget: (self: RateLimiter, player: Player) -> (),
	destroy: (self: RateLimiter) -> (),
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

type RateLimiterState = {
	_perSecond: number,
	_burst: number,
	_buckets: { [Player]: Bucket },
	_clock: () -> number,
	_leavingConnection: RBXScriptConnection,
}

function RateLimiter.new(perSecond: number, burst: number?, clock: (() -> number)?): RateLimiter
	assert(perSecond > 0, "RateLimiter: perSecond must be positive")

	local self: RateLimiterState = {
		_perSecond = perSecond,
		-- Default burst of one second's worth of calls.
		_burst = burst or math.max(1, perSecond),
		_buckets = {},
		_clock = clock or os.clock,
		_leavingConnection = nil :: any,
	}

	self._leavingConnection = Players.PlayerRemoving:Connect(function(player)
		self._buckets[player] = nil
	end)

	return setmetatable(self, RateLimiter) :: any
end

function RateLimiter.check(self: RateLimiterState, player: Player): boolean
	local now = self._clock()
	local bucket = self._buckets[player]

	if not bucket then
		bucket = { tokens = self._burst, updatedAt = now }
		self._buckets[player] = bucket
	end

	-- Refill based on time passed since the last call, capped at burst.
	local elapsed = now - bucket.updatedAt
	bucket.tokens = math.min(self._burst, bucket.tokens + elapsed * self._perSecond)
	bucket.updatedAt = now

	if bucket.tokens < 1 then
		return false
	end

	bucket.tokens -= 1

	return true
end

function RateLimiter.forget(self: RateLimiterState, player: Player)
	self._buckets[player] = nil
end

function RateLimiter.destroy(self: RateLimiterState)
	self._leavingConnection:Disconnect()
	table.clear(self._buckets)
end

return RateLimiter
