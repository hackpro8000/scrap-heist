-- Sousvide Silvano: a sous-vide wand, a slim brushed-steel column with a
-- guard round its foot slotted for the water, a black head with a glowing
-- orange readout and a scroll wheel on top, and its clamp out to one side
-- like an arm with the screw knob under its jaw. 4 studs tall.
-- include: JunkrotKit
local FACE = { { -0.15, -0.35, 2.6, 0.15 }, { 0.15, -0.35, 2.62, 0.15 } }
local FEET = { 0.5, 0.5 }
local BASE = 0.6
local HEAD = 3.0 -- where the head starts
part("Column", nil, BARE_METAL, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.36, 0 }, { 0.38, 0.06 }, { 0.38, 0.85 }, { 0.33, 0.95 }, { 0.32, HEAD - BASE }, { 0, HEAD - BASE } }, 16)
	-- Slots round the guard, every other face.
	local slots = m:select("face", "where", function(p)
		local sector = math.floor((math.deg(math.atan2(p[2], p[1])) % 360) / 22.5)
		return p[3] > 0.15 and p[3] < 0.75 and sector % 2 == 0
	end)
	if slots:count() > 0 then
		Kit.recess(m, slots, 0.03, 0.05)
	end
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, 40, 0.03)
part("Head", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.4, 0 }, { 0.44, 0.1 }, { 0.44, 0.55 }, { 0.36, 0.72 }, { 0, 0.75 } }, 16)
	m:translate(0, 0, HEAD)
	m:emit(mesh)
end, true, 0)
part("Readout", nil, { 1.0, 0.45, 0.2 }, function(mesh)
	local m = Kit.block(0.36, 0.05, 0.22, 0.05)
	m:translate(0, -0.43, HEAD + 0.32)
	m:emit(mesh)
end, 50, 0, nil, 1.2)
part("Clamp", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	local wheel = EditMesh.cylinder(0.18, 0.1, 12, 1)
	wheel:translate(0, 0, HEAD + 0.78)
	wheel:emit(mesh)
	local arm = Kit.block(0.6, 0.25, 0.18, 0.05)
	arm:translate(0.6, 0, HEAD - 0.35)
	arm:emit(mesh)
	local jaw = Kit.block(0.18, 0.25, 0.5, 0.05)
	jaw:translate(0.85, 0, HEAD - 0.6)
	jaw:emit(mesh)
	local screw = Kit.lathe({ { 0, 0 }, { 0.12, 0 }, { 0.12, 0.08 }, { 0.04, 0.1 }, { 0.04, 0.3 }, { 0, 0.3 } }, 12)
	screw:translate(0.85, 0, HEAD - 1.15)
	screw:emit(mesh)
end, 50, 0)
part("Cable", nil, { 0.1, 0.1, 0.12 }, function(mesh)
	Kit.tube(Kit.curve({ { 0, 0.4, HEAD + 0.3 }, { 0.1, 0.72, HEAD - 0.3 }, { 0.3, 0.9, 0.05 } }, 4), 0.05, 6):emit(mesh)
end, true, RUBBER)
-- include: JunkrotFace
