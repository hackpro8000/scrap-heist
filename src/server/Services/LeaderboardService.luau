--!strict
--[[
	LeaderboardService

	The player list leaderboard (leaderstats): each player's scrap and
	raids won. Roblox shows any folder named "leaderstats" under a Player
	in the player list, so this just keeps two values in step with the
	profile.

	Nothing needs cleaning up: the folder is destroyed with the Player.

	Public API: none.
]]

local DataService = require(script.Parent.DataService)
local RaidService = require(script.Parent.RaidService)

local LeaderboardService = {}

local function statValue(player: Player, name: string): IntValue?
	local folder = player:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(name)
	return if value and value:IsA("IntValue") then value else nil
end

local function setStat(player: Player, name: string, amount: number)
	local value = statValue(player, name)
	if value then
		value.Value = math.floor(amount)
	end
end

local function createStats(player: Player, data: any)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local scrap = Instance.new("IntValue")
	scrap.Name = "Scrap"
	scrap.Value = data.scrap
	scrap.Parent = folder

	local raids = Instance.new("IntValue")
	raids.Name = "Raids"
	raids.Value = data.stats.raidsWon
	raids.Parent = folder

	folder.Parent = player
end

function LeaderboardService.init() end

function LeaderboardService.start()
	DataService.forEachLoaded(createStats)
	DataService.scrapChanged:connect(function(player, balance)
		setStat(player, "Scrap", balance)
	end)
	RaidService.raidBanked:connect(function(player)
		local data = DataService.getData(player)
		if data then
			setStat(player, "Raids", data.stats.raidsWon)
		end
	end)
end

return LeaderboardService
