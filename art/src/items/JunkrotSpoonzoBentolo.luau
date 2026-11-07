-- Spoonzo Bentolo: a bent spoon standing on its handle, its bowl a real
-- dish for a face, the handle flattened and bent twice on its way down and
-- widening to its end, rust staining the bowl. 3 studs tall.
-- include: JunkrotKit
local FACE = { { -0.17, -0.1, 2.38, 0.17 }, { 0.17, -0.09, 2.4, 0.18 } }
local FEET = { 0.5, 0.5 }
local BOWL = 2.3 -- the bowl's middle
part("Spoon", nil, BARE_METAL, function(mesh)
	-- The bowl: a squashed ball with its front pressed in to a dish.
	local bowl = EditMesh.sphere(1, 16)
	Kit.size(bowl, { 0.52, 0.2, 0.75 })
	bowl:transform(function(p)
		if p[2] >= 0 then
			return p
		end
		local fall = 1 - (p[1] / 0.52) ^ 2 - (p[3] / 0.75) ^ 2
		return { p[1], p[2] + 0.16 * math.max(0, fall), p[3] }
	end)
	bowl:translate(0, 0, BOWL)
	bowl:emit(mesh)
	-- The handle: flat, bent twice, wider toward its end.
	local path = Kit.curve({ { 0, 0.02, BOWL - 0.68 }, { 0, 0.05, BOWL - 1.02 }, { 0.18, 0.05, BOWL - 1.28 }, { 0.25, 0, BOWL - 1.5 }, { 0.1, 0, 0.6 } }, 4)
	local handle = EditMesh.sweep({ { -0.13, -0.04 }, { 0.13, -0.04 }, { 0.13, 0.04 }, { -0.13, 0.04 } }, path, {
		scale = function(t)
			return 0.8 + 0.5 * t
		end,
	})
	handle:emit(mesh)
end, true, 0.7)
part("Stain", nil, RUST_ORANGE, function(mesh)
	for _, at in { { 0.25, -0.06, 0.32 }, { -0.3, 0.1, -0.35 } } do
		local spot = EditMesh.sphere(0.12, 8)
		Kit.size(spot, { 1, 0.35, 1 })
		spot:translate(at[1], at[2], BOWL + at[3])
		spot:emit(mesh)
	end
end, true, 0.9)
-- include: JunkrotFace
