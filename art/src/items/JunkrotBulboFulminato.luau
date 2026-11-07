-- Bulbo Fulminato: a blown light bulb standing on its cap, smoked glass
-- swelling from a narrow neck, a scorched hole broken in through the top,
-- a brass screw cap with two rounded bands, and the black insulator and
-- contact under it. 2.9 studs tall.
-- include: JunkrotKit
local FACE = { { -0.3, -0.85, 2.05, 0.21 }, { 0.3, -0.85, 2.08, 0.22 } }
local FEET = { 0.55, 0.55 }
local BASE = 0.55
local GLASS = BASE + 0.5 -- where the glass starts
part("Glass", nil, { 0.56, 0.54, 0.46 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.34, 0 }, { 0.4, 0.2 }, { 0.72, 0.55 }, { 0.84, 0.95 }, { 0.8, 1.35 }, { 0.6, 1.66 }, { 0.32, 1.8 }, { 0, 1.83 } }, 20)
	-- The hole: the top sunk in.
	local top = m:select("face", "facing", { 0, 0, 1 }, 25)
	if top:count() > 0 then
		m:inset(top, 0.06, -0.18)
	end
	m:translate(0, 0, GLASS)
	m:emit(mesh)
end, true, 0.25)
part("Soot", nil, { 0.16, 0.14, 0.12 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.3, 0 }, { 0.26, 0.03 }, { 0, 0.04 } }, 16)
	m:translate(0, 0, GLASS + 1.62)
	m:emit(mesh)
end, true, 0.3)
part("Cap", nil, { 0.72, 0.6, 0.3 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.3, 0 }, { 0.34, 0.06 }, { 0.37, 0.14 }, { 0.34, 0.22 }, { 0.37, 0.3 }, { 0.34, 0.38 }, { 0.36, 0.46 }, { 0, 0.5 } }, 16)
	m:translate(0, 0, BASE + 0.04)
	m:emit(mesh)
end, true, 0.6)
part("Contact", nil, { 0.1, 0.1, 0.11 }, function(mesh)
	local m = Kit.lathe({ { 0, 0 }, { 0.2, 0 }, { 0.24, 0.04 }, { 0.24, 0.08 }, { 0, 0.08 } }, 12)
	m:translate(0, 0, BASE)
	m:emit(mesh)
end, 40, 0.3)
-- include: JunkrotFace
