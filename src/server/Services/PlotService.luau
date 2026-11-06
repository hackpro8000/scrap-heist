--!strict
--[[
	PlotService

	Gives every player a yard and builds what they have laid out in it.

	The map bakes each yard's shell (island, floor, fence, gate), marked by a
	part per plot in workspace.YardSpots. Everything inside is the player's
	own: pads, build bays, the crate, the junk mound and the rebirth press,
	saved in their profile (yard.objects) and placed on the plot's grid
	(Shared/Yard). A new player gets the starter layout.

	Each thing is built as a Model under the yard's model in workspace.Yards,
	from the template of its name in ServerStorage.YardKit when there is
	one, else from a plain placeholder. The model carries what the thing is
	as attributes (ObjectId, Kind, Family, CellX, CellZ, Turn), which the
	client's build mode reads. Other services hang their prompts and models
	on a thing when thingBuilt fires for it; a thing is rebuilt from scratch
	whenever it changes.

	This service also owns the yard's storage crate (the profile's
	yard.crateScrap): junkrots fill it, the owner collects it, raiders steal
	from it, and all three go through here so the crate's label always
	matches the saved number.

	Public API:
		PlotService.getYards(): { Yard }
		PlotService.yardOf(player): Yard?
		PlotService.yardAt(position): Yard?          -- which yard a point is in
		PlotService.spawnCFrame(yard): CFrame
		PlotService.objectsOf(player): { Object }
		PlotService.objectOf(player, objectId): Object?
		PlotService.objectCFrame(yard, object): CFrame   -- its middle, on the floor
		PlotService.thingOf(yard, objectId): Model?
		PlotService.seatOf(thing): CFrame             -- where something set on it rests
		PlotService.rebuildThing(yard, object)
		PlotService.rebuildYard(yard)
		PlotService.forEachThing(callback)           -- every thing, now and later
		PlotService.incomeOf(player): number         -- scrap per second
		PlotService.refreshIncome(player)            -- after junkrots or rank change
		PlotService.getCrate(player): number
		PlotService.setCrate(player, scrap)
		PlotService.addToCrate(player, amount): number   -- returns amount stored
		PlotService.takeFromCrate(player, amount): number -- returns amount taken
		PlotService.crateCapacity(player): number
		PlotService.yardAssigned: Signal(player, yard)
		PlotService.yardReleased: Signal(player, yard)
		PlotService.thingBuilt: Signal(yard, object, model)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BuildRules = require(ReplicatedStorage.Shared.Yard.BuildRules)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Notify = require(ReplicatedStorage.Shared.Net.Notify)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local YardConfig = require(ReplicatedStorage.Shared.Config.Yard)
local YardGrid = require(ReplicatedStorage.Shared.Yard.YardGrid)

local DataService = require(script.Parent.DataService)
local JunkrotRules = require(script.Parent.Parent.Tycoon.JunkrotRules)
local RebirthRules = require(script.Parent.Parent.Tycoon.RebirthRules)
local ShopService = require(script.Parent.ShopService)

local YARD_KIT_FOLDER = "YardKit"
local YARD_SPOTS_FOLDER = "YardSpots"
local FREE_YARD_TEXT = "Free yard"
local WELCOME_TEXT = "Welcome! Buy a capsule off the belt, carry it home to your build bay and hatch it"
local RUBBLE_FOLDER = "Rubble"
local RUBBLE_THICKNESS = 0.3
local RUBBLE_COLOR = Color3.fromRGB(95, 85, 72)

-- Placeholder yards, for a place with no map: two rows either side of the
-- Line, as the map has them.
local PLACEHOLDER_ROW = 180
local PLACEHOLDER_COLUMNS = { -210, -70, 70, 210 }
local PLACEHOLDER_HEIGHT = 6
local FLOOR_COLOR = Color3.fromRGB(110, 110, 105)

-- Placeholder things: how tall each is and its colour.
local PLACEHOLDER_HEIGHTS = { Pad = 0.4, Bay = 0.4, Crate = 5, Mound = 4, Press = 6 }
local PLACEHOLDER_COLORS = {
	Kitchen = Color3.fromRGB(199, 77, 56),
	Garage = Color3.fromRGB(230, 158, 38),
	Gadget = Color3.fromRGB(71, 128, 184),
	Bay = Color3.fromRGB(214, 195, 154),
	Crate = Color3.fromRGB(70, 130, 70),
	Mound = Color3.fromRGB(120, 95, 70),
	Press = Color3.fromRGB(138, 106, 74),
}

export type Object = YardGrid.Object

export type Yard = {
	index: number,
	origin: Vector3,
	yaw: number,
	model: Model,
	owner: Player?,
	-- What stands in the yard, by object id.
	things: { [number]: Model },
	markerLabel: TextLabel,
}

local PlotService = {}

PlotService.yardAssigned = Signal.new()
PlotService.yardReleased = Signal.new()
PlotService.thingBuilt = Signal.new()

local yards: { Yard } = {}
local yardByPlayer: { [Player]: Yard } = {}

local function yardCFrame(yard: Yard, offset: Vector3?): CFrame
	local position = if offset then YardGrid.toWorld(yard.origin, yard.yaw, offset) else yard.origin
	return CFrame.new(position) * CFrame.Angles(0, yard.yaw, 0)
end

local function billboard(adornee: BasePart, studsOffset: Vector3, text: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(10, 0, 2, 0)
	gui.StudsOffset = studsOffset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 160
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui

	return label
end

local function hookPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = parent

	return part
end

local function placement(index: number): (Vector3, number, boolean)
	local spots = workspace:FindFirstChild(YARD_SPOTS_FOLDER)
	local spot = spots and spots:FindFirstChild(`Yard{index}`)
	if spot and spot:IsA("BasePart") then
		local _, yaw = spot.CFrame:ToOrientation()
		return spot.Position, yaw, true
	end

	-- Yards 1-4 stand north of the Line (-Z) and face south, 5-8 the other way.
	local column = PLACEHOLDER_COLUMNS[(index - 1) % #PLACEHOLDER_COLUMNS + 1]
	local north = index <= #PLACEHOLDER_COLUMNS
	local origin = Vector3.new(column, PLACEHOLDER_HEIGHT, if north then -PLACEHOLDER_ROW else PLACEHOLDER_ROW)
	return origin, if north then 0 else math.pi, false
end

local function buildYard(index: number, folder: Folder): Yard
	local origin, yaw, hasShell = placement(index)

	local model = Instance.new("Model")
	model.Name = `Yard{index}`
	model:SetAttribute("YardIndex", index)
	-- Clients read these to show owner-only prompts to the owner only, and
	-- to lay the build grid over the plot.
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("Origin", origin)
	model:SetAttribute("Yaw", yaw)
	model:SetAttribute("Rank", 0)

	local yard: Yard = {
		index = index,
		origin = origin,
		yaw = yaw,
		model = model,
		owner = nil,
		things = {},
		markerLabel = nil :: any,
	}

	if not hasShell then
		local floor = hookPart(
			"Floor",
			Vector3.new(YardGrid.WIDTH, 1, YardGrid.DEPTH),
			yardCFrame(yard, Vector3.new(0, -0.5, 0)),
			model
		)
		floor.Transparency = 0
		floor.CanCollide = true
		floor.CanQuery = true
		floor.Color = FLOOR_COLOR
	end

	-- The owner's name hangs over the gate.
	local marker =
		hookPart("Marker", Vector3.one, yardCFrame(yard, YardGrid.GATE_OFFSET + Vector3.new(0, 11, 0)), model)
	yard.markerLabel = billboard(marker, Vector3.zero, FREE_YARD_TEXT)

	model.Parent = folder

	return yard
end

function PlotService.objectCFrame(yard: Yard, object: Object): CFrame
	return yardCFrame(yard, YardGrid.centre(object)) * CFrame.Angles(0, object.turn * math.pi / 2, 0)
end

local function templateFor(object: Object): Model?
	local kit = ServerStorage:FindFirstChild(YARD_KIT_FOLDER)
	local template = kit
		and (kit:FindFirstChild(`{object.kind}{object.family or ""}`) or kit:FindFirstChild(object.kind))
	return if template and template:IsA("Model") then template else nil
end

-- A thing's model: its template stood on the floor at its cells, or a
-- plain block. Either way it gets an invisible Hook part filling its cells
-- up to its top, for prompts and labels.
local function buildThing(yard: Yard, object: Object): Model
	local floor = PlotService.objectCFrame(yard, object)
	local footprint = YardConfig.FOOTPRINTS[object.kind]
	local width, depth = footprint.width * YardConfig.CELL, footprint.depth * YardConfig.CELL

	local model: Model
	local height = PLACEHOLDER_HEIGHTS[object.kind] or 1
	local template = templateFor(object)
	if template then
		model = template:Clone()
		-- Stand the template's bounding box, not its pivot, on the floor.
		local box, size = model:GetBoundingBox()
		model:PivotTo(floor * CFrame.new(0, size.Y / 2, 0) * box:ToObjectSpace(model:GetPivot()))
		height = size.Y
	else
		model = Instance.new("Model")
		local block = hookPart("Body", Vector3.new(width, height, depth), floor * CFrame.new(0, height / 2, 0), model)
		block.Transparency = 0
		block.CanCollide = true
		block.CanQuery = true
		block.Color = PLACEHOLDER_COLORS[object.family or object.kind] or FLOOR_COLOR
		block.Material = if object.kind == "Mound" then Enum.Material.Slate else Enum.Material.Metal
	end

	model.Name = `{object.kind}{object.id}`
	model:SetAttribute("ObjectId", object.id)
	model:SetAttribute("Kind", object.kind)
	model:SetAttribute("Family", object.family)
	model:SetAttribute("CellX", object.x)
	model:SetAttribute("CellZ", object.z)
	model:SetAttribute("Turn", object.turn)

	local hook = hookPart("Hook", Vector3.new(width, height, depth), floor * CFrame.new(0, height / 2, 0), model)
	model.PrimaryPart = hook
	model.Parent = yard.model

	return model
end

function PlotService.getYards(): { Yard }
	return yards
end

function PlotService.yardOf(player: Player): Yard?
	return yardByPlayer[player]
end

function PlotService.yardAt(position: Vector3): Yard?
	for _, yard in yards do
		if YardGrid.contains(yard.origin, yard.yaw, position) then
			return yard
		end
	end

	return nil
end

function PlotService.spawnCFrame(yard: Yard): CFrame
	local spawn = YardGrid.toWorld(yard.origin, yard.yaw, YardGrid.SPAWN_OFFSET)
	-- Face into the yard on spawn, so the first thing a player sees is theirs.
	return CFrame.lookAt(spawn, Vector3.new(yard.origin.X, spawn.Y, yard.origin.Z))
end

function PlotService.objectsOf(player: Player): { Object }
	local data = DataService.getData(player)
	return if data then data.yard.objects else {}
end

function PlotService.objectOf(player: Player, objectId: number): Object?
	for _, object in PlotService.objectsOf(player) do
		if object.id == objectId then
			return object
		end
	end

	return nil
end

function PlotService.thingOf(yard: Yard, objectId: number): Model?
	return yard.things[objectId]
end

-- Where something set down on a thing rests: the thing's surface under its
-- middle, turned as the thing is. A thing's Hook is its art's whole
-- bounding box, which reaches up to whatever stands tallest on it (a pad's
-- junction box, a bay's lamp posts), so the surface is found by dropping a
-- ray onto the art itself.
function PlotService.seatOf(model: Model): CFrame
	local hook = model.PrimaryPart :: BasePart
	local top = hook.CFrame * CFrame.new(0, hook.Size.Y / 2, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local hit = workspace:Raycast(top.Position + Vector3.new(0, 1, 0), Vector3.new(0, -hook.Size.Y - 2, 0), params)

	return if hit then top.Rotation + hit.Position else top
end

function PlotService.rebuildThing(yard: Yard, object: Object)
	local old = yard.things[object.id]
	if old then
		old:Destroy()
	end

	local model = buildThing(yard, object)
	yard.things[object.id] = model
	PlotService.thingBuilt:fire(yard, object, model)
end

local function clearThings(yard: Yard)
	for _, model in yard.things do
		model:Destroy()
	end
	yard.things = {}
end

-- Lays a sheet of rubble over every parcel the owner hasn't cleared yet,
-- so they can see which land is still to come. It can be walked over.
local function showLand(yard: Yard)
	local old = yard.model:FindFirstChild(RUBBLE_FOLDER)
	if old then
		old:Destroy()
	end
	local data = if yard.owner then DataService.getData(yard.owner) else nil
	if not data then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = RUBBLE_FOLDER
	local cleared = BuildRules.clearedParcels(data.rank)
	local width = YardConfig.PARCEL_WIDTH * YardConfig.CELL
	local depth = YardConfig.PARCEL_DEPTH * YardConfig.CELL
	for parcel = 1, YardConfig.PARCEL_COLUMNS * YardConfig.PARCEL_ROWS do
		if not table.find(cleared, parcel) then
			local column = (parcel - 1) % YardConfig.PARCEL_COLUMNS
			local row = math.floor((parcel - 1) / YardConfig.PARCEL_COLUMNS)
			local middle = Vector3.new(
				(column + 0.5) * width - YardGrid.WIDTH / 2,
				RUBBLE_THICKNESS / 2,
				(row + 0.5) * depth - YardGrid.DEPTH / 2
			)
			local sheet = hookPart(
				`Rubble{parcel}`,
				Vector3.new(width - 1, RUBBLE_THICKNESS, depth - 1),
				yardCFrame(yard, middle),
				folder
			)
			sheet.Transparency = 0
			sheet.Color = RUBBLE_COLOR
			sheet.Material = Enum.Material.Slate
		end
	end
	folder.Parent = yard.model
end

function PlotService.rebuildYard(yard: Yard)
	clearThings(yard)
	showLand(yard)
	if yard.owner then
		for _, object in PlotService.objectsOf(yard.owner) do
			PlotService.rebuildThing(yard, object)
		end
	end
end

-- Calls back (yard, object, model) for every thing standing now and every
-- one built from here on. Services call this in start: yards may already
-- have owners by then.
function PlotService.forEachThing(callback: (Yard, Object, Model) -> ())
	PlotService.thingBuilt:connect(callback)
	for _, yard in yards do
		local objects: { Object } = if yard.owner then PlotService.objectsOf(yard.owner) else {}
		for _, object in objects do
			local model = yard.things[object.id]
			if model then
				task.spawn(callback, yard, object, model)
			end
		end
	end
end

function PlotService.incomeOf(player: Player): number
	local data = DataService.getData(player)
	if not data then
		return 0
	end

	local multiplier = RebirthRules.incomeMultiplier(data.rank) * ShopService.productionMultiplier(player)
	return JunkrotRules.yardIncome(data.yard.objects, multiplier)
end

function PlotService.crateCapacity(player: Player): number
	local capacity = JunkrotRules.crateCapacity(PlotService.incomeOf(player))
	return if ShopService.hasPass(player, "BigCrate") then math.floor(capacity * Shop.BIG_CRATE) else capacity
end

function PlotService.getCrate(player: Player): number
	local data = DataService.getData(player)
	return if data then data.yard.crateScrap else 0
end

-- The crate's thing shows what it holds; the HUD reads the player's own.
local function showCrate(player: Player)
	local yard = yardByPlayer[player]
	local data = DataService.getData(player)
	if not yard or not data then
		return
	end

	local scrap = math.floor(data.yard.crateScrap)
	local capacity = PlotService.crateCapacity(player)
	player:SetAttribute("CrateScrap", scrap)
	player:SetAttribute("CrateCapacity", capacity)
	for _, object in data.yard.objects do
		local thing = if object.kind == "Crate" then yard.things[object.id] else nil
		if thing then
			thing:SetAttribute("Scrap", scrap)
			thing:SetAttribute("Capacity", capacity)
		end
	end
end

function PlotService.refreshIncome(player: Player)
	local data = DataService.getData(player)
	local yard = yardByPlayer[player]
	if not data then
		return
	end

	player:SetAttribute("Income", PlotService.incomeOf(player))
	player:SetAttribute("Rank", data.rank)
	player:SetAttribute("Parts", data.parts)
	if yard then
		yard.model:SetAttribute("Rank", data.rank)
	end
	showCrate(player)
end

function PlotService.setCrate(player: Player, scrap: number)
	local data = DataService.getData(player)
	if not data then
		return
	end

	data.yard.crateScrap = math.max(0, scrap)
	showCrate(player)
end

-- A full crate takes no more: the rest is lost.
function PlotService.addToCrate(player: Player, amount: number): number
	local before = PlotService.getCrate(player)
	local room = math.max(0, PlotService.crateCapacity(player) - before)
	local stored = math.clamp(amount, 0, room)
	PlotService.setCrate(player, before + stored)

	return stored
end

function PlotService.takeFromCrate(player: Player, amount: number): number
	local before = PlotService.getCrate(player)
	-- DUPE-SAFE: never take more than is there, and take whole scrap, so
	-- what leaves the crate is exactly what the taker receives.
	local taken = math.clamp(math.floor(amount), 0, math.floor(before))
	PlotService.setCrate(player, before - taken)

	return taken
end

local function moveToYard(player: Player)
	local yard = yardByPlayer[player]
	local character = player.Character
	if not yard or not character then
		return
	end

	character:WaitForChild("HumanoidRootPart")
	if character.Parent then
		character:PivotTo(PlotService.spawnCFrame(yard))
	end
end

local function assignYard(player: Player, data: any)
	if yardByPlayer[player] then
		return
	end

	for _, yard in yards do
		if yard.owner == nil then
			if #data.yard.objects == 0 then
				data.yard.objects = BuildRules.starterObjects()
				data.yard.nextObjectId = #data.yard.objects + 1
				Notify.Message:FireClient(player, WELCOME_TEXT)
			end

			yard.owner = player
			yardByPlayer[player] = yard
			yard.model:SetAttribute("OwnerUserId", player.UserId)
			yard.markerLabel.Text = `{player.DisplayName}'s Yard`
			player:SetAttribute("YardIndex", yard.index)

			PlotService.rebuildYard(yard)
			PlotService.refreshIncome(player)
			PlotService.yardAssigned:fire(player, yard)
			task.spawn(moveToYard, player)
			return
		end
	end

	-- More players than yards: they can still fight and trade, just not
	-- build. Server size should match Game.YARD_COUNT to avoid this.
	warn(`[PlotService] no free yard for {player.Name}`)
end

local function releaseYard(player: Player)
	local yard = yardByPlayer[player]
	if not yard then
		return
	end

	yardByPlayer[player] = nil
	PlotService.yardReleased:fire(player, yard)

	yard.owner = nil
	yard.model:SetAttribute("OwnerUserId", 0)
	yard.model:SetAttribute("Rank", 0)
	yard.markerLabel.Text = FREE_YARD_TEXT
	clearThings(yard)
	showLand(yard)
end

function PlotService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Yards"
	folder.Parent = workspace

	-- Built in init so every other service can use the yards in its start.
	for index = 1, Game.YARD_COUNT do
		table.insert(yards, buildYard(index, folder))
	end
end

function PlotService.start()
	DataService.forEachLoaded(assignYard)
	-- Released while the profile is still open, so listeners can save.
	DataService.profileReleasing:connect(releaseYard)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			moveToYard(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return PlotService
