-- Layout prelude: lets a layout build other models in place. Each model's
-- script is wrapped as build<Name>(), and place() runs it with every vertex
-- moved, turned about z and optionally stretched along one axis. Parts are
-- renamed <Label>_<Part> so game code can find each placed piece by label.
local placeX, placeY, placeZ, placeTurn, placeStretch, placeAxis = 0, 0, 0, 0, 1, "x"
local placeLabel = ""
local RealMesh, realPart = Mesh, model.part

local function unwrapMesh(mesh)
	return if type(mesh) == "table" and mesh._mesh then mesh._mesh else mesh
end

Mesh = {
	new = function()
		local real = RealMesh.new()
		local c, s = math.cos(placeTurn), math.sin(placeTurn)
		local ox, oy, oz = placeX, placeY, placeZ
		local stretchX = if placeAxis == "x" then placeStretch else 1
		local stretchY = if placeAxis == "y" then placeStretch else 1
		return setmetatable({
			_mesh = real,
			vertex = function(_, x, y, z)
				x, y = x * stretchX, y * stretchY
				return real:vertex(x * c - y * s + ox, x * s + y * c + oy, z + oz)
			end,
			paintShading = function(_, image, options)
				if options and options.occluders then
					local occluders = {}
					for i, occluder in options.occluders do
						occluders[i] = unwrapMesh(occluder)
					end
					options.occluders = occluders
				end
				return real:paintShading(image, options)
			end,
		}, {
			__index = function(_, key)
				return function(_, ...)
					return real[key](real, ...)
				end
			end,
		})
	end,
}

-- Layouts override this to leave out parts, such as fill levels.
local function skipPart(_name: string): boolean
	return false
end

-- The assembler fills this with a hash of each used model's source, so
-- place() can cache that model's parts per placement.
local buildKeys = {}
local builtParts = nil

local function addPart(name, mesh, image, preview)
	if skipPart(name) then
		return
	end
	realPart(placeLabel .. "_" .. name, mesh, image, { preview = preview })
end

model.part = function(name, mesh, image, options)
	local preview = if options and options.preview ~= nil then options.preview else true
	if builtParts then
		table.insert(builtParts, { name = name, mesh = unwrapMesh(mesh), image = image, preview = preview })
		return
	end
	addPart(name, unwrapMesh(mesh), image, preview)
end

local function place(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, stretch: number?, axis: string?)
	placeLabel = label
	placeX, placeY, placeZ, placeTurn = x, y, z or 0, math.rad(turn or 0)
	placeStretch, placeAxis = stretch or 1, axis or "x"
	local key = buildKeys[build]
	if not key then
		build()
		return
	end
	key = `{key} {placeX} {placeY} {placeZ} {placeTurn} {placeStretch} {placeAxis}`
	for _, part in model.cached(key, function()
		builtParts = {}
		build()
		local built = builtParts
		builtParts = nil
		return built
	end) do
		addPart(part.name, part.mesh, part.image, part.preview)
	end
end
