--!strict
--[[
	MachineService

	The tycoon loop: buying and upgrading salvage machines on a yard's
	pads, producing parts into the storage crate every tick, collecting the
	crate into scrap, and paying offline earnings when a player returns.

	Buying, upgrading and collecting use ProximityPrompts on the pads and
	crate. The prompts are marked OwnerOnly, and their Available attribute
	says whether there's anything to do (a maxed machine has nothing to
	buy). Each client shows a prompt only if it owns the yard and the prompt
	is available, but that's only for tidiness: every press is checked here
	(right player, close enough, enough scrap).

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
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local MachineRules = require(script.Parent.Parent.Tycoon.MachineRules)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local ShopService = require(script.Parent.ShopService)

local SYSTEM = "Machine"
local MODELS_FOLDER = "MachineModels"
-- The placed map art (tools/studio/PlaceMap.luau).
local MAP_FOLDER = "Map"
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
	-- Drawn by the client's PromptController as a kit card.
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("OwnerOnly", true)
	prompt.Parent = parent

	return prompt
end

-- Where the pad's bay floor is, under its middle. The pad hook part is the
-- art's whole bounding box, which reaches up to the junction box on its back
-- edge, so the floor is found by dropping a ray onto the map art itself.
local function padSurface(pad: BasePart): Vector3
	local top = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	local map = workspace:FindFirstChild(MAP_FOLDER)
	if not map then
		return top
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	local hit = workspace:Raycast(top + Vector3.new(0, 1, 0), Vector3.new(0, -pad.Size.Y - 2, 0), params)

	return if hit then hit.Position else top
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
	-- Seat the machine's bounding box, not its pivot, on the pad: a template's
	-- pivot can sit anywhere inside it.
	local box, size = model:GetBoundingBox()
	local boxToPivot = box:ToObjectSpace(model:GetPivot())
	local seat = CFrame.new(padSurface(pad)) * pad.CFrame.Rotation
	model:PivotTo(seat * CFrame.new(0, size.Y / 2, 0) * boxToPivot)
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
		state.prompt:SetAttribute("Available", false)
		return
	end

	local machine = data.yard.machines[padName]
	if machine then
		state.model = buildMachineModel(yard.pads[padName], machine.level)
	end

	local cost = if machine then MachineRules.upgradeCost(padName, machine.level) else MachineRules.buyCost(padName)
	state.prompt:SetAttribute("Available", cost ~= nil)
	state.prompt.ActionText = if machine then `Upgrade to level {machine.level + 1}` else "Buy salvage machine"
	state.prompt.ObjectText = if cost then `{cost} scrap` else "Max level"
	-- What the pad card shows: the level change, its cost and the rates.
	local level = if machine then machine.level else 0
	state.prompt:SetAttribute("Pad", true)
	state.prompt:SetAttribute("Level", level)
	state.prompt:SetAttribute("Cost", cost)
	state.prompt:SetAttribute("RateFrom", if machine then MachineRules.rateOf(level) else nil)
	state.prompt:SetAttribute("RateTo", if cost then MachineRules.rateOf(level + 1) else nil)
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
	local cost = if machine then MachineRules.upgradeCost(padName, machine.level) else MachineRules.buyCost(padName)
	if not cost then
		return
	end
	if not DataService.trySpend(player, cost) then
		Notify.Message:FireClient(player, `You need {cost} scrap`)
		return
	end

	local level = if machine then machine.level + 1 else 1
	data.yard.machines[padName] = { level = level }
	Notify.Sound:FireClient(player, "Purchase")
	refreshPad(yard, padName)
	MachineService.machineChanged:fire(player, padName, level)
end

-- Takes everything in the crate and turns it into scrap, with the
-- player's scrap passes applied. The scrap flies out of the crate into the
-- player while the heap drains with it. Returns the parts taken.
local function collectCrate(player: Player, yard: PlotService.Yard): number
	local before = PlotService.getCrateParts(player)
	local parts = PlotService.takeFromCrate(player, before)
	if parts <= 0 then
		return 0
	end

	local fill = before / ShopService.crateCapacity(player)
	local scrap = math.floor(parts * Economy.PART_VALUE * ShopService.scrapMultiplier(player))
	DataService.addScrap(player, scrap)
	PlotService.drainCrateFill(player, before, Juice.collectPieces(fill) * Juice.COLLECT_PIECE_GAP)
	Notify.ScrapBurst:FireClient(player, yard.crate.Position, scrap, fill)
	MachineService.crateCollected:fire(player, parts)
	return parts
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

	if collectCrate(player, yard) <= 0 then
		Notify.Message:FireClient(player, "The crate is empty")
	end
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
			local after = MachineRules.produce(
				before,
				data.yard.machines,
				Economy.TICK_SECONDS,
				ShopService.crateCapacity(owner),
				ShopService.productionMultiplier(owner)
			)
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
		PlotService.setCrateParts(player, tonumber(args[1]) or ShopService.crateCapacity(player))
		return `Crate now holds {math.floor(PlotService.getCrateParts(player))} parts`
	end)

	for _, yard in PlotService.getYards() do
		local states = {}
		for padName, pad in yard.pads do
			local prompt = newPrompt(pad, "Buy salvage machine")
			prompt:SetAttribute("Available", false)
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
	-- A profile can load (and get its yard) before this service starts,
	-- for example with ProfileStore's offline mock in Studio.
	for _, yard in PlotService.getYards() do
		if yard.owner then
			onYardAssigned(yard.owner, yard)
		end
	end
	PlotService.yardReleased:connect(function(_player: Player, yard: PlotService.Yard)
		-- The owner is still set while released fires, so clear the models
		-- and prompts here rather than through refreshPad.
		for _, state in padStates[yard] do
			if state.model then
				state.model:Destroy()
				state.model = nil
			end
			state.prompt:SetAttribute("Available", false)
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
	-- Auto Collect pass: the crate banks itself every so often.
	task.spawn(function()
		while true do
			task.wait(Shop.AUTO_COLLECT_SECONDS)
			for _, yard in PlotService.getYards() do
				local owner = yard.owner
				if owner and ShopService.hasPass(owner, "AutoCollect") then
					collectCrate(owner, yard)
				end
			end
		end
	end)
end

return MachineService
