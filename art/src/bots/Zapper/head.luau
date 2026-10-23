-- Zapper: the ranged scrap bot, about 4.5 studs tall. A smooth round rusty
-- body banded and patched with bolted plates, a blue glowing eye in a
-- bolted steel rim, spindly legs with visible hip, knee and ankle joints,
-- and a tesla coil on top that fires bolts from its tip. Faces -Y; stands
-- with its feet on the origin.
-- Rig: Root > Body > Eye, Coil > CoilTip, LegUpperL/R > LegLowerL/R.

-- Mismatched scrap: rusty tank steel, a galvanised band, a brass patch off
-- an old boiler, dark steel legs, copper windings, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local BRASS = { 0.7, 0.58, 0.3 }
local STEEL = { 0.62, 0.64, 0.66 }
local OLIVE = { 0.42, 0.45, 0.36 }
local BLUE_GREY = { 0.4, 0.47, 0.52 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local GLOW = { 0.3, 0.8, 1.0 }

local HIP_Z, KNEE_Z = 2.0, 1.0
local HIP_X, FOOT_X = 0.45, 0.75
local BODY_Z, BODY_RADIUS = 2.55, 0.85
local COIL_BOTTOM, COIL_TOP = 3.3, 4.1
local EYE_Z = BODY_Z + 0.1
