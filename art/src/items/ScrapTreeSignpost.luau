-- Scrap Tree (Signpost): a street signpost with stolen road signs clamped on
-- at every angle until they bush out into a leafy crown. Green street-name
-- plates and hazard-yellow warning diamonds give the yard its few spots of
-- "foliage" colour.
-- include: HandFinish
local SIGN_GREEN = { 0.18, 0.42, 0.24 }
local HAZARD = { 0.9, 0.72, 0.1 }
local CONCRETE = { 0.5, 0.48, 0.44 }
-- Each blade: its bearing in degrees, its lower edge, its length and its tilt.
-- Each height band holds blades on one side of the post and a diamond on the
-- other, so nothing crosses the post from any angle.
local BLADES = {
	{ 35, 4.2, 1.4, 0.06 },
	{ 40, 5.15, 2.9, 0.08 },
	{ 55, 5.8, 1.8, -0.05 },
	{ 130, 6.6, 2.5, 0 },
	{ 150, 7.3, 1.2, 0.14 },
	{ 215, 8.0, 2.0, -0.1 },
	{ 240, 8.55, 0.9, -0.16 },
}
-- How far to one side of the post each blade is held by its clamp.
local BLADE_OFFSET = 0.2
-- Each diamond: its bearing in degrees and its middle's height.
local DIAMONDS = {
	{ 215, 4.5 },
	{ 225, 5.85 },
	{ 320, 7.25 },
	{ 45, 8.3 },
}
local DIAMOND_HALF = 0.68
local DIAMOND_OUT = 0.98

-- Builds into a mesh whose local x runs out from the post on a bearing, with z
-- still up, so a sign is a thin box or plate along x. A `tilt` lifts it per
-- stud out.
local function outFromPost(mesh, bearing: number, tilt: number?)
	local c, s = math.cos(math.rad(bearing)), math.sin(math.rad(bearing))
	return {
		vertex = function(_self, x: number, y: number, z: number)
			return mesh:vertex(c * x - s * y, s * x + c * y, z + x * (tilt or 0))
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end

part("Footing", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, 2.5, 2.3, 0.4)
	box(mesh, 0.6, 0.45, 0.4, 0.9, 0.8, 0.14)
end, nil, 0.25)

part("Post", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0.1, 0.25, 0.25, 8.9)
	box(mesh, 0, 0, 0.4, 0.75, 0.75, 0.07)
	for _, x in { -0.28, 0.28 } do
		for _, y in { -0.28, 0.28 } do
			bolt(mesh, x, y, 0.48, "z", 0.06)
		end
	end
	-- Gussets from the flange up the post.
	for _, turn in { 0, 90, 180, 270 } do
		plate(outFromPost(mesh, turn), { { 0.1, 0.9 }, { 0.32, 0.47 }, { 0.1, 0.47 } }, 0, 0.05, 0.005)
	end
end, nil, 0.5)

part("StreetSigns", nil, SIGN_GREEN, function(mesh)
	for _, blade in BLADES do
		box(outFromPost(mesh, blade[1], blade[4]), 0.02 + blade[3] / 2, BLADE_OFFSET, blade[2], blade[3], 0.06, 0.5)
	end
end, nil, 0.3)

part("WarningSigns", nil, HAZARD, function(mesh)
	for _, diamond in DIAMONDS do
		local z = diamond[2]
		local h = DIAMOND_HALF
		plate(outFromPost(mesh, diamond[1]), {
			{ DIAMOND_OUT, z + h }, { DIAMOND_OUT + h, z }, { DIAMOND_OUT, z - h }, { DIAMOND_OUT - h, z },
		}, 0, 0.06, 0.008)
	end
	cylinder(mesh, 0, 0, 9.03, 0.68, 0.06, "z", 8)
end, nil, 0.35)

part("Clamps", nil, STEEL, function(mesh)
	-- One band round the post per sign, and an arm out to each diamond.
	for i, blade in BLADES do
		-- The clamp's arm reaches round to the blade's side of the post.
		box(outFromPost(mesh, blade[1]), 0.02, BLADE_OFFSET / 2, blade[2] + 0.19, 0.3, 0.38, 0.09 + (i % 3) * 0.04)
	end
	for _, diamond in DIAMONDS do
		box(mesh, 0, 0, diamond[2] + 0.1, 0.36, 0.36, 0.12)
		box(outFromPost(mesh, diamond[1]), 0.35, -0.05, diamond[2] + 0.11, 0.4, 0.05, 0.1)
	end
	-- The cap bracket under the top sign.
	box(mesh, 0, 0, 8.92, 0.36, 0.36, 0.1)
end, nil, 0.4)

handFinish({
	Footing = "rock",
	Post = "metal",
	StreetSigns = "metal",
	WarningSigns = "metal",
	Clamps = "metal",
}, {}, PROP_FINISH)
finishParts()
