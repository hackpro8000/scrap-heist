-- Yard Footing: the low concrete kerb an 8-stud yard fence panel stands in,
-- so the fence meets the ground on something built. A cast strip with a
-- narrower capping course on top, its ends knocked off where neighbouring
-- footings meet. Runs along x under a fence panel, centered on the origin.
local CONCRETE = { 0.58, 0.57, 0.53 }
-- Footing length, width and height, then the capping course's inset from
-- each side and its height.
local LENGTH, WIDTH, HEIGHT = 8, 1, 0.25
local CAP_INSET, CAP_HEIGHT = 0.1, 0.1

part("Footing", nil, CONCRETE, function(mesh)
	box(mesh, 0, 0, 0, LENGTH - 0.04, WIDTH, HEIGHT)
	box(mesh, 0, 0, HEIGHT, LENGTH - 0.16, WIDTH - 2 * CAP_INSET, CAP_HEIGHT)
	-- Chunks knocked off the corners, left lying at the foot.
	box(mesh, LENGTH / 2 - 0.35, WIDTH / 2 + 0.12, 0, 0.3, 0.22, 0.12)
	box(mesh, -LENGTH / 2 + 0.6, -WIDTH / 2 - 0.1, 0, 0.22, 0.18, 0.1)
end, nil, 0.35)

finishParts()
