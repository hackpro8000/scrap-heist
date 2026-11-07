-- Proof Toaster: a test of the edit-mesh tools. The whole shell is one
-- rounded box: two slots inset into its top and pushed down into it, a
-- lever housing extruded from its side, and four feet extruded from its
-- base. 2.6 x 1.6, about 2.1 tall, standing on the origin. The toast sits
-- in the -y slot.
-- include: EditMesh
-- include: EditOps
-- include: EditShapes
local SHELL = { 0.74, 0.76, 0.78 }
local BREAD = { 0.62, 0.42, 0.2 }
part("Shell", nil, SHELL, function(mesh)
	local m = EditMesh.roundedBox({ 2.6, 1.6, 2.0 }, 0.3, 3, { 6, 5, 2 })
	-- Slots: a strip of the top's flat faces either side of the middle.
	for _, y in { -0.2, 0.2 } do
		local strip = m:select("face", "facing", { 0, 0, 1 }, 5):filter(function(p)
			return math.abs(p[1]) < 0.7 and math.abs(p[2] - y) < 0.05
		end)
		local inner = m:inset(strip, 0.04, 0)
		m:extrude(inner, -1.0)
	end
	-- Lever housing on the +x side, high up, with a knob on it.
	local housing = m:select("face", "facing", { 1, 0, 0 }, 5):filter(function(p)
		return math.abs(p[2]) < 0.15 and p[3] > 0
	end)
	local top = m:extrude(housing, 0.12)
	local knob = m:inset(top, 0.04, 0)
	m:extrude(knob, 0.18)
	-- Feet at the four corners of the base.
	local feet = m:select("face", "facing", { 0, 0, -1 }, 5):filter(function(p)
		return math.abs(p[1]) > 0.6 and math.abs(p[2]) > 0.35
	end)
	m:extrude(feet, 0.1, { each = true })
	m:translate(0, 0, 1.1)
	m:emit(mesh)
end, nil, 0.2)
part("Toast", nil, BREAD, function(mesh)
	local m = EditMesh.roundedBox({ 1.1, 0.16, 0.8 }, 0.06, 2)
	m:translate(0, -0.2, 2.0)
	m:emit(mesh)
end, nil, RUBBER)
finishParts()
