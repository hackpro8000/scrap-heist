-- Proof Shark: a test of the edit-mesh tools as box modelling. One box,
-- cut into slices along its length, each slice sized to a shark's body; a
-- dorsal fin, a forked tail and two side fins extruded out of its faces
-- and swept back; then smoothed twice. About 4.5 long, nose toward +x.
-- include: EditMesh
-- include: EditOps
-- include: EditShapes
local SHARK = { 0.42, 0.5, 0.58 }
part("Body", nil, SHARK, function(mesh)
	local m = EditMesh.box({ 4, 1, 1 }, { 8, 2, 2 })
	-- Thickest a third of the way from the nose, thin at both ends.
	m:transform(function(p)
		local t = (p[1] + 2) / 4
		local girth = 0.18 + 0.82 * math.sin(math.pi * math.clamp(t, 0, 1) ^ 0.7)
		local nose = if t > 0.85 then 1 - (t - 0.85) * 2.5 else 1
		return { p[1], p[2] * girth * nose, p[3] * girth * 1.15 * nose + 0.08 * math.sin(math.pi * t) }
	end)
	-- Dorsal fin: up from the top, swept back and thinned to a point.
	local dorsal = m:select("face", "facing", { 0, 0, 1 }, 40):filter(function(p)
		return p[1] > 0 and p[1] < 0.5
	end)
	local fin = m:extrude(dorsal, { -0.15, 0, 0.45 })
	fin:scale({ 0.75, 0.35, 1 })
	fin = m:extrude(fin, { -0.35, 0, 0.35 })
	fin:scale({ 0.35, 0.5, 1 })
	-- Tail: the upper half of the tail end swept up and back, the lower
	-- half down and back.
	local tailEnd = m:select("face", "facing", { -1, 0, 0 }, 40)
	local upper = tailEnd:filter(function(p)
		return p[3] > 0.0
	end)
	local lower = tailEnd:minus(upper)
	local u = m:extrude(upper, { -0.35, 0, 0.55 })
	u:scale({ 0.6, 0.35, 0.6 })
	u = m:extrude(u, { -0.25, 0, 0.35 })
	u:scale(0.4)
	local l = m:extrude(lower, { -0.35, 0, -0.35 })
	l:scale({ 0.6, 0.35, 0.6 })
	-- Side fins near the front, out and back, flattened.
	for _, side in { -1, 1 } do
		local base = m:select("face", "facing", { 0, side, 0 }, 40):filter(function(p)
			return p[1] > 0.5 and p[1] < 1.0 and p[3] < 0
		end)
		local pectoral = m:extrude(base, { -0.25, side * 0.55, -0.2 })
		pectoral:scale({ 0.7, 1, 0.3 })
	end
	m:smoothSubdivide(2)
	m:translate(0, 0, 1.2)
	m:emit(mesh)
end, nil, 0.2)
finishParts()
