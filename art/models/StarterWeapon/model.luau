-- Starter weapon: a wooden baseball bat, built along +Z with the knob at the
-- origin so the tool's grip sits at the handle.
local SEGMENTS = 24

-- Bat profile as {radius, height, tone} from the knob up to the barrel cap.
-- Tone is hand-painted shading baked into the color: positive brightens edges
-- and bulges, negative darkens creases. It is painted by shape, not light.
local PROFILE = {
	{ 0.0, 0.0, 0.0 },
	{ 0.17, 0.0, 0.15 },
	{ 0.17, 0.08, 0.45 },
	{ 0.1, 0.16, -0.55 },
	{ 0.1, 1.3, -0.15 },
	{ 0.12, 2.0, -0.05 },
	{ 0.2, 2.9, 0.1 },
	{ 0.24, 3.5, 0.3 },
	{ 0.24, 3.9, 0.15 },
	{ 0.2, 4.0, 0.5 },
	{ 0.0, 4.02, 0.1 },
}

-- Hand-painted palette, in sRGB: tone blends from the base toward these.
local BASE = { 0.78, 0.55, 0.32 }
local HIGHLIGHT = { 0.97, 0.8, 0.55 }
local SHADOW = { 0.4, 0.23, 0.11 }
local GRAIN = { 0.55, 0.35, 0.18 }

local TEXTURE_WIDTH = 64
local TEXTURE_HEIGHT = 256

-- Distance along the silhouette, 0 to 1, used as the texture's V.
local function arcLengths(profile)
	local lengths = { 0 }
	for i = 2, #profile do
		local a, b = profile[i - 1], profile[i]
		lengths[i] = lengths[i - 1] + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	end
	local total = lengths[#lengths]
	for i, length in lengths do
		lengths[i] = length / total
	end
	return lengths
end

local function lathe(profile)
	local mesh = Mesh.new()
	local vs = arcLengths(profile)
	local rings = {}
	for index, point in profile do
		local ring = {}
		for i = 0, SEGMENTS - 1 do
			local angle = 2 * math.pi * i / SEGMENTS
			ring[i] = mesh:vertex(math.cos(angle) * point[1], math.sin(angle) * point[1], point[2])
		end
		rings[index] = ring
	end
	for index = 1, #profile - 1 do
		local low, high = rings[index], rings[index + 1]
		local v0, v1 = vs[index], vs[index + 1]
		for i = 0, SEGMENTS - 1 do
			local j = (i + 1) % SEGMENTS
			-- The last column wraps to u = 1 so the seam doesn't smear.
			local u0, u1 = i / SEGMENTS, (i + 1) / SEGMENTS
			mesh:face({ low[i], low[j], high[j], high[i] }, { u0, v0, u1, v0, u1, v1, u0, v1 })
		end
	end
	-- The first and last rings have zero radius, so merge them into poles.
	mesh:weld()
	return mesh
end

local function mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local function toneAt(v, vs, profile)
	for i = 2, #vs do
		if v <= vs[i] then
			local v0, v1 = vs[i - 1], vs[i]
			local t0, t1 = profile[i - 1][3], profile[i][3]
			return t0 + (t1 - t0) * (if v1 > v0 then (v - v0) / (v1 - v0) else 0)
		end
	end
	return profile[#profile][3]
end

-- Long streaks running down the bat, wobbling a little along its length.
local function grainAt(u, v)
	local wobble = 0.02 * math.sin(v * 37 + u * 11)
	local streaks = math.sin((u + wobble) * 2 * math.pi * 9) * 0.5 + math.sin((u + wobble) * 2 * math.pi * 23 + 1.7) * 0.5
	return math.max(0, streaks - 0.55) * 1.4
end

local function paintTexture(profile)
	local vs = arcLengths(profile)
	local image = Image.new(TEXTURE_WIDTH, TEXTURE_HEIGHT)
	for y = 0, TEXTURE_HEIGHT - 1 do
		local v = (y + 0.5) / TEXTURE_HEIGHT
		local tone = toneAt(v, vs, profile)
		local shaded = if tone >= 0 then mix(BASE, HIGHLIGHT, tone) else mix(BASE, SHADOW, -tone)
		for x = 0, TEXTURE_WIDTH - 1 do
			local color = mix(shaded, GRAIN, grainAt((x + 0.5) / TEXTURE_WIDTH, v) * 0.6)
			image:set(x, y, color[1], color[2], color[3])
		end
	end
	return image
end

model.part("StarterWeapon", lathe(PROFILE), paintTexture(PROFILE))
