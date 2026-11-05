-- Layout prelude: lets a layout build other models in place. Each model's
-- script is wrapped as build<Name>(), and place() runs it with every vertex
-- moved, turned about z, optionally scaled up or down as a whole and
-- optionally stretched along one axis. Parts are
-- renamed <Label>_<Part> so game code can find each placed piece by label.
local placeX, placeY, placeZ, placeTurn, placeStretch, placeAxis = 0, 0, 0, 0, 1, "x"
local placeScale = 1
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
		local scale = placeScale
		local stretchX = scale * (if placeAxis == "x" then placeStretch else 1)
		local stretchY = scale * (if placeAxis == "y" then placeStretch else 1)
		return setmetatable({
			_mesh = real,
			vertex = function(_, x, y, z)
				x, y = x * stretchX, y * stretchY
				return real:vertex(x * c - y * s + ox, x * s + y * c + oy, z * scale + oz)
			end,
			paintShading = function(_, image, options)
				for _, list in { "occluders", "group" } do
					if options and options[list] then
						local real = {}
						for i, other in options[list] do
							real[i] = unwrapMesh(other)
						end
						options[list] = real
					end
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

-- A placed item caches its shell entries, which hold meshes; the cache
-- stores real meshes only, so unwrap them first. Inside a place() build the
-- placement cache already stores the item, so skip the item's own cache.
local realCached = model.cached
local builtParts = nil
model.cached = function(key, build)
	if builtParts then
		return build()
	end
	return realCached(key, function()
		local result = build()
		if type(result) == "table" then
			for _, entry in result do
				if type(entry) == "table" and entry.mesh then
					entry.mesh = unwrapMesh(entry.mesh)
				end
			end
		end
		return result
	end)
end

-- Layouts override this to leave out parts, such as fill levels.
local function skipPart(_name: string): boolean
	return false
end

-- The assembler fills this with a hash of each used model's source, so
-- place() can build each model once and reuse it at every placement.
local buildKeys = {}
-- And a hash of each slab body with the code around it, by the line its
-- function starts on, so placeSlab() can reuse an unchanged slab.
local slabKeys = {}

-- With modelkit --shard, each placement goes to the shard with the least work
-- dealt so far, by its measured build time (SHARD_COSTS, from the assembler's
-- <Layout>Costs.txt; unmeasured ones count as the median). A model a shard has
-- already built costs it almost nothing to place again, so repeats of a prop
-- gather on one shard. Every machine runs the same deal in the same order, so
-- between them the shards build each placement once. A placement inside
-- another one's build belongs to it, and isn't dealt: whether it runs depends
-- on that build being cached.
local REPEAT_COST = 0.01
local shardLoads, shardModels = {}, {}
local medianCost = 1
do
	local costs = {}
	for _, seconds in SHARD_COSTS do
		table.insert(costs, seconds)
	end
	table.sort(costs)
	if #costs > 0 then
		medianCost = costs[(#costs + 1) // 2]
	end
end
-- `reuses`, when given, names the model build this placement reuses.
local function inThisShard(costKey: string, reuses: string?): boolean
	if builtParts or SHARD_COUNT == nil then
		return true
	end
	local cost = SHARD_COSTS[costKey] or medianCost
	local best, bestLoad = 1, math.huge
	for shard = 1, SHARD_COUNT do
		shardModels[shard] = shardModels[shard] or {}
		local extra = if reuses and shardModels[shard][reuses] then REPEAT_COST else cost
		local load = (shardLoads[shard] or 0) + extra
		if load < bestLoad then
			best, bestLoad = shard, load
		end
	end
	shardLoads[best] = bestLoad
	if reuses then
		shardModels[best][reuses] = true
	end
	return best == SHARD_INDEX
end

-- Times a cached build when sharding, printing a line the build workflow
-- gathers into <Layout>Costs.txt for the next deal.
local function timedBuild(costKey: string, build: () -> any): any
	if SHARD_COUNT == nil then
		return build()
	end
	local started = os.clock()
	local result = build()
	print(string.format("SHARD_COST\t%s\t%.3f", costKey, os.clock() - started))
	return result
end

local function addPart(name, mesh, image, preview, emissive)
	if skipPart(name) then
		return
	end
	realPart(placeLabel .. "_" .. name, mesh, image, { preview = preview, emissive = emissive })
end

model.part = function(name, mesh, image, options)
	local preview = if options and options.preview ~= nil then options.preview else true
	if builtParts then
		if skipPart(name) then
			return
		end
		table.insert(builtParts, { name = name, mesh = unwrapMesh(mesh), image = image, preview = preview, emissive = options and options.emissive })
		return
	end
	addPart(name, unwrapMesh(mesh), image, preview, options and options.emissive)
end

-- `scale` builds the model that many times its own size, so its textures
-- keep their density instead of being stretched with it.
local function place(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, stretch: number?, axis: string?, scale: number?)
	local key = buildKeys[build]
	if not key then
		if not inThisShard(`place {label}`) then
			return
		end
		placeLabel = label
		placeX, placeY, placeZ, placeTurn = x, y, z or 0, math.rad(turn or 0)
		placeStretch, placeAxis, placeScale = stretch or 1, axis or "x", scale or 1
		build()
		placeScale = 1
		return
	end
	-- Built once at the origin per model, scale and stretch, then moved into
	-- place, so moving a prop never rebuilds it. Eye previews size textures by
	-- distance, so there placements share a build per distance band.
	local variant = if (scale or 1) == 1 then `{stretch or 1} {axis or "x"}` else `{stretch or 1} {axis or "x"} x{scale}`
	-- Costs are keyed by model name, not source hash, so an edited model keeps
	-- its last measured cost until it's measured again.
	local costKey = `{string.match(key, "^(.-)%-%x+$") or key} {variant}`
	if not inThisShard(costKey, `{key} {variant}`) then
		return
	end
	placeLabel = label
	placeX, placeY, placeZ, placeTurn = x, y, z or 0, math.rad(turn or 0)
	placeStretch, placeAxis, placeScale = stretch or 1, axis or "x", scale or 1
	key = `{key} {variant}`
	if previewBand then
		key = `{key} band {previewBand(x, y, z or 0)}`
	end
	local x0, y0, z0, turn0 = placeX, placeY, placeZ, placeTurn
	for _, part in model.cached(key, function()
		return timedBuild(costKey, function()
			placeX, placeY, placeZ, placeTurn = 0, 0, 0, 0
			if previewPlacing then
				previewPlacing(x0, y0, z0, turn0)
			end
			builtParts = {}
			build()
			if previewPlacing then
				previewPlacing()
			end
			local built = builtParts
			builtParts = nil
			return built
		end)
	end) do
		addPart(part.name, part.mesh:moved(turn0, x0, y0, z0), part.image, part.preview, part.emissive)
	end
	placeX, placeY, placeZ, placeTurn = x0, y0, z0, turn0
	placeScale = 1
end

-- Places a piece built where it stands. Its paint can depend on where it
-- stands, so it is cached in place, keyed on its source and placement.
-- finish(), if given, runs after build() inside the cached build.
local function placeSlab(label: string, build: () -> (), x: number, y: number, turn: number?, finish: (() -> ())?)
	local key = slabKeys[debug.info(build, "l")]
	if not key then
		error(`slab {label} has no cache key; start its body on a line ending in "function()"`)
	end
	local costKey = `slab {label}`
	if not inThisShard(costKey) then
		return
	end
	placeLabel = label
	placeX, placeY, placeZ, placeTurn = x, y, 0, math.rad(turn or 0)
	placeStretch, placeAxis, placeScale = 1, "x", 1
	for _, part in model.cached(`{key} {label} {x} {y} {turn or 0}`, function()
		return timedBuild(costKey, function()
			builtParts = {}
			build()
			if finish then
				finish()
			end
			local built = builtParts
			builtParts = nil
			return built
		end)
	end) do
		addPart(part.name, part.mesh, part.image, part.preview, part.emissive)
	end
end
