--!strict
--[[
	PropellerController

	Spins the arena drone's four propellers, on this client only. Each
	propeller is a blade, a blur disc, a hub and tip caps (ArenaDrone's
	Prop<n>, PropDisc<n>, PropHub<n> and PropTips<n> in workspace.Map). Its
	motor leans in towards the drone's middle, so the propeller turns about
	its shaft: through the hub, tipped MOTOR_TILT from upright towards the
	middle. The tilt is baked into the meshes, so the parts themselves sit
	upright and their own axes are no use. Every part of a propeller turns by
	the same angle, so the smear painted on its disc stays trailing its
	blades. Anticlockwise from above, the way the art paints the smear.

	The place streams, so parts come and go as the player moves: each is
	picked up when it streams in, from where it rests, and dropped when it
	streams out. A propeller spins once its hub is in, since the hub fixes
	its shaft.

	Public API: none.
]]

local RunService = game:GetService("RunService")

-- Turns per second.
local SPIN_SPEED = 2
-- How far each motor leans in (MOTOR_TILT in art/src/items/ArenaDrone.luau).
local MOTOR_TILT = math.rad(8)
local PROPELLER_PART = "^Prop%a*(%d+)$"

type Propeller = {
	-- Each part and where it rests.
	parts: { [BasePart]: CFrame },
	-- Through the hub, along the shaft; nil until the hub streams in.
	shaft: CFrame?,
}

local PropellerController = {}

local propellers: { [string]: Propeller } = {}
local angle = 0

-- The shaft through `hub`: its axis tipped from upright towards the
-- drone's middle, as a CFrame whose Y axis runs along it.
local function shaftThrough(hub: BasePart, droneCentre: Vector3): CFrame
	local outward = ((hub.Position - droneCentre) * Vector3.new(1, 0, 1)).Unit
	local axis = Vector3.yAxis * math.cos(MOTOR_TILT) - outward * math.sin(MOTOR_TILT)
	return CFrame.fromMatrix(hub.Position, axis:Cross(outward).Unit, axis)
end

local function propellerFor(index: string): Propeller
	local propeller = propellers[index]
	if not propeller then
		propeller = { parts = {}, shaft = nil }
		propellers[index] = propeller
	end
	return propeller
end

local function track(child: Instance, drone: Model)
	if not child:IsA("BasePart") then
		return
	end
	local index = string.match(child.Name, PROPELLER_PART)
	if not index then
		return
	end
	local propeller = propellerFor(index)
	propeller.parts[child] = child.CFrame
	if child.Name == `PropHub{index}` then
		propeller.shaft = shaftThrough(child, drone:GetPivot().Position)
	end
end

local function untrack(child: Instance)
	local index = string.match(child.Name, PROPELLER_PART)
	local propeller = index and propellers[index]
	if not (propeller and child:IsA("BasePart")) then
		return
	end
	propeller.parts[child] = nil
	if child.Name == `PropHub{index}` then
		propeller.shaft = nil
	end
end

local function spin(deltaTime: number)
	angle = (angle + deltaTime * SPIN_SPEED * math.pi * 2) % (math.pi * 2)
	-- A turn about the shaft's own Y axis, carried out in world space.
	local turn = CFrame.Angles(0, angle, 0)
	local parts, cframes = {}, {}
	for _, propeller in propellers do
		local shaft = propeller.shaft
		if not shaft then
			continue
		end
		local turned = shaft * turn * shaft:Inverse()
		for part, rest in propeller.parts do
			table.insert(parts, part)
			table.insert(cframes, turned * rest)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function PropellerController.init() end

function PropellerController.start()
	-- Waits off the boot thread: the map may still be streaming in.
	task.spawn(function()
		local drone = workspace:WaitForChild("Map"):WaitForChild("ArenaDrone") :: Model
		for _, child in drone:GetChildren() do
			track(child, drone)
		end
		drone.ChildAdded:Connect(function(child)
			track(child, drone)
		end)
		drone.ChildRemoved:Connect(untrack)
		RunService.Heartbeat:Connect(spin)
	end)
end

return PropellerController
