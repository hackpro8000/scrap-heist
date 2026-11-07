-- Trashalero Trashala: Tralalero Tralala riveted from tin sheet. A blue
-- shark with a white belly, nose forward (+x), standing on three steel pipe
-- legs in blue sneakers with white soles: two under its chest, one under
-- its tail end. Its own small black shark eyes, a raked dorsal fin, two
-- flat side fins, a tall forked tail and a toothy mouth under its snout.
-- No googly face. 3.4 studs tall, 4 long.
-- include: JunkrotKit
local TIN_BLUE = { 0.36, 0.55, 0.78 }
local SNEAKER_BLUE = { 0.16, 0.32, 0.86 }
local MIDDLE = 2.1 -- the body's middle
-- Legs stand here: two under the chest, one under the tail end.
local STANDS = { { 0.65, -0.38 }, { 0.65, 0.38 }, { -0.95, 0 } }

-- The shark, as one mesh: a sphere drawn out along x and tapering to the
-- tail, its dorsal fin pulled out of it (tagged "fins", so the belly
-- leaves it blue). The belly is its own underside; the tail and side fins
-- are plates of tin riveted on (part Fins).
local function shark()
	local m = EditMesh.sphere(1, 16)
	m:transform(function(p)
		local x = p[1] * 1.95
		local tail = math.clamp(-x / 1.95, 0, 1)
		local nose = math.clamp(x / 1.95, 0, 1)
		local thick = 1 - 0.6 * tail ^ 1.4 - 0.25 * nose ^ 2
		return { x, p[2] * 0.72 * thick, p[3] * 0.85 * thick - 0.12 * nose ^ 2 + 0.15 * tail ^ 2 }
	end)
	-- Faces picked before any extrusion moves things about.
	local back = m:select("face", "facing", { 0, 0, 1 }, 30):filter(function(p)
		return p[1] > -0.75 and p[1] < 0.15 and math.abs(p[2]) < 0.25
	end)
	local chin = m:select("face", "facing", { 0.4, 0, -1 }, 35):filter(function(p)
		return p[1] > 1.05 and math.abs(p[2]) < 0.3
	end)
	m:tagging("fins", function()
		-- Dorsal fin, raked back and thin side to side.
		local fin = back
		for step, rise in { 0.38, 0.32, 0.24 } do
			fin = m:extrude(fin, { -0.12 - 0.08 * step, 0, rise })
			fin:scale({ 0.65, 0.45, 0.65 })
		end
	end)
	-- The mouth: the chin sunk in under the snout.
	if chin:count() > 0 then
		local lip = m:inset(chin, 0.05, 0)
		m:extrude(lip, -0.14)
	end
	m:smoothSubdivide(1)
	m:translate(0, 0, MIDDLE)
	return m
end
local body = shark()

part("Body", nil, TIN_BLUE, function(mesh)
	body:emit(mesh)
end, true, 0.35)
part("Belly", nil, { 0.88, 0.89, 0.86 }, function(mesh)
	-- The body's underside, fins left out, lifted off a hair and given its
	-- own thickness.
	local belly = body:copy()
	local keep = belly:select("face", "where", function(p)
		return p[3] < MIDDLE - 0.12 and p[1] > -1.5
	end):minus(belly:select("face", "tag", "fins"))
	for _, id in belly:select("face", "all"):minus(keep):list() do
		belly:removeFace(id)
	end
	belly:push(belly:select("vertex", "all"), 0.012)
	belly:solidify(0.03)
	belly:emit(mesh)
end, true, 0.25)
part("Fins", nil, TIN_BLUE, function(mesh)
	-- The tail: a tall crescent, its upper lobe sweeping up and back, a
	-- shorter one below, thin side to side.
	for _, lobe in {
		{ { -1.7, 0.05 }, { -1.5, 0.18 }, { -2.15, 0.95 }, { -2.3, 0.88 } },
		{ { -1.6, 0.1 }, { -1.75, 0.2 }, { -2.15, -0.35 }, { -2.0, -0.42 } },
	} do
		local plate = Kit.plate(lobe, 0.08)
		plate:translate(0, -0.04, MIDDLE)
		plate:emit(mesh)
	end
	-- Side fins: out from the chest and down, swept back.
	for _, side in { -1, 1 } do
		local fin = Kit.plate({ { 0, 0 }, { 0.35, 0 }, { -0.15, 0.55 }, { -0.3, 0.5 } }, 0.05)
		Kit.turn(fin, "x", -side * 120)
		fin:translate(0.45, side * 0.32, MIDDLE - 0.25)
		fin:emit(mesh)
	end
end, 40, 0.35)
part("Eyes", nil, { 0.04, 0.04, 0.05 }, function(mesh)
	for _, side in { -1, 1 } do
		local eye = EditMesh.sphere(0.11, 8)
		eye:translate(1.32, side * 0.4, MIDDLE + 0.22)
		eye:emit(mesh)
	end
end, true, 0)
part("Teeth", nil, { 0.95, 0.95, 0.9 }, function(mesh)
	-- A row of chunky teeth along each side of the mouth, points down.
	for _, side in { -1, 1 } do
		for k = 0, 3 do
			local tooth = EditMesh.cone(0.075, 0.015, 0.22, 4, 1)
			Kit.turn(tooth, "x", 180)
			tooth:translate(1.2 + k * 0.12, side * (0.2 - k * 0.03), MIDDLE - 0.62 + k * 0.05)
			tooth:emit(mesh)
		end
	end
end, 40, 0)
part("Legs", nil, DARK_STEEL, function(mesh)
	for _, at in STANDS do
		local m = EditMesh.cylinder(0.12, MIDDLE - 0.3, 8, 2)
		m:translate(at[1], at[2], 0.28 + (MIDDLE - 0.3) / 2)
		m:emit(mesh)
	end
end, true, 0.4)
part("Sneakers", nil, SNEAKER_BLUE, function(mesh)
	for _, at in STANDS do
		local shoe = Kit.shoe(0.95, 0.5, 0.36)
		shoe:translate(at[1] + 0.12, at[2], 0.06)
		shoe:emit(mesh)
	end
end, true, RUBBER)
part("Soles", nil, { 0.95, 0.95, 0.93 }, function(mesh)
	for _, at in STANDS do
		local sole = Kit.block(0.98, 0.52, 0.1, 0.04)
		sole:translate(at[1] + 0.12, at[2], 0.05)
		sole:emit(mesh)
	end
end, 50, RUBBER)
finishParts()
