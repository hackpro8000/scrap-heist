--!strict
--[[
	DebugCommands

	Parses chat commands like "/givescrap 500" and decides who may use them.
	DebugService wires these to chat and to the showcase panel.

	Public API:
		DebugCommands.PREFIX
		DebugCommands.parse(text): (name?, args)   -- name is lowercased
		DebugCommands.isAllowed(userId, isStudio, adminUserIds): boolean
]]

local DebugCommands = {}

DebugCommands.PREFIX = "/"

-- Longer messages aren't commands; skip parsing them at all.
local MAX_COMMAND_LENGTH = 100

function DebugCommands.parse(text: string): (string?, { string })
	if type(text) ~= "string" or #text > MAX_COMMAND_LENGTH then
		return nil, {}
	end
	if string.sub(text, 1, #DebugCommands.PREFIX) ~= DebugCommands.PREFIX then
		return nil, {}
	end

	local words = {}
	for word in string.gmatch(string.sub(text, #DebugCommands.PREFIX + 1), "%S+") do
		table.insert(words, word)
	end
	if #words == 0 then
		return nil, {}
	end

	local name = string.lower(table.remove(words, 1) :: string)
	return name, words
end

function DebugCommands.isAllowed(userId: number, isStudio: boolean, adminUserIds: { number }): boolean
	-- SECURITY: outside Studio, only listed admins. Debug commands hand out
	-- currency and items, so they must never be reachable by a normal player.
	return isStudio or table.find(adminUserIds, userId) ~= nil
end

return DebugCommands
