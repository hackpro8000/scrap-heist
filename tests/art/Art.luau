--!strict
-- Loads art/src/shared includes (which define globals-in-chunk rather than
-- returning a module) for unit tests.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Art = {}

-- Runs the named shared files in order in one chunk and returns the value
-- of `expression` from it (e.g. "EditMesh").
function Art.load(names: { string }, expression: string): any
	local parts = {}
	for _, name in names do
		table.insert(parts, fs.readFile(`art/src/shared/{name}.luau`))
	end
	table.insert(parts, `return {expression}`)
	return luau.load(table.concat(parts, "\n"), { debugName = table.concat(names, "+") })()
end

-- A recording stand-in for the engine's Mesh.
function Art.recorder(): any
	local recorder = { positions = {}, faces = {} }
	function recorder:vertex(x, y, z)
		table.insert(self.positions, { x, y, z })
		return #self.positions
	end
	function recorder:face(verts)
		table.insert(self.faces, verts)
	end
	return recorder
end

return Art
