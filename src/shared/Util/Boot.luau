--!strict
--[[
	Boot

	Starts a list of services (server) or controllers (client) in two passes:

	1. init(): every module sets up its own state and remotes. Modules must
	   not talk to each other yet, because some haven't initialized.
	2. start(): every module may now use the others. Each start() runs in
	   its own thread so a long-running loop in one module doesn't block
	   the rest from starting.

	The list order is the boot order, so dependencies go first (for example
	DataService before InventoryService). It is written out by hand in the
	entry scripts so anyone reading them can see exactly what boots.

	An init() error stops the boot, since later modules may depend on it.
	A start() error is reported but doesn't stop other modules.

	Public API:
		Boot.run(label, modules)
]]

local Boot = {}

export type Module = {
	init: ((self: any) -> ())?,
	start: ((self: any) -> ())?,
}

export type Entry = {
	name: string,
	module: Module,
}

function Boot.run(label: string, entries: { Entry })
	for _, entry in entries do
		if entry.module.init then
			entry.module:init()
		end
		print(`[{label}] init {entry.name}`)
	end

	for _, entry in entries do
		local start = entry.module.start
		if start then
			task.spawn(function()
				local ok, message = pcall(start, entry.module)
				if not ok then
					warn(`[{label}] start {entry.name} failed: {message}`)
				end
			end)
		end
		print(`[{label}] start {entry.name}`)
	end

	print(`[{label}] booted {#entries} module(s)`)
end

return Boot
