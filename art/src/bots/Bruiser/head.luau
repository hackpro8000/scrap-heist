-- Bruiser: the slow tank scrap bot, about 5 studs tall. A hulking rusty body
-- plated with dumpster lids (ribbed, hinged, with grab handles), a red visor
-- slit in a steel frame, bolted shoulder plates and two lugged tank treads.
-- Faces -Y; stands with the treads on the origin.
-- Rig: Root > Treads, Body > ShoulderL, ShoulderR, Visor.

-- Mismatched scrap: rusty body steel, green dumpster lids, a galvanised
-- patch, a cream panel off an old fridge, dark steel running gear, in sRGB.
local RUST = { 0.55, 0.35, 0.16 }
local DUMPSTER = { 0.25, 0.4, 0.28 }
local GALVANISED = { 0.6, 0.63, 0.62 }
local FRIDGE = { 0.82, 0.78, 0.66 }
local OLIVE = { 0.42, 0.45, 0.36 }
local BLUE_GREY = { 0.4, 0.47, 0.52 }
local GREY = { 0.55, 0.57, 0.6 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local STEEL = { 0.62, 0.64, 0.66 }
local TREAD = { 0.18, 0.18, 0.2 }
local VISOR = { 0.95, 0.15, 0.1 }

local TREAD_HEIGHT = 0.9
local TREAD_X, TREAD_WIDTH, TREAD_LENGTH = 1.5, 0.7, 2.6
local BODY_TOP = 4.2
local BODY_FRONT = -0.85
local SHOULDER_Z = 3.7
