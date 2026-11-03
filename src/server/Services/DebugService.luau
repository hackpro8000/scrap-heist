--!strict
--[[
	DebugService

	Chat commands for testing, usable in Studio or by admins listed in
	Config/Game.ADMIN_USER_IDS. Services register their own commands, so
	each command sits next to the system it pokes at; the showcase panel
	(ShowcaseService) runs the same commands through run().

	Built-in commands:
		/givescrap <amount>
		/resetdata
		/help

	Public API:
		DebugService.register(name, usage, handler)   -- handler(player, args): string?
		DebugService.run(player, name, args): string  -- result message
		DebugService.isAllowed(player): boolean
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)

local DataService = require(script.Parent.DataService)
local DebugCommands = require(script.Parent.Parent.Debug.DebugCommands)

type Handler = (player: Player, args: { string }) -> string?

type Command = {
	usage: string,
	handler: Handler,
}

local DebugService = {}

local commands: { [string]: Command } = {}

function DebugService.isAllowed(player: Player): boolean
	return DebugCommands.isAllowed(player.UserId, RunService:IsStudio(), Game.ADMIN_USER_IDS)
end

function DebugService.register(name: string, usage: string, handler: Handler)
	commands[string.lower(name)] = { usage = usage, handler = handler }
end

function DebugService.run(player: Player, name: string, args: { string }): string
	-- SECURITY: every path into a command checks the gate here, including
	-- the showcase panel's remote.
	if not DebugService.isAllowed(player) then
		return "Not allowed"
	end

	local command = commands[string.lower(name)]
	if not command then
		return `Unknown command /{name}. Try /help`
	end

	local ok, result = pcall(command.handler, player, args)
	if not ok then
		warn(`[Debug] /{name} failed: {result}`)
		return `/{name} failed`
	end

	return result or "Done"
end

local function onChatted(player: Player, message: string)
	local name, args = DebugCommands.parse(message)
	if not name or not commands[name] or not DebugService.isAllowed(player) then
		return
	end

	Notify.Message:FireClient(player, DebugService.run(player, name, args))
end

function DebugService.init()
	DebugService.register("givescrap", "/givescrap <amount>", function(player, args)
		local amount = tonumber(args[1])
		if not amount or not DataService.addScrap(player, math.floor(amount)) then
			return "Usage: /givescrap <positive whole number>"
		end
		return `Gave {math.floor(amount)} scrap`
	end)

	DebugService.register("resetdata", "/resetdata", function(player)
		DataService.resetData(player)
		return "Data reset"
	end)

	DebugService.register("help", "/help", function()
		local lines = {}
		for _, command in commands do
			table.insert(lines, command.usage)
		end
		table.sort(lines)
		return table.concat(lines, "  ")
	end)
end

function DebugService.start()
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return DebugService
