-- Layout prelude: lets a layout build other models in place. Each model's
-- script is wrapped as build<Name>(), and place() runs it with every vertex
-- moved, turned about z, optionally scaled up or down as a whole and
-- optionally stretched along one axis. Parts are
-- renamed <Label>_<Part> so game code can find each placed piece by label.
local placeX, placeY, placeZ, placeTurn, placeStretch, placeAxis = 0, 0, 0, 0, 1, "x"
local placeScale = 1
local placeLabel = ""
local RealMesh, realPart = Mesh, model.part

-- Set further down, with the shard deal: whether this shard paints a part.
local paintsPart: (name: string, image: any) -> boolean

-- While a split model builds, every image it creates is noted in order, so
-- its parts can be dealt by texels before any is painted (see ownsPart).
local RealImage = Image
local splitImages: { any }? = nil
Image = setmetatable({
	new = function(...)
		local image = RealImage.new(...)
		if splitImages then
			table.insert(splitImages, image)
		end
		return image
	end,
}, { __index = RealImage })

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
				-- A model split across shards paints only this shard's parts.
				if options and options.name and not paintsPart(options.name, image) then
					return
				end
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
--
-- A model build costing well over half an even share, and marked "#split"
-- (most of its parts are shaded through a named paint, as finishParts does),
-- is split into pieces of about half an even share across the least-loaded
-- shards: small pieces leave the deal room to even the shards out. Each piece's
-- shard builds the geometry, which is cheap, but paints and keeps only its
-- share of the parts. Parts are dealt by
-- texels: a build creates every image before painting any, so the images are
-- sorted largest first and each goes to the share with the fewest texels so
-- far. Every shard in the split deals the same images the same way. Placing
-- that model again goes to the same shards, each keeping the same parts.
local REPEAT_COST = 0.01
-- Pieces are about this much of an even share; a model splits once it costs
-- a quarter more than one piece.
local SPLIT_PIECE = 0.5
local SPLIT_ABOVE = 1.25
local shardLoads, shardModels, splitModels = {}, {}, {}
local medianCost, totalCost = 1, 0
do
	local costs = {}
	for key, seconds in SHARD_COSTS do
		if not string.find(key, " #split$") then
			table.insert(costs, seconds)
			totalCost += seconds
		end
	end
	table.sort(costs)
	if #costs > 0 then
		medianCost = costs[(#costs + 1) // 2]
	end
end

-- While a split model builds: this shard's share, out of how many, and once
-- its images are dealt, which share keeps each image and each share's texels.
type PartShare = { index: number, count: number, owners: { [any]: number }?, texels: { number } }
local partShare: PartShare? = nil
-- Parts seen while building, and how many were shaded through a named paint,
-- so a build can tell whether splitting it would save any paint.
local partsEmitted, partsGated = 0, 0

local function texelsOf(image: any): number
	local width, height = image:size()
	return width * height
end

-- Gives an image to the share with the fewest texels so far.
local function dealImage(share: PartShare, image: any, texels: number): number
	local lightest = 1
	for index = 2, share.count do
		if share.texels[index] < share.texels[lightest] then
			lightest = index
		end
	end
	(share.owners :: { [any]: number })[image] = lightest
	share.texels[lightest] += texels
	return lightest
end

-- Deals every image the split build has made, largest first; ties go by the
-- order they were made, so every shard deals them alike.
local function dealImages(share: PartShare)
	local images = {}
	for order, image in splitImages or {} do
		table.insert(images, { image = image, texels = texelsOf(image), order = order })
	end
	table.sort(images, function(a, b)
		return if a.texels ~= b.texels then a.texels > b.texels else a.order < b.order
	end)
	share.owners = {}
	for _, entry in images do
		dealImage(share, entry.image, entry.texels)
	end
end

-- Whether this shard keeps a part of the split model being built: by its
-- texture's share when it has one (an image made after the deal goes to the
-- lightest share then), else by a hash of its name.
local function ownsPart(name: string, image: any?): boolean
	if not partShare then
		return true
	end
	if image then
		if not partShare.owners then
			dealImages(partShare)
		end
		local owner = (partShare.owners :: { [any]: number })[image] or dealImage(partShare, image, texelsOf(image))
		return owner == partShare.index
	end
	local hash = 5381
	for i = 1, #name do
		hash = (hash * 33 + string.byte(name, i)) % 4294967296
	end
	return hash % partShare.count + 1 == partShare.index
end
-- Every named shading paint (finishParts in common.luau passes the part's
-- name) asks this first, through the Mesh wrapper above.
paintsPart = function(name: string, image: any): boolean
	partsGated += 1
	return ownsPart(name, image)
end

-- The shards a split takes, and which of them this one is.
local function shareOf(shards: { number }): (boolean, number?, number?)
	local index = table.find(shards, SHARD_INDEX)
	return index ~= nil, index, #shards
end

-- Deals one placement: whether this shard builds it, and for a split model
-- which share of its parts this shard keeps, out of how many. `reuses`, when
-- given, names the model build this placement reuses.
local function inThisShard(costKey: string, reuses: string?): (boolean, number?, number?)
	if builtParts or SHARD_COUNT == nil then
		return true
	end
	local cost = SHARD_COSTS[costKey] or medianCost
	local split = reuses and splitModels[reuses]
	if split then
		for _, shard in split do
			shardLoads[shard] = (shardLoads[shard] or 0) + REPEAT_COST
		end
		return shareOf(split)
	end
	local fairShare = if totalCost > 0 then totalCost / SHARD_COUNT else medianCost
	local piece = fairShare * SPLIT_PIECE
	if reuses and SHARD_COSTS[`{costKey} #split`] and cost > piece * SPLIT_ABOVE then
		local order = {}
		for shard = 1, SHARD_COUNT do
			order[shard] = shard
		end
		table.sort(order, function(a, b)
			local loadA, loadB = shardLoads[a] or 0, shardLoads[b] or 0
			return if loadA ~= loadB then loadA < loadB else a < b
		end)
		split = table.move(order, 1, math.min(SHARD_COUNT, math.ceil(cost / piece)), 1, {})
		for _, shard in split do
			shardLoads[shard] = (shardLoads[shard] or 0) + cost / #split
		end
		splitModels[reuses] = split
		return shareOf(split)
	end
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

-- Times a cached build when sharding, printing lines the build workflow
-- gathers into <Layout>Costs.txt for the next deal: its time, and "#split"
-- when most of its parts are shaded through a named paint, so splitting pays.
-- A split's own build (`splitHere`) paints only its share, so its time is
-- scaled up by its share of the texels; builds nested in a split aren't timed.
local function timedBuild(costKey: string, build: () -> any, splitHere: boolean?): any
	if SHARD_COUNT == nil then
		return build()
	end
	local started, emitted, gated = os.clock(), partsEmitted, partsGated
	local result = build()
	local seconds = os.clock() - started
	if splitHere and partShare then
		local all = 0
		for _, texels in partShare.texels do
			all += texels
		end
		local mine = partShare.texels[partShare.index]
		seconds = if mine > 0 then seconds * all / mine else -1
	elseif partShare then
		seconds = -1
	end
	if seconds >= 0 then
		print(string.format("SHARD_COST\t%s\t%.3f", costKey, seconds))
	end
	emitted, gated = partsEmitted - emitted, partsGated - gated
	if emitted > 0 and gated * 2 >= emitted then
		print(string.format("SHARD_COST\t%s #split\t1", costKey))
	end
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
		partsEmitted += 1
		if skipPart(name) or not ownsPart(name, image) then
			return
		end
		table.insert(builtParts, { name = name, mesh = unwrapMesh(mesh), image = image, preview = preview, emissive = options and options.emissive })
		return
	end
	addPart(name, unwrapMesh(mesh), image, preview, options and options.emissive)
end

-- Says which object a placement is, for the upload (scripts/export-objects.py
-- reads these lines from the build's output): its label, its turn in
-- degrees, and the key its build is cached under, or "-" when it has none.
-- Placements with one key are copies of one object, uploaded once. A
-- placement inside another's build is part of that object, and isn't told.
local function tellPlacement(label: string, turn: number, key: string)
	if not builtParts then
		print(string.format("PLACED\t%s\t%s\t%s", label, tostring(turn), key))
	end
end

-- `scale` builds the model that many times its own size, so its textures
-- keep their density instead of being stretched with it.
local function place(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, stretch: number?, axis: string?, scale: number?)
	local key = buildKeys[build]
	if not key then
		if not inThisShard(`place {label}`) then
			return
		end
		tellPlacement(label, turn or 0, "-")
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
	local owns, share, shares = inThisShard(costKey, `{key} {variant}`)
	if not owns then
		return
	end
	placeLabel = label
	placeX, placeY, placeZ, placeTurn = x, y, z or 0, math.rad(turn or 0)
	placeStretch, placeAxis, placeScale = stretch or 1, axis or "x", scale or 1
	key = `{key} {variant}`
	if previewBand then
		key = `{key} band {previewBand(x, y, z or 0)}`
	end
	-- A split build keeps only its share of the parts, so it caches apart. The
	-- texel deal follows from the model's source, already in the key.
	if share then
		key = `{key} part {share}/{shares}`
	end
	tellPlacement(label, turn or 0, key)
	local x0, y0, z0, turn0 = placeX, placeY, placeZ, placeTurn
	for _, part in model.cached(key, function()
		local outerShare, outerImages = partShare, splitImages
		if share then
			partShare = { index = share, count = shares :: number, texels = table.create(shares :: number, 0) }
			splitImages = {}
		end
		local built = timedBuild(costKey, function()
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
		end, share ~= nil)
		partShare, splitImages = outerShare, outerImages
		return built
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
	-- A slab is built where it stands, so it is its own object, unturned.
	tellPlacement(label, 0, `{key} {label} {x} {y} {turn or 0}`)
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
