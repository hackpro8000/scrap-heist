--!strict
local Source = require("../../Source")
local Test = require("../../Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Yard = Source.require("src/shared/Config/Yard")
local BuildRules = Source.require("src/shared/Yard/BuildRules")
local YardGrid = Source.require("src/shared/Yard/YardGrid")

local FRONT = Yard.STARTING_PARCELS
local ALL = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

local function pad(id: number, x: number, z: number, turn: number?): any
	return { id = id, kind = "Pad", family = "Kitchen", x = x, z = z, turn = turn or 0 }
end

describe("YardGrid", function()
	it("swaps a thing's width and depth on an odd turn", function()
		local width, depth = YardGrid.footprint("Press", 0)
		local turnedWidth, turnedDepth = YardGrid.footprint("Press", 1)
		expect(turnedWidth).toBe(depth)
		expect(turnedDepth).toBe(width)
	end)

	it("numbers parcels from the back row's left, so the front row is last", function()
		expect(YardGrid.parcelOf(0, 0)).toBe(1)
		expect(YardGrid.parcelOf(Yard.COLUMNS - 1, 0)).toBe(3)
		expect(YardGrid.parcelOf(0, Yard.ROWS - 1)).toBe(10)
		expect(YardGrid.parcelOf(Yard.COLUMNS - 1, Yard.ROWS - 1)).toBe(12)
	end)

	it("puts a thing's centre where its cells are", function()
		local centre = YardGrid.centre({ kind = "Crate", x = 0, z = 0, turn = 0 })
		expect(centre.X).toBe(-YardGrid.WIDTH / 2 + 4)
		expect(centre.Z).toBe(-YardGrid.DEPTH / 2 + 4)
		local x, z = YardGrid.cellAt(centre)
		expect(x).toBe(2)
		expect(z).toBe(2)
	end)

	it("turns yard space into the world and back", function()
		local origin, yaw = Vector3.new(100, 6, -180), math.rad(90)
		local world = YardGrid.toWorld(origin, yaw, YardGrid.GATE_OFFSET)
		expect((YardGrid.toLocal(origin, yaw, world) - YardGrid.GATE_OFFSET).Magnitude < 1e-6).toBe(true)
		expect(YardGrid.contains(origin, yaw, world)).toBe(true)
		expect(YardGrid.contains(origin, yaw, origin + Vector3.new(0, 0, 80))).toBe(false)
	end)
end)

describe("BuildRules starter layout", function()
	local starter = BuildRules.starterObjects()

	it("fits a new player's allowance exactly", function()
		local allowed = BuildRules.allowance(0)
		for kind, count in allowed do
			expect(BuildRules.count(starter, kind)).toBe(count)
		end
	end)

	it("obeys every rule itself", function()
		for _, object in starter do
			expect(BuildRules.canPlace(starter, FRONT, object)).toBe(nil)
		end
		expect(#BuildRules.unreachable(starter)).toBe(0)
	end)
end)

describe("BuildRules.canPlace", function()
	it("keeps things on the plot", function()
		expect(BuildRules.canPlace({}, ALL, pad(1, -1, 10))).toBe("OffPlot")
		expect(BuildRules.canPlace({}, ALL, pad(1, Yard.COLUMNS - 4, 10))).toBe("OffPlot")
		expect(BuildRules.canPlace({}, ALL, pad(1, 0, 0))).toBe(nil)
	end)

	it("keeps things on cleared land", function()
		expect(BuildRules.canPlace({}, FRONT, pad(1, 0, 0))).toBe("NotCleared")
		-- Straddling the edge of cleared land counts as off it.
		expect(BuildRules.canPlace({}, FRONT, pad(1, 0, 40))).toBe("NotCleared")
		expect(BuildRules.canPlace({}, FRONT, pad(1, 0, 42))).toBe(nil)
	end)

	it("keeps the doorstep clear", function()
		expect(BuildRules.canPlace({}, ALL, pad(1, Yard.DOORSTEP.x, Yard.DOORSTEP.z - 2))).toBe("Doorstep")
	end)

	it("refuses overlaps but lets a thing move onto its own old cells", function()
		local objects = { pad(1, 0, 0), pad(2, 10, 0) }
		expect(BuildRules.canPlace(objects, ALL, pad(3, 3, 3))).toBe("Overlap")
		expect(BuildRules.canPlace(objects, ALL, pad(1, 2, 2))).toBe(nil)
	end)

	it("refuses to wall something in", function()
		-- A pad in the back corner, then pads closing off its two open sides
		-- with gaps a cell wide: too narrow for a player.
		local objects = { pad(1, 0, 0), pad(2, 6, 0) }
		expect(BuildRules.canPlace(objects, ALL, pad(3, 0, 6))).toBe("WalledIn")
		-- A gap two cells wide is a way in.
		expect(BuildRules.canPlace(objects, ALL, pad(3, 0, 7))).toBe(nil)
	end)

	it("refuses things that aren't buildable", function()
		expect(BuildRules.canPlace({}, ALL, { id = 1, kind = "Tank", x = 0, z = 0, turn = 0 })).toBe("UnknownKind")
	end)
end)

describe("BuildRules allowance", function()
	it("adds a pad per rank up to the most a yard holds", function()
		expect(BuildRules.allowance(0).Pad).toBe(Yard.STARTING_PADS)
		expect(BuildRules.allowance(3).Pad).toBe(Yard.STARTING_PADS + 3)
		expect(BuildRules.allowance(40).Pad).toBe(Yard.MAX_PADS)
	end)

	it("adds build bays at their ranks", function()
		expect(BuildRules.allowance(4).Bay).toBe(1)
		expect(BuildRules.allowance(5).Bay).toBe(2)
		expect(BuildRules.allowance(11).Bay).toBe(3)
	end)

	it("says when a yard is full of something", function()
		local starter = BuildRules.starterObjects()
		expect(BuildRules.canAdd(starter, 0, "Pad")).toBe("TooMany")
		expect(BuildRules.canAdd(starter, 1, "Pad")).toBe(nil)
		expect(BuildRules.canAdd(starter, 1, "Tank")).toBe("UnknownKind")
	end)

	it("clears a parcel at each clearing rank, always next to cleared land", function()
		expect(#BuildRules.clearedParcels(0)).toBe(3)
		expect(#BuildRules.clearedParcels(14)).toBe(12)
		for rank = 0, 14 do
			local cleared = BuildRules.clearedParcels(rank)
			local newest = cleared[#cleared]
			if #cleared > 3 then
				local touches = false
				for index = 1, #cleared - 1 do
					local other = cleared[index]
					local sameRow = math.floor((other - 1) / 3) == math.floor((newest - 1) / 3)
					if other == newest + 3 or other == newest - 3 or (sameRow and math.abs(other - newest) == 1) then
						touches = true
					end
				end
				expect(touches).toBe(true)
			end
		end
	end)
end)
