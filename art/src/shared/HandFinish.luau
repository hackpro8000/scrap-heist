-- The hand-painted finish for a model's parts: `coats` names a part's hand coat
-- ("metal", "wood" or "rock"), `plain` lists parts left alone, such as lamps. A
-- crisp part with a hand coat keeps its exact shapes and takes only the
-- brushwork's tone. Call it just before finishParts().
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

local function handFinish(coats, plain)
	for _, entry in parts do
		if plain[entry.name] then
			continue
		end
		entry.hand = coats[entry.name]
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
	end
end
