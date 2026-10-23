-- Scrapper: the fast, weak scrap bot, about 2.5 studs tall. A rusty box body
-- patched with odd plates, carried on a swing arm over one wobbly wheel. A
-- red eye in a steel rim, a buzzsaw on a side arm and a bent antenna
-- topped with a little radar dish. Faces -Y; stands with the wheel on the
-- origin.
-- Rig: Root > Body > Suspension > Wheel (spins), SawArm > Saw (spins),
-- Antenna (wobbles).

-- Mismatched scrap: rusty box steel, a galvanised panel, a sky-blue panel
-- off an old appliance, dark steel running gear, a bright saw, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local APPLIANCE = { 0.36, 0.55, 0.66 }
local OLIVE = { 0.42, 0.45, 0.36 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local STEEL = { 0.62, 0.64, 0.66 }
local TYRE = { 0.16, 0.16, 0.17 }
local EYE = { 0.95, 0.15, 0.1 }

local WHEEL_RADIUS = 0.42
-- The wheel trails behind the body, held on the swing arm's axle.
local AXLE_Y = 0.3
local AXLE_LENGTH = 0.8
local BODY_BOTTOM, BODY_HEIGHT = 0.95, 0.9
local BODY_WIDTH, BODY_DEPTH = 1.05, 0.9
-- Swing arm pivot, under the body on the +X side.
local PIVOT = { 0.36, -0.15, BODY_BOTTOM - 0.08 }
local SAW_X, SAW_Z = 1.05, 1.35
local SAW_RADIUS = 0.42
local SAW_TEETH = 14
local EYE_Z = 1.5
