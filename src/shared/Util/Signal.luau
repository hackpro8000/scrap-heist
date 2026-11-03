--!strict
--[[
	Signal

	A tiny event object for module-to-module communication on one machine.
	Roblox's BindableEvent works too, but it deep-copies tables passed through
	it and loses metatables. This keeps references intact and stays typed.

	Used anywhere a service or controller wants to announce something without
	knowing who listens (for example "profile loaded" or "round started").

	Public API:
		Signal.new(): Signal
		signal:connect(callback): Connection
		signal:once(callback): Connection
		signal:fire(...)
		signal:wait(): ...
		signal:destroy()
		connection:disconnect()
]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

export type Connection = {
	connected: boolean,
	disconnect: (self: Connection) -> (),
}

export type Signal = {
	connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	once: (self: Signal, callback: (...any) -> ()) -> Connection,
	fire: (self: Signal, ...any) -> (),
	wait: (self: Signal) -> ...any,
	destroy: (self: Signal) -> (),
}

type SignalState = {
	_listeners: { ConnectionState },
}

type ConnectionState = {
	connected: boolean,
	_signal: SignalState,
	_callback: (...any) -> (),
}

function Connection.disconnect(self: ConnectionState)
	if not self.connected then
		return
	end

	self.connected = false

	local listeners = self._signal._listeners
	local index = table.find(listeners, self)
	if index then
		table.remove(listeners, index)
	end
end

function Signal.new(): Signal
	local self: SignalState = {
		_listeners = {},
	}

	return setmetatable(self, Signal) :: any
end

function Signal.connect(self: SignalState, callback: (...any) -> ()): Connection
	local connection: ConnectionState = {
		connected = true,
		_signal = self,
		_callback = callback,
	}
	table.insert(self._listeners, connection)

	return setmetatable(connection, Connection) :: any
end

function Signal.once(self: SignalState, callback: (...any) -> ()): Connection
	local connection: Connection
	connection = Signal.connect(self, function(...)
		connection:disconnect()
		callback(...)
	end)

	return connection
end

function Signal.fire(self: SignalState, ...: any)
	-- Iterate over a copy so listeners can disconnect while we fire.
	-- Each listener runs in its own thread so one erroring or yielding
	-- listener can't stop the others from running.
	for _, connection in table.clone(self._listeners) do
		if connection.connected then
			task.spawn(connection._callback, ...)
		end
	end
end

function Signal.wait(self: SignalState): ...any
	local thread = coroutine.running()
	Signal.once(self, function(...)
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

function Signal.destroy(self: SignalState)
	for _, connection in table.clone(self._listeners) do
		Connection.disconnect(connection)
	end
end

return Signal
