-- The hand-painted finish for a model's parts: `coats` names a part's hand coat
-- ("metal", "wood" or "rock"), `plain` lists parts left alone, such as lamps. A
-- crisp part with a hand coat keeps its exact shapes and takes only the
-- brushwork's tone. `finish` maps coat names and part names to a preset below,
-- for props standing alone on open ground; the town models leave it nil.
-- Call it just before finishParts().
local SMALL_MARKS = {
	big_length_min = 0.4,
	big_length_max = 0.75,
	big_width_min = 0.14,
	big_width_max = 0.28,
	mid_length_min = 0.2,
	mid_length_max = 0.4,
	mid_width_min = 0.07,
	mid_width_max = 0.13,
	edge_opacity = 0,
}

-- One preset per material, so tuning concrete never moves steel. A number a
-- model set on the part before handFinish wins over the preset's. `bands`
-- paints the stepped gradient: `steps` (default by height), `drop` (how dark
-- the lowest step goes), `top` (the top step's brightness), `facing` (loose
-- pieces each lit from above) and `stain` (how far a short part's steps wander
-- as blotches instead of bands; high values fleck a dark surface).
local PRESETS = {
	-- Steel standing alone on open ground. Its coat is paint over metal: the
	-- roughness map polishes the worn rims and roughens creases and rust, and
	-- the metalness map shows bare metal where the edge wear cuts through,
	-- never under the rust.
	propMetal = { gradient = 0.2, shade = 2, rustEdges = true, edge = 0.3, lit = 1.6, litUneven = 0.85, bands = { drop = 0.48, top = 1 }, roughness = { base = 0.7, edge = -0.6, crease = 0.15, wear = 0.25 }, metalness = { base = 0.05, edge = 0.85, crease = 0, wear = -0.3 } },
	-- Concrete footings and plinths.
	propConcrete = { gradient = 0.4, shade = 2, rustEdges = true, edge = 0.3, lit = 1.28, litUneven = 0.85, bands = { drop = 0.48, top = 1 } },
	-- Stones on the map, banded from the turf up by the bandDepth the layout gives them.
	-- Stone's edges tilt hard in the normal map, along the highlight strokes,
	-- and its roughness map polishes those worn rims while the creases stay matte.
	rock = { gradient = 0.4, shade = 1, rustEdges = true, edge = 0.3, lit = 1.28, litUneven = 0.85, bands = { steps = 4, drop = 0.32, top = 1 }, bevel = { tilt = 8 }, roughness = { base = 0.85, edge = -0.7, crease = 0.1, wear = 0 } },
	-- Loose pieces lying on a heap, each banded on its own from the model's bandPieces.
	heapPiece = { gradient = 0.2, shade = 1.4, rustEdges = true, edge = 0.3, lit = 1.8, litUneven = 0.85, bands = { steps = 4, drop = 0.58, top = 1, facing = true } },
	-- The earth body of a heap: it darkens well under everything resting on it.
	heapBody = { gradient = 0.4, shade = 1.8, rustEdges = true, edge = 0.45, lit = 1.0, litUneven = 0.85, softLit = 0, bands = { drop = 0.48, top = 1, stain = 0.08 } },
}
-- The finish most props take.
local PROP_FINISH = { metal = "propMetal", rock = "propConcrete" }

-- Light at the top, stepping down to dark and cool at the base. The hand coat
-- samples this per stroke, so each step's edge comes out brushed, not ruled.
local function paintStepBands(entry, bands)
	if entry.crisp and not entry.bandCrisp then
		return
	end
	-- The part's height range, read off a scratch paint of its surface.
	local low, high = math.huge, -math.huge
	entry.mesh:paint(Image.new(32, 32), function(_x, _y, z)
		low, high = math.min(low, z), math.max(high, z)
		return 0, 0, 0
	end)
	if high - low < 0.25 then
		return
	end
	-- Loose pieces listed as { x, y, z, radius } each band from their own top to
	-- their own foot, instead of all sharing the part's height.
	if entry.bandPieces then
		local pieces = entry.bandPieces
		entry.bandDepth = function(x: number, y: number, z: number): number
			local nearest, best = pieces[1], math.huge
			for _, piece in pieces do
				local d = (x - piece[1]) ^ 2 + (y - piece[2]) ^ 2 + (z - piece[3]) ^ 2
				if d < best then
					nearest, best = piece, d
				end
			end
			return 1 - math.clamp((z - nearest[3] + nearest[4]) / (2 * nearest[4]), 0, 1)
		end
	end
	-- Tall parts get more steps, so any stretch of them shows some.
	local steps = bands.steps or math.clamp(math.round((high - low) / 1.5), 4, 8)
	local drop, top = bands.drop, bands.top
	local paint = entry.paint
	entry.custom = true
	entry.paint = function(x: number, y: number, z: number, nx: number, ny: number, nz: number)
		local r, g, b = paint(x, y, z, nx, ny, nz)
		local depth = if entry.bandDepth then entry.bandDepth(x, y, z) else 1 - (z - low) / (high - low)
		if bands.facing then
			depth = depth * 0.3 + (1 - nz) * 0.35
		end
		depth += 0.07 * math.noise(x * 0.7, y * 0.7, z * 0.35)
		-- A short part has no height to band, so it stains in steps instead.
		if high - low < 1.5 then
			depth += (bands.stain or 0.4) * math.noise(x * 0.5, y * 0.5, z * 0.3)
		end
		local step = math.clamp(math.floor(depth * steps), 0, steps - 1) / (steps - 1)
		-- A small lift at the top, so near-black paint still shows its steps.
		local lift = (1 - step) * 0.22 * (1 - math.max(r, g, b)) ^ 2
		return r * (top - drop * step) + lift, g * (top - (drop + 0.02) * step) + lift, b * (top - (drop - 0.08) * step) + lift
	end
end

local function applyPreset(entry, preset)
	entry.gradient = entry.gradient or preset.gradient
	entry.shade = entry.shade or preset.shade
	entry.edge = entry.edge or preset.edge
	entry.lit = entry.lit or preset.lit
	entry.litUneven = preset.litUneven
	if entry.rustEdges == nil then
		entry.rustEdges = preset.rustEdges
	end
	-- Earth has no edge for the soft highlight to glow along; it flecks the rim.
	if preset.softLit then
		entry.softLit = preset.softLit
	end
	-- The normal map's bevel field, where the material shapes it.
	if preset.bevel then
		entry.bevelReach = entry.bevelReach or preset.bevel.reach
		entry.bevelFold = entry.bevelFold or preset.bevel.fold
		entry.bevelTilt = entry.bevelTilt or preset.bevel.tilt
	end
	-- The roughness map, from the material's base and the layers already baked.
	if preset.roughness then
		entry.roughnessBase = entry.roughnessBase or preset.roughness.base
		entry.roughnessEdge = entry.roughnessEdge or preset.roughness.edge
		entry.roughnessCrease = entry.roughnessCrease or preset.roughness.crease
		entry.roughnessWear = entry.roughnessWear or preset.roughness.wear
	end
	if preset.metalness then
		entry.metalnessBase = entry.metalnessBase or preset.metalness.base
		entry.metalnessEdge = entry.metalnessEdge or preset.metalness.edge
		entry.metalnessCrease = entry.metalnessCrease or preset.metalness.crease
		entry.metalnessWear = entry.metalnessWear or preset.metalness.wear
	end
	entry.handTune = SMALL_MARKS
	paintStepBands(entry, preset.bands)
end

local function handFinish(coats, plain, finish)
	-- Every chunk of one part must come out with the same finish; a chunk
	-- that doesn't is a seam in the paint, so it stops the build.
	local finishes: { [string]: string } = {}
	for _, entry in parts do
		-- A chunked part takes the coat of the part it was built under
		-- (chunkedPart tags each chunk with it), not whatever its own name parses to.
		local name = entry.chunkOf or entry.name
		if plain[name] or plain[entry.name] then
			continue
		end
		entry.hand = coats[name]
		if entry.hand == nil then
			entry.litMotion = "worn"
		elseif entry.hand == "metal" then
			entry.handTune = SMALL_MARKS
		end
		entry.softLit, entry.softEdge, entry.softUneven, entry.softTaper = 0.25, 0.22, 0, 0.8
		entry.softToZero, entry.softPower = true, 2
		entry.taper = entry.taper or 0.5
		entry.litToZero, entry.litUneven, entry.litUnevenStep = true, 0.6, 0.5
		entry.brushes = { shade = { motion = "feather", tune = { width = 0.02 } } }
		local presetName = finish and (finish[name] or finish[entry.hand])
		if presetName then
			applyPreset(entry, PRESETS[presetName] or error(`no finish preset {presetName}`))
		end
		local signature = `{entry.hand or "-"}/{presetName or "-"}`
		if finishes[name] and finishes[name] ~= signature then
			error(`chunks of {name} would wear different finishes ({finishes[name]} and {signature}); the paint would seam`)
		end
		finishes[name] = signature
	end
end
