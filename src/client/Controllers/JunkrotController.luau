--!strict
--[[
	JunkrotController

	Gives every junkrot standing on a pad its idle loop: a little bounce
	and a sway from side to side, each one out of step with its neighbours.
	The server stands junkrots still (JunkrotService); this only moves what
	the local player sees, and only the ones near the camera.
]]

local RunService = game:GetService("RunService")

local JUNKROT_NAME = "Junkrot"
-- Studs from the camera past which junkrots stand still.
local IDLE_DISTANCE = 140
local BOUNCE_HEIGHT = 0.18
local BOUNCE_SPEED = 5
local SWAY_DEGREES = 5
local SWAY_SPEED = 2.2

type Idler = {
	model: Model,
	-- Where the server stood it, and the point on the ground under it that
	-- it sways about.
	home: CFrame,
	foot: CFrame,
	offset: number,
}

local JunkrotController = {}

local idlers: { [Model]: Idler } = {}

local function watch(instance: Instance)
	if instance.Name ~= JUNKROT_NAME or not instance:IsA("Model") or idlers[instance] then
		return
	end
	-- Its parts may still be streaming in.
	task.defer(function()
		if not instance:IsDescendantOf(workspace) then
			return
		end
		local home = instance:GetPivot()
		local box, size = instance:GetBoundingBox()
		idlers[instance] = {
			model = instance,
			home = home,
			foot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)),
			-- Out of step with the others, by where it stands.
			offset = (home.Position.X * 0.37 + home.Position.Z * 0.61) % 6.28,
		}
	end)
end

local function idle()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local eye = camera.CFrame.Position
	for model, idler in idlers do
		if not model:IsDescendantOf(workspace) then
			idlers[model] = nil
			continue
		end
		if (idler.home.Position - eye).Magnitude > IDLE_DISTANCE then
			continue
		end

		local bounce = math.abs(math.sin(now * BOUNCE_SPEED + idler.offset)) * BOUNCE_HEIGHT
		local sway = math.rad(math.sin(now * SWAY_SPEED + idler.offset) * SWAY_DEGREES)
		-- Sway about the feet, so they stay planted on the pad.
		local moved = idler.foot * CFrame.new(0, bounce, 0) * CFrame.Angles(0, 0, sway) * idler.foot:Inverse()
		model:PivotTo(moved * idler.home)
	end
end

function JunkrotController.init() end

function JunkrotController.start()
	task.spawn(function()
		local yards = workspace:WaitForChild("Yards")
		for _, descendant in yards:GetDescendants() do
			watch(descendant)
		end
		yards.DescendantAdded:Connect(watch)
		RunService.RenderStepped:Connect(idle)
	end)
end

return JunkrotController
