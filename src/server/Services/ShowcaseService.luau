--!strict
--[[
	ShowcaseService

	Showcase mode, for recording clips and demoing systems to clients.
	Available in Studio and to admins (Config/Game.ADMIN_USER_IDS) only.

	- The showcase panel (ShowcaseController) runs DebugService commands
	  through one remote: storm now, spawn bots, give items, fake raid...
	- The debug overlay shows the systems are real: every server hitbox as
	  it's checked, every bot path as it's computed, bot states, and live
	  counts of rejected remote calls.

	Allowed players get the IsAdmin attribute so their client shows the
	panel. That attribute only decides what UI appears; every command is
	checked again on the server.

	Public API: none.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Remotes = require(ReplicatedStorage.Shared.Net.Showcase)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)

local CombatService = require(script.Parent.CombatService)
local DebugService = require(script.Parent.DebugService)
local DummyService = require(script.Parent.DummyService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)

local SYSTEM = "Showcase"
local COMMAND_RATE = 4
local MAX_ARGS = 4
local MAX_TEXT_LENGTH = 32
local STATS_INTERVAL = 1
-- Studs in front of the player where a showcase dummy appears.
local DUMMY_DISTANCE = 10

local ShowcaseService = {}

local overlayWatchers: { [Player]: boolean } = {}

local function isValidArgs(args: any): boolean
	if type(args) ~= "table" or #args > MAX_ARGS then
		return false
	end
	for key, value in args do
		if type(key) ~= "number" or not Validate.isShortString(value, MAX_TEXT_LENGTH) then
			return false
		end
	end

	return true
end

local function toWatchers(kind: string, data: { [string]: any })
	for player in overlayWatchers do
		Remotes.DebugDraw:FireClient(player, kind, data)
	end
end

function ShowcaseService.init()
	DebugService.register("dummy", "/dummy", function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return "No character"
		end
		DummyService.spawnDummy(root.Position + root.CFrame.LookVector * DUMMY_DISTANCE)
		return "Dummy spawned"
	end)

	DebugService.register("overlay", "/overlay", function(player)
		if overlayWatchers[player] then
			overlayWatchers[player] = nil
			Remotes.OverlayStats:FireClient(player, nil)
			return "Debug overlay off"
		end
		overlayWatchers[player] = true
		Remotes.OverlayStats:FireClient(player, RemoteGuard.rejectionCounts())
		return "Debug overlay on"
	end)
end

function ShowcaseService.start()
	RemoteGuard.listen(SYSTEM, Remotes.Command, COMMAND_RATE, function(player: Player, name: any, args: any)
		-- SECURITY: the gate in DebugService.run applies too; this keeps
		-- non-admins from even reaching command parsing.
		if not DebugService.isAllowed(player) then
			return "NotAllowed"
		end
		if not Validate.isShortString(name, MAX_TEXT_LENGTH) or not isValidArgs(args) then
			return "BadArgument"
		end

		Notify.Message:FireClient(player, DebugService.run(player, name, args))
		return nil
	end)

	local function markAdmin(player: Player)
		player:SetAttribute("IsAdmin", DebugService.isAllowed(player))
	end
	Players.PlayerAdded:Connect(markAdmin)
	for _, player in Players:GetPlayers() do
		markAdmin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		overlayWatchers[player] = nil
	end)

	CombatService.swingChecked:connect(function(boxCFrame: CFrame, size: Vector3)
		toWatchers("Hitbox", { cframe = boxCFrame, size = size })
	end)
	task.spawn(function()
		while true do
			task.wait(STATS_INTERVAL)
			if next(overlayWatchers) then
				local counts = RemoteGuard.rejectionCounts()
				for player in overlayWatchers do
					Remotes.OverlayStats:FireClient(player, counts)
				end
			end
		end
	end)
end

return ShowcaseService
