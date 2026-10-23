-- Salvage machine: a junk shredder that chews scrap dropped in its hopper and
-- spits parts down a chute. Three upgrade tiers, each a group, each a step up
-- in technology: a hand-cranked two-roller shredder; a three-roller shredder
-- run by a petrol engine with a flywheel, belt and pressure gauge; and an
-- electric four-roller shredder with a geared drive, a control box with a
-- status light and a conveyor carrying parts off the chute. Sits on its pad with the base at the origin.
-- Sketch blockout: tiers stand side by side for review.

local SPACING = 6

local FRAME = { 0.42, 0.46, 0.5 }
local HOPPER = { 0.86, 0.55, 0.18 }
local ROLLER = { 0.3, 0.3, 0.32 }
local MOTOR = { 0.7, 0.2, 0.18 }
local CHUTE = { 0.6, 0.62, 0.6 }
local BOLT = { 0.62, 0.58, 0.52 }
local PATCH = { 0.74, 0.46, 0.28 }
local ELECTRICS = { 0.9, 0.78, 0.2 }
local LAMP = { 0.3, 0.95, 0.4 }
-- Guards over the drive: plain frame steel on tier 2, glossy enamel on tier 3.
local GUARD = { { 0.5, 0.54, 0.58 }, { 0.2, 0.42, 0.5 } }

local TAU = 2 * math.pi

-- Texture sizes: large parts (frame, hopper) get detail, small ones stay cheap.
local LARGE_TEXTURE = 1024
local SMALL_TEXTURE = 256

-- Auto smooth: round surfaces (rollers, pulleys) shade smoothly, while edges
-- sharper than this many degrees (box corners, teeth) stay crisp.
local SMOOTH_ANGLE = 30

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local v = {}
	for i = 0, 7 do
		local x = cx + (if i % 2 == 0 then -sx else sx) / 2
		local y = cy + (if i // 2 % 2 == 0 then -sy else sy) / 2
		local z = cz + (if i // 4 == 0 then 0 else sz)
		v[i + 1] = mesh:vertex(x, y, z)
	end
	mesh:face({ v[1], v[3], v[4], v[2] })
	mesh:face({ v[5], v[6], v[8], v[7] })
	mesh:face({ v[1], v[2], v[6], v[5] })
	mesh:face({ v[3], v[7], v[8], v[4] })
	mesh:face({ v[1], v[5], v[7], v[3] })
	mesh:face({ v[2], v[4], v[8], v[6] })
end

-- Cylinder along X (axis "x") or Z (axis "z"), centered at (cx, cy, cz).
local function cylinder(mesh, cx, cy, cz, radius, length, axis)
	local sides = 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - length / 2, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + length / 2, cy + u, cz + w)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + length)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- Square beam of the given thickness running from one point to another, for
-- braces that cut across at an angle.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	-- Two sides square to the beam: one level, one roughly up.
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Build quality, rising up the tiers. Tier 1 is propped up with one crooked
-- scrap brace per side and wire-lashed legs. Tier 2 is properly braced:
-- crossed struts on the long sides, end rails, gussets where the legs meet
-- the housing and angle iron down the housing corners. Tier 3 is factory
-- built: crossed struts all round, a low perimeter rail, corner guards and
-- trim bands on the housing, levelling feet and bearing caps on the rollers.
local function reinforcement(mesh, cx, scale, tier, rollerYs, rollerRadius)
	local legX, legY, top = 0.9 * scale, 0.7 * scale, 1.2 * scale
	local halfX, halfY, housingTop = 1.1 * scale, 0.9 * scale, 2.1 * scale
	-- Braces on the +y side start above the chute so they don't pass through it.
	local function crossSide(x0, y0, x1, y1, thick)
		local low = if y0 > 0 and y1 > 0 then 0.6 else 0.15
		strut(mesh, x0, y0, low, x1, y1, top - 0.05, thick)
		strut(mesh, x0, y0, top - 0.05, x1, y1, low, thick)
	end
	if tier == 1 then
		for _, side in { -1, 1 } do
			-- One bent rebar brace, not quite reaching the far leg's foot.
			strut(mesh, cx - legX, side * legY, if side > 0 then 0.6 else 0.3, cx + legX - 0.05, side * legY, top * 0.85, 0.07)
		end
		for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			-- Wire lashing wrapped round the leg.
			for k = 0, 1 do
				box(mesh, cx + c[1] * legX, c[2] * legY, top * 0.45 + k * 0.08, 0.26, 0.26, 0.04)
			end
		end
		return
	end
	for _, side in { -1, 1 } do
		crossSide(cx - legX, side * legY, cx + legX, side * legY, 0.08)
		-- Rail across each end.
		box(mesh, cx + side * legX, 0, top * 0.35, 0.12, 2 * legY, 0.1)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local x, y = cx + c[1] * legX, c[2] * legY
		-- Gusset strut tying each leg top into the housing underside.
		strut(mesh, x, y, top * 0.75, x - c[1] * 0.4, y, top, 0.1)
		-- Angle iron (tier 2) or corner guard (tier 3) down the housing corner.
		local hx, hy = cx + c[1] * (halfX + 0.02), c[2] * (halfY + 0.02)
		box(mesh, hx, hy, top, if tier == 2 then 0.12 else 0.18, if tier == 2 then 0.12 else 0.18, housingTop - top)
	end
	if tier == 2 then
		return
	end
	for _, side in { -1, 1 } do
		crossSide(cx + side * legX, -legY, cx + side * legX, legY, 0.08)
		-- Low perimeter rail.
		box(mesh, cx, side * legY, 0.12, 2 * legX + 0.2, 0.12, 0.1)
		box(mesh, cx + side * legX, 0, 0.12, 0.12, 2 * legY, 0.1)
	end
	-- Trim bands round the housing's bottom and top edges.
	for _, z in { top, housingTop - 0.08 } do
		box(mesh, cx, 0, z, 2 * halfX + 0.08, 2 * halfY + 0.08, 0.08)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		-- Levelling foot: a round pad on a threaded stem.
		cylinder(mesh, cx + c[1] * legX, c[2] * legY, 0, 0.24, 0.06, "z")
	end
	for _, y in rollerYs do
		-- Bearing cap on each end of every roller shaft.
		for _, side in { -1, 1 } do
			local capX = cx + side * (halfX + 0.06)
			box(mesh, capX, y, housingTop - 0.15, 0.12, rollerRadius, 2.15 * scale - housingTop + 0.15)
			cylinder(mesh, capX, y, 2.15 * scale, rollerRadius * 0.6, 0.12, "x")
		end
	end
end

-- Shredder roller along X: a stack of toothed cutter discs on a shaft. Each
-- disc is a star-shaped prism, and neighbours are turned half a tooth so the
-- teeth stagger along the roller.
local function toothedRoller(mesh, cx, cy, cz, radius, length, teeth, discs)
	local points = teeth * 2
	local width = length / discs
	for d = 0, discs - 1 do
		local x0 = cx - length / 2 + d * width
		local x1 = x0 + width * 0.8
		local phase = if d % 2 == 0 then 0 else math.pi / teeth
		local a, b = {}, {}
		for i = 0, points - 1 do
			local t = i / points * TAU + phase
			local r = if i % 2 == 0 then radius else radius * 0.7
			local y, z = cy + math.cos(t) * r, cz + math.sin(t) * r
			a[i + 1] = mesh:vertex(x0, y, z)
			b[i + 1] = mesh:vertex(x1, y, z)
		end
		for i = 1, points do
			local j = i % points + 1
			mesh:face({ a[i], a[j], b[j], b[i] })
		end
		local capA = {}
		for i = points, 1, -1 do
			table.insert(capA, a[i])
		end
		mesh:face(capA)
		mesh:face(b)
	end
	cylinder(mesh, cx, cy, cz, radius * 0.45, length + 0.1, "x")
end

-- Open-topped hopper flaring out from the shredder throat.
local function hopper(mesh, cx, z, bottom, top, height, chaos)
	-- Walls are a grid so the cartoon wobble can bend them into curves.
	local around, rows = 16, 5
	local rings = {}
	for row = 0, rows do
		local t = row / rows
		local half = (bottom + (top - bottom) * t) / 2
		local ring = {}
		for i = 0, around - 1 do
			-- Walk the square's perimeter, four steps per side.
			local side, step = i // 4, (i % 4) / 4
			local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
			local a, b = corners[side + 1], corners[(side + 1) % 4 + 1]
			local u, v = a[1] + (b[1] - a[1]) * step, a[2] + (b[2] - a[2]) * step
			ring[i + 1] = mesh:vertex(cx + u * half, v * half, z + height * t)
		end
		rings[row + 1] = ring
	end
	for row = 1, rows do
		local low, high = rings[row], rings[row + 1]
		for i = 1, around do
			local j = i % around + 1
			mesh:face({ low[i], low[j], high[j], high[i] })
		end
	end
	mesh:solidify(-0.08)
	-- Reinforced rim: one lip band around the top edge that wobbles up and
	-- down and in and out as it goes round, like a hand-bent strip.
	local lip = 0.12
	local steps = 48
	local profile = { { -1, 0 }, { 1, 0 }, { 1, 1 }, { -1, 1 } } -- {in/out, up}
	local rimRings = {}
	for i = 0, steps - 1 do
		local t = i / steps
		local side, along = math.floor(t * 4), (t * 4) % 1
		local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
		local a, b = corners[side + 1], corners[(side + 1) % 4 + 1]
		local u, v = a[1] + (b[1] - a[1]) * along, a[2] + (b[2] - a[2]) * along
		local angle = t * TAU
		-- Rim wobble: random on old tiers, an even four-lobed swell on new ones.
		local order = 1 - chaos
		local rise = (math.sin(angle * 3 + cx) * chaos + math.cos(angle * 4) * order) * 0.05
		local thick = lip * (1 + (math.sin(angle * 5 + cx * 2) * chaos + math.cos(angle * 8) * order * 0.5) * 0.3)
		local ring = {}
		for k, p in profile do
			local reach = top / 2 + p[1] * thick / 2
			ring[k] = mesh:vertex(cx + u * reach, v * reach, z + height + rise + p[2] * thick)
		end
		rimRings[i + 1] = ring
	end
	for i = 1, steps do
		local low, high = rimRings[i], rimRings[i % steps + 1]
		for k = 1, 4 do
			local m = k % 4 + 1
			mesh:face({ low[k], high[k], high[m], low[m] })
		end
	end
end

-- Hopper paint: orange that darkens with grime toward the throat, and a dark
-- band on the rim. bottomZ and height bound the funnel; wear 0-1 scales the
-- grime, so newer tiers look cleaner.
local function hopperColor(bottomZ, height, wear)
	return function(x, y, z)
		local t = math.clamp((z - bottomZ) / height, 0, 1)
		local grime = ((1 - t) * 0.45 + math.noise(x * 3, y * 3, z * 3) * 0.12) * wear
		if t > 0.97 then
			grime = 0.35
		end
		local k = 1 - math.clamp(grime, 0, 0.6)
		return HOPPER[1] * k, HOPPER[2] * k, HOPPER[3] * k
	end
end

-- Chunky cartoon bolt heads, like the scrap crate's: fat 8-sided cones that
-- stand out from the housing in wobbly, mismatched rows, with crooked scrap
-- plates bolted on over the panels.
local BOLT_SIZE = 0.1
local BOLT_SPACING = 0.5
local PATCH_THICKNESS = 0.04

-- Bolt head on a side face at (x, y, z), pointing out along normalX/normalY.
local function bolt(mesh, x, y, z, normalX, normalY, size)
	local segments = 8
	local base, top = {}, {}
	for k = 0, segments - 1 do
		local a = k / segments * TAU
		local side, up = math.cos(a), math.sin(a)
		local function ring(out, radius)
			return mesh:vertex(
				x + normalX * out + normalY * side * radius,
				y + normalY * out + normalX * side * radius,
				z + up * radius
			)
		end
		base[k + 1] = ring(-size / 2, size)
		top[k + 1] = ring(size / 2, size * 0.8)
	end
	for k = 1, segments do
		local j = k % segments + 1
		mesh:face({ base[k], base[j], top[j], top[k] })
	end
	local cap = {}
	for k = segments, 1, -1 do
		table.insert(cap, top[k])
	end
	mesh:face(cap)
end

local function uniform(a, b)
	return a + (b - a) * math.random()
end

-- Crooked scrap plate on a side face: a jittered, tilted quad slab centred
-- at (x, y, z), with a little bolt in each corner.
local function patchPlate(plates, bolts, x, y, z, normalX, normalY)
	local w, h, tilt = uniform(0.3, 0.45), uniform(0.2, 0.3), uniform(-0.45, 0.45)
	local corners = { { -w, -h }, { w, -h }, { w, h }, { -w, h } }
	local outer, inner = {}, {}
	for i, c in corners do
		local u, v = c[1] + uniform(-0.09, 0.09), c[2] + uniform(-0.07, 0.07)
		u, v = u * math.cos(tilt) - v * math.sin(tilt), u * math.sin(tilt) + v * math.cos(tilt)
		local px, py, pz = x + normalY * u, y + normalX * u, z + v
		inner[i] = plates:vertex(px, py, pz)
		outer[i] = plates:vertex(px + normalX * PATCH_THICKNESS, py + normalY * PATCH_THICKNESS, pz)
		local inset = 0.75
		local bx, by = x + normalY * u * inset, y + normalX * u * inset
		bolt(bolts, bx + normalX * PATCH_THICKNESS, by + normalY * PATCH_THICKNESS, z + v * inset, normalX, normalY, BOLT_SIZE * 0.55)
	end
	-- Winding flips with the side so the faces point outward.
	local flip = normalX + normalY < 0
	local function quad(a, b, c, d)
		plates:face(if flip then { d, c, b, a } else { a, b, c, d })
	end
	quad(outer[1], outer[2], outer[3], outer[4])
	quad(inner[4], inner[3], inner[2], inner[1])
	for i = 1, 4 do
		local j = i % 4 + 1
		quad(inner[i], inner[j], outer[j], outer[i])
	end
end

-- Rows of bolts that wobble, vary in size and sometimes go missing, plus a
-- couple of patch plates per tier. Seeded per tier so each one looks different.
local function housingBolts(bolts, plates, cx, scale, seed)
	math.randomseed(seed)
	local halfX, halfY = 1.1 * scale, 0.9 * scale
	local function scrappyBolt(x, y, z, normalX, normalY)
		-- Leave the corners clear for angle iron, and the +x face clear for the drive.
		local nearCorner = math.abs(x - cx) > halfX - 0.2 and math.abs(y) > halfY - 0.2
		local behindDrive = normalX > 0 and math.abs(y) < 0.45
		if math.random() < 0.12 or nearCorner or behindDrive then
			return
		end
		local size = BOLT_SIZE * uniform(0.7, 1.5)
		local slide = uniform(-0.1, 0.1)
		bolt(bolts, x + normalY * slide, y + normalX * slide, z + uniform(-0.08, 0.08), normalX, normalY, size)
	end
	for _, z in { 1.35 * scale, 1.95 * scale } do
		local countX = math.floor(2 * halfX / BOLT_SPACING)
		for i = 0, countX do
			local x = cx - countX * BOLT_SPACING / 2 + i * BOLT_SPACING
			scrappyBolt(x, -halfY, z, 0, -1)
			scrappyBolt(x, halfY, z, 0, 1)
		end
		local countY = math.floor(2 * halfY / BOLT_SPACING)
		for i = 0, countY do
			local y = -countY * BOLT_SPACING / 2 + i * BOLT_SPACING
			scrappyBolt(cx - halfX, y, z, -1, 0)
			scrappyBolt(cx + halfX, y, z, 1, 0)
		end
	end
	local mid = 1.65 * scale
	patchPlate(plates, bolts, cx + uniform(-0.5, 0.5) * scale, -halfY, mid + uniform(-0.05, 0.05), 0, -1)
	patchPlate(plates, bolts, cx + uniform(-0.5, 0.5) * scale, halfY, mid + uniform(-0.05, 0.05), 0, 1)
	patchPlate(plates, bolts, cx - halfX, uniform(-0.3, 0.3) * scale, mid, -1, 0)
end

-- Cartoon wobble, like the scrap crate. It moves from chaos to order up the
-- tiers: tier 1 leans, twists, sways and has every corner nudged off true;
-- tier 3 keeps none of that randomness and instead exaggerates its base
-- shapes evenly, with every side pillowing out and a symmetric barrel
-- swell, so it stays wacky but balanced. Builders write into a warped mesh,
-- which bends each vertex on its way in.
local LEAN = 0.06
local TWIST = 0.06
local JITTER = 0.03
-- Curvy wobble: a sideways S-sway rising up the tier, and sides that bulge.
local SWAY = 0.22
local SWAY_WAVE = 1.1
local BULGE = 0.1
-- Ordered wobble: how far each side pillows out at its middle, and the
-- barrel swell at mid-height.
local PILLOW = 0.12
local BARREL = 0.08

local function tierWarp(cx, seed, scale, chaos)
	local order = 1 - chaos
	local leanX, leanY = math.sin(seed) * LEAN * chaos, math.cos(seed * 1.7) * LEAN * 0.6 * chaos
	local twist = (if seed % 2 == 0 then TWIST else -TWIST) * chaos
	local halfX, halfY, midZ, halfZ = 1.1 * scale, 0.9 * scale, 1.65 * scale, 1.65 * scale
	return function(x, y, z)
		local a = twist * z
		local dx = x - cx
		dx, y = dx * math.cos(a) - y * math.sin(a), dx * math.sin(a) + y * math.cos(a)
		local sway = math.sin(z * SWAY_WAVE + seed) * SWAY * chaos
		local swayY = math.sin(z * SWAY_WAVE * 0.8 + seed * 2.1) * SWAY * 0.6 * chaos
		local bulge = 1 + (0.5 + 0.5 * math.sin(z * 2.2 + seed)) * BULGE * chaos
		-- Even pillowing: each side swells most at its centre, symmetric
		-- left to right and front to back, plus a barrel swell round mid-height.
		local u = math.clamp(math.abs(dx) / halfX, 0, 1)
		local v = math.clamp(math.abs(y) / halfY, 0, 1)
		local w = math.clamp(math.abs(z - midZ) / halfZ, 0, 1)
		local barrel = BARREL * (1 - w * w)
		local pillowX = 1 + order * (PILLOW * (1 - v * v) + barrel)
		local pillowY = 1 + order * (PILLOW * (1 - u * u) + barrel)
		dx, y = dx * bulge * pillowX, y * bulge * pillowY
		local n = JITTER * chaos
		return cx + dx + sway + leanX * z + math.noise(x * 2.3 + seed, y * 2.3, z * 2.3) * n,
			y + swayY + leanY * z + math.noise(x * 2.3, y * 2.3 + seed, z * 2.3) * n,
			z + math.noise(x * 2.3, y * 2.3, z * 2.3 + seed) * n
	end
end

local function warpedMesh(warp)
	local mesh = Mesh.new()
	return {
		mesh = mesh,
		vertex = function(_self, x, y, z)
			return mesh:vertex(warp(x, y, z))
		end,
		face = function(_self, verts)
			return mesh:face(verts)
		end,
		solidify = function(_self, ...)
			return mesh:solidify(...)
		end,
	}
end

-- Edge highlight strength, about 36% under modelkit's 0.7 default so the
-- rims blend into the paint instead of reading as pale outlines.
local EDGE_HIGHLIGHT = 0.45
-- Feathered, base-tinted highlight strokes instead of crisp cream ones.
local EDGE_BLEND = 0.7

local function part(name, warped, color, group, size, paint)
	local mesh = warped.mesh
	mesh:setSmooth(SMOOTH_ANGLE)
	mesh:unwrap()
	local image = Image.new(size, size, color[1], color[2], color[3])
	if paint then
		mesh:paint(image, paint)
	end
	mesh:paintShading(image, { highlight = EDGE_HIGHLIGHT, blend = EDGE_BLEND })
	model.part(name, mesh, image, { group = group, preview = true })
end

-- Frame paint: grey steel with chips worn through to bare metal, rust
-- streaks running down from the housing, and grime rising from the feet.
local BARE_METAL = { 0.68, 0.7, 0.72 }
local RUST = { 0.45, 0.24, 0.12 }

-- Frame paint for one tier's frame, whose housing is centred on cx at scale.
-- A seam splits each long side of the housing into two panels. wear 0-1
-- scales the rust, chips and grime.
local function frameColor(cx, scale, wear)
	local bottom = 1.2 * scale
	return function(x, y, z)
		local r, g, b = FRAME[1], FRAME[2], FRAME[3]
		-- Rust streaks: noise stretched tall so it runs in vertical drips.
		-- Banded to a few flat steps so it reads as cartoon paint, not grit.
		local streak = math.floor(math.clamp(math.noise(x * 3, y * 3, z * 0.5) * 2 - 0.4, 0, 0.6) * 3) / 3 * 0.5 * wear
		r, g, b = r + (RUST[1] - r) * streak, g + (RUST[2] - g) * streak, b + (RUST[3] - b) * streak
		-- Few, big chips rather than fine speckle.
		if math.noise(x * 2 + 5, y * 2, z * 2) > 0.45 + (1 - wear) * 0.4 then
			r, g, b = BARE_METAL[1], BARE_METAL[2], BARE_METAL[3]
		end
		if z > bottom - 0.01 and math.abs(x - cx) < 0.03 then
			-- Seam splitting each long side into two panels.
			return r * 0.45, g * 0.45, b * 0.45
		end
		local grime = 1 - math.clamp(0.5 - z * 0.4, 0, 0.5) * wear
		return r * grime, g * grime, b * grime
	end
end

-- Motor paint: red, with soot creeping down the exhaust stack from its mouth.
-- Engine paint: soot up top and scuffs, both fading on newer, cleaner kit.
local function motorColor(wear)
	return function(x, y, z)
		local soot = math.clamp((z - 1.8) / 0.9, 0, 1) * (0.8 + math.noise(x * 6, y * 6, z * 6) * 0.3) * wear
		local scuff = if math.noise(x * 9 + 3, y * 9, z * 9) > 0.4 + (1 - wear) * 0.5 then 0.25 else 0
		local k = 1 - math.clamp(soot + scuff, 0, 0.85)
		return MOTOR[1] * k, MOTOR[2] * k, MOTOR[3] * k
	end
end

for tier = 1, 3 do
	local group = `Tier_{tier}`
	local cx = (tier - 2) * SPACING
	local scale = 1 + (tier - 1) * 0.2
	local chaos = (3 - tier) / 2
	local warp = tierWarp(cx, tier, scale, chaos)
	-- Higher tiers are newer kit: less rust, chipping and grime.
	local wear = ({ 1, 0.5, 0.15 })[tier]

	local frame = warpedMesh(warp)
	-- Legs and shredder housing.
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local legX, legY = cx + corner[1] * 0.9 * scale, corner[2] * 0.7 * scale
		box(frame, legX, legY, 0, 0.2, 0.2, 1.2 * scale)
		-- Foot plate bolted to the pad.
		box(frame, legX, legY, 0, 0.4, 0.4, 0.05)
	end
	box(frame, cx, 0, 1.2 * scale, 2.2 * scale, 1.8 * scale, 0.9 * scale)
	local rollerCount = tier + 1
	-- Rollers share the hopper's whole floor, teeth just meshing, so scrap
	-- has nowhere to land but between them.
	local throatWidth = 1.9 * scale
	local rollerRadius = throatWidth / rollerCount / 2 * 1.05
	local rollerYs = {}
	for i = 1, rollerCount do
		rollerYs[i] = ((i - 0.5) / rollerCount - 0.5) * throatWidth
	end
	reinforcement(frame, cx, scale, tier, rollerYs, rollerRadius)
	part(`{group}_Frame`, frame, FRAME, group, LARGE_TEXTURE, frameColor(cx, scale, wear))

	local bolts, plates = warpedMesh(warp), warpedMesh(warp)
	housingBolts(bolts, plates, cx, scale, tier * 17)
	part(`{group}_Bolts`, bolts, BOLT, group, SMALL_TEXTURE)
	part(`{group}_PatchPlates`, plates, PATCH, group, SMALL_TEXTURE)

	local rollers = warpedMesh(warp)
	-- Better tiers pack more, finer rollers: 2 → 3 → 4, with more teeth each.
	for _, y in rollerYs do
		toothedRoller(rollers, cx, y, 2.15 * scale, rollerRadius, 1.9 * scale, 4 + tier * 2, 5 + tier * 2)
	end
	if tier == 2 then
		-- Belt drive in the gap between housing and motor: a small pulley on
		-- the motor, a large one on the housing, and the belt's two runs.
		local beltX = cx + 1.1 * scale + 0.06
		local low, high = 1.2, 1.65 * scale
		cylinder(rollers, beltX, 0, low, 0.15, 0.08, "x")
		cylinder(rollers, beltX, 0, high, 0.25, 0.08, "x")
		box(rollers, beltX, -0.2, low, 0.05, 0.04, high - low)
		box(rollers, beltX, 0.2, low, 0.05, 0.04, high - low)
	elseif tier == 3 then
		-- Geared drive: a small pinion on the motor shaft meshing with a big
		-- gear on the roller shaft, no slipping belt.
		local gearX = cx + 1.1 * scale + 0.08
		toothedRoller(rollers, gearX, 0, 1.25, 0.2, 0.12, 8, 1)
		toothedRoller(rollers, gearX, 0, 1.25 + 0.2 + 0.32, 0.36, 0.12, 14, 1)
		-- Conveyor off the end of the chute: a belt on two end drums.
		local beltY0, beltY1 = 2.1 * scale, 4.2 * scale
		box(rollers, cx, (beltY0 + beltY1) / 2, 0.42, 1 * scale, beltY1 - beltY0, 0.06)
		for _, y in { beltY0, beltY1 } do
			cylinder(rollers, cx, y, 0.45, 0.1, 1.05 * scale, "x")
		end
		for _, x in { -0.5, 0.5 } do
			for _, y in { beltY0 + 0.2, beltY1 - 0.2 } do
				box(rollers, cx + x * scale, y, 0, 0.08, 0.08, 0.42)
			end
		end
	end
	part(`{group}_Rollers`, rollers, ROLLER, group, SMALL_TEXTURE)

	if tier > 1 then
		-- Guards hiding the drive, shaped like stamped covers: flat sides
		-- with rounded ends that follow the pulleys or gears inside.
		local guards = warpedMesh(warp)
		local lowZ, lowR, highZ, highR
		if tier == 2 then
			lowZ, lowR, highZ, highR = 1.2, 0.24, 1.65 * scale, 0.34
		else
			lowZ, lowR, highZ, highR = 1.25, 0.3, 1.25 + 0.52, 0.46
		end
		local width = 0.22
		local guardX = cx + 1.1 * scale + width / 2 + 0.01
		cylinder(guards, guardX, 0, lowZ, lowR, width, "x")
		cylinder(guards, guardX, 0, highZ, highR, width, "x")
		box(guards, guardX, 0, lowZ, width, lowR * 2, highZ - lowZ)
		if tier == 3 then
			-- Vent louvres pressed into the cover's face, and side skirts
			-- boxing in the conveyor belt.
			for k = 0, 2 do
				box(guards, guardX + width / 2, 0, highZ - 0.15 + k * 0.12, 0.04, highR * 1.2, 0.04)
			end
			for _, side in { -1, 1 } do
				box(guards, cx + side * 0.55 * scale, 3.15 * scale, 0.32, 0.05, 2.1 * scale, 0.22)
			end
		end
		part(`{group}_Guards`, guards, GUARD[tier - 1], group, SMALL_TEXTURE)
	end

	local bin = warpedMesh(warp)
	hopper(bin, cx, 2.1 * scale, 1.9 * scale, 3 * scale, 1.1 * scale, chaos)
	part(`{group}_Hopper`, bin, HOPPER, group, LARGE_TEXTURE, hopperColor(2.1 * scale, 1.1 * scale, wear))

	local chute = warpedMesh(warp)
	box(chute, cx, 1.3 * scale, 0.3, 1 * scale, 1.4 * scale, 0.15)
	part(`{group}_Chute`, chute, CHUTE, group, SMALL_TEXTURE)

	local extras = warpedMesh(warp)
	if tier == 1 then
		-- Hand crank on the side.
		cylinder(extras, cx + 1.25 * scale, 0, 1.6 * scale, 0.08, 0.3, "x")
		box(extras, cx + 1.4, 0, 1.6 * scale, 0.1, 0.1, 0.6)
	elseif tier == 2 then
		-- Petrol engine with cooling fins, an exhaust stack, a heavy flywheel
		-- on its far side and a pressure gauge on top.
		local motorX = cx + 1.1 * scale + 0.75
		box(extras, motorX, 0, 0.6, 0.9, 1, 0.9)
		for _, offset in { -0.35, -0.2, -0.05 } do
			box(extras, motorX + offset, 0, 1.5, 0.04, 1, 0.1)
		end
		cylinder(extras, motorX + 0.24, 0.3, 1.5, 0.1, 1.2, "z")
		cylinder(extras, motorX + 0.55, 0, 1.05, 0.42, 0.12, "x")
		cylinder(extras, motorX + 0.55, 0, 1.05, 0.08, 0.3, "x")
		cylinder(extras, motorX + 0.2, -0.3, 1.5, 0.05, 0.25, "z")
		cylinder(extras, motorX + 0.2, -0.3, 1.75, 0.13, 0.06, "z")
	else
		-- Electric motor: an upright drum wrapped in cooling rings.
		local motorX = cx + 1.7 * scale
		-- Bolted down on a base plate with a bracket arm back to the frame.
		box(extras, motorX, 0, 0, 1.1, 1.1, 0.2)
		box(extras, (cx + 1.1 * scale + motorX) / 2, 0, 0.6, motorX - cx - 1.1 * scale + 0.2, 0.5, 0.15)
		cylinder(extras, motorX, 0, 0.2, 0.45, 1.3, "z")
		for k = 0, 4 do
			cylinder(extras, motorX, 0, 0.35 + k * 0.22, 0.52, 0.05, "z")
		end
		cylinder(extras, motorX, 0, 1.5, 0.2, 0.15, "z")
	end
	part(`{group}_Extras`, extras, if tier == 1 then FRAME else MOTOR, group, SMALL_TEXTURE, if tier == 1 then nil else motorColor(wear))

	if tier == 3 then
		-- Control box on the housing's front with a cable run to the motor.
		local electrics = warpedMesh(warp)
		box(electrics, cx + 0.5 * scale, -0.9 * scale - 0.12, 1.4 * scale, 0.6, 0.24, 0.6)
		box(electrics, cx + 0.5 * scale + 0.3, -0.9 * scale - 0.1, 1.2, 1.2 * scale, 0.06, 0.06)
		part(`{group}_Electrics`, electrics, ELECTRICS, group, SMALL_TEXTURE)

		local lamp = warpedMesh(warp)
		cylinder(lamp, cx + 0.5 * scale, -0.9 * scale - 0.12, 1.4 * scale + 0.6, 0.09, 0.12, "z")
		part(`{group}_StatusLamp`, lamp, LAMP, group, SMALL_TEXTURE)
	end
end
