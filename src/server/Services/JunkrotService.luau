--!strict
--[[
	JunkrotService

	The earning side of a yard: junkrots stand on pads and earn scrap into
	the crate every tick; the owner collects the crate, adds stars to
	junkrots with parts, and whacks the junk mound for a trickle of scrap
	when they have nothing else.

	It hangs its prompts and models on the things PlotService builds:
	- a pad with a junkrot gets the junkrot's model (its template from
	  ServerStorage.Junkrots, else a placeholder block), a label, and an
	  owner-only "Add star" prompt;
	- the crate gets a label and an owner-only "Collect" prompt;
	- the mound gets an owner-only "Whack" prompt.

	CapsuleService hands a hatched junkrot over through JunkrotService.place.

	Public API:
		JunkrotService.place(player, junkrotId, limited): Junkrot?
		    -- nil when it was scrapped for want of a pad
		JunkrotService.hatched: Signal(player, junkrot, limited)
		JunkrotService.crateCollected: Signal(player, scrap)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local YardConfig = require(ReplicatedStorage.Shared.Config.Yard)

local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local JunkrotRules = require(script.Parent.Parent.Tycoon.JunkrotRules)
local PlotService = require(script.Parent.PlotService)
local RemoteGuard = require(script.Parent.Parent.Security.RemoteGuard)
local ShopService = require(script.Parent.ShopService)

local SYSTEM = "Junkrot"
local MODELS_FOLDER = "Junkrots"
-- Studs an owner may stand from a thing and still use it; a little more
-- than the prompts' own reach, to allow for lag.
local PROMPT_DISTANCE = 12
local REACH_SLACK = 6
-- Seconds between mound whacks that count.
local MOUND_COOLDOWN = 0.25
local GOLD = Color3.fromRGB(255, 205, 70)
-- Art faces its own -Z (Roblox's forward); a pad's +Z points at the gate,
-- so a junkrot is turned half round to greet whoever walks in.
local ART_FACES_GATE = CFrame.Angles(0, math.pi, 0)
local ART_SCALE = 1.5
local ART_SCALE_PER_TIER = 0.12

local JunkrotService = {}

JunkrotService.hatched = Signal.new()
JunkrotService.crateCollected = Signal.new()

local lastWhackAt: { [Player]: number } = {}

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	-- From the thing's edge, not its middle: a press is 16 studs long.
	local reach = math.max(part.Size.X, part.Size.Z) / 2 + PROMPT_DISTANCE + REACH_SLACK
	return (root.Position - part.Position).Magnitude <= reach
end

local function newPrompt(parent: Instance, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	-- The client shows this one to the yard's owner only.
	prompt:SetAttribute("OwnerOnly", true)
	prompt.Parent = parent

	return prompt
end

local function label(adornee: BasePart, height: number, lines: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(9, 0, 1.1 * lines, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.Adornee = adornee
	gui.Parent = adornee

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Parent = gui

	return text
end

local function starsText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", Junkrots.MAX_STARS - stars)
end

-- The junkrot's model, stood on the pad: its own template when the art
-- exists, else a block in its tier's colour, bigger for better tiers.
local function buildJunkrotModel(junkrot: Junkrots.Junkrot, seat: CFrame): Model
	local folder = ServerStorage:FindFirstChild(MODELS_FOLDER)
	local template = folder and folder:FindFirstChild(junkrot.id)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		-- Art is modelled about 3 studs tall; on a 10-stud pad it stands
		-- bigger, and bigger still the better its tier.
		model:ScaleTo(ART_SCALE + ART_SCALE_PER_TIER * (Junkrots.tierIndex(junkrot.tier) - 1))
		local box, size = model:GetBoundingBox()
		model:PivotTo(seat * ART_FACES_GATE * CFrame.new(0, size.Y / 2, 0) * box:ToObjectSpace(model:GetPivot()))
	else
		model = Instance.new("Model")
		local tier = Junkrots.tierIndex(junkrot.tier)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3, 3.5, 3) + Vector3.one * tier * 0.4
		body.CFrame = seat * CFrame.new(0, body.Size.Y / 2, 0)
		body.Color = Junkrots.TIER_INFO[junkrot.tier].color
		body.Material = if tier >= 5 then Enum.Material.Metal else Enum.Material.CorrodedMetal
		body.Anchored = true
		body.Parent = model
		model.PrimaryPart = body
	end
	model.Name = "Junkrot"
	model:SetAttribute("JunkrotId", junkrot.id)

	return model
end

local function dressPad(yard: PlotService.Yard, object: PlotService.Object, model: Model)
	local hook = model.PrimaryPart :: BasePart
	local placed = object.junkrot
	local junkrot = if placed then Junkrots.BY_ID[placed.id] else nil
	if not placed or not junkrot then
		return
	end

	local seat = PlotService.seatOf(model)
	local junkrotModel = buildJunkrotModel(junkrot, seat)
	junkrotModel.Parent = model

	local _, size = junkrotModel:GetBoundingBox()
	local text = label(hook, seat.Position.Y - hook.Position.Y + size.Y + 2.2, 3)
	local rate = JunkrotRules.rate(placed, object.family)
	local name = if placed.limited then `LIMITED {junkrot.name}` else junkrot.name
	text.Text = `{name}\n{starsText(placed.stars)}\n{Format.short(rate)}/s`
	text.TextColor3 = if placed.limited then GOLD else Color3.new(1, 1, 1)

	local cost = JunkrotRules.starCost(placed.id, placed.stars)
	local prompt = newPrompt(hook, "Add star", if cost then `{Format.short(cost)} parts` else "Max stars")
	prompt:SetAttribute("Available", cost ~= nil)
	prompt.Triggered:Connect(function(player: Player)
		-- SECURITY: only the owner, standing at the pad. The star and its
		-- cost are read from the save, never from the client.
		if yard.owner ~= player then
			RemoteGuard.reject(SYSTEM, "NotOwner")
			return
		end
		if not isNear(player, hook) then
			RemoteGuard.reject(SYSTEM, "TooFar")
			return
		end
		local data = DataService.getData(player)
		local saved = PlotService.objectOf(player, object.id)
		local standing = saved and saved.junkrot
		if not data or not saved or not standing then
			return
		end
		local price = JunkrotRules.starCost(standing.id, standing.stars)
		if not price then
			return
		end
		if data.parts < price then
			Notify.Message:FireClient(
				player,
				`You need {Format.short(price)} parts (you have {Format.short(data.parts)})`
			)
			return
		end

		data.parts -= price
		standing.stars += 1
		Notify.Sound:FireClient(player, "Purchase")
		PlotService.rebuildThing(yard, saved)
		PlotService.refreshIncome(player)
	end)
end

-- Takes everything in the crate as scrap, with the player's scrap passes
-- applied. Returns the scrap banked.
local function collectCrate(player: Player, from: Vector3): number
	local before = PlotService.getCrate(player)
	local fill = before / PlotService.crateCapacity(player)
	local taken = PlotService.takeFromCrate(player, before)
	if taken <= 0 then
		return 0
	end

	local scrap = math.floor(taken * ShopService.scrapMultiplier(player))
	DataService.addScrap(player, scrap)
	Notify.ScrapBurst:FireClient(player, from, scrap, math.clamp(fill, 0, 1))
	JunkrotService.crateCollected:fire(player, scrap)

	return scrap
end

local function dressCrate(yard: PlotService.Yard, model: Model)
	local hook = model.PrimaryPart :: BasePart
	local text = label(hook, hook.Size.Y / 2 + 2, 1)
	local function show()
		local scrap = model:GetAttribute("Scrap") :: number? or 0
		local capacity = model:GetAttribute("Capacity") :: number? or 0
		text.Text = `{Format.short(scrap)} / {Format.short(capacity)} scrap`
	end
	model:GetAttributeChangedSignal("Scrap"):Connect(show)
	model:GetAttributeChangedSignal("Capacity"):Connect(show)
	show()

	local prompt = newPrompt(hook, "Collect", "Storage crate")
	prompt.Triggered:Connect(function(player: Player)
		if yard.owner ~= player then
			RemoteGuard.reject(SYSTEM, "NotOwner")
			return
		end
		if not isNear(player, hook) then
			RemoteGuard.reject(SYSTEM, "TooFar")
			return
		end
		if collectCrate(player, hook.Position) <= 0 then
			Notify.Message:FireClient(player, "The crate is empty")
		end
	end)
end

local function dressMound(yard: PlotService.Yard, model: Model)
	local hook = model.PrimaryPart :: BasePart
	local prompt = newPrompt(hook, "Whack", "Junk mound")
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(function(player: Player)
		if yard.owner ~= player then
			RemoteGuard.reject(SYSTEM, "NotOwner")
			return
		end
		if not isNear(player, hook) then
			RemoteGuard.reject(SYSTEM, "TooFar")
			return
		end
		-- SECURITY: prompt presses can be faked faster than a hand can whack.
		local now = os.clock()
		if now - (lastWhackAt[player] or 0) < MOUND_COOLDOWN then
			RemoteGuard.reject(SYSTEM, "WhackTooFast")
			return
		end
		lastWhackAt[player] = now

		local data = DataService.getData(player)
		if not data then
			return
		end
		DataService.addScrap(player, YardConfig.MOUND_SCRAP)
		Notify.ScrapBurst:FireClient(player, hook.Position, YardConfig.MOUND_SCRAP, 0)
		if math.random(YardConfig.MOUND_PART_ONE_IN) == 1 then
			data.parts += 1
			player:SetAttribute("Parts", data.parts)
			Notify.Message:FireClient(player, "Found a part in the junk!")
		end
	end)
end

local function onThingBuilt(yard: PlotService.Yard, object: PlotService.Object, model: Model)
	if object.kind == "Pad" then
		dressPad(yard, object, model)
	elseif object.kind == "Crate" then
		dressCrate(yard, model)
	elseif object.kind == "Mound" then
		dressMound(yard, model)
	end
end

function JunkrotService.place(player: Player, junkrotId: string, limited: boolean): Junkrots.Junkrot?
	local data = DataService.getData(player)
	local yard = PlotService.yardOf(player)
	local junkrot = Junkrots.BY_ID[junkrotId]
	if not data or not yard or not junkrot then
		return nil
	end

	data.stats.capsulesHatched += 1
	local isNew = not data.logbook[junkrotId]
	data.logbook[junkrotId] = true
	JunkrotService.hatched:fire(player, junkrot, limited)

	local pad, replaced = JunkrotRules.choosePad(data.yard.objects, junkrotId, limited)
	if not pad then
		-- Every pad holds something better: the newcomer is scrapped.
		local refund = JunkrotRules.refund(junkrotId)
		DataService.addScrap(player, refund)
		Notify.Message:FireClient(
			player,
			`{junkrot.name} hatched, but your pads all hold better. Scrapped for {Format.short(refund)}`
		)
		return nil
	end

	if replaced then
		local refund = JunkrotRules.refund(replaced.id)
		DataService.addScrap(player, refund)
		local old = Junkrots.BY_ID[replaced.id]
		Notify.Message:FireClient(
			player,
			`{if old then old.name else "A junkrot"} made way, scrapped for {Format.short(refund)}`
		)
	end
	local placed: JunkrotRules.Placed = { id = junkrotId, stars = 1, limited = if limited then true else nil }
	pad.junkrot = placed
	PlotService.rebuildThing(yard, pad)
	PlotService.refreshIncome(player)

	local rate = Format.short(JunkrotRules.rate(placed, pad.family))
	local heading = if limited then "LIMITED EDITION! " elseif isNew then "New! " else ""
	Notify.Message:FireClient(player, `{heading}{junkrot.name} ({junkrot.what}) hatched: {rate}/s`)
	Notify.Sound:FireClient(player, "Purchase")

	return junkrot
end

local function onYardAssigned(player: Player)
	local data = DataService.getData(player)
	if not data or data.lastSeenAt <= 0 then
		return
	end

	local earned = JunkrotRules.offlineEarnings(PlotService.incomeOf(player), os.time() - data.lastSeenAt)
	-- Stamp now, so a reload in the same session can't pay the same time twice.
	data.lastSeenAt = os.time()
	if earned > 0 and DataService.addScrap(player, earned) then
		Notify.Message:FireClient(player, `While you were away your junkrots made {Format.short(earned)} scrap`)
	end
end

local function earn()
	for _, yard in PlotService.getYards() do
		local owner = yard.owner
		if owner then
			local income = PlotService.incomeOf(owner)
			local before = PlotService.getCrate(owner)
			local after = JunkrotRules.earn(before, income, Economy.TICK_SECONDS, PlotService.crateCapacity(owner))
			if after ~= before then
				PlotService.setCrate(owner, after)
			end
		end
	end
end

function JunkrotService.init()
	DebugService.register("junkrot", "/junkrot <id> [limited]", function(player, args)
		local junkrot = Junkrots.BY_ID[args[1] or ""]
		if not junkrot then
			return "Usage: /junkrot <id> [limited], for example /junkrot CrumboPoppalot"
		end
		JunkrotService.place(player, junkrot.id, args[2] == "limited")
		return `Hatched {junkrot.name}`
	end)
	DebugService.register("parts", "/parts <count>", function(player, args)
		local data = DataService.getData(player)
		if not data then
			return "No profile"
		end
		data.parts = math.max(0, data.parts + (tonumber(args[1]) or 100))
		player:SetAttribute("Parts", data.parts)
		return `You have {data.parts} parts`
	end)
	DebugService.register("fillcrate", "/fillcrate [scrap]", function(player, args)
		if not PlotService.yardOf(player) then
			return "You don't have a yard"
		end
		PlotService.setCrate(player, tonumber(args[1]) or PlotService.crateCapacity(player))
		return `Crate now holds {math.floor(PlotService.getCrate(player))} scrap`
	end)
end

function JunkrotService.start()
	PlotService.forEachThing(onThingBuilt)
	PlotService.yardAssigned:connect(onYardAssigned)
	for _, yard in PlotService.getYards() do
		if yard.owner then
			task.spawn(onYardAssigned, yard.owner)
		end
	end
	PlotService.yardReleased:connect(function(player: Player)
		lastWhackAt[player] = nil
	end)
	DataService.profileReleasing:connect(function(_player, data)
		data.lastSeenAt = os.time()
	end)

	task.spawn(function()
		while true do
			task.wait(Economy.TICK_SECONDS)
			earn()
		end
	end)
	-- Auto Collect pass: the crate banks itself every so often.
	task.spawn(function()
		while true do
			task.wait(Shop.AUTO_COLLECT_SECONDS)
			for _, yard in PlotService.getYards() do
				local owner = yard.owner
				if owner and ShopService.hasPass(owner, "AutoCollect") then
					collectCrate(owner, yard.origin)
				end
			end
		end
	end)
end

return JunkrotService
