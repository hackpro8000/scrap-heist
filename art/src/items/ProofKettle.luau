-- Proof Kettle: a test of the edit-mesh tools. One sphere, squashed and
-- flattened underneath; a lid inset into its top with a knob pulled up from
-- it; a spout extruded out of its side in curving steps; a handle made by
-- extruding two faces out, turning them to face each other and bridging
-- them; then smoothed once. About 2.4 across and 2 tall, on the origin.
-- include: EditMesh
-- include: EditOps
-- include: EditShapes
local ENAMEL = { 0.2, 0.46, 0.6 }
part("Body", nil, ENAMEL, function(mesh)
	local m = EditMesh.sphere(1.0, 16)
	m:transform(function(p)
		return { p[1], p[2], math.max(p[3] * 0.85, -0.6) }
	end)
	-- The handle's two ends, chosen now while the -x side is plain sphere:
	-- ids don't change, so they can be used after the lid and spout are made.
	local side = m:select("face", "facing", { -1, 0, 0 }, 50):filter(function(p)
		return math.abs(p[2]) < 0.3
	end)
	local upper = side:filter(function(p)
		return p[3] > 0.3
	end)
	local lower = side:filter(function(p)
		return p[3] < -0.3
	end)
	-- The flat base keeps its edge through the smoothing.
	m:select("edge", "where", function(p)
		return p[3] < -0.59
	end):crease(1)
	-- Lid and knob.
	local lid = m:select("face", "facing", { 0, 0, 1 }, 22)
	local inner = m:inset(lid, 0.1, -0.03)
	local knobBase = m:inset(inner, 0.12, 0.04)
	local knob = m:extrude(knobBase, 0.22)
	knob:scale(0.7)
	-- Spout: out of the +x side, rising and narrowing step by step.
	local spout = m:select("face", "facing", { 1, 0, 0 }, 25):filter(function(p)
		return p[3] < 0.2
	end)
	for step = 1, 4 do
		spout = m:extrude(spout, { 0.22, 0, 0.08 + 0.1 * step })
		spout:scale(0.82)
		spout:rotate({ 0, 1, 0 }, -12)
	end
	-- Handle: the two ends extruded out, turned to face each other, bridged.
	local a = m:extrude(upper, 0.35)
	a:rotate({ 0, 1, 0 }, -60)
	local b = m:extrude(lower, 0.35)
	b:rotate({ 0, 1, 0 }, 60)
	m:bridgeFaces(a, b)
	m:smoothSubdivide(1)
	m:translate(0, 0, 0.62)
	m:emit(mesh)
end, nil, 0.25)
finishParts()
