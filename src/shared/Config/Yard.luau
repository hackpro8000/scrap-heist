--!strict
--[[
	Yard config

	The plot every player builds on, as a grid. A cell is CELL studs square.
	Cell (0, 0) is the back corner on the left as you walk in through the
	gate; x counts across the plot and z toward the gate, which stands in
	the middle of the last row.

	The plot is PARCEL_COLUMNS x PARCEL_ROWS parcels of land. A parcel is
	numbered 1.. from the back row's left, row by row, so the front row (by
	the gate) is the last PARCEL_COLUMNS numbers. Only cleared parcels can
	be built on; the rest lie under rubble, which can be walked through.
]]

local Yard = {}

export type Kind = "Pad" | "Bay" | "Crate" | "Mound" | "Press"

-- Studs per grid cell. Things snap to cells and turn in quarter turns.
Yard.CELL = 2
-- The plot in cells: 96 x 112 studs.
Yard.COLUMNS = 48
Yard.ROWS = 56

Yard.PARCEL_COLUMNS = 3
Yard.PARCEL_ROWS = 4
-- A parcel in cells: 32 x 28 studs.
Yard.PARCEL_WIDTH = 16
Yard.PARCEL_DEPTH = 14

-- The front row is clear from the start.
Yard.STARTING_PARCELS = { 10, 11, 12 }
-- Each of these ranks clears one more parcel, in CLEAR_ORDER (always next
-- to land already cleared).
Yard.CLEAR_RANKS = { 1, 2, 3, 4, 6, 8, 10, 12, 14 }
Yard.CLEAR_ORDER = { 8, 7, 9, 5, 4, 6, 2, 1, 3 }

-- The cells just inside the gate that always stay clear: 12 x 8 studs.
Yard.DOORSTEP = { x = 21, z = 52, width = 6, depth = 4 }

-- A player is 4 studs across, so a way through must be this many cells wide.
Yard.WALK_CELLS = 2

-- How many cells each kind of thing covers, before turning.
Yard.FOOTPRINTS = {
	Pad = { width = 5, depth = 5 },
	Bay = { width = 5, depth = 5 },
	Crate = { width = 4, depth = 4 },
	Mound = { width = 5, depth = 5 },
	Press = { width = 8, depth = 4 },
} :: { [Kind]: { width: number, depth: number } }

-- Things a player must be able to walk to from the gate.
Yard.MUST_REACH = { Pad = true, Bay = true, Crate = true, Mound = true, Press = true } :: { [string]: boolean }

-- Pads: this many to start with, one more per rank up to MAX_PADS.
Yard.STARTING_PADS = 6
Yard.MAX_PADS = 20
-- Build bays: one to start with, one more at each of these ranks.
Yard.BAY_RANKS = { 5, 11 }

-- What a new player's yard holds, placed for them: six pads (two of each
-- family) across the front row, with the bay, crate, press and mound
-- between them and the fence either side of the doorstep.
Yard.STARTER_LAYOUT = {
	{ kind = "Pad", family = "Kitchen", x = 2, z = 43, turn = 0 },
	{ kind = "Pad", family = "Garage", x = 9, z = 43, turn = 0 },
	{ kind = "Pad", family = "Gadget", x = 16, z = 43, turn = 0 },
	{ kind = "Pad", family = "Kitchen", x = 27, z = 43, turn = 0 },
	{ kind = "Pad", family = "Garage", x = 34, z = 43, turn = 0 },
	{ kind = "Pad", family = "Gadget", x = 41, z = 43, turn = 0 },
	{ kind = "Crate", x = 4, z = 50, turn = 0 },
	{ kind = "Bay", x = 12, z = 50, turn = 0 },
	{ kind = "Press", x = 29, z = 50, turn = 0 },
	{ kind = "Mound", x = 40, z = 50, turn = 0 },
} :: { { kind: Kind, family: string?, x: number, z: number, turn: number } }

-- How high above the plot's floor still counts as "in the yard", and how
-- far below it.
Yard.HEIGHT = 30
Yard.DEPTH = 5

-- The junk mound: scrap per whack, and one whack in PART_ONE_IN gives a part.
Yard.MOUND_SCRAP = 3
Yard.MOUND_PART_ONE_IN = 20

-- The crate holds this many seconds of the yard's income, and never less
-- than CRATE_MIN.
Yard.CRATE_SECONDS = 600
Yard.CRATE_MIN = 2000

-- The gate: its owner can lock it for LOCK_SECONDS, then must wait
-- LOCK_COOLDOWN_SECONDS before locking it again. The opening is GATE_WIDTH
-- studs across.
Yard.LOCK_SECONDS = 30
Yard.LOCK_COOLDOWN_SECONDS = 60
Yard.GATE_WIDTH = 12

return Yard
