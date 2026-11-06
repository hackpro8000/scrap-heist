--!strict
--[[
	BeltController

	Slides the capsules on the belt smoothly. The server only moves them a
	few times a second (BeltService); each carries its distance along the
	belt, when that was true and its speed (Distance, DistanceAt in server
	time, Speed), so every frame this puts each one where it is by now on
	the same path the server uses (Shared/Belt/BeltRules).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Belt = require(ReplicatedStorage.Shared.Config.Belt)
local BeltRules = require(ReplicatedStorage.Shared.Belt.BeltRules)

local BeltController = {}

local function slide(capsules: Instance)
	local now = workspace:GetServerTimeNow()
	local lap = BeltRules.lapLength()
	for _, body in capsules:GetChildren() do
		local distance = body:GetAttribute("Distance")
		local distanceAt = body:GetAttribute("DistanceAt")
		local speed = body:GetAttribute("Speed")
		if
			not body:IsA("BasePart")
			or type(distance) ~= "number"
			or type(distanceAt) ~= "number"
			or type(speed) ~= "number"
		then
			continue
		end

		-- Short of the lap's end: the server takes it off the belt there.
		local along = math.min(distance + (now - distanceAt) * speed, lap - 0.01)
		local x, z, headingX, headingZ = BeltRules.pointAt(along)
		local position = Vector3.new(x, Belt.HEIGHT + body.Size.Y / 2, z)
		body.CFrame = CFrame.lookAt(position, position + Vector3.new(headingX, 0, headingZ))
	end
end

function BeltController.init() end

function BeltController.start()
	task.spawn(function()
		local capsules = workspace:WaitForChild("Belt"):WaitForChild("Capsules")
		RunService.RenderStepped:Connect(function()
			slide(capsules)
		end)
	end)
end

return BeltController
