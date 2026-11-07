-- Jackolo Crickato: a scissor car jack cranked halfway up, four channel
-- arms in a diamond on pivot pins, the long screw run through its side
-- pivots out to a crank handle, a cupped saddle on top for a hat and a
-- wide base plate to stand on. 3.2 studs tall.
-- include: JunkrotKit
local FACE = { { -0.2, -0.32, 2.75, 0.16 }, { 0.2, -0.32, 2.77, 0.16 } }
local FEET = { 1.2, 0.5 }
local JACK_RED = { 0.7, 0.16, 0.12 }
local BOTTOM, SIDE, TOP = 0.75, 1.65, 2.55
local HALF = 0.82 -- half the diamond's width
local PINS = { { 0, BOTTOM }, { -HALF, SIDE }, { 0, TOP }, { HALF, SIDE } }
part("Arms", nil, JACK_RED, function(mesh)
	-- Each arm runs pin to pin as two side plates: a channel.
	for k = 1, 4 do
		local a, b = PINS[k], PINS[k % 4 + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dz * dz)
		for _, y in { -0.13, 0.13 } do
			local plate = Kit.block(length + 0.16, 0.05, 0.22, 0.03)
			Kit.turn(plate, "y", -math.deg(math.atan2(dz, dx)))
			plate:translate((a[1] + b[1]) / 2, y, (a[2] + b[2]) / 2)
			plate:emit(mesh)
		end
	end
	local base = Kit.block(1.4, 0.6, 0.14, 0.04)
	base:translate(0, 0, BOTTOM - 0.12)
	base:emit(mesh)
end, 50, 0.6)
part("Saddle", nil, JACK_RED, function(mesh)
	local m = Kit.block(0.8, 0.5, 0.3, 0.08)
	local top = m:select("face", "facing", { 0, 0, 1 }, 10)
	if top:count() > 0 then
		Kit.recess(m, top, 0.08, 0.06)
	end
	m:translate(0, 0, TOP + 0.2)
	m:emit(mesh)
end, 50, 0.55)
part("Screw", nil, STEEL, function(mesh)
	for _, pin in PINS do
		local m = EditMesh.cylinder(0.07, 0.4, 8, 1)
		Kit.turn(m, "x", 90)
		m:translate(pin[1], 0, pin[2])
		m:emit(mesh)
	end
	Kit.tube({ { -HALF - 0.12, 0, SIDE }, { HALF + 0.9, 0, SIDE } }, 0.07, 8):emit(mesh)
	Kit.tube({ { HALF + 0.88, 0, SIDE }, { HALF + 0.95, -0.3, SIDE }, { HALF + 0.95, -0.3, SIDE + 0.45 } }, 0.05, 6):emit(mesh)
	local knob = EditMesh.sphere(0.08, 8)
	knob:translate(HALF + 0.95, -0.3, SIDE + 0.5)
	knob:emit(mesh)
end, true, 0.5)
-- include: JunkrotFace
