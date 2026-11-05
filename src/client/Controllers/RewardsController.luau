--!strict
--[[
	RewardsController

	The rewards window (Rewards button, UI/Screens/Rewards): the daily
	streak and the playtime gifts. Playtime counts on locally between the
	server's snapshots (RewardsUpdated), which come on join, on every claim
	and at the turn of the UTC day.

	Public API: none.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Rewards)

local HudController = require(script.Parent.HudController)
local Kit = require(script.Parent.Parent.UI.Kit)
local RewardsScreen = require(script.Parent.Parent.UI.Screens.Rewards)
local Windows = require(script.Parent.Parent.UI.Windows)

local WINDOW = "Rewards"

local RewardsController = {}

local state: { [string]: any }? = nil
local receivedAt = 0
local root: Kit.Root

local function render()
	-- Playtime keeps counting from the snapshot until the next one.
	local played = if state then state.playSeconds + math.max(0, os.clock() - receivedAt) else 0
	root.render(React.createElement(RewardsScreen, {
		state = state,
		played = played,
		now = workspace:GetServerTimeNow(),
		onClaimDaily = function()
			Remotes.ClaimDaily:FireServer()
		end,
		onClaimGift = function(index: number)
			Remotes.ClaimGift:FireServer(index)
		end,
	}))
end

function RewardsController.init()
	root = Kit.mount("Rewards", 10)
	Windows.opened:connect(function(name: string)
		if name == WINDOW then
			render()
		end
	end)
	render()
end

function RewardsController.start()
	Remotes.RewardsUpdated.OnClientEvent:Connect(function(newState: any)
		if type(newState) == "table" and type(newState.daily) == "table" then
			state = newState
			receivedAt = os.clock()
			render()
		end
	end)
	Remotes.RequestRewards:FireServer()

	-- Timers and bars tick while the window is open.
	task.spawn(function()
		while true do
			task.wait(1)
			if Windows.isOpen(WINDOW) then
				render()
			end
		end
	end)

	HudController.addButton("Rewards", 3, function()
		Windows.toggle(WINDOW)
	end)
end

return RewardsController
