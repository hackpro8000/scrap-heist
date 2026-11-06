--!strict
--[[
	RebirthService

	"Scrap the Yard": at the rebirth press in their yard, a player with the
	junkrots the next rank asks for (standing on pads) and the scrap it
	costs takes the rank. Their scrap goes to 0; everything else stays.
	Each rank earns more (Tycoon/RebirthRules), clears land and allows
	another pad (Shared/Yard/BuildRules), which they place in build mode.

	The press shows the next rank's cost and which of its junkrots are
	still missing.

	Public API:
		RebirthService.rankChanged: Signal(player, rank)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local PlotService = require(script.Parent.PlotService)
local RebirthRules = require(script.Parent.Parent.Tycoon.RebirthRules)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)

local SYSTEM = "Rebirth"
local PROMPT_DISTANCE = 14
-- Seconds between refreshes of what each press shows.
local LABEL_INTERVAL = 2

local RebirthService = {}

RebirthService.rankChanged = Signal.new()

-- The label on each yard's press.
local pressLabels: { [PlotService.Yard]: TextLabel } = {}

local function missingText(rank: number, objects: { PlotService.Object }): string
	local names = {}
	for _, need in RebirthRules.missing(rank, objects) do
		table.insert(names, RebirthRules.describe(need))
	end

	return table.concat(names, ", ")
end

local function showPress(yard: PlotService.Yard)
	local label = pressLabels[yard]
	local owner = yard.owner
	local data = owner and DataService.getData(owner)
	if not label or not label.Parent or not data then
		return
	end

	local step = RebirthRules.next(data.rank)
	if not step then
		label.Text = `Rank {data.rank}\nScrap Baron`
		return
	end

	local missing = missingText(data.rank, data.yard.objects)
	local needs = if missing == "" then "Junkrots ready" else `Needs: {missing}`
	label.Text = `Rank {data.rank + 1}: {Format.short(step.cost)} scrap\n{needs}\nUnlocks: {step.unlocks}`
end

local function setRank(player: Player, rank: number)
	local data = DataService.getData(player)
	local yard = PlotService.yardOf(player)
	if not data then
		return
	end

	data.rank = math.clamp(rank, 0, Rebirth.MAX_RANK)
	if yard then
		-- The rank clears land and may change what the things show.
		PlotService.rebuildYard(yard)
	end
	PlotService.refreshIncome(player)
	RebirthService.rankChanged:fire(player, data.rank)
end

local function onPressTriggered(player: Player, yard: PlotService.Yard, press: BasePart)
	-- SECURITY: only the owner, at the press; the cost and the junkrots
	-- are read from the save.
	if yard.owner ~= player then
		RemoteGuard.reject(SYSTEM, "NotOwner")
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or (root.Position - press.Position).Magnitude > PROMPT_DISTANCE + 14 then
		RemoteGuard.reject(SYSTEM, "TooFar")
		return
	end
	local data = DataService.getData(player)
	if not data then
		return
	end

	local reason = RebirthRules.canRebirth(data.rank, DataService.getScrap(player), data.yard.objects)
	if reason == "MissingJunkrots" then
		Notify.Message:FireClient(player, `Still needed on your pads: {missingText(data.rank, data.yard.objects)}`)
		return
	elseif reason then
		Notify.Message:FireClient(player, RebirthRules.REASON_TEXT[reason])
		return
	end

	-- The press takes all the player's scrap, not just the cost.
	if not DataService.trySpend(player, DataService.getScrap(player)) then
		return
	end
	local step = Rebirth.LADDER[data.rank + 1]
	setRank(player, data.rank + 1)
	Notify.Message:FireClient(
		player,
		`RANK {data.rank}! Income x{RebirthRules.incomeMultiplier(data.rank)}. {step.unlocks}`
	)
	Notify.Message:FireClient(player, "Open build mode to place your new pad")
	Notify.Sound:FireClient(player, "Bank")
end

local function onThingBuilt(yard: PlotService.Yard, object: PlotService.Object, model: Model)
	local hook = model.PrimaryPart
	if object.kind ~= "Press" or not hook then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(16, 0, 4.5, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, hook.Size.Y / 2 + 3.5, 0)
	gui.MaxDistance = 90
	gui.Adornee = hook
	gui.Parent = hook
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	pressLabels[yard] = label
	showPress(yard)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Scrap the yard"
	prompt.ObjectText = "Rebirth press"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("OwnerOnly", true)
	prompt.Parent = hook
	prompt.Triggered:Connect(function(player: Player)
		onPressTriggered(player, yard, hook)
	end)
end

function RebirthService.init()
	DebugService.register("rank", "/rank <0-20>", function(player, args)
		local rank = tonumber(args[1])
		if not rank then
			return "Usage: /rank <0-20>"
		end
		setRank(player, math.floor(rank))
		return `You are rank {player:GetAttribute("Rank")}`
	end)
end

function RebirthService.start()
	PlotService.forEachThing(onThingBuilt)

	task.spawn(function()
		while true do
			task.wait(LABEL_INTERVAL)
			for _, yard in PlotService.getYards() do
				showPress(yard)
			end
		end
	end)
end

return RebirthService
