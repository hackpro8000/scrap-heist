--!strict
--[[
	LeaderboardController

	The leaderboard, top right, in place of Roblox's player list. It sits
	collapsed as one plank showing your rank; tapping it drops the top five
	(and your own row, if you're further down) under it, with a Scrap /
	Raids switch. VIP pass holders' names are gold.

	Ranks come from each player's leaderstats (LeaderboardService), which
	replicate to every client, so this asks the server for nothing.

	Public API: none.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local React = require(ReplicatedStorage.Packages.React)

local Kit = require(script.Parent.Parent.UI.Kit)
local LeaderboardScreen = require(script.Parent.Parent.UI.Screens.Leaderboard)

local localPlayer = Players.LocalPlayer

local SHOWN = 5
local REFRESH_SECONDS = 1

local LeaderboardController = {}

local stat = "Scrap"
local open = false
local root: Kit.Root

local function valueOf(player: Player, name: string): number
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	return if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then (value :: any).Value else 0
end

local function ranked(name: string): { Player }
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		local va, vb = valueOf(a, name), valueOf(b, name)
		if va ~= vb then
			return va > vb
		end
		return a.UserId < b.UserId
	end)
	return players
end

-- 22950 -> "22,950"
local function formatNumber(value: number): string
	local text, changed = tostring(math.floor(value)), 1
	while changed > 0 do
		text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	end
	return text
end

local function refresh()
	local order = ranked(stat)
	local myRank = table.find(order, localPlayer) or 0

	-- The top five, then you on a sixth row if you're further down.
	local shown: { number } = {}
	for index = 1, math.min(SHOWN, #order) do
		table.insert(shown, index)
	end
	if myRank > SHOWN then
		table.insert(shown, myRank)
	end
	local rows: { LeaderboardScreen.Row } = {}
	for _, rank in shown do
		local player = order[rank]
		table.insert(rows, {
			rank = rank,
			name = player.DisplayName,
			value = formatNumber(valueOf(player, stat)),
			you = player == localPlayer,
			vip = player:GetAttribute("VIP") == true,
		})
	end

	root.render(React.createElement(LeaderboardScreen, {
		myRank = myRank,
		open = open,
		stat = stat,
		rows = rows,
		onToggle = function()
			open = not open
			refresh()
		end,
		onStat = function(name: string)
			stat = name
			refresh()
		end,
	}))
end

function LeaderboardController.init()
	-- This board replaces Roblox's player list.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
	root = Kit.mount("Leaderboard", 5)
	refresh()
end

function LeaderboardController.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardController
