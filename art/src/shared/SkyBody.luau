-- Sky bodies: shared builders and painters for the planet and the moons.
-- A body is a smooth sphere, 10 studs in radius, spinning about z, painted
-- flat (the game's sun shades it). Two genotypes: banded gas giants and
-- cratered moons, each drawn from a palette and a seed. Rings are flat
-- bands of real geometry with gaps between them, so they need no alpha.

local BODY_RADIUS = 10

-- A seeded random source (the engine has no Random).
local function seeded(seed)
	local state = seed % 2147483647
	local function nextUnit()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		number = function(low, high)
			return low + (high - low) * nextUnit()
		end,
		integer = function(low, high)
			return math.min(high, low + math.floor(nextUnit() * (high - low + 1)))
		end,
		unit = function()
			local z = nextUnit() * 2 - 1
			local t, r = nextUnit() * TAU, math.sqrt(1 - z * z)
			return r * math.cos(t), r * math.sin(t), z
		end,
	}
end

local function fbm(x, y, z)
	return math.noise(x, y, z) + 0.5 * math.noise(x * 2.03, y * 2.03, z * 2.03) + 0.25 * math.noise(x * 4.1, y * 4.1, z * 4.1)
end

local function blend(a, b, f)
	return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- Part of a sphere at (cx, cy, cz): rows `from` to `to` of `rings`, top first.
local function sphereRows(mesh, cx, cy, cz, radius, rings, sides, from, to)
	local grid = {}
	for r = from, to do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local theta = s / sides * TAU
			grid[r][s] = mesh:vertex(
				cx + math.sin(phi) * math.cos(theta) * radius,
				cy + math.sin(phi) * math.sin(theta) * radius,
				cz + math.cos(phi) * radius
			)
		end
	end
	for r = from, to - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r + 1][s], grid[r + 1][n], grid[r][n] })
		end
	end
end

-- A flat ring band round z at (cx, cy, cz), `thick` deep.
local function ringBand(mesh, cx, cy, cz, inner, outer, thick, steps)
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		local c, s = math.cos(t), math.sin(t)
		rows[i + 1] = {
			mesh:vertex(cx + c * outer, cy + s * outer, cz - thick / 2),
			mesh:vertex(cx + c * outer, cy + s * outer, cz + thick / 2),
			mesh:vertex(cx + c * inner, cy + s * inner, cz + thick / 2),
			mesh:vertex(cx + c * inner, cy + s * inner, cz - thick / 2),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], a[l], b[l], b[k] })
		end
	end
end

-- A banded giant's paint. `look` has: bands (colours, pole to pole), seed,
-- storms (how many), shadow (the ring's shadow line, or nil).
local function bandedPainter(look, cx, cy, cz)
	local rng = seeded(look.seed)
	-- Band edges from the north pole (1) to the south (-1), uneven widths.
	local edges, total = { 0 }, 0
	for i = 1, #look.bands do
		total += rng.number(0.6, 1.6)
		edges[i + 1] = total
	end
	for i = 1, #edges do
		edges[i] = 1 - 2 * edges[i] / total
	end
	local storms = {}
	for _ = 1, look.storms or 0 do
		local sx, sy, sz = rng.unit()
		sz *= 0.55
		local l = math.sqrt(sx * sx + sy * sy + sz * sz)
		table.insert(storms, {
			x = sx / l,
			y = sy / l,
			z = sz / l,
			wide = rng.number(0.1, 0.22),
			tall = rng.number(0.045, 0.085),
			color = look.bands[rng.integer(1, #look.bands)],
		})
	end
	local white, deep = { 1, 1, 1 }, look.deep
	return function(x, y, z)
		local px, py, pz = (x - cx) / BODY_RADIUS, (y - cy) / BODY_RADIUS, (z - cz) / BODY_RADIUS
		local s = look.seed * 0.13
		-- Bands wander: a broad wave and a fine ripple, stretched along the spin.
		local v = pz + fbm(px * 1.2 + s, py * 1.2, pz * 3.5) * 0.05 + fbm(px * 4 + s, py * 4, pz * 11) * 0.012
		local index = #look.bands
		for i = 1, #look.bands do
			if v > edges[i + 1] then
				index = i
				break
			end
		end
		local color = look.bands[index]
		local r, g, b = color[1], color[2], color[3]
		local within = (edges[index] - v) / (edges[index] - edges[index + 1])
		-- Brush strokes: long streaks of a lighter and a darker tone.
		local streak = fbm(px * 2.2 + s, py * 2.2 + index * 3.7, pz * 26)
		if streak > 0.22 then
			r, g, b = blend({ r, g, b }, white, 0.3)
		elseif streak < -0.3 then
			r, g, b = blend({ r, g, b }, deep, 0.28)
		end
		-- Hair-thin strokes over those.
		if fbm(px * 5 + s, py * 5, pz * 70 + index) > 0.42 then
			r, g, b = blend({ r, g, b }, white, 0.45)
		end
		-- Each band has a pale upper edge and a darker lower one.
		if within < 0.08 then
			r, g, b = blend({ r, g, b }, white, 0.5)
		elseif within > 0.9 then
			r, g, b = blend({ r, g, b }, deep, 0.3)
		end
		for _, storm in storms do
			if px * storm.x + py * storm.y + pz * storm.z > 0 then
				-- East and north at the storm, on the sphere.
				local el = math.sqrt(storm.x * storm.x + storm.y * storm.y)
				local ex, ey = -storm.y / el, storm.x / el
				local dx, dy, dz = px - storm.x, py - storm.y, pz - storm.z
				local u = (dx * ex + dy * ey) / storm.wide
				local n = (dz * el - (dx * storm.x + dy * storm.y) * storm.z / el) / storm.tall
				local q = math.sqrt(u * u + n * n)
				if q < 1 then
					-- Swirled rings, edged with a dark line.
					local swirl = math.floor(q * 4 + math.atan2(n, u) / TAU) % 2
					if q > 0.88 then
						r, g, b = blend(storm.color, deep, 0.45)
					elseif swirl == 0 then
						r, g, b = blend(storm.color, white, 0.5)
					else
						r, g, b = blend(storm.color, deep, 0.12)
					end
				end
			end
		end
		-- Soft pale caps at the poles.
		local cap = math.clamp((math.abs(pz) - 0.86) / 0.1, 0, 1)
		r, g, b = blend({ r, g, b }, look.pole, cap * 0.7)
		-- The ring's shadow, a line just off the equator.
		if look.shadow and pz < look.shadow and pz > look.shadow - 0.07 then
			r, g, b = blend({ r, g, b }, deep, 0.4)
		end
		return r, g, b
	end
end

-- A cratered moon's paint. `look` has: tones (dark to light), seed, craters.
local function crateredPainter(look, cx, cy, cz)
	local rng = seeded(look.seed)
	local craters = {}
	for _ = 1, look.craters do
		local x, y, z = rng.unit()
		table.insert(craters, { x, y, z, rng.number(0.06, 0.24) })
	end
	local tones = look.tones
	return function(x, y, z)
		local px, py, pz = (x - cx) / BODY_RADIUS, (y - cy) / BODY_RADIUS, (z - cz) / BODY_RADIUS
		local s = look.seed * 0.17
		-- Seas and highlands in flat patches.
		local land = fbm(px * 1.6 + s, py * 1.6, pz * 1.6)
		local level = if land > 0.2 then 3 elseif land > -0.25 then 2 else 1
		for _, crater in craters do
			local dx, dy, dz = px - crater[1], py - crater[2], pz - crater[3]
			local q = math.sqrt(dx * dx + dy * dy + dz * dz) / crater[4]
			if q < 1.12 then
				-- Lit from the upper left: the far wall catches the light.
				local facing = (dx * -0.5 + dy * -0.5 + dz * 0.7) / math.max(q * crater[4], 1e-4)
				if q > 1 then
					level = math.min(level + 1, 4)
				elseif q > 0.72 then
					level = if facing > 0.1 then 4 else 1
				else
					level = math.max(level - 1, 1)
				end
			end
		end
		-- Speckle so the flats aren't empty.
		if math.noise(px * 14 + s, py * 14, pz * 14) > 0.38 then
			level = math.max(level - 1, 1)
		end
		local color = tones[level]
		return color[1], color[2], color[3]
	end
end

-- A ring's paint: fine pastel grooves across it and scattered glints.
local function ringPainter(colors, cx, cy, inner, outer, seed)
	return function(x, y, _z)
		local dx, dy = x - cx, y - cy
		local reach = math.sqrt(dx * dx + dy * dy)
		local t = math.clamp((reach - inner) / (outer - inner), 0, 0.999) * (#colors - 1)
		local i = math.floor(t)
		local r, g, b = blend(colors[i + 1], colors[i + 2], t - i)
		local groove = math.sin(reach * 21 + seed) + math.sin(reach * 53 + seed * 2) * 0.6 + math.noise(reach * 6, seed) * 0.8
		if groove > 0.7 then
			r, g, b = blend({ r, g, b }, { 1, 1, 1 }, 0.55)
		elseif groove < -0.8 then
			r, g, b = blend({ r, g, b }, { 0.62, 0.56, 0.86 }, 0.35)
		end
		if math.noise(x * 7 + seed, y * 7, 0.5) > 0.44 then
			return 1, 1, 0.96
		end
		return r, g, b
	end
end

-- Bakes one flat-painted part.
local function bakeBody(name, size, build, painter)
	local mesh = Mesh.new()
	build(mesh)
	mesh:setSmooth(true)
	mesh:unwrap()
	local image = Image.new(size, size, 1, 1, 1)
	mesh:paint(image, painter)
	model.part(name, mesh, image, { preview = true })
end
