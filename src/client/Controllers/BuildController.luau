--!strict
--[[
	BuildController

	Build mode: the player lays out their own yard. Opened from the HUD's
	Build button.

	With nothing in hand, pointing at a thing in the yard picks it up, and
	the bar offers whatever the player's rank has earned but they haven't
	placed yet (a pad of each family, a build bay). With something in hand,
	a ghost of it follows the pointer over the plot's grid, green where it
	may stand and red where it may not, with why. It turns a quarter turn
	(the Turn button, or R), drops (a click, or the Place button after a
	tap on a phone), or goes back where it was (Cancel, or Q).

	The ghost is checked with the same rules the server uses
	(Shared/Yard/BuildRules), from what stands in the yard as the server
	built it: each thing's model says what it is and where (ObjectId, Kind,
	Family, CellX, CellZ, Turn). The server checks every drop again and has
	the last word (BuildService).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BuildRules = require(ReplicatedStorage.Shared.Yard.BuildRules)
local Junkrots = require(ReplicatedStorage.Shared.Config.Junkrots)
local React = require(ReplicatedStorage.Packages.React)
local Remotes = require(ReplicatedStorage.Shared.Net.Build)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local YardConfig = require(ReplicatedStorage.Shared.Config.Yard)
local YardGrid = require(ReplicatedStorage.Shared.Yard.YardGrid)

local HudController = require(script.Parent.HudController)
local Kit = require(script.Parent.Parent.UI.Kit)
local BuildScreen = require(script.Parent.Parent.UI.Screens.Build)

local localPlayer = Players.LocalPlayer

local MENU_ORDER = 5
local GHOST_HEIGHT = 0.6
-- An id no saved thing has, for a thing not yet placed.
local NEW_ID = -1
local IDLE_HINT = "Tap something in your yard to move it"
local HELD_HINT = "Move it where you want it"

type Held = {
	-- NEW_ID for a thing being added.
	id: number,
	kind: string,
	family: string?,
	turn: number,
	x: number,
	z: number,
	-- Whether the pointer has put it anywhere yet.
	aimed: boolean,
}

local BuildController = {}

local root: Kit.Root
local building = false
local held: Held? = nil
local ghost: Part? = nil
local hint = IDLE_HINT

local function ownYard(): Instance?
	local yards = workspace:FindFirstChild("Yards")
	for _, yard in if yards then yards:GetChildren() else {} do
		if yard:GetAttribute("OwnerUserId") == localPlayer.UserId then
			return yard
		end
	end

	return nil
end

-- What stands in the yard, as the server built it.
local function objectsIn(yard: Instance): { YardGrid.Object }
	local objects = {}
	for _, thing in yard:GetChildren() do
		local id = thing:GetAttribute("ObjectId")
		if type(id) == "number" then
			table.insert(objects, {
				id = id,
				kind = thing:GetAttribute("Kind") :: string,
				family = thing:GetAttribute("Family") :: string?,
				x = thing:GetAttribute("CellX") :: number,
				z = thing:GetAttribute("CellZ") :: number,
				turn = thing:GetAttribute("Turn") :: number,
			})
		end
	end

	return objects
end

local function rankOf(yard: Instance): number
	return yard:GetAttribute("Rank") :: number? or 0
end

-- Why the thing in hand can't stand where it is, or nil if it can.
local function refusal(yard: Instance, holding: Held): string?
	local objects = objectsIn(yard)
	local rank = rankOf(yard)
	if holding.id == NEW_ID then
		local reason = BuildRules.canAdd(objects, rank, holding.kind)
		if reason then
			return reason
		end
	end

	return BuildRules.canPlace(objects, BuildRules.clearedParcels(rank), {
		id = holding.id,
		kind = holding.kind,
		family = holding.family,
		x = holding.x,
		z = holding.z,
		turn = holding.turn,
	})
end

local function ghostPart(): Part
	if ghost then
		return ghost
	end

	local part = Instance.new("Part")
	part.Name = "BuildGhost"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.5
	part.Parent = workspace
	ghost = part

	return part
end

local function showGhost()
	local yard = ownYard()
	local holding = held
	if not building or not yard or not holding or not holding.aimed then
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		return
	end

	local part = ghostPart()

	local origin = yard:GetAttribute("Origin") :: Vector3
	local yaw = yard:GetAttribute("Yaw") :: number
	local width, depth = YardGrid.footprint(holding.kind, holding.turn)
	local centre = YardGrid.centre(holding) + Vector3.new(0, GHOST_HEIGHT / 2, 0)
	part.Size = Vector3.new(width * YardConfig.CELL, GHOST_HEIGHT, depth * YardConfig.CELL)
	part.CFrame = CFrame.new(YardGrid.toWorld(origin, yaw, centre)) * CFrame.Angles(0, yaw, 0)

	local reason = refusal(yard, holding)
	part.Color = if reason then Theme.Colors.Bad else Theme.Colors.Good
	hint = if reason then BuildRules.REASON_TEXT[reason] or "It can't go there" else HELD_HINT
end

local render: () -> ()

local function drop()
	held = nil
	hint = IDLE_HINT
	showGhost()
	render()
end

local function turn()
	local holding = held
	if holding then
		holding.turn = (holding.turn + 1) % 4
		showGhost()
		render()
	end
end

local function place()
	local yard = ownYard()
	local holding = held
	if not yard or not holding or not holding.aimed then
		return
	end
	if refusal(yard, holding) then
		-- The ghost is red and the bar says why.
		return
	end

	if holding.id == NEW_ID then
		Remotes.Add:FireServer(holding.kind, holding.family, holding.x, holding.z, holding.turn)
	else
		Remotes.Move:FireServer(holding.id, holding.x, holding.z, holding.turn)
	end
	drop()
end

local function pickUpNew(kind: string, family: string?)
	held = { id = NEW_ID, kind = kind, family = family, turn = 0, x = 0, z = 0, aimed = false }
	hint = HELD_HINT
	showGhost()
	render()
end

-- The cell of the plot under a point on the screen, if it is over the plot.
local function cellUnder(yard: Instance, screen: Vector2): (number?, number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local origin = yard:GetAttribute("Origin") :: Vector3
	local yaw = yard:GetAttribute("Yaw") :: number
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	if ray.Direction.Y >= -1e-3 then
		return nil, nil
	end

	local reach = (origin.Y - ray.Origin.Y) / ray.Direction.Y
	local x, z = YardGrid.cellAt(YardGrid.toLocal(origin, yaw, ray.Origin + ray.Direction * reach))
	if x < 0 or z < 0 or x >= YardConfig.COLUMNS or z >= YardConfig.ROWS then
		return nil, nil
	end

	return x, z
end

-- Puts the thing in hand under the pointer, its middle on the pointed cell.
local function aim(screen: Vector2)
	local yard = ownYard()
	local holding = held
	if not yard or not holding then
		return
	end
	local x, z = cellUnder(yard, screen)
	if not x or not z then
		return
	end

	local width, depth = YardGrid.footprint(holding.kind, holding.turn)
	holding.x = math.clamp(x - width // 2, 0, YardConfig.COLUMNS - width)
	holding.z = math.clamp(z - depth // 2, 0, YardConfig.ROWS - depth)
	holding.aimed = true
	showGhost()
	render()
end

local function pickUpAt(screen: Vector2)
	local yard = ownYard()
	if not yard then
		return
	end
	local x, z = cellUnder(yard, screen)
	if not x or not z then
		return
	end

	for _, object in objectsIn(yard) do
		local width, depth = YardGrid.footprint(object.kind, object.turn)
		if x >= object.x and x < object.x + width and z >= object.z and z < object.z + depth then
			held = {
				id = object.id,
				kind = object.kind,
				family = object.family,
				turn = object.turn,
				x = object.x,
				z = object.z,
				aimed = true,
			}
			hint = HELD_HINT
			showGhost()
			render()
			return
		end
	end
end

-- What the player's rank allows that they haven't placed yet.
local function owedButtons(yard: Instance): { BuildScreen.BarButton }
	local objects = objectsIn(yard)
	local allowed = BuildRules.allowance(rankOf(yard))
	local buttons = {}
	if BuildRules.count(objects, "Pad") < allowed.Pad then
		for _, family in Junkrots.FAMILIES do
			table.insert(buttons, {
				text = `{string.upper(family)} PAD`,
				kind = "Action",
				onClick = function()
					pickUpNew("Pad", family)
				end,
			})
		end
	end
	if BuildRules.count(objects, "Bay") < allowed.Bay then
		table.insert(buttons, {
			text = "BUILD BAY",
			kind = "Action",
			onClick = function()
				pickUpNew("Bay", nil)
			end,
		})
	end

	return buttons
end

local function toggle()
	building = not building
	held = nil
	hint = if ownYard() then IDLE_HINT else "You need a yard to build in"
	showGhost()
	render()
end

render = function()
	local yard = ownYard()
	local buttons: { BuildScreen.BarButton } = {}
	if building and yard and held then
		buttons = {
			{ text = "TURN", onClick = turn },
			{ text = "PLACE", kind = "Action", enabled = held.aimed, onClick = place },
			{ text = "CANCEL", kind = "Danger", onClick = drop },
		}
	elseif building and yard then
		buttons = owedButtons(yard)
		table.insert(buttons, { text = "DONE", kind = "Danger", onClick = toggle })
	elseif building then
		buttons = { { text = "DONE", kind = "Danger", onClick = toggle } }
	end

	root.render(React.createElement(BuildScreen, {
		open = building,
		hint = hint,
		buttons = buttons,
	}))
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if not building or gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if held then
			aim(UserInputService:GetMouseLocation())
			place()
		else
			pickUpAt(UserInputService:GetMouseLocation())
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		-- A finger hides what it points at, so a tap only aims; the Place
		-- button drops. Touch positions leave out the top bar's inset.
		local screen = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		if held then
			aim(screen)
		else
			pickUpAt(screen)
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		turn()
	elseif input.KeyCode == Enum.KeyCode.Q and held then
		drop()
	end
end

function BuildController.init()
	root = Kit.mount("Build", 5)
	render()
end

function BuildController.start()
	HudController.addButton("Build", MENU_ORDER, toggle)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if building and held and input.UserInputType == Enum.UserInputType.MouseMovement then
			aim(UserInputService:GetMouseLocation())
		end
	end)
end

return BuildController
