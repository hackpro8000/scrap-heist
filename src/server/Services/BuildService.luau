--!strict
--[[
	BuildService

	Build mode's server side. A player lays out their own yard: moving the
	things in it and placing the new pads and bays their rank has earned.
	Every request is checked against Shared/Yard/BuildRules from the saved
	layout, never from what the client says is there.

	No building in a storm, or while a raider is inside the yard: a layout
	can't be shuffled to dodge a raid in progress.

	Moving a pad moves the junkrot on it, and moving a bay moves the capsule
	in it: they are part of the thing's saved entry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildRules = require(ReplicatedStorage.Shared.Yard.BuildRules)
local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Remotes = require(ReplicatedStorage.Shared.Net.Build)
local Rounds = require(ReplicatedStorage.Shared.Config.Rounds)
local YardConfig = require(ReplicatedStorage.Shared.Config.Yard)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RaidService = require(script.Parent.RaidService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local RoundService = require(script.Parent.RoundService)

local SYSTEM = "Build"
local REQUEST_RATE = 4

local BuildService = {}

local function isCell(value: any, most: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0 and value < most
end

-- SECURITY: arguments come from the client and can be anything.
local function isSpot(x: any, z: any, turn: any): boolean
	return isCell(x, YardConfig.COLUMNS) and isCell(z, YardConfig.ROWS) and isCell(turn, 4)
end

-- Why the player can't build right now, as a message for them.
local function blocked(player: Player, yard: PlotService.Yard): string?
	if Rounds.isStorm(RoundService.getPhase()) then
		return "No building in a storm"
	end
	if RaidService.hasIntruders(yard) then
		return "No building while a raider is in your yard"
	end
	if player:GetAttribute("CarryingCapsule") ~= nil then
		return "Put your capsule down first"
	end

	return nil
end

local function refuse(player: Player, reason: string): string
	Notify.Message:FireClient(player, BuildRules.REASON_TEXT[reason] or "You can't build that there")
	return reason
end

local function onMove(player: Player, objectId: any, x: any, z: any, turn: any): string?
	if type(objectId) ~= "number" or not isSpot(x, z, turn) then
		return "BadArgument"
	end
	local data = DataService.getData(player)
	local yard = PlotService.yardOf(player)
	local object = PlotService.objectOf(player, objectId)
	if not data or not yard or not object then
		return "NoObject"
	end
	local message = blocked(player, yard)
	if message then
		Notify.Message:FireClient(player, message)
		return nil
	end

	local moved = table.clone(object)
	moved.x, moved.z, moved.turn = x, z, turn
	local reason = BuildRules.canPlace(data.yard.objects, BuildRules.clearedParcels(data.rank), moved)
	if reason then
		return refuse(player, reason)
	end

	object.x, object.z, object.turn = x, z, turn
	PlotService.rebuildThing(yard, object)
	Notify.Sound:FireClient(player, "Collect")

	return nil
end

local function onAdd(player: Player, kind: any, family: any, x: any, z: any, turn: any): string?
	if type(kind) ~= "string" or not isSpot(x, z, turn) then
		return "BadArgument"
	end
	if kind == "Pad" and not table.find(Junkrots.FAMILIES, family) then
		return "BadFamily"
	end
	local data = DataService.getData(player)
	local yard = PlotService.yardOf(player)
	if not data or not yard then
		return "NoYard"
	end
	local message = blocked(player, yard)
	if message then
		Notify.Message:FireClient(player, message)
		return nil
	end

	local added: PlotService.Object = {
		id = data.yard.nextObjectId,
		kind = kind,
		family = if kind == "Pad" then family else nil,
		x = x,
		z = z,
		turn = turn,
	}
	local reason = BuildRules.canAdd(data.yard.objects, data.rank, kind)
		or BuildRules.canPlace(data.yard.objects, BuildRules.clearedParcels(data.rank), added)
	if reason then
		return refuse(player, reason)
	end

	data.yard.nextObjectId += 1
	table.insert(data.yard.objects, added)
	PlotService.rebuildThing(yard, added)
	PlotService.refreshIncome(player)
	Notify.Sound:FireClient(player, "Purchase")

	return nil
end

function BuildService.init() end

function BuildService.start()
	RemoteGuard.listen(SYSTEM, Remotes.Move, REQUEST_RATE, onMove)
	RemoteGuard.listen(SYSTEM, Remotes.Add, REQUEST_RATE, onAdd)
end

return BuildService
