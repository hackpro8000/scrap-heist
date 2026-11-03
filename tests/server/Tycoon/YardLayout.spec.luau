--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local YardLayout = Source.require("src/server/Tycoon/YardLayout")

local function near(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 1e-6
end

describe("YardLayout", function()
	it("turns every ring yard's gate toward the map centre", function()
		local count = 8
		for index = 1, count do
			local origin, yaw = YardLayout.ringPlacement(index, count)
			local gate = YardLayout.toWorld(origin, yaw, YardLayout.GATE_OFFSET)

			expect(gate.Magnitude < origin.Magnitude).toBe(true)
		end
	end)

	it("spaces ring yards so they don't overlap", function()
		local count = 8
		for index = 1, count do
			local a = YardLayout.ringPlacement(index, count)
			local b = YardLayout.ringPlacement(index % count + 1, count)
			expect((a - b).Magnitude > YardLayout.SIZE * 1.5).toBe(true)
		end
	end)

	it("converts between world and yard space both ways", function()
		local origin, yaw = Vector3.new(50, 10, -30), math.rad(70)
		local offset = Vector3.new(3, 2, -7)

		local world = YardLayout.toWorld(origin, yaw, offset)

		expect(near(YardLayout.toLocal(origin, yaw, world), offset)).toBe(true)
	end)

	it("rotates offsets the way Roblox's CFrame.Angles does", function()
		-- A 90 degree turn takes yard +X to world -Z, and +Z to world +X.
		local yaw = math.rad(90)

		expect(near(YardLayout.toWorld(Vector3.zero, yaw, Vector3.new(1, 0, 0)), Vector3.new(0, 0, -1))).toBe(true)
		expect(near(YardLayout.toWorld(Vector3.zero, yaw, Vector3.new(0, 0, 1)), Vector3.new(1, 0, 0))).toBe(true)
	end)

	it("knows what's inside a yard", function()
		local origin, yaw = YardLayout.ringPlacement(3, 8)
		local half = YardLayout.SIZE / 2
		local function insideAt(offset: Vector3): boolean
			return YardLayout.contains(origin, yaw, YardLayout.toWorld(origin, yaw, offset))
		end

		expect(insideAt(Vector3.new(0, 3, 0))).toBe(true)
		expect(insideAt(Vector3.new(half - 1, 3, half - 1))).toBe(true)
		expect(insideAt(Vector3.new(half + 1, 3, 0))).toBe(false)
		expect(insideAt(Vector3.new(0, 100, 0))).toBe(false)
	end)

	it("keeps pads and the crate inside the yard", function()
		local half = YardLayout.SIZE / 2
		for _, offset in YardLayout.PAD_OFFSETS do
			expect(math.abs(offset.X) < half and math.abs(offset.Z) < half).toBe(true)
		end
		expect(math.abs(YardLayout.CRATE_OFFSET.Z) < half).toBe(true)
	end)
end)
