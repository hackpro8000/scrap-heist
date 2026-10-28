--!strict
--[[
	MachineService

	The tycoon loop: buying and upgrading salvage machines on a yard's
	pads, producing parts into the storage crate every tick, collecting the
	crate into scrap, and paying offline earnings when a player returns.

	Buying, upgrading and collecting use ProximityPrompts on the pads and
	crate. The prompts are marked OwnerOnly and the client hides them from
	everyone but the owner, but that's only for tidiness: every press is
	checked here (right player, close enough, enough scrap).

	All income is calculated on the server from the machines saved in the
	owner's profile (Tycoon/MachineRules).

	Machine models come from ServerStorage.MachineModels.SalvageMachine1-3
	(one per tier) if present, otherwise gray blocks that grow per level.

	Public API:
		MachineService.machineChanged: Signal(player, padName, level)
		MachineService.crateCollected: Signal(player, parts)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local MachineRules = require(script.Parent.Parent.Tycoon.MachineRules)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)

local SYSTEM = "Machine"
local MODELS_FOLDER = "MachineModels"
local PROMPT_DISTANCE = 10
-- Extra studs allowed on the server's distance check, for lag.
local DISTANCE_SLACK = 4
local MACHINE_COLORS = {
	Color3.fromRGB(150, 110, 70),
	Color3.fromRGB(120, 130, 140),
	Color3.fromRGB(90, 160, 200),
}

local MachineService = {}

MachineService.machineChanged = Signal.new()
MachineService.crateCollected = Signal.new()

type PadState = {
	prompt: ProximityPrompt,
	model: Model?,
}

-- padStates[yard][padName]
local padStates: { [any]: { [string]: PadState } } = {}

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- SECURITY: re-check distance on the server. A prompt press can be
	-- faked by exploit tools from anywhere on the map.
	return root ~= nil and (root.Position - part.Position).Magnitude <= PROMPT_DISTANCE + DISTANCE_SLACK
end

local function newPrompt(parent: BasePart, actionText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerOnly", true)
	prompt.Parent = parent

	return prompt
end

local function buildMachineModel(pad: BasePart, level: number): Model
	local folder = ServerStorage:FindFirstChild(MODELS_FOLDER)
	local template = folder and folder:FindFirstChild(`SalvageMachine{level}`)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Name = "Body"
		block.Size = Vector3.new(3 + level, 2 + level * 1.5, 3 + level)
		block.Color = MACHINE_COLORS[level] or MACHINE_COLORS[1]
		block.Anchored = true
		block.Parent = model
		model.PrimaryPart = block
	end

	model.Name = "SalvageMachine"
	local _, size = model:GetBoundingBox()
	-- Stand the machine on top of the pad.
	model:PivotTo(pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + size.Y / 2, 0))
	model.Parent = pad

	return model
end

local function refreshPad(yard: PlotService.Yard, padName: string)
	local state = padStates[yard][padName]
	local owner = yard.owner
	local data = owner and DataService.getData(owner)

	if state.model then
		state.model:Destroy()
		state.model = nil
	end

	if not data then
		state.prompt.Enabled = false
		return
	end

	local machine = data.yard.machines[padName]
	if machine then
		state.model = buildMachineModel(yard.pads[padName], machine.level)
	end

	local cost = if machine
		then MachineRules.upgradeCost(padName, machine.level)
		else MachineRules.buyCost(padName)
	state.prompt.Enabled = cost ~= nil
	state.prompt.ActionText = if machine then `Upgrade to level {machine.level + 1}` else "Buy salvage machine"
	state.prompt.ObjectText = if cost then `{cost} scrap` else "Max level"
end

local function onPadTriggered(player: Player, yard: PlotService.Yard, padName: string)
	-- SECURITY: only the owner builds in a yard, and only standing at the pad.
	if yard.owner ~= player then
		RemoteGuard.reject(SYSTEM, "NotOwner")
		return
	end
	if not isNear(player, yard.pads[padName]) then
		RemoteGuard.reject(SYSTEM, "TooFar")
		return
	end

	local data = DataService.getData(player)
	if not data then
		return
	end

	local machine = data.yard.machines[padName]
	local cost = if machine
		then MachineRules.upgradeCost(padName, machine.level)
		else MachineRules.buyCost(padName)
	if not cost then
		return
	end
	if not DataService.trySpend(player, cost) then
		Notify.Message:FireClient(player, `You need {cost} scrap`)
		return
	end

	local level = if machine then machine.level + 1 else 1
	data.yard.machines[padName] = { level = level }
	refreshPad(yard, padName)
	MachineService.machineChanged:fire(player, padName, level)
end

local function onCollectTriggered(player: Player, yard: PlotService.Yard)
	if yard.owner ~= player then
		RemoteGuard.reject(SYSTEM, "NotOwner")
		return
	end
	if not isNear(player, yard.crate) then
		RemoteGuard.reject(SYSTEM, "TooFar")
		return
	end

	local parts = PlotService.takeFromCrate(player, PlotService.getCrateParts(player))
	if parts <= 0 then
		Notify.Message:FireClient(player, "The crate is empty")
		return
	end

	DataService.addScrap(player, parts * Economy.PART_VALUE)
	Notify.Message:FireClient(player, `Collected {parts * Economy.PART_VALUE} scrap`)
	MachineService.crateCollected:fire(player, parts)
end

local function onYardAssigned(player: Player, yard: PlotService.Yard)
	for padName in yard.pads do
		refreshPad(yard, padName)
	end

	local data = DataService.getData(player)
	if not data or data.lastSeenAt <= 0 then
		return
	end

	local earned = MachineRules.offlineEarnings(data.yard.machines, os.time() - data.lastSeenAt)
	-- Stamp now, so a reload in the same session can't pay the same time twice.
	data.lastSeenAt = os.time()
	if earned > 0 and DataService.addScrap(player, earned) then
		Notify.Message:FireClient(player, `While you were away your machines made {earned} scrap`)
	end
end

local function produce()
	for _, yard in PlotService.getYards() do
		local owner = yard.owner
		local data = owner and DataService.getData(owner)
		if owner and data then
			local before = data.yard.crateParts
			local after = MachineRules.produce(before, data.yard.machines, Economy.TICK_SECONDS)
			if after ~= before then
				PlotService.setCrateParts(owner, after)
			end
		end
	end
end

function MachineService.init()
	DebugService.register("fillcrate", "/fillcrate [parts]", function(player, args)
		if not PlotService.yardOf(player) then
			return "You don't have a yard"
		end
		PlotService.setCrateParts(player, tonumber(args[1]) or Economy.CRATE_CAPACITY)
		return `Crate now holds {math.floor(PlotService.getCrateParts(player))} parts`
	end)

	for _, yard in PlotService.getYards() do
		local states = {}
		for padName, pad in yard.pads do
			local prompt = newPrompt(pad, "Buy salvage machine")
			prompt.Enabled = false
			prompt.Triggered:Connect(function(player)
				onPadTriggered(player, yard, padName)
			end)
			states[padName] = { prompt = prompt, model = nil }
		end
		padStates[yard] = states

		local collect = newPrompt(yard.crate, "Collect")
		collect.ObjectText = "Storage crate"
		collect.Triggered:Connect(function(player)
			onCollectTriggered(player, yard)
		end)
	end
end

function MachineService.start()
	PlotService.yardAssigned:connect(onYardAssigned)
	PlotService.yardReleased:connect(function(_player: Player, yard: PlotService.Yard)
		-- The owner is still set while released fires; clear models now and
		-- the prompts go quiet because refreshPad finds no data next time.
		for _, state in padStates[yard] do
			if state.model then
				state.model:Destroy()
				state.model = nil
			end
			state.prompt.Enabled = false
		end
	end)
	DataService.profileReleasing:connect(function(_player, data)
		data.lastSeenAt = os.time()
	end)

	task.spawn(function()
		while true do
			task.wait(Economy.TICK_SECONDS)
			produce()
		end
	end)
end

return MachineService
