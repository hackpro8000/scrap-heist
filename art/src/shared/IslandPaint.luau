-- Island paint: the rock islands' texture (strata, pebbles, grit and topsoil),
-- shared by the rock-wall items and the rock-cell items.
local GROUND = { 0.3, 0.27, 0.22 }
local STRATA = { { 0.5, 0.4, 0.27 }, { 0.36, 0.35, 0.34 }, { 0.48, 0.3, 0.22 } }
local TOPSOIL = { 0.24, 0.19, 0.14 }
-- Grit flecks in the ground and topsoil, and the pebbles set in the strata.
local GRIT_LIGHT, GRIT_DARK = { 0.58, 0.54, 0.46 }, { 0.11, 0.09, 0.07 }
local PEBBLES = { { 0.6, 0.57, 0.52 }, { 0.27, 0.26, 0.25 }, { 0.55, 0.38, 0.26 } }
-- How far a bed's colour drifts warmer or cooler.
local HUE_SHIFT = 0.07

local function random(k: number): number
	local s = math.sin(k * 12.9898 + 4.1414) * 43758.5453
	return s - math.floor(s)
end

local function mix(r: number, g: number, b: number, colour, f: number): (number, number, number)
	return r + (colour[1] - r) * f, g + (colour[2] - g) * f, b + (colour[3] - b) * f
end

-- Grit: sparse light and dark flecks a texel or two across, blended in.
local function grit(r: number, g: number, b: number, x: number, y: number, z: number): (number, number, number)
	local n = math.noise(x * 9, y * 9, z * 9 + 61)
	if math.abs(n) < 0.5 then return r, g, b end
	return mix(r, g, b, if n > 0 then GRIT_LIGHT else GRIT_DARK, math.min((math.abs(n) - 0.5) * 6, 0.7))
end

-- The island's texture: gritty ground on top, then topsoil fading into wavy
-- rock strata that darken with depth, with pebbles packed into some beds
-- like a conglomerate. A rock's `seed` shifts its strata, grain and hue
-- so neighbours don't match, and each rock has its own `tint`.
-- `spread` scales how far a rock's tint and hue wander from its neighbours' (1
-- by default). `single` holds the whole rock to one stratum and one pebble
-- colour, so a rock reads as cut from a single material.
local function islandPaint(x: number, y: number, z: number, seed: number?, tint: number?, spread: number?, single: boolean?)
	local below = -z
	if below < 0.3 then
		local k = 1 + 0.12 * math.noise(x / 4, y / 4, 31) + 0.05 * math.noise(x * 3, y * 3, 37)
		return grit(GROUND[1] * k, GROUND[2] * k, GROUND[3] * k, x, y, z)
	end
	local s = seed or 0
	local band = math.noise(x / 9 + s, y / 9, z / 2) * 0.6 + z * (0.8 + 0.2 * random(s + 1)) + random(s + 2) * 3
	local wave = math.sin(band * 2.4)
	local layer = STRATA[if single then math.floor(random(s + 4) * 3) + 1 else math.floor(band * 2.4 / (2 * math.pi)) % 3 + 1]
	local k = (1 + ((tint or 1) - 1) * (spread or 1)) * (1 + 0.1 * wave + 0.06 * math.noise(x * 2 + s, y * 2, z * 2))
	if wave > 0.93 then k -= 0.25 end
	k *= 1 - 0.6 * math.clamp((below - 3) / 20, 0, 1)
	local r, g, b = layer[1], layer[2], layer[3]
	-- Pebbles: rounded clasts, packed denser in some beds than others, each
	-- picked from PEBBLES by a slower noise and ringed by a dark seam.
	local threshold = 0.42 - 0.2 * math.noise(x / 6, y / 6, z / 1.5 + 79)
	local p = math.noise(x * 1.7 + s, y * 1.7, z * 1.7 + 71) - threshold
	if p > 0 then
		local c = if single then random(s + 5) * 0.6 - 0.3 else math.noise(x * 0.9, y * 0.9, z * 0.9 + 83)
		local pebble = PEBBLES[if c < -0.12 then 1 elseif c < 0.12 then 2 else 3]
		local seam = 1 - 0.3 * math.max(0, 1 - p / 0.05)
		r, g, b = pebble[1] * seam, pebble[2] * seam, pebble[3] * seam
	end
	-- The rock's hue drifts warmer or cooler, keeping its brightness.
	local hue = HUE_SHIFT * (spread or 1) * (2 * random(s + 3) - 1)
	r, g, b = r * k * (1 + hue), g * k * (1 + 0.2 * hue), b * k * (1 - hue)
	local soil = 1 - math.clamp((below - 0.5) / 4 + 0.3 * math.noise(x / 2, y / 2, 41), 0, 1)
	r, g, b = mix(r, g, b, TOPSOIL, soil)
	if soil <= 0 then return r, g, b end
	-- Grit only shows where the soil does.
	local gr, gg, gb = grit(r, g, b, x, y, z)
	return r + (gr - r) * soil, g + (gg - g) * soil, b + (gb - b) * soil
end
