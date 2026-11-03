--!strict
--[[
	PlotService

	Owns the yards: builds them, hands one to each player when their profile
	loads, spawns them there, and frees it when they leave. Also owns the
	storage crate's contents (saved in the owner's profile as
	yard.crateParts): MachineService fills it, the owner collects it,
	RaidService steals from it.

	Yard models come from ServerStorage.YardTemplate if Tristen has added
	one (a Model with parts or models named Pad1-Pad4, Crate and PlotMarker),
	otherwise gray-block placeholders are built. Placement comes from parts
	named Yard1, Yard2, ... in a workspace folder called YardSpots if it
	exists, otherwise a ring around the map centre (see Tycoon/YardLayout).

	Public API:
		PlotService.getYards(): { Yard }
		PlotService.yardOf(player): Yard?
		PlotService.yardAt(position): Yard?
		PlotService.getCrateParts(player): number
		PlotService.setCrateParts(player, parts)
		PlotService.addToCrate(player, amount): number   -- amount actually added
		PlotService.takeFromCrate(player, amount): number -- amount actually taken
		PlotService.spawnCFrame(yard): CFrame
		PlotService.yardAssigned: Signal(player, yard)
		PlotService.yardReleased: Signal(player, yard)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local YardLayout = require(script.Parent.Parent.Tycoon.YardLayout)

local YARD_TEMPLATE_NAME = "YardTemplate"
local YARD_SPOTS_FOLDER = "YardSpots"
local FREE_YARD_TEXT = "Free yard"

local FLOOR_COLOR = Color3.fromRGB(110, 110, 105)
local PAD_COLOR = Color3.fromRGB(70, 72, 78)
local CRATE_COLOR = Color3.fromRGB(70, 130, 70)
local MARKER_COLOR = Color3.fromRGB(200, 160, 60)

export type Yard = {
	index: number,
	origin: Vector3,
	yaw: number,
	model: Model,
	pads: { [string]: BasePart },
	crate: BasePart,
	marker: BasePart,
	owner: Player?,
	crateLabel: TextLabel,
	markerLabel: TextLabel,
}

local PlotService = {}

PlotService.yardAssigned = Signal.new()
PlotService.yardReleased = Signal.new()

local yards: { Yard } = {}
local yardByPlayer: { [Player]: Yard } = {}

local function yardCFrame(origin: Vector3, yaw: number, offset: Vector3?): CFrame
	local position = if offset then YardLayout.toWorld(origin, yaw, offset) else origin
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

local function placeholderPart(name: string, size: Vector3, color: Color3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = cframe
	part.Parent = parent

	return part
end

local function buildPlaceholderYard(origin: Vector3, yaw: number): Model
	local model = Instance.new("Model")
	local size = YardLayout.SIZE

	-- Each part is placed by its centre, so lift it by half its height to
	-- sit on the floor's top surface (the yard origin).
	local function place(name: string, partSize: Vector3, color: Color3, offset: Vector3): Part
		return placeholderPart(
			name,
			partSize,
			color,
			yardCFrame(origin, yaw, offset + Vector3.new(0, partSize.Y / 2, 0)),
			model
		)
	end

	-- The floor's top surface is the yard origin.
	local floorCFrame = yardCFrame(origin, yaw, Vector3.new(0, -0.5, 0))
	model.PrimaryPart = placeholderPart("Floor", Vector3.new(size, 1, size), FLOOR_COLOR, floorCFrame, model)

	for padName, offset in YardLayout.PAD_OFFSETS do
		place(padName, Vector3.new(6, 0.4, 6), PAD_COLOR, offset)
	end
	place("Crate", Vector3.new(5, 4, 5), CRATE_COLOR, YardLayout.CRATE_OFFSET)
	place("PlotMarker", Vector3.new(2.3, 3.3, 1.1), MARKER_COLOR, YardLayout.MARKER_OFFSET)

	return model
end

-- Finds a named piece in a yard model; template pieces may be Models, in
-- which case their PrimaryPart (or first part) stands in for them.
local function partNamed(model: Model, name: string): BasePart
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	if found and found:IsA("Model") then
		local part = found.PrimaryPart or found:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part
		end
	end

	error(`PlotService: yard model is missing a part named {name}`)
end

local function billboard(adornee: BasePart, studsOffset: Vector3, text: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(8, 0, 2, 0)
	gui.StudsOffset = studsOffset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
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

local function placement(index: number): (Vector3, number)
	local spots = workspace:FindFirstChild(YARD_SPOTS_FOLDER)
	local spot = spots and spots:FindFirstChild(`Yard{index}`)
	if spot and spot:IsA("BasePart") then
		local _, yaw = spot.CFrame:ToOrientation()
		return spot.Position, yaw
	end

	return YardLayout.ringPlacement(index, Game.YARD_COUNT)
end

local function buildYard(index: number, folder: Folder): Yard
	local origin, yaw = placement(index)

	local template = ServerStorage:FindFirstChild(YARD_TEMPLATE_NAME)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		model:PivotTo(yardCFrame(origin, yaw))
	else
		model = buildPlaceholderYard(origin, yaw)
	end
	model.Name = `Yard{index}`
	model:SetAttribute("YardIndex", index)
	-- Clients read this to show owner-only prompts to the owner only.
	model:SetAttribute("OwnerUserId", 0)
	model.Parent = folder

	local pads = {}
	for _, padName in Economy.PADS do
		pads[padName] = partNamed(model, padName)
	end
	local crate = partNamed(model, "Crate")
	local marker = partNamed(model, "PlotMarker")

	return {
		index = index,
		origin = origin,
		yaw = yaw,
		model = model,
		pads = pads,
		crate = crate,
		marker = marker,
		owner = nil,
		crateLabel = billboard(crate, Vector3.new(0, 4, 0), ""),
		markerLabel = billboard(marker, Vector3.new(0, 5, 0), FREE_YARD_TEXT),
	}
end

local function showCrate(yard: Yard, parts: number)
	yard.crateLabel.Text = if yard.owner then `{math.floor(parts)} / {Economy.CRATE_CAPACITY} parts` else ""
	yard.crate:SetAttribute("Parts", math.floor(parts))
end

function PlotService.getYards(): { Yard }
	return yards
end

function PlotService.yardOf(player: Player): Yard?
	return yardByPlayer[player]
end

function PlotService.yardAt(position: Vector3): Yard?
	for _, yard in yards do
		if YardLayout.contains(yard.origin, yard.yaw, position) then
			return yard
		end
	end

	return nil
end

function PlotService.spawnCFrame(yard: Yard): CFrame
	local spawn = YardLayout.toWorld(yard.origin, yard.yaw, YardLayout.SPAWN_OFFSET)
	local crate = YardLayout.toWorld(yard.origin, yard.yaw, YardLayout.CRATE_OFFSET)
	-- Face the crate on spawn, so the first thing a player sees is their yard.
	return CFrame.lookAt(spawn, Vector3.new(crate.X, spawn.Y, crate.Z))
end

function PlotService.getCrateParts(player: Player): number
	local data = DataService.getData(player)
	return if data then data.yard.crateParts else 0
end

function PlotService.setCrateParts(player: Player, parts: number)
	local data = DataService.getData(player)
	if not data then
		return
	end

	data.yard.crateParts = math.clamp(parts, 0, Economy.CRATE_CAPACITY)
	local yard = yardByPlayer[player]
	if yard then
		showCrate(yard, data.yard.crateParts)
	end
end

function PlotService.addToCrate(player: Player, amount: number): number
	local before = PlotService.getCrateParts(player)
	PlotService.setCrateParts(player, before + math.max(0, amount))

	return PlotService.getCrateParts(player) - before
end

function PlotService.takeFromCrate(player: Player, amount: number): number
	local before = PlotService.getCrateParts(player)
	-- DUPE-SAFE: never take more than is there, and take in whole parts, so
	-- what leaves the crate is exactly what the taker receives.
	local taken = math.clamp(math.floor(amount), 0, math.floor(before))
	PlotService.setCrateParts(player, before - taken)

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
			yard.owner = player
			yardByPlayer[player] = yard
			yard.model:SetAttribute("OwnerUserId", player.UserId)
			yard.markerLabel.Text = `{player.DisplayName}'s Yard`
			showCrate(yard, data.yard.crateParts)
			player:SetAttribute("YardIndex", yard.index)

			PlotService.yardAssigned:fire(player, yard)
			task.spawn(moveToYard, player)
			return
		end
	end

	-- More players than yards: they can still fight, raid and trade, just
	-- not build. Server size should match Game.YARD_COUNT to avoid this.
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
	yard.markerLabel.Text = FREE_YARD_TEXT
	showCrate(yard, 0)
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
