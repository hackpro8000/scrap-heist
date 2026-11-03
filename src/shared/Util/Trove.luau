--!strict
--[[
	Trove

	Collects everything an object or player creates (connections, instances,
	threads, cleanup functions) so it can all be torn down with one call.
	Forgetting to disconnect a single connection on player leave is the most
	common memory leak in Roblox games; a Trove makes cleanup one line.

	Typical use: each player session or spawned object owns a Trove, and
	calls trove:destroy() when the player leaves or the object is removed.

	Public API:
		Trove.new(): Trove
		trove:add(item): item       -- track something for cleanup
		trove:connect(signal, fn)   -- connect and track the connection
		trove:extend(): Trove       -- a child Trove cleaned with this one
		trove:clean()               -- clean everything, keep using the Trove
		trove:destroy()             -- clean everything, stop using the Trove
]]

local Trove = {}
Trove.__index = Trove

-- Anything with a disconnect/destroy method, or a plain cleanup function.
export type Cleanable = Instance | RBXScriptConnection | thread | () -> () | { [any]: any }

export type Trove = {
	add: <T>(self: Trove, item: T) -> T,
	connect: (self: Trove, signal: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	extend: (self: Trove) -> Trove,
	clean: (self: Trove) -> (),
	destroy: (self: Trove) -> (),
}

type TroveState = {
	_items: { Cleanable },
	_cleaning: boolean,
}

local function cleanItem(item: Cleanable)
	if typeof(item) == "Instance" then
		item:Destroy()
	elseif typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif type(item) == "thread" then
		-- A thread can't cancel itself; that case happens when cleanup is
		-- triggered from inside the tracked thread.
		if coroutine.running() ~= item then
			task.cancel(item)
		end
	elseif type(item) == "function" then
		item()
	elseif type(item) == "table" then
		if type(item.destroy) == "function" then
			item:destroy()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.disconnect) == "function" then
			item:disconnect()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Trove.new(): Trove
	local self: TroveState = {
		_items = {},
		_cleaning = false,
	}

	return setmetatable(self, Trove) :: any
end

function Trove.add<T>(self: TroveState, item: T): T
	-- Adding during clean would either be skipped or leak, so fail loudly.
	assert(not self._cleaning, "Trove: cannot add while cleaning")
	table.insert(self._items, item :: any)

	return item
end

function Trove.connect(self: TroveState, signal: RBXScriptSignal, callback: (...any) -> ()): RBXScriptConnection
	return Trove.add(self, signal:Connect(callback))
end

function Trove.extend(self: TroveState): Trove
	return Trove.add(self, Trove.new())
end

function Trove.clean(self: TroveState)
	if self._cleaning then
		return
	end

	self._cleaning = true

	-- Clean newest first, so things are torn down in reverse order of setup.
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		cleanItem(items[index])
	end

	self._cleaning = false
end

function Trove.destroy(self: TroveState)
	Trove.clean(self)
end

return Trove
