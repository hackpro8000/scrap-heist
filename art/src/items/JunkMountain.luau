-- Junk Mountain: the impassable boundary mountain, one huge smooth heap of
-- packed scrap like the fill in a storage crate, with crushed car bales,
-- tyres, drums and girders half buried in its slope. One 32-stud section,
-- toe at the front (-y) and the peak toward the back edge (+y), so sections
-- set side by side form a continuous ridge. Lumps fade out at the side
-- edges so neighbouring sections meet on the same profile. Centered on the
-- origin.
local WIDTH = 33
local FRONT, PEAK_Y, BACK = -12, 6, 14
local PEAK = 22
local COLUMNS, ROWS = 40, 28

local SCRAP = { 0.4, 0.34, 0.29 }
local CAR_COLORS = { { 0.55, 0.14, 0.12 }, { 0.38, 0.42, 0.5 }, { 0.3, 0.36, 0.26 }, { 0.7, 0.6, 0.3 } }

-- Height of the heap's surface: a slope rising from the toe to the peak and
-- falling off behind it, with big swells and small lumps on top.
local function heightAt(x: number, y: number): number
	local base = if y < PEAK_Y
		then PEAK * math.sin(math.clamp((y - FRONT) / (PEAK_Y - FRONT), 0, 1) * math.pi / 2) ^ 1.4
		else PEAK - (y - PEAK_Y) * 1.6
	local edge = math.sin(math.clamp((x + WIDTH / 2) / WIDTH, 0, 1) * math.pi)
	local rise = math.clamp(base / PEAK, 0, 1)
	local swell = 4 * math.sin(x * 0.33 + y * 0.21) * math.cos(y * 0.27 - x * 0.12)
	local lumps = 2 * math.noise(x * 0.4, y * 0.4, 0.5)
	return math.max(0, base + (swell + lumps) * edge * rise)
end

part("Heap", nil, SCRAP, function(mesh)
	local rows = {}
	for j = 0, ROWS do
		local y = FRONT + (BACK - FRONT) * j / ROWS
		rows[j] = {}
		for i = 0, COLUMNS do
			local x = -WIDTH / 2 + WIDTH * i / COLUMNS
			rows[j][i] = mesh:vertex(x, y, heightAt(x, y))
		end
	end
	for j = 0, ROWS - 1 do
		for i = 0, COLUMNS - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end, true, 0.9)

-- Junk spots on the slope, scattered from a fixed seed so every section is
-- the same: x, y, kind, a variant number and a size.
local KINDS = { "Bale", "Bale", "Bale", "Tyre", "Drum", "Girder", "Plate" }
local JUNK = {}
local seed = 7
local function random(low: number, high: number): number
	seed = (seed * 16807) % 2147483647
	return low + (high - low) * seed / 2147483647
end
for _ = 1, 70 do
	local x, y = random(-15, 15), random(FRONT + 1, BACK - 3)
	table.insert(JUNK, { x, y, KINDS[math.floor(random(1, #KINDS + 1))], math.floor(random(1, 5)), random(0.7, 1.4) })
end

local function spotsOf(kind: string, variant: number?)
	local spots = {}
	for _, spot in JUNK do
		if spot[3] == kind and (variant == nil or spot[4] == variant) then
			table.insert(spots, spot)
		end
	end
	return spots
end

for index, color in CAR_COLORS do
	part("Bales" .. index, nil, color, function(mesh)
		for _, spot in spotsOf("Bale", index) do
			local x, y = spot[1], spot[2]
			local size = spot[5]
			box(mesh, x, y, heightAt(x, y) - 1.4 * size, 3.2 * size, 2.2 * size, 2.4 * size)
		end
	end, nil, 0.6)
end

part("Tyres", nil, RUBBER_BLACK, function(mesh)
	for _, spot in spotsOf("Tyre") do
		local x, y = spot[1], spot[2]
		ring(mesh, x, y, heightAt(x, y) + 0.3, 0.8, 1.6, 0.8, if spot[4] % 2 == 0 then "x" else "y", 16)
	end
end, nil, RUBBER)

part("Drums", nil, RUST_ORANGE, function(mesh)
	for _, spot in spotsOf("Drum") do
		local x, y = spot[1], spot[2]
		cylinder(mesh, x, y, heightAt(x, y) + 0.3, 1, 3, if spot[4] == 1 then "z" else if spot[4] == 2 then "y" else "x", 14)
	end
end, nil, 0.8)

part("Girders", nil, RUST_DARK, function(mesh)
	for _, spot in spotsOf("Girder") do
		local x, y = spot[1], spot[2]
		local z = heightAt(x, y)
		local lean = if spot[4] % 2 == 0 then 1 else -1
		strut(mesh, x - 3 * lean, y - 1, z - 0.5, x + 3 * lean, y + 2, z + 3.5, 0.4)
	end
end, nil, 0.85)

part("Plates", nil, RUST_ORANGE, function(mesh)
	for _, spot in spotsOf("Plate") do
		local x, y = spot[1], spot[2]
		local z = heightAt(x, y)
		strut(mesh, x - 2, y, z - 0.3, x + 2, y + 0.6, z + 1.2, 0.15 * spot[5] + 0.6)
	end
end, nil, 0.9)

finishParts()
