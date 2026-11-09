-- A mesh that moves every vertex built into it through `move`, for tilting,
-- turning or crumpling simple shapes.
local function warped(mesh, move)
	return {
		vertex = function(_self, x: number, y: number, z: number)
			local a, b, c = move(x, y, z)
			return mesh:vertex(a, b, c)
		end,
		face = function(_self, face)
			return mesh:face(face)
		end,
	}
end
