--!strict
--[[
	Net

	Creates (on the server) or finds (on the client) the RemoteEvents for one
	system, under ReplicatedStorage.Remotes.<System>. Each system has a small
	module next to this one listing its remotes, for example Net/Trade.luau,
	so every remote in the game is declared in one obvious place.

	The server creates remotes as soon as a Net module is required, which
	happens during boot, before any client can ask for them. The client waits
	for them, since they replicate after it starts.

	Public API:
		Net.event(system, name): RemoteEvent
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ROOT_NAME = "Remotes"

local Net = {}

local function findOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent

	return created
end

local function systemFolder(system: string): Instance
	if RunService:IsServer() then
		local root = findOrCreate(ReplicatedStorage, "Folder", ROOT_NAME)
		return findOrCreate(root, "Folder", system)
	end

	return ReplicatedStorage:WaitForChild(ROOT_NAME):WaitForChild(system)
end

function Net.event(system: string, name: string): RemoteEvent
	local folder = systemFolder(system)
	if RunService:IsServer() then
		return findOrCreate(folder, "RemoteEvent", name) :: RemoteEvent
	end

	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
