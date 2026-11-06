local SHARD_COSTS = { ["ArenaDrone 1 x"] = 50.373, ["ArenaDrone 1 x #split"] = 1, ["Barrels 1 x x1.9"] = 0.183, ["Barrels 1 x x1.9 #split"] = 1, ["CarStack 1 x x2.5"] = 0.332, ["CarStack 1 x x2.5 #split"] = 1, ["CrushedCar 1 x x2.5"] = 0.166, ["CrushedCar 1 x x2.5 #split"] = 1, ["Dumpster 1 x x2.2"] = 0.220, ["Dumpster 1 x x2.2 #split"] = 1, ["GroundTile 1 x x1.5"] = 0.179, ["GroundTile 1 x x1.5 #split"] = 1, ["HubSectionA 1 x"] = 75.171, ["HubSectionA 1 x #split"] = 1, ["HubSectionB 1 x"] = 70.434, ["HubSectionB 1 x #split"] = 1, ["HubSectionEnd 1 x"] = 74.559, ["HubSectionEnd 1 x #split"] = 1, ["JunkWall 1 x x1.75"] = 0.236, ["JunkWall 1 x x1.75 #split"] = 1, ["MachinePad 1 x x1.5"] = 0.182, ["MachinePad 1 x x1.5 #split"] = 1, ["MarketIsland 1 x"] = 53.344, ["MarketIsland 1 x #split"] = 1, ["PadIsland 1 x"] = 11.137, ["PadIsland 1 x #split"] = 1, ["Pallets 1 x x1.4"] = 0.185, ["Pallets 1 x x1.4 #split"] = 1, ["ParkBench 1 x x1.85"] = 0.083, ["ParkBench 1 x x1.85 #split"] = 1, ["PlotMarker 1 x x1.5"] = 0.379, ["PlotMarker 1 x x1.5 #split"] = 1, ["ScrapPalm 1 x x1.5"] = 0.177, ["ScrapPalm 1 x x1.5 #split"] = 1, ["ScrapTreeLamppost 1 x x1.5"] = 0.208, ["ScrapTreeLamppost 1 x x1.5 #split"] = 1, ["ShippingContainer 1 x x1.5"] = 0.307, ["ShippingContainer 1 x x1.5 #split"] = 1, ["ShopConceptContainer 1 x x2.5"] = 79.711, ["ShopConceptContainer 1 x x2.5 #split"] = 1, ["StorageCrate 1 x x1.5"] = 9.657, ["StreetlightBroken 1 x x2"] = 0.120, ["StreetlightBroken 1 x x2 #split"] = 1, ["TrafficCones 1 x x1.8"] = 0.155, ["TrafficCones 1 x x1.8 #split"] = 1, ["TyreStack 1 x x1.8"] = 0.113, ["TyreStack 1 x x1.8 #split"] = 1, ["VendingMachine 1 x x2"] = 5.971, ["VendingMachine 1 x x2 #split"] = 1, ["YardFence 1 x x1.5"] = 0.169, ["YardFence 1 x x1.5 #split"] = 1, ["YardFenceHalf 1 x x1.5"] = 0.151, ["YardFenceHalf 1 x x1.5 #split"] = 1, ["YardFooting 0.5 x x1.5"] = 0.066, ["YardFooting 0.5 x x1.5 #split"] = 1, ["YardFooting 1 x x1.5"] = 0.059, ["YardFooting 1 x x1.5 #split"] = 1, ["YardGate 1 x x1.5"] = 0.241, ["YardGate 1 x x1.5 #split"] = 1, ["YardIsland 1 x"] = 83.475, ["YardIsland 1 x #split"] = 1, ["YardPath 1 x x1.5"] = 0.213, ["YardPath 1 x x1.5 #split"] = 1, ["YardPathStub 1 x x1.5"] = 0.175, ["YardPathStub 1 x x1.5 #split"] = 1, ["slab ArenaWall"] = 1.698, ["slab ArenaWall #split"] = 1, ["slab Avenue1"] = 1.371, ["slab Avenue1 #split"] = 1, ["slab Avenue2"] = 1.946, ["slab Avenue2 #split"] = 1, ["slab Avenue3"] = 2.037, ["slab Avenue3 #split"] = 1, ["slab Avenue4"] = 2.055, ["slab Avenue4 #split"] = 1, ["slab Avenue5"] = 1.910, ["slab Avenue5 #split"] = 1, ["slab Beacon"] = 0.634, ["slab Beacon #split"] = 1, ["slab Bridge1"] = 1.695, ["slab Bridge1 #split"] = 1, ["slab Bridge2"] = 1.720, ["slab Bridge2 #split"] = 1, ["slab Bridge3"] = 1.416, ["slab Bridge3 #split"] = 1, ["slab Bridge4"] = 1.591, ["slab Bridge4 #split"] = 1, ["slab Bridge5"] = 1.530, ["slab Bridge5 #split"] = 1, ["slab Bridge6"] = 1.286, ["slab Bridge6 #split"] = 1, ["slab Bridge7"] = 1.597, ["slab Bridge7 #split"] = 1, ["slab Bridge8"] = 1.524, ["slab Bridge8 #split"] = 1, ["slab Hatch1"] = 0.126, ["slab Hatch1 #split"] = 1, ["slab Hatch2"] = 0.131, ["slab Hatch2 #split"] = 1, ["slab Hatch3"] = 0.124, ["slab Hatch3 #split"] = 1, ["slab Hatch4"] = 0.131, ["slab Hatch4 #split"] = 1, ["slab LandmarkPlanter"] = 0.061, ["slab LandmarkPlanter #split"] = 1, ["slab Line"] = 33.177, ["slab Line #split"] = 1, ["slab MarketIsland"] = 4.385, ["slab MarketIsland #split"] = 1, ["slab Pad1"] = 0.544, ["slab Pad1 #split"] = 1, ["slab Pad2"] = 0.537, ["slab Pad2 #split"] = 1, ["slab Pad3"] = 0.540, ["slab Pad3 #split"] = 1, ["slab Pad4"] = 0.541, ["slab Pad4 #split"] = 1, ["slab Palm1Planter"] = 0.061, ["slab Palm1Planter #split"] = 1, ["slab Palm2Planter"] = 0.062, ["slab Palm2Planter #split"] = 1, ["slab Plot1"] = 4.136, ["slab Plot1 #split"] = 1, ["slab Plot2"] = 5.108, ["slab Plot2 #split"] = 1, ["slab Plot3"] = 4.819, ["slab Plot3 #split"] = 1, ["slab Plot4"] = 4.919, ["slab Plot4 #split"] = 1, ["slab Plot5"] = 5.103, ["slab Plot5 #split"] = 1, ["slab Plot6"] = 5.076, ["slab Plot6 #split"] = 1, ["slab Plot7"] = 3.650, ["slab Plot7 #split"] = 1, ["slab Plot8"] = 4.779, ["slab Plot8 #split"] = 1, ["slab Ramps"] = 4.571, ["slab Ramps #split"] = 1, ["slab Side1"] = 0.894, ["slab Side1 #split"] = 1, ["slab Side2"] = 0.880, ["slab Side2 #split"] = 1, ["slab Side3"] = 0.926, ["slab Side3 #split"] = 1, ["slab Side4"] = 0.722, ["slab Side4 #split"] = 1, ["slab Side5"] = 0.888, ["slab Side5 #split"] = 1, ["slab Side6"] = 0.877, ["slab Side6 #split"] = 1, ["slab Spawn"] = 0.093, ["slab Spawn #split"] = 1, ["slab Spoke1"] = 0.088, ["slab Spoke1 #split"] = 1, ["slab Spoke2"] = 0.084, ["slab Spoke2 #split"] = 1, ["slab Spoke3"] = 0.072, ["slab Spoke3 #split"] = 1, ["slab Spoke4"] = 0.086, ["slab Spoke4 #split"] = 1, ["slab Spoke5"] = 0.085, ["slab Spoke5 #split"] = 1, ["slab Spoke6"] = 0.070, ["slab Spoke6 #split"] = 1, ["slab Spoke7"] = 0.084, ["slab Spoke7 #split"] = 1, ["slab Spoke8"] = 0.087, ["slab Spoke8 #split"] = 1,  }
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
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
local function buildHubSectionA()
local CACHE_KEY = "HubSectionA-9e178aacbb8e0c13"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Hub Section A: a middle stretch of the Scrap Line's hub, a rounded slab of
-- floating island from the shared column generator (shared/ColumnIsland.luau).
-- The hub is five of these in a row along x, overlapping at their ends.
local RADIUS = 56
local PEAK = 64
local SEED = 53
-- The rim is a rounded rectangle: at least HALF_LENGTH along the Line (x) and
-- HALF_WIDTH across it once the rim's wobble is taken off.
local RIM_WOBBLE = 0.05
local HALF_LENGTH, HALF_WIDTH = 58.5, 64.5
local function rimShape(angle: number): number
	local c, s = math.abs(math.cos(angle)) / HALF_LENGTH, math.abs(math.sin(angle)) / HALF_WIDTH
	return (c ^ 8 + s ^ 8) ^ (-1 / 8) / HALF_LENGTH
end
-- What stands on it (ServerMap.luau): the Line's paved deck, DECK_HALF either
-- side of the middle, running the section's whole length.
local DECK_HALF = 56.5
-- The deck buries the turf under it.
local COVER_INSET = 2
-- How far a point lies outside the deck.
local function wornDistance(x: number, y: number): number
	return math.abs(y) - DECK_HALF
end

-- Column Island: the generator for the map's floating islands, a mountain
-- of stone columns turned upside down, so a flat grassy top hangs over a
-- rocky cone that tapers to a point below. The columns, of every size and
-- shape, are packed edge to edge like cracked basalt; each hangs as deep as
-- the cone at its centre with a low faceted tip, so the underside steps down
-- in uneven tiers to the lowest point and a shallower shoulder. The columns
-- are the cells of a weighted Voronoi diagram (a power diagram) over
-- scattered stones, so big stones claim big cells. Stones grow from small
-- near the tip to big at the rim, and the big rim stones give the top its
-- lobed outline. Each column is carved, a few angled planes chiselling
-- chunks off its lower corners and edges. The model is built the mountain
-- way up (heights, summit, foot) and flipped as it is written out. Centered
-- on the origin, stone top at z = 0, turf GRASS_HEIGHT above it.
--
-- The item including this sets:
--   RADIUS        the island's radius;
--   PEAK          how far the cone hangs below the top;
--   SEED          which scatter of stones it gets;
--   wornDistance(x, y)  how far a point on the top lies outside the ground
--                 worn by what stands on it (math.huge where nothing does);
--                 the grass wears to dirt within about APRON_WIDTH of it;
--   COVER_INSET   turf lying more than this many studs inside the worn
--                 ground is buried under what stands there and left out
--                 (math.huge keeps it all);
--   RIM_WOBBLE    how far the rim swells and dips, as a share of its radius;
--   rimShape(angle)  how far out the rim stands at an angle, as a multiple
--                 of the round rim: 1 all round for a round island, never
--                 under 1, more toward the corners of a squarer one.
-- Stone sizes at the summit and at the foot, as shares of the radius, so
-- a bigger island has bigger stones rather than more of them.
local SMALLEST, LARGEST = 0.055 * RADIUS, 0.34 * RADIUS
-- Every other size in studs below was tuned on stones up to 4.5 studs
-- across and is multiplied by DETAIL, so an island with bigger stones looks
-- the same, only bigger: chips, slabs, cookie stones, cracks, rounding,
-- grass and the paint's blotches all grow with the stones.
local DETAIL = LARGEST / 4.5
-- The rim the columns are trimmed to: a circle of RIM_PUSH * RADIUS
-- swelling and dipping by up to RIM_WOBBLE of it in broad waves, so the top
-- is a dependable surface rather than sharp lobes and bays, and standing
-- rimShape times as far out at each angle. RIM_SIDES flat facets make it up,
-- so the rim stones end in cut faces.
local RIM_SIDES = 192
-- The rim stands RIM_PUSH times RADIUS out.
local RIM_PUSH = 1.1
-- The top tier of dirt, this deep under the grass, stays a clean wall
-- straight down from the rim the grass follows: chisel cuts, chips and bare
-- rock slabs all start below it.
local DIRT_CONFORM = 1.5 * DETAIL
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before they are trimmed to it.
local RIM_REACH = 1
for i = 0, RIM_SIDES - 1 do
	RIM_REACH = math.max(RIM_REACH, rimShape(i / RIM_SIDES * 2 * math.pi))
end
local SCATTER = RIM_PUSH * RADIUS * RIM_REACH + LARGEST
-- Shortest a column hangs, so the rim stones read as a thick slab; a
-- share of the radius like the stone sizes.
local MIN_LENGTH = 0.2 * RADIUS
-- Chisel cuts per column, at most, and how deep one bites as a share of
-- the stone's size.
local MAX_CUTS = 3
local CUT_DEPTH = { 0.2, 0.55 }
-- Fine chips per column (fewest, most) and how deep one bites, in studs.
local CHIPS = { 3, 6 }
local CHIP_DEPTH = { 0.15 * DETAIL, 0.45 * DETAIL }
-- How far a cut's heading may swing from straight out, in radians.
local CUT_SPREAD = math.rad(55)

local STONE = { 0.46, 0.45, 0.5 }
-- Under the grass the island is all dirt, until rocks start breaking
-- through it at the first share of the island's depth in DIRT_TRANSITION,
-- more and more of them going down, until from the second share it is all
-- rock. Each rock comes through the dirt at its own depth in that range. The
-- dirt's bottom edge is bevelled back DIRT_BEVEL studs on its outer side, so
-- the rock it sits on stands proud.
local DIRT = { 0.33, 0.24, 0.18 }
local DIRT_TRANSITION = { 0.2, 0.65 }
-- Where a rock comes through, the line between its dirt and its stone tilts
-- by up to DIRT_TILT radians, each rock its own way, so the line wanders
-- round the island instead of stepping level.
local DIRT_TILT = math.rad(25)
-- Above that, rock already shows through the dirt in slabs: a rock still
-- under dirt may have up to PATCHES slabs of its faces bare below tilted
-- lines, each facing out from the island's centre within PATCH_SPREAD
-- radians. The chance of each rises from nothing at PATCH_FROM of the depth
-- to certain at PATCH_FULL. A slab is PATCH_THICKNESS studs deep, its back
-- leaning in or out by up to PATCH_LEAN, and its top line tilted by up to
-- PATCH_TILT; PATCH_PEAKED of the slabs have a second top line, so the bare
-- rock comes up to a point through the dirt.
local PATCHES = 2
local PATCH_FROM = 0.04
local PATCH_FULL = 0.25
local PATCH_SPREAD = math.rad(45)
local PATCH_THICKNESS = { 0.4 * DETAIL, 1.4 * DETAIL }
local PATCH_LEAN = 0.5
local PATCH_TILT = 0.8
local PATCH_PEAKED = 0.6
-- The bare rock of a slab is chiselled into a rough stone: this many chips
-- (fewest, most), each biting this deep (studs) off its outer side at its
-- own angle, up to PATCH_CHIP_SPREAD radians off straight out.
local PATCH_CHIPS = { 4, 8 }
local PATCH_CHIP_DEPTH = { 0.3 * DETAIL, 0.8 * DETAIL }
local PATCH_CHIP_SPREAD = math.rad(65)
-- The colours blend too, over a wider share of the depth: dirt greys toward
-- stone and stone keeps a dirty tint across COLOR_TRANSITION, the line
-- wandering by COLOR_WOBBLE of the depth. At any depth the dirt stays
-- DIRT_LEAD further toward dirt than the stone, so the two still read apart.
local COLOR_TRANSITION = { 0.08, 0.55 }
local COLOR_WOBBLE = 0.06
local DIRT_LEAD = 0.45
-- Traces of dirt stay on the stone just under each rock's dirt line, as
-- patchy blotches thinning out over DIRT_TRACE studs below it. Bare rock
-- breaking through above the line keeps DIRT_DUSTING of them.
local DIRT_TRACE = 4 * DETAIL
local DIRT_DUSTING = 0.35
-- Grime and dead grey lichen crust the stone in patches, thickest where
-- the dirt gives way to rock and thinning out to nothing by GRIME_REACH of
-- the island's depth.
-- GRIME_COVER is the most of the stone it covers.
local GRIME = { 0.21, 0.22, 0.19 }
local GRIME_REACH = 0.8
local GRIME_COVER = 0.45

-- Small whole stones half sunk in the dirt, like crushed cookie in ice
-- cream: STONE_BITS of them per square stud of dirt near the top, rising to
-- the second number where the dirt gives way to rock. Each is STONE_BIT_SIZE
-- studs across, most of them small and a few big (STONE_BIT_SKEW over 1), a
-- chipped box, and stands out of the dirt by STONE_BIT_RISE
-- of its size. None sit within STONE_BIT_CLEAR studs of the top, under the
-- grass's lip. With bigger stones (DETAIL) they are bigger and sparser.
local PEBBLE = { 0.47, 0.46, 0.49 }
local STONE_BITS = { 0.035 / DETAIL ^ 2, 0.17 / DETAIL ^ 2 }
local STONE_BIT_SIZE = { 0.45 * DETAIL, 1.9 * DETAIL }
local STONE_BIT_SKEW = 2
local STONE_BIT_RISE = { 0.3, 0.4 }
local STONE_BIT_CLEAR = 1.2 * DETAIL
-- The stones are stained with dirt: solid where they come out of it,
-- breaking into blotches up to STONE_BIT_STAIN of their height.
local STONE_BIT_STAIN = 1.6

-- Drawn cracks in the dirt, running out from the stones sunk in it, as if
-- pushing them in split it: CRACK_CHANCE of the stones have them, up to
-- CRACKS each, CRACK_LENGTH studs long in CRACK_SEGMENTS jagged steps,
-- CRACK_WIDTH wide at the stone and thinning steadily to nothing at its end.
-- CRACK_BRANCH of the cracks fork once.
local CRACK = { 0.17, 0.12, 0.08 }
-- Each crack is drawn in depth: a pale lip where light catches its lower
-- edge (CRACK_LIP), the crack over it, and a darker core down its middle
-- (CRACK_CORE, CRACK_CORE_WIDTH of the crack's width).
local CRACK_LIP = { 0.66, 0.53, 0.4 }
local CRACK_CORE = { 0.06, 0.04, 0.03 }
local CRACK_CORE_WIDTH = 0.45
local CRACK_CHANCE = 1
local CRACKS = 3
local CRACK_LENGTH = { 0.6 * DETAIL, 1.8 * DETAIL }
local CRACK_SEGMENTS = 4
local CRACK_WIDTH = { 0.1 * DETAIL, 0.18 * DETAIL }
local CRACK_BRANCH = 0.4
local DIRT_BEVEL = { 0.3 * DETAIL, 0.6 * DETAIL }
-- How steeply each rock's bevel slants, in radians up from flat; each rock
-- takes its own angle in this range, so the bevels don't all match.
local DIRT_BEVEL_LIFT = { math.rad(25), math.rad(65) }
-- The dirt's outer edges and corners are rounded off on this radius, each
-- edge in this many facets, so it reads soft rather than jagged.
local DIRT_ROUND = 0.6 * DETAIL
local DIRT_ROUND_STEPS = 4
-- Each rock shades from STONE times the first where it meets the top to
-- STONE times the second at its tip.
local ROCK_GRADIENT = { 1.1, 0.6 }
-- Brush splotches in the stone: one may sit in each cell of a 3D grid
-- (`cell` studs, with `chance`), a lobed blot `radius` studs across that
-- shifts the stone's tone by up to `tone` and its tint by up to `tint`. The
-- coat's brush strokes lay them on as dabs.
local SPLOTCH = { cell = 1.8 * DETAIL, chance = 1, radius = { DETAIL, 2 * DETAIL }, tone = 0.1, tint = 0.02 }
-- Texture pixels per stud; chunks are 1024 texels across at this density.
local TEXEL_DENSITY = 16
-- Edge highlights: how far edge paint reaches from an edge, in studs, and how
-- many times wider than the default the highlight strokes are.
local EDGE_REACH = DETAIL
local HIGHLIGHT_WIDTH = 4
-- Studs over which a highlight thins from full width at a corner.
local CORNER_TAPER = 0.5 * DETAIL
-- Grass and dirt are soft, so their edge highlights and contact shadows run
-- at this share of the stone's.
local SOFT_SHADING = 0.12

-- Grass over the top: a turf slab GRASS_HEIGHT thick, pushed GRASS_OUTSET
-- past the rim, whose edge hangs down as a lip (shallowest and deepest, in
-- studs) hung all along with tongues of grass dripping further down, each
-- DRIP_WIDTH across and DRIP_LENGTH below the lip. Neighbouring drips
-- overlap by DRIP_OVERLAP of their widths, so the edge runs as one
-- unbroken wave with no flat stretch between drips.
local GRASS = { 0.74, 0.63, 0.4 }
local GRASS_HEIGHT = 0.45 * DETAIL
local GRASS_OUTSET = 0.25 * DETAIL
local GRASS_LIP = { 0.3 * DETAIL, 0.6 * DETAIL }
local DRIP_WIDTH = { 1.6 * DETAIL, 4 * DETAIL }
local DRIP_LENGTH = { 0.3 * DETAIL, 1.1 * DETAIL }
local DRIP_OVERLAP = 0.35
-- A finer octave of wobble over the wave: how far it moves the edge up or
-- down, in studs, and how fast it changes along the rim.
local DRIP_DETAIL = 0.3 * DETAIL
local DRIP_DETAIL_FREQUENCY = 1.1 / DETAIL
-- Spacing of the points the rim is walked in, in studs.
local GRASS_STEP = 0.25 * DETAIL
-- The turf's top rolls over into its hanging edge on a quarter circle this
-- many studs across, in this many facets.
local GRASS_ROUND = 0.42 * DETAIL
local GRASS_ROUND_STEPS = 4
-- The hanging edge's bottom curls under into its underside on this radius.
local GRASS_BOTTOM_ROUND = 0.2 * DETAIL
-- The rim's corners in plan are rounded off by blurring its outline over
-- about this many studs, just enough to soften each stone's jog while the
-- grass still follows the stones, pushed out GRASS_OUTSET past them. The drips' depth is
-- blurred over GRASS_DEPTH_BLUR studs, so neighbouring tongues meet in soft
-- dips rather than sharp notches.
local GRASS_CORNER_BLUR = 0.2 * DETAIL
local GRASS_DEPTH_BLUR = 0.3 * DETAIL
-- The turf's flat top is cut into squares this many studs across, to keep
-- its texture chunks small; this one doesn't grow with DETAIL.
local GRASS_TOP_CELL = 8
-- How much the grass darkens toward the tip of the deepest drip.
local DRIP_SHADE = 0.35
-- The grass is dead: straw GRASS drifting into a dull olive where a little
-- life hangs on (GRASS_OLIVE_COVER of it), in soft noise patches this many
-- studs across.
local GRASS_OLIVE = { 0.6, 0.57, 0.35 }
local GRASS_OLIVE_COVER = 0.3
local GRASS_PATCH_SIZE = 6 * DETAIL
-- Within about APRON_WIDTH studs of what stands on the top (wornDistance)
-- the grass is worn down to TRODDEN dirt and gravel, in patches toward the
-- outside. These follow what stands there, not the stones, so DETAIL leaves
-- them alone.
local APRON_WIDTH = 6
local TRODDEN = { 0.47, 0.4, 0.31 }

-- Fixed per-column jitter, so the columns look uneven but every build matches.
local function hash(i: number, j: number): number
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
end

local seed = SEED
local function random(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

-- Height of the slope at a point: the main cone, ridges running down from
-- the summit, and a lower shoulder peak off to one side. The cone is
-- rounded BOWL of the way toward a dome, so the underside reads as a
-- shallow bowl rather than a spike under a flat shelf.
local BOWL = 0.4
local function heightAt(x: number, y: number): number
	local r = math.sqrt(x * x + y * y) / RADIUS
	local angle = math.atan2(y, x)
	local ridges = 1 + 0.12 * math.cos(angle * 5) * r
	local out = math.min(r * ridges, 1)
	local cone = (1 - out) ^ 1.25
	local dome = math.sqrt(1 - out * out)
	local main = PEAK * (cone + (dome - cone) * BOWL)
	local sx, sy = x - 8, y + 5
	local shoulder = 19 * math.max(0, 1 - math.sqrt(sx * sx + sy * sy) / 11) ^ 1.1
	return math.max(main, shoulder)
end

-- The rim's radius at an angle.
local function rimAt(angle: number): number
	local phase = SEED * 1.7
	local wave = 0.5 * math.sin(2 * angle + phase) + 0.3 * math.sin(3 * angle + 2 * phase) + 0.2 * math.sin(5 * angle + 3 * phase)
	return RIM_PUSH * RADIUS * rimShape(angle) * (1 + RIM_WOBBLE * wave)
end

-- Stones scattered by dart throwing, none crowding another, sized by how
-- high on the slope they sit: x, y and size.
local stones = {}
for _ = 1, 8000 do
	local angle, reach = random() * TAU, math.sqrt(random()) * SCATTER
	local x, y = reach * math.cos(angle), reach * math.sin(angle)
	local height = math.clamp(heightAt(x, y) / PEAK, 0, 1)
	local size = (LARGEST + (SMALLEST - LARGEST) * height ^ 0.5) * (0.8 + 0.4 * random())
	local clear = true
	for _, other in stones do
		local dx, dy = x - other[1], y - other[2]
		if dx * dx + dy * dy < ((size + other[3]) * 0.72) ^ 2 then
			clear = false
			break
		end
	end
	if clear then
		table.insert(stones, { x, y, size })
	end
end

-- Cuts a cell outline down to the side of stone q's boundary nearer stone
-- p. Each corner carries the stone across the edge that starts there (nil
-- on the outer rim), so walls can find their neighbour.
local function clip(outline, p, q, neighbour)
	local nx, ny = q[1] - p[1], q[2] - p[2]
	local limit = (q[1] ^ 2 + q[2] ^ 2 - p[1] ^ 2 - p[2] ^ 2 - q[3] ^ 2 + p[3] ^ 2) / 2
	local function side(point)
		return point[1] * nx + point[2] * ny - limit
	end
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = side(a), side(b)
		local crossing = if (sa <= 0) ~= (sb <= 0)
			then { a[1] + (b[1] - a[1]) * sa / (sa - sb), a[2] + (b[2] - a[2]) * sa / (sa - sb) }
			else nil
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
			if crossing then
				table.insert(kept, { crossing[1], crossing[2], neighbour })
			end
		elseif crossing then
			table.insert(kept, { crossing[1], crossing[2], a[3] })
		end
	end
	return kept
end

-- The rim's corners, then each of its sides as a plane n . p <= limit,
-- in order round from angle 0.
local rimSides = {}
do
	local rim = {}
	for i = 0, RIM_SIDES - 1 do
		local angle = i / RIM_SIDES * TAU
		local r = rimAt(angle)
		rim[i + 1] = { r * math.cos(angle), r * math.sin(angle) }
	end
	for i, a in rim do
		local b = rim[i % #rim + 1]
		-- Counter-clockwise, so out is to the right of each side.
		local nx, ny = b[2] - a[2], a[1] - b[1]
		table.insert(rimSides, { nx, ny, nx * a[1] + ny * a[2] })
	end
end

-- Cuts a cell outline down to the inside of one rim side; corners where it
-- crosses carry nil, as on the outer rim.
local function clipToRim(outline, side)
	local nx, ny, limit = side[1], side[2], side[3]
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = a[1] * nx + a[2] * ny - limit, b[1] * nx + b[2] * ny - limit
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
		end
		if (sa <= 0) ~= (sb <= 0) then
			local t = sa / (sa - sb)
			table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, if sa <= 0 then nil else a[3] })
		end
	end
	return kept
end

-- Each stone's column: its outline and its top corners on a slanted plane.
local columns = {}
for index, stone in stones do
	local outline = {}
	for i = 0, 31 do
		local angle = i / 32 * TAU
		table.insert(outline, { SCATTER * math.cos(angle), SCATTER * math.sin(angle), nil })
	end
	for other, neighbour in stones do
		if other ~= index and #outline >= 3 then
			local dx, dy = neighbour[1] - stone[1], neighbour[2] - stone[2]
			if dx * dx + dy * dy < (LARGEST * 3) ^ 2 then
				outline = clip(outline, stone, neighbour, other)
			end
		end
	end
	-- Every cell is trimmed to the rim sides it faces (the rim isn't convex,
	-- so the far sides would cut into its swells); those left with nothing
	-- inside the rim are dropped. A cell's sides are those over the angles
	-- its corners span, and a few either way so neighbours trim alike.
	local low, high, farthest = math.huge, -math.huge, 0
	local heading = math.atan2(stone[2], stone[1])
	for _, corner in outline do
		local offset = (math.atan2(corner[2], corner[1]) - heading + math.pi) % TAU - math.pi
		low, high = math.min(low, offset), math.max(high, offset)
		farthest = math.max(farthest, math.sqrt(corner[1] ^ 2 + corner[2] ^ 2))
	end
	if farthest > RIM_PUSH * RADIUS * (1 - RIM_WOBBLE) then
		local first = math.floor((heading + low) / TAU * RIM_SIDES) - 8
		local last = math.ceil((heading + high) / TAU * RIM_SIDES) + 8
		for k = first, last do
			if #outline < 3 then
				break
			end
			outline = clipToRim(outline, rimSides[k % RIM_SIDES + 1])
		end
	end
	local area = 0
	for i, a in outline do
		local b = outline[i % #outline + 1]
		area += (a[1] * b[2] - b[1] * a[2]) / 2
	end
	-- Only cells the rim leaves nothing of are dropped; a small one kept at
	-- the rim fills its stretch so the edge doesn't notch.
	if #outline < 3 or math.abs(area) < 1e-3 then
		continue
	end
	local cx, cy = 0, 0
	for _, corner in outline do
		cx, cy = cx + corner[1] / #outline, cy + corner[2] / #outline
	end
	local rise = math.max(MIN_LENGTH * (0.8 + 0.4 * hash(index, 5)), heightAt(cx, cy) + (hash(index, 1) - 0.5) * (1 + stone[3]))
	local tiltX, tiltY = (hash(index, 2) - 0.5) * 0.45, (hash(index, 3) - 0.5) * 0.45
	local corners = {}
	-- Neighbouring columns share their edges exactly, so no gap opens
	-- between them.
	for i, corner in outline do
		local z = rise + (corner[1] - cx) * tiltX + (corner[2] - cy) * tiltY
		corners[i] = { corner[1], corner[2], z, corner[3] }
	end
	columns[index] = {
		index = index,
		size = stone[3],
		corners = corners,
		-- The top rises to a low ridge point, so it reads as broken stone.
		peak = { cx, cy, rise + 0.15 * stone[3] * (0.5 + hash(index, 4)) },
	}
end

-- A column as a closed solid: faces as lists of points, wound outward,
-- from the foot (z = 0) up to its slanted top and the low point above it.
local function solidOf(column)
	local bottom = 0
	local corners, peak = column.corners, column.peak
	local count = #corners
	local faces = {}
	local base = {}
	for i = count, 1, -1 do
		table.insert(base, { corners[i][1], corners[i][2], bottom })
	end
	table.insert(faces, base)
	for i = 1, count do
		local a, b = corners[i], corners[i % count + 1]
		table.insert(faces, { { a[1], a[2], bottom }, { b[1], b[2], bottom }, { b[1], b[2], b[3] }, { a[1], a[2], a[3] } })
		table.insert(faces, { { peak[1], peak[2], peak[3] }, { a[1], a[2], a[3] }, { b[1], b[2], b[3] } })
	end
	return faces
end

-- Cuts away everything on the far side of the plane n . p = d, closing the
-- wound with a cap facing along n.
local function carve(faces, n, d)
	local kept, cut = {}, {}
	for _, face in faces do
		local out = {}
		for i, a in face do
			local b = face[i % #face + 1]
			local sa = a[1] * n[1] + a[2] * n[2] + a[3] * n[3] - d
			local sb = b[1] * n[1] + b[2] * n[2] + b[3] * n[3] - d
			if sa <= 0 then
				table.insert(out, a)
			end
			if (sa <= 0) ~= (sb <= 0) then
				local t = sa / (sa - sb)
				local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
				table.insert(out, p)
				table.insert(cut, p)
			end
		end
		if #out >= 3 then
			table.insert(kept, out)
		end
	end
	if #cut < 3 then
		return kept
	end
	-- The cap's corners, sorted round their centre in the plane.
	local mx, my, mz = 0, 0, 0
	for _, p in cut do
		mx, my, mz = mx + p[1] / #cut, my + p[2] / #cut, mz + p[3] / #cut
	end
	local ux, uy, uz = if math.abs(n[3]) < 0.9 then -n[2] else 0, if math.abs(n[3]) < 0.9 then n[1] else -n[3], if math.abs(n[3]) < 0.9 then 0 else n[2]
	local length = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / length, uy / length, uz / length
	local vx, vy, vz = n[2] * uz - n[3] * uy, n[3] * ux - n[1] * uz, n[1] * uy - n[2] * ux
	local cap = {}
	for _, p in cut do
		local ox, oy, oz = p[1] - mx, p[2] - my, p[3] - mz
		local angle = math.atan2(ox * vx + oy * vy + oz * vz, ox * ux + oy * uy + oz * uz)
		local duplicate = false
		for _, other in cap do
			duplicate = duplicate or math.abs(other[2] - angle) < 1e-4
		end
		if not duplicate then
			table.insert(cap, { p, angle })
		end
	end
	table.sort(cap, function(a, b)
		return a[2] < b[2]
	end)
	if #cap >= 3 then
		local face = {}
		for i, entry in cap do
			face[i] = entry[1]
		end
		table.insert(kept, face)
	end
	return kept
end

-- Carve every column first, so walls can be cut against their
-- neighbours' finished shapes.
for _, column in columns do
	local corners, index = column.corners, column.index
	local faces = solidOf(column)
	local outward = math.atan2(column.peak[2], column.peak[1])

	-- Chisel cuts: each faces out and up at its own angle, from a low
	-- slant (shaving a side edge) to steep (bevelling the top), and
	-- bites a set depth in from the farthest point along it. None is
	-- near level, which would open holes down between columns. Every cut
	-- faces away from the island's centre, within CUT_SPREAD either side,
	-- so the carving shows on the outside and never faces inward.
	-- The cuts to make: heading, lift and depth. The big chisel cuts come
	-- first, then fine chips that knock small corners off what is left.
	local cuts = {}
	for k = 1, 1 + math.floor(hash(index, 40) * MAX_CUTS) do
		table.insert(cuts, {
			outward + (hash(index, 40 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 50 + k) * 0.85,
			column.size * (CUT_DEPTH[1] + (CUT_DEPTH[2] - CUT_DEPTH[1]) * hash(index, 60 + k)),
		})
	end
	for k = 1, CHIPS[1] + math.floor(hash(index, 70) * (CHIPS[2] - CHIPS[1] + 1)) do
		table.insert(cuts, {
			outward + (hash(index, 70 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 80 + k) * 1.05,
			CHIP_DEPTH[1] + (CHIP_DEPTH[2] - CHIP_DEPTH[1]) * hash(index, 90 + k),
		})
	end
	for _, cut in cuts do
		local heading, lift, depth = cut[1], cut[2], cut[3]
		local n = { math.cos(heading) * math.cos(lift), math.sin(heading) * math.cos(lift), math.sin(lift) }
		local farthest = -math.huge
		for _, face in faces do
			for _, p in face do
				farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
			end
		end
		-- A cut stops short of the top tier, which follows the grass, so
		-- the wall under the grass is never carved into.
		local tiermost = -math.huge
		for _, corner in corners do
			tiermost = math.max(tiermost, corner[1] * n[1] + corner[2] * n[2] + DIRT_CONFORM * n[3])
		end
		local plane = math.max(farthest - depth, tiermost + 0.3)
		if plane < farthest then
			faces = carve(faces, n, plane)
		end
	end

	column.faces = faces

	-- Where the column's carved underside begins: the shallowest point of
	-- any face that isn't a side wall or its foot.
	column.surfaceFrom = math.huge
	for _, face in faces do
		local foot, nz = true, 0
		for i, p in face do
			local q = face[i % #face + 1]
			foot = foot and p[3] == 0
			nz += (p[1] - q[1]) * (p[2] + q[2])
		end
		if not foot and math.abs(nz) > 1e-3 then
			for _, p in face do
				column.surfaceFrom = math.min(column.surfaceFrom, p[3])
			end
		end
	end
end

-- How deep each column hides behind the tier around it: it comes into view
-- where its shallowest neighbour's underside begins, or at the top if it
-- faces the open edge.
for _, column in columns do
	column.shownFrom = math.huge
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		column.shownFrom = math.min(column.shownFrom, if neighbour then neighbour.surfaceFrom else 0)
	end
end

-- How deep the island hangs at its lowest point.
local islandDepth = 0
for _, column in columns do
	islandDepth = math.max(islandDepth, column.peak[3])
end

-- How far a solid reaches along a direction.
local function farthestAlong(faces, n): number
	local farthest = -math.huge
	for _, face in faces do
		for _, p in face do
			farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
		end
	end
	return farthest
end

-- Cuts a solid's outer bottom edge off, `depth` studs in along a slant facing
-- out from the island's centre and down, `lift` radians up from flat.
local function bevelled(faces, outward: number, depth: number, lift: number)
	local n = { math.cos(outward) * math.cos(lift), math.sin(outward) * math.cos(lift), math.sin(lift) }
	return carve(faces, n, farthestAlong(faces, n) - depth)
end

-- Each rock is dirt down to where it comes through, and stone below, split
-- into a dirt solid and a stone one. The dirt's outer bottom edge is
-- bevelled off, so the stone under it stands proud. Higher up, a patch of a
-- rock's outer face may already show through: the dirt is split into the
-- slab on its outer face and the rest, and the slab into bare stone below a
-- tilted line and dirt above, bevelled like the rest.
for _, column in columns do
	local index, faces = column.index, column.faces
	local share = DIRT_TRANSITION[1] + (DIRT_TRANSITION[2] - DIRT_TRANSITION[1]) * hash(index, 30)
	local dirtLine = islandDepth * share
	column.dirtLine = dirtLine
	if dirtLine <= column.shownFrom then
		column.solids = { { faces = faces, dirt = false } }
		continue
	end
	local shown = column.shownFrom
	local outward = math.atan2(column.peak[2], column.peak[1])
	local bevel = DIRT_BEVEL[1] + (DIRT_BEVEL[2] - DIRT_BEVEL[1]) * hash(index, 31)
	local lift = DIRT_BEVEL_LIFT[1] + (DIRT_BEVEL_LIFT[2] - DIRT_BEVEL_LIFT[1]) * hash(index, 34)
	-- The tilted line passes through dirtLine under the rock's tip.
	local tilt, heading = DIRT_TILT * hash(index, 32), hash(index, 33) * 2 * math.pi
	local down = { math.sin(tilt) * math.cos(heading), math.sin(tilt) * math.sin(heading), math.cos(tilt) }
	local line = down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * dirtLine
	local dirt = bevelled(carve(faces, down, line), outward, bevel, lift)
	local stone = carve(faces, { -down[1], -down[2], -down[3] }, -line)
	column.solids = { { faces = dirt, dirt = true }, { faces = stone, dirt = false } }
	-- The stone shows from below the dirt.
	column.shownFrom = math.min(dirtLine, column.peak[3])

	local middle = (shown + dirtLine) / 2 / islandDepth
	local chance = math.clamp((middle - PATCH_FROM) / (PATCH_FULL - PATCH_FROM), 0, 1)
	if dirtLine - shown <= 1 then
		continue
	end
	-- Each slab is cut from the dirt left after the last, so they sit side
	-- by side round the rock.
	local rest, solids = dirt, { { faces = stone, dirt = false } }
	for k = 1, PATCHES do
		if hash(index, 204 + k * 10) >= chance then
			continue
		end
		local heading = outward + (hash(index, 205 + k * 10) - 0.5) * 2 * PATCH_SPREAD
		local lean = (hash(index, 300 + k * 10) - 0.5) * 2 * PATCH_LEAN
		local size = math.sqrt(1 + lean * lean)
		local across = { math.cos(heading) / size, math.sin(heading) / size, lean / size }
		local thickness = PATCH_THICKNESS[1] + (PATCH_THICKNESS[2] - PATCH_THICKNESS[1]) * hash(index, 206 + k * 10)
		local face = farthestAlong(rest, across) - thickness
		local slab = carve(rest, { -across[1], -across[2], -across[3] }, -face)
		rest = carve(rest, across, face)
		-- The slab's top line, tilted, somewhere down what shows of the rock:
		-- above it dirt, below it bare rock.
		local function topLine(seed: number)
			local top = shown + (dirtLine - shown) * (0.05 + 0.45 * hash(index, seed))
			local tx = (hash(index, seed + 1) - 0.5) * 2 * PATCH_TILT
			local ty = (hash(index, seed + 2) - 0.5) * 2 * PATCH_TILT
			local length = math.sqrt(tx * tx + ty * ty + 1)
			local down = { tx / length, ty / length, 1 / length }
			-- Never above the top tier anywhere across the slab.
			local level = -math.huge
			for _, f in slab do
				for _, p in f do
					level = math.max(level, down[1] * p[1] + down[2] * p[2] + down[3] * DIRT_CONFORM)
				end
			end
			return down, math.max(down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * top, level)
		end
		local down, line = topLine(207 + k * 10)
		table.insert(solids, { faces = bevelled(carve(slab, down, line), heading, bevel * 0.7, lift), dirt = true })
		local bare = carve(slab, { -down[1], -down[2], -down[3] }, -line)
		-- A second line peaks the rock: the dirt it cuts off stays dirt.
		if hash(index, 320 + k * 10) < PATCH_PEAKED then
			local second, secondLine = topLine(330 + k * 10)
			table.insert(solids, { faces = bevelled(carve(bare, second, secondLine), heading, bevel * 0.7, lift), dirt = true })
			bare = carve(bare, { -second[1], -second[2], -second[3] }, -secondLine)
		end
		-- Chipped into a rough stone rather than a flat slab.
		local chips = PATCH_CHIPS[1] + math.floor(hash(index, 400 + k * 10) * (PATCH_CHIPS[2] - PATCH_CHIPS[1] + 1))
		for c = 1, chips do
			local seed = 500 + k * 100 + c * 7
			local yaw = heading + (hash(index, seed) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local pitch = (hash(index, seed + 1) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local n = { math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch) }
			local depth = PATCH_CHIP_DEPTH[1] + (PATCH_CHIP_DEPTH[2] - PATCH_CHIP_DEPTH[1]) * hash(index, seed + 2)
			local plane = farthestAlong(bare, n) - depth
			if plane > -math.huge then
				bare = carve(bare, n, plane)
			end
		end
		table.insert(solids, { faces = bare, dirt = false })
	end
	table.insert(solids, { faces = rest, dirt = true })
	column.solids = solids
end

-- Each face's plane, as a unit normal pointing out and its distance.
local function planeOf(face)
	local nx, ny, nz = 0, 0, 0
	for i, a in face do
		local b = face[i % #face + 1]
		nx += (a[2] - b[2]) * (a[3] + b[3])
		ny += (a[3] - b[3]) * (a[1] + b[1])
		nz += (a[1] - b[1]) * (a[2] + b[2])
	end
	local length = math.sqrt(nx * nx + ny * ny + nz * nz)
	if length < 1e-9 then
		return nil
	end
	nx, ny, nz = nx / length, ny / length, nz / length
	local p = face[1]
	return { nx, ny, nz, nx * p[1] + ny * p[2] + nz * p[3] }
end

-- Splits a face by a plane into the part outside it and the part inside.
local EPSILON = 1e-5
local function split(face, plane)
	local outside, inside = {}, {}
	local function side(p)
		local s = plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
		return if math.abs(s) < EPSILON then 0 else s
	end
	for i, a in face do
		local b = face[i % #face + 1]
		local sa, sb = side(a), side(b)
		if sa >= 0 then
			table.insert(outside, a)
		end
		if sa <= 0 then
			table.insert(inside, a)
		end
		if (sa > 0 and sb < 0) or (sa < 0 and sb > 0) then
			local t = sa / (sa - sb)
			local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
			table.insert(outside, p)
			table.insert(inside, p)
		end
	end
	return outside, inside
end

local function area(face): number
	local plane = planeOf(face)
	if not plane or #face < 3 then
		return 0
	end
	local total = 0
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
		total += ((uy * vz - uz * vy) * plane[1] + (uz * vx - ux * vz) * plane[2] + (ux * vy - uy * vx) * plane[3]) / 2
	end
	return total
end

-- The parts of a face that don't lie inside a neighbour. Only a face lying
-- against one of the neighbour's own faces can touch it; that face's plane
-- is skipped, and the face is carved by the rest, every piece that falls
-- outside one of them showing.
local function uncovered(face, neighbour)
	local own = planeOf(face)
	if not own then
		return {}
	end
	local touching, planes = false, {}
	for _, other in neighbour.faces do
		local plane = planeOf(other)
		if plane then
			local facing = own[1] * plane[1] + own[2] * plane[2] + own[3] * plane[3] < -0.9999
			local p = face[1]
			if facing and math.abs(plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]) < 1e-4 then
				touching = true
			else
				table.insert(planes, plane)
			end
		end
	end
	if not touching then
		return { face }
	end
	local shown, rest = {}, face
	for _, plane in planes do
		local outside, inside = split(rest, plane)
		if #outside >= 3 and area(outside) > 1e-4 then
			table.insert(shown, outside)
		end
		rest = inside
		if #rest < 3 or area(rest) <= 1e-4 then
			break
		end
	end
	return shown
end

-- Columns bucketed by the 2-stud cells their outlines cover, so paint can
-- find the rock under a point without testing them all.
local CELL = 2
local cells = {}
for _, column in columns do
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, corner in column.corners do
		x0, y0 = math.min(x0, corner[1]), math.min(y0, corner[2])
		x1, y1 = math.max(x1, corner[1]), math.max(y1, corner[2])
	end
	for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
		for cy = math.floor(y0 / CELL), math.floor(y1 / CELL) do
			local cellKey = `{cx},{cy}`
			cells[cellKey] = cells[cellKey] or {}
			table.insert(cells[cellKey], column)
		end
	end
end

-- The rock a point on the island belongs to. On a wall two rocks share,
-- the deeper one owns it, since only its wall shows there.
local function rockAt(x: number, y: number)
	local found = nil
	for _, column in cells[`{math.floor(x / CELL)},{math.floor(y / CELL)}`] or {} do
		local corners, within = column.corners, true
		for i, a in corners do
			local b = corners[i % #corners + 1]
			if (b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1]) < -1e-3 then
				within = false
				break
			end
		end
		if within and (found == nil or column.peak[3] > found.peak[3]) then
			found = column
		end
	end
	return found
end

-- The splotch on top at a point, as its tone and warmth shifts (0, 0 where
-- none reaches). Of the splotches covering a point, the one laid last wins.
local function splotchAt(x: number, y: number, z: number): (number, number)
	local size = SPLOTCH.cell
	local gx, gy, gz = math.floor(x / size), math.floor(y / size), math.floor(z / size)
	local tone, warm, order = 0, 0, -1
	for i = gx - 1, gx + 1 do
		for j = gy - 1, gy + 1 do
			for k = gz - 1, gz + 1 do
				local seed = i * 7.31 + k * 3.17
				if hash(seed, j + 101) < SPLOTCH.chance then
					local cx = (i + hash(seed, j + 201)) * size
					local cy = (j + hash(seed, j + 301)) * size
					local cz = (k + hash(seed, j + 401)) * size
					local radius = SPLOTCH.radius[1] + (SPLOTCH.radius[2] - SPLOTCH.radius[1]) * hash(seed, j + 501)
					local dx, dy, dz = x - cx, y - cy, z - cz
					-- Lobed rim, so a blot isn't a clean circle.
					local lobes = 1 + 0.25 * math.noise(dx / radius * 1.5 + i, dy / radius * 1.5 + j, dz / radius * 1.5 + k)
					local laid = hash(seed, j + 601)
					if dx * dx + dy * dy + dz * dz < (radius * lobes) ^ 2 and laid > order then
						order = laid
						tone = (hash(seed, j + 701) - 0.5) * 2 * SPLOTCH.tone
						warm = (hash(seed, j + 801) - 0.5) * 2 * SPLOTCH.tint
					end
				end
			end
		end
	end
	return tone, warm
end

-- Per-rock gradient over the part of a rock that shows: light where it
-- comes out from behind the tier around it, darkening toward its tip. The
-- island hangs below z = 0, so depth is -z. Near the top the rock is dirt,
-- fading to stone further down.
-- How far from dirt toward stone the colour has blended at a point, 0 to 1.
local function stoneAt(x: number, y: number, z: number): number
	local share = -z / islandDepth + COLOR_WOBBLE * math.noise(x * 0.15 / DETAIL, y * 0.15 / DETAIL, z * 0.15 / DETAIL)
	local t = math.clamp((share - COLOR_TRANSITION[1]) / (COLOR_TRANSITION[2] - COLOR_TRANSITION[1]), 0, 1)
	return t * t * (3 - 2 * t)
end

-- A colour between dirt and stone, `t` of the way to stone.
local function soil(t: number): (number, number, number)
	return DIRT[1] + (STONE[1] - DIRT[1]) * t, DIRT[2] + (STONE[2] - DIRT[2]) * t, DIRT[3] + (STONE[3] - DIRT[3]) * t
end

local paintRock = rusting(0.1, function(x, y, z)
	local rock = rockAt(x, y)
	local depth = if rock
		then math.clamp((-z - rock.shownFrom) / math.max(rock.peak[3] - rock.shownFrom, 0.5), 0, 1)
		else 0
	local shade = ROCK_GRADIENT[1] + (ROCK_GRADIENT[2] - ROCK_GRADIENT[1]) * depth ^ 0.8
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local blend = stoneAt(x, y, z)
	local r, g, b = soil(DIRT_LEAD + (1 - DIRT_LEAD) * blend)
	-- Dirt traces: blotches whose share of the stone shrinks below the line.
	if rock then
		local below = -z - rock.dirtLine
		local amount = if below < 0 then DIRT_DUSTING else math.max(0, 1 - below / DIRT_TRACE) ^ 1.5
		local f = 0.7 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f) + 0.25 * math.noise(x * f * 3, y * f * 3, z * f * 3)
		local trace = math.clamp((blot - (1 - 0.7 * amount)) / 0.08, 0, 1)
		if trace > 0 then
			local dr, dg, db = soil(0.25 * blend)
			r, g, b = r + (dr - r) * trace, g + (dg - g) * trace, b + (db - b) * trace
		end
	end
	local share = -z / islandDepth
	-- Grime: soft-edged patches, less of them deeper down.
	local growth = math.clamp((GRIME_REACH - share) / (GRIME_REACH - DIRT_TRANSITION[1]), 0, 1)
	if growth > 0 then
		local f = 0.45 / DETAIL
		local patch = 0.5 + 0.5 * math.noise(x * f + 31, y * f, z * f) + 0.2 * math.noise(x * f * 3.6, y * f * 3.6 + 17, z * f * 3.6)
		local grime = math.clamp((patch - (1 - GRIME_COVER * growth)) / 0.1, 0, 1)
		r, g, b = r + (GRIME[1] - r) * grime, g + (GRIME[2] - g) * grime, b + (GRIME[3] - b) * grime
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Dirt darkens a little with depth, greys toward stone, and is splotched
-- like the stone.
local paintDirt = rusting(0.05, function(x, y, z)
	local shade = 1.05 - 0.3 * math.clamp(-z / (islandDepth * DIRT_TRANSITION[2]), 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local r, g, b = soil((1 - DIRT_LEAD) * stoneAt(x, y, z))
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Flipped upside down as it is written out: z mirrors, and the winding
-- reverses so faces still point outward. The foot becomes the island's top.
local function addFlipped(mesh, face)
	local verts = {}
	for i, p in face do
		verts[#face + 1 - i] = mesh:vertex(p[1], p[2], -p[3])
	end
	mesh:face(verts)
end

-- The island is split into cubic chunks, each with its own texture, so the
-- stone reads sharp at one density everywhere.
useTexelDensity(TEXEL_DENSITY)

-- A unit vector along x, y, z, and the cross product of two vectors.
local function unit(x: number, y: number, z: number)
	local length = math.max(math.sqrt(x * x + y * y + z * z), 1e-9)
	return { x / length, y / length, z / length }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The solids that may cover a solid of a column: the column's other pieces
-- and its neighbours'.
local function coverersOf(column, solid)
	local others = {}
	for _, other in column.solids do
		if other ~= solid then
			table.insert(others, other)
		end
	end
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		if neighbour then
			for _, other in neighbour.solids do
				table.insert(others, other)
			end
		end
	end
	return others
end

-- What of a face no other solid covers.
local function exposed(face, others)
	local pieces = { face }
	for _, other in others do
		local kept = {}
		for _, piece in pieces do
			for _, part in uncovered(piece, other) do
				table.insert(kept, part)
			end
		end
		pieces = kept
	end
	return pieces
end

local function isFoot(face): boolean
	for _, p in face do
		if p[3] ~= 0 then
			return false
		end
	end
	return true
end

-- Rounds a convex solid's edges and corners where faces that show meet, on
-- DIRT_ROUND. Each such edge is cut by planes turning from one face to the
-- other, each touching a cylinder of that radius set in from both faces;
-- each such corner by one plane facing out between its faces.
local function rounded(faces, shows)
	local planes = {}
	for i, face in faces do
		planes[i] = planeOf(face)
	end
	local function key(p)
		return `{math.round(p[1] * 1e4)},{math.round(p[2] * 1e4)},{math.round(p[3] * 1e4)}`
	end
	local edgeFaces, cornerFaces, points = {}, {}, {}
	for i, face in faces do
		if not planes[i] or not shows[i] then
			continue
		end
		for k, a in face do
			local b = face[k % #face + 1]
			local ka, kb = key(a), key(b)
			points[ka] = a
			local edge = if ka < kb then `{ka}|{kb}` else `{kb}|{ka}`
			edgeFaces[edge] = edgeFaces[edge] or { a = a }
			table.insert(edgeFaces[edge], i)
			cornerFaces[ka] = cornerFaces[ka] or {}
			cornerFaces[ka][i] = true
		end
	end
	local cuts = {}
	for _, edge in edgeFaces do
		if #edge ~= 2 then
			continue
		end
		local n1, n2 = planes[edge[1]], planes[edge[2]]
		local cosine = n1[1] * n2[1] + n1[2] * n2[2] + n1[3] * n2[3]
		if cosine > 0.985 then
			continue
		end
		local p = edge.a
		local inset = DIRT_ROUND / (1 + cosine)
		local centre = { p[1] - (n1[1] + n2[1]) * inset, p[2] - (n1[2] + n2[2]) * inset, p[3] - (n1[3] + n2[3]) * inset }
		for k = 1, DIRT_ROUND_STEPS do
			local t = k / (DIRT_ROUND_STEPS + 1)
			local m = unit(n1[1] + (n2[1] - n1[1]) * t, n1[2] + (n2[2] - n1[2]) * t, n1[3] + (n2[3] - n1[3]) * t)
			table.insert(cuts, { m, m[1] * centre[1] + m[2] * centre[2] + m[3] * centre[3] + DIRT_ROUND })
		end
	end
	for corner, touching in cornerFaces do
		local sum, count = { 0, 0, 0 }, 0
		for i in touching do
			sum = { sum[1] + planes[i][1], sum[2] + planes[i][2], sum[3] + planes[i][3] }
			count += 1
		end
		if count >= 3 then
			local m = unit(sum[1], sum[2], sum[3])
			local v = points[corner]
			table.insert(cuts, { m, m[1] * v[1] + m[2] * v[2] + m[3] * v[3] - DIRT_ROUND * 0.6 })
		end
	end
	for _, cut in cuts do
		faces = carve(faces, cut[1], cut[2])
	end
	return faces
end

-- Round the dirt where it shows: which faces show is settled for every
-- solid first, so rounding one doesn't change what its neighbours see.
do
	local plans = {}
	for _, column in columns do
		for _, solid in column.solids do
			if not solid.dirt then
				continue
			end
			local others, shows = coverersOf(column, solid), {}
			for i, face in solid.faces do
				local whole = area(face)
				if whole > 1e-4 and not isFoot(face) then
					local open = 0
					for _, piece in exposed(face, others) do
						open += area(piece)
					end
					shows[i] = open > whole * 0.5
				end
			end
			table.insert(plans, { solid = solid, shows = shows })
		end
	end
	for _, plan in plans do
		plan.solid.faces = rounded(plan.solid.faces, plan.shows)
	end
end

-- The faces of every column's dirt or stone that show. Only what no other
-- solid covers is kept, another piece of its own column or a neighbour's,
-- so nothing lies buried inside the island. The flat top is left open: the
-- grass covers it.
local function visibleRock(dirt: boolean)
	local shown = {}
	for _, column in columns do
		for _, solid in column.solids do
			if solid.dirt ~= dirt then
				continue
			end
			local others = coverersOf(column, solid)
			for _, face in solid.faces do
				if isFoot(face) then
					continue
				end
				for _, piece in exposed(face, others) do
					table.insert(shown, piece)
				end
			end
		end
	end
	return shown
end

local dirtFaces = visibleRock(true)

-- A box around a centre, `r` from it each way, its faces wound outward.
local function boxAround(c, r)
	local x0, x1, y0, y1, z0, z1 = c[1] - r, c[1] + r, c[2] - r, c[2] + r, c[3] - r, c[3] + r
	return {
		{ { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 }, { x1, y0, z0 } },
		{ { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } },
		{ { x0, y0, z0 }, { x1, y0, z0 }, { x1, y0, z1 }, { x0, y0, z1 } },
		{ { x0, y1, z0 }, { x0, y1, z1 }, { x1, y1, z1 }, { x1, y1, z0 } },
		{ { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } },
		{ { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 }, { x1, y0, z1 } },
	}
end

-- The stones in the dirt, each as the faces that stand out of it. A stone
-- is a box turned at random and chipped at its corners, sunk into a dirt
-- face, and cut off at that face so nothing of it lies buried.
local pebbleSeed = 7
local function pebbleRandom(): number
	pebbleSeed = (pebbleSeed * 16807) % 2147483647
	return pebbleSeed / 2147483647
end
-- How far a point lies from the nearest edge of a face.
local function edgeDistance(face, p): number
	local nearest = math.huge
	for i, a in face do
		local b = face[i % #face + 1]
		local ab = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local length = ab[1] ^ 2 + ab[2] ^ 2 + ab[3] ^ 2
		local t = if length > 0 then math.clamp(((p[1] - a[1]) * ab[1] + (p[2] - a[2]) * ab[2] + (p[3] - a[3]) * ab[3]) / length, 0, 1) else 0
		local dx, dy, dz = p[1] - a[1] - ab[1] * t, p[2] - a[2] - ab[2] * t, p[3] - a[3] - ab[3] * t
		nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy + dz * dz))
	end
	return nearest
end

local pebbles = {}
-- Where cracks start: each stone's face, normal, centre on the dirt and how
-- far its rim reaches.
local crackOrigins = {}
-- Each stone as where it meets the dirt (point and outward normal, already
-- flipped) and how far it stands out, bucketed by 2-stud cell for its paint.
local pebbleCells = {}
local function pebbleCell(x: number, y: number, z: number): string
	return `{math.floor(x / 2)},{math.floor(y / 2)},{math.floor(z / 2)}`
end
for _, face in dirtFaces do
	local plane = planeOf(face)
	if not plane then
		continue
	end
	local n = { plane[1], plane[2], plane[3] }
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local triangle = area({ a, b, c })
		local depth = (a[3] + b[3] + c[3]) / 3
		local toward = math.clamp(depth / (islandDepth * DIRT_TRANSITION[1]), 0, 1)
		local density = STONE_BITS[1] + (STONE_BITS[2] - STONE_BITS[1]) * toward
		local count = math.floor(triangle * density + pebbleRandom())
		for _ = 1, count do
			local u, v = pebbleRandom(), pebbleRandom()
			if u + v > 1 then
				u, v = 1 - u, 1 - v
			end
			local p = {
				a[1] + (b[1] - a[1]) * u + (c[1] - a[1]) * v,
				a[2] + (b[2] - a[2]) * u + (c[2] - a[2]) * v,
				a[3] + (b[3] - a[3]) * u + (c[3] - a[3]) * v,
			}
			local size = STONE_BIT_SIZE[1] + (STONE_BIT_SIZE[2] - STONE_BIT_SIZE[1]) * pebbleRandom() ^ STONE_BIT_SKEW
			-- A stone too big for the room it has on its face is made smaller,
			-- so it never hangs off an edge.
			size = math.min(size, edgeDistance(face, p) * 2.2)
			local r = size / 2
			if p[3] < STONE_BIT_CLEAR or size < STONE_BIT_SIZE[1] * 0.8 then
				continue
			end
			local rise = STONE_BIT_RISE[1] + (STONE_BIT_RISE[2] - STONE_BIT_RISE[1]) * pebbleRandom()
			table.insert(crackOrigins, { face = face, normal = n, at = p, rim = r * 1.0 })
			local centre = { p[1] + n[1] * r * (2 * rise - 1), p[2] + n[2] * r * (2 * rise - 1), p[3] + n[3] * r * (2 * rise - 1) }
			-- A box turned at random: start big, and cut each side in to r.
			local x = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
			local y = cross(x, unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5))
			y = unit(y[1], y[2], y[3])
			local z = cross(x, y)
			local stone = boxAround(centre, size * 2)
			for _, axis in { x, y, z } do
				for _, sign in { 1, -1 } do
					local d = { axis[1] * sign, axis[2] * sign, axis[3] * sign }
					local reach = r * (0.75 + 0.35 * pebbleRandom())
					stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + reach)
				end
			end
			-- Chips knock its corners off.
			for _ = 1, 9 do
				local d = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
				stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + r * (0.65 + 0.25 * pebbleRandom()))
			end
			-- Cut off at the dirt: only what stands out of it is kept, and the
			-- cap the cut leaves lies against the dirt, so it goes too.
			local level = n[1] * p[1] + n[2] * p[2] + n[3] * p[3]
			stone = carve(stone, { -n[1], -n[2], -n[3] }, -level)
			local record = { point = { p[1], p[2], -p[3] }, normal = { n[1], n[2], -n[3] }, height = size * rise, reach = size }
			for cx = -1, 1 do
				for cy = -1, 1 do
					for cz = -1, 1 do
						local key = pebbleCell(p[1] + cx * 2, p[2] + cy * 2, -p[3] + cz * 2)
						pebbleCells[key] = pebbleCells[key] or {}
						table.insert(pebbleCells[key], record)
					end
				end
			end
			for _, piece in stone do
				local onDirt = true
				for _, q in piece do
					onDirt = onDirt and math.abs(n[1] * q[1] + n[2] * q[2] + n[3] * q[3] - level) < 1e-6
				end
				if not onDirt then
					table.insert(pebbles, piece)
				end
			end
		end
	end
end

-- The cracks, drawn over the dirt's coat as tapering brush strokes, one per
-- step of a crack (already flipped).
local crackStrokes = {}
local crackSeed = 3
local function crackRandom(): number
	crackSeed = (crackSeed * 16807) % 2147483647
	return crackSeed / 2147483647
end
-- Whether a point lies inside a convex face, `margin` studs in from its edges.
local function insideFace(face, n, p, margin: number): boolean
	for i, a in face do
		local b = face[i % #face + 1]
		local edge = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local inward = unit(table.unpack(cross(n, edge)))
		if (p[1] - a[1]) * inward[1] + (p[2] - a[2]) * inward[2] + (p[3] - a[3]) * inward[3] < margin then
			return false
		end
	end
	return true
end
-- A direction turned by `angle` about the face's normal.
local function turned(v, n, angle: number)
	local side = cross(n, v)
	local c, s = math.cos(angle), math.sin(angle)
	return { v[1] * c + side[1] * s, v[2] * c + side[2] * s, v[3] * c + side[3] * s }
end
-- A jagged line from `start` heading along `heading` in a face, stopping
-- short of its edges.
local function crackLine(face, n, start, heading, length: number)
	local points = { start }
	local step = length / CRACK_SEGMENTS
	local at, way = start, heading
	for _ = 1, CRACK_SEGMENTS do
		way = turned(way, n, (crackRandom() - 0.5) * 1.1)
		local nextAt = { at[1] + way[1] * step, at[2] + way[2] * step, at[3] + way[3] * step }
		if not insideFace(face, n, nextAt, 0.04 * DETAIL) then
			break
		end
		table.insert(points, nextAt)
		at = nextAt
	end
	return points
end
-- Lays a line down as a crack `width` wide at its start, thinning evenly
-- along its length to nothing at its end.
local function addCrack(points, normal, width: number)
	if #points < 2 then
		return
	end
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	local travelled = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		local widthA = width * (1 - travelled / total)
		local widthB = width * (1 - (travelled + length) / total)
		travelled += length
		local start = { a[1], a[2], -a[3] }
		local along = { (b[1] - a[1]) / length, (b[2] - a[2]) / length, -(b[3] - a[3]) / length }
		local facing = { normal[1], normal[2], -normal[3] }
		local function stroke(at, width: number, color)
			table.insert(crackStrokes, { start = at, along = along, normal = facing, length = length, width = width, tail = widthB / widthA, color = color })
		end
		-- The lip sits on the crack's lower side, half a crack's width over.
		local across = cross(facing, along)
		local side = if across[3] > 0 then -1 else 1
		local shift = widthA * 0.5 * side
		stroke({ start[1] + across[1] * shift, start[2] + across[2] * shift, start[3] + across[3] * shift }, widthA * 0.8, CRACK_LIP)
		stroke(start, widthA, CRACK)
		stroke(start, widthA * CRACK_CORE_WIDTH, CRACK_CORE)
	end
end

for _, origin in crackOrigins do
	if crackRandom() >= CRACK_CHANCE then
		continue
	end
	local face, n, at = origin.face, origin.normal, origin.at
	-- Some way across the face, to turn into each crack's heading.
	local first = face[1]
	local outward = unit(first[1] - at[1], first[2] - at[2], first[3] - at[3])
	for _ = 1, 1 + math.floor(crackRandom() * CRACKS) do
		local heading = turned(outward, n, crackRandom() * TAU)
		local start = { at[1] + heading[1] * origin.rim, at[2] + heading[2] * origin.rim, at[3] + heading[3] * origin.rim }
		if not insideFace(face, n, start, 0.04 * DETAIL) then
			continue
		end
		local length = CRACK_LENGTH[1] + (CRACK_LENGTH[2] - CRACK_LENGTH[1]) * crackRandom()
		local width = CRACK_WIDTH[1] + (CRACK_WIDTH[2] - CRACK_WIDTH[1]) * crackRandom()
		local line = crackLine(face, n, start, heading, length)
		addCrack(line, n, width)
		-- A fork off partway along, thinner and shorter.
		if #line >= 3 and crackRandom() < CRACK_BRANCH then
			local from = line[2]
			local share = 1 / (#line - 1)
			local away = unit(line[3][1] - from[1], line[3][2] - from[2], line[3][3] - from[3])
			local fork = turned(away, n, (if crackRandom() < 0.5 then -1 else 1) * (0.5 + 0.4 * crackRandom()))
			addCrack(crackLine(face, n, from, fork, length * 0.5), n, width * (1 - share) * 0.8)
		end
	end
end


-- The stones are grey, splotched like the rest and stained with the dirt
-- they sit in: solid at the dirt line, in blotches higher up.
local paintPebble = rusting(0.1, function(x, y, z)
	local tone, warm = splotchAt(x, y, z)
	local shade = 1 + tone * 1.5
	local r, g, b = PEBBLE[1], PEBBLE[2], PEBBLE[3]
	-- The stone this point is on: the nearest whose dirt line it sits above.
	local height, best = math.huge, math.huge
	for _, record in pebbleCells[pebbleCell(x, y, z)] or {} do
		local q, n = record.point, record.normal
		local dx, dy, dz = x - q[1], y - q[2], z - q[3]
		local distance = dx * dx + dy * dy + dz * dz
		if distance < record.reach * record.reach and distance < best then
			best = distance
			height = (dx * n[1] + dy * n[2] + dz * n[3]) / math.max(record.height, 0.05)
		end
	end
	if height < STONE_BIT_STAIN then
		local f = 2.2 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f)
		local stain = math.clamp((blot - height / STONE_BIT_STAIN) / 0.12, 0, 1)
		local dr, dg, db = soil(0.15 * stoneAt(x, y, z))
		r, g, b = r + (dr - r) * stain, g + (dg - g) * stain, b + (db - b) * stain
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Columns", nil, STONE, function(mesh)
	for _, piece in visibleRock(false) do
		addFlipped(mesh, piece)
	end
end, false, paintRock, true, EDGE_REACH)

chunkedPart("Dirt", nil, DIRT, function(mesh)
	for _, piece in dirtFaces do
		addFlipped(mesh, piece)
	end
end, nil, paintDirt, true, EDGE_REACH)

chunkedPart("Pebbles", nil, PEBBLE, function(mesh)
	for _, piece in pebbles do
		addFlipped(mesh, piece)
	end
end, false, paintPebble, true, EDGE_REACH)

-- The rim walked in even steps, each point pushed out from the stone by the
-- grass's outset (outer) and a hair's width (inner), with how deep the grass
-- hangs there.
local function grassRim()
	-- The rim the stones are trimmed to, walked clockwise seen from above
	-- in GRASS_STEP strides, so the grass follows it exactly.
	local points = {}
	local steps = math.ceil(TAU * RIM_PUSH * RADIUS * RIM_REACH * (1 + RIM_WOBBLE) / GRASS_STEP)
	for k = 0, steps - 1 do
		local angle = -k / steps * TAU
		local r = rimAt(angle)
		table.insert(points, { r * math.cos(angle), r * math.sin(angle) })
	end
	local count = #points

	-- Blurs a list of numbers round the loop: repeated passes of a 1-2-1
	-- average, each spreading it by half a step squared, until it spreads
	-- `studs`.
	local function blurLoop(values: { number }, studs: number)
		for _ = 1, math.round(2 * (studs / GRASS_STEP) ^ 2) do
			local before = table.clone(values)
			for i = 1, #values do
				values[i] = (before[(i - 2) % #values + 1] + 2 * before[i] + before[i % #values + 1]) / 4
			end
		end
	end
	local raw = table.clone(points)
	for axis = 1, 2 do
		local coordinates = {}
		for i, p in points do
			coordinates[i] = p[axis]
		end
		blurLoop(coordinates, GRASS_CORNER_BLUR)
		for i = 1, count do
			points[i] = table.clone(points[i])
			points[i][axis] = coordinates[i]
		end
	end
	-- Blurring cuts the outside corners in, uncovering the stone there, so
	-- the rim swells back out round each one: by the most it was cut in
	-- anywhere near, blurred so the swell has no edge of its own.
	local cut, outward = {}, {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		outward[i] = { -dy / length, dx / length }
		cut[i] = math.max(0, (raw[i][1] - p[1]) * outward[i][1] + (raw[i][2] - p[2]) * outward[i][2])
	end
	local reach = math.ceil(2 * GRASS_CORNER_BLUR / GRASS_STEP)
	local swell = {}
	for i = 1, count do
		local most = 0
		for k = -reach, reach do
			most = math.max(most, cut[(i + k - 1) % count + 1])
		end
		swell[i] = most
	end
	blurLoop(swell, GRASS_CORNER_BLUR)
	for i, p in points do
		p[1] += outward[i][1] * swell[i]
		p[2] += outward[i][2] * swell[i]
	end

	-- The lip wanders between its shallowest and deepest, and drips hang
	-- from it as rounded tongues, each overlapping the next.
	local along, travelled = {}, 0
	for i, p in points do
		along[i] = travelled
		local q = points[i % count + 1]
		travelled += math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
	end
	local function halfWidth(n)
		return (DRIP_WIDTH[1] + (DRIP_WIDTH[2] - DRIP_WIDTH[1]) * hash(n, 21)) / 2
	end
	local drips, at, n = {}, 0, 0
	while at < travelled do
		n += 1
		table.insert(drips, { at, halfWidth(n), DRIP_LENGTH[1] + (DRIP_LENGTH[2] - DRIP_LENGTH[1]) * hash(n, 22) })
		at += (halfWidth(n) + halfWidth(n + 1)) * (1 - DRIP_OVERLAP)
	end

	-- The outline is wound clockwise seen from above, so out is to the left
	-- of each step. A point's way out averages the steps either side of it.
	local rim = {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		local ox, oy = -dy / length, dx / length
		local s = along[i]
		local depth = GRASS_LIP[1] + (GRASS_LIP[2] - GRASS_LIP[1]) * (0.5 + 0.5 * math.noise(s * 0.3 / DETAIL, 3.7))
		for _, drip in drips do
			-- The distance round the rim either way, so drips near the
			-- start also reach the end.
			local gap = math.abs(s - drip[1])
			gap = math.min(gap, travelled - gap)
			if gap < drip[2] then
				depth = math.max(depth, GRASS_LIP[1] + drip[3] * math.sqrt(1 - (gap / drip[2]) ^ 2))
			end
		end
		-- The finer octave never lifts the edge above the stone's top.
		depth = math.max(depth + DRIP_DETAIL * math.noise(s * DRIP_DETAIL_FREQUENCY, 8.1), 0.15 * DETAIL)
		table.insert(rim, {
			outer = { p[1] + ox * GRASS_OUTSET, p[2] + oy * GRASS_OUTSET },
			out = { ox, oy },
			inner = { p[1] + ox * 0.02 * DETAIL, p[2] + oy * 0.02 * DETAIL },
			depth = depth,
		})
	end

	local depths = {}
	for i, point in rim do
		depths[i] = point.depth
	end
	blurLoop(depths, GRASS_DEPTH_BLUR)
	for i, point in rim do
		point.depth = depths[i]
	end

	-- Pushed out of a sharp inward notch, the outer line crosses itself; the
	-- loop it makes is cut away at the crossing.
	local function crossing(a, b, c, d)
		local rx, ry, sx, sy = b[1] - a[1], b[2] - a[2], d[1] - c[1], d[2] - c[2]
		local denominator = rx * sy - ry * sx
		if math.abs(denominator) < 1e-12 then
			return nil
		end
		local t = ((c[1] - a[1]) * sy - (c[2] - a[2]) * sx) / denominator
		local u = ((c[1] - a[1]) * ry - (c[2] - a[2]) * rx) / denominator
		if t <= 0 or t >= 1 or u <= 0 or u >= 1 then
			return nil
		end
		return { a[1] + rx * t, a[2] + ry * t }
	end
	local i = 1
	while i < #rim do
		for k = 2, 12 do
			local j = i + k
			if j + 1 > #rim then
				break
			end
			local hit = crossing(rim[i].outer, rim[i + 1].outer, rim[j].outer, rim[j + 1].outer)
			if hit then
				local kept = rim[i]
				for _ = i + 1, j do
					table.remove(rim, i + 1)
				end
				table.insert(rim, i + 1, { outer = hit, out = kept.out, inner = kept.inner, depth = kept.depth })
				break
			end
		end
		i += 1
	end
	return rim
end

-- How deep the deepest drip hangs, for the grass's shading.
local GRASS_DEEPEST = GRASS_LIP[1] + DRIP_LENGTH[2]

-- Grass is dead straw with olive patches, darkening down
-- the hanging edge toward the drip tips, and splotched like the stone.
local paintGrass = rusting(0, function(x, y, z)
	local shade = 1 - DRIP_SHADE * math.clamp(-z / GRASS_DEEPEST, 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	-- Patch strength from soft noise: 0 outside, 1 well inside a patch
	-- covering `cover` of the grass.
	local function patch(cover: number, seed: number): number
		local u, v = x / GRASS_PATCH_SIZE + seed, y / GRASS_PATCH_SIZE
		local n = 0.5 + math.noise(u, v, seed) + 0.3 * math.noise(u * 3, v * 3, seed + 5)
		return math.clamp((n - (1 - cover)) / 0.12, 0, 1)
	end
	local function toward(r, g, b, c, t)
		return r + (c[1] - r) * t, g + (c[2] - g) * t, b + (c[3] - b) * t
	end
	local r, g, b = toward(GRASS[1], GRASS[2], GRASS[3], GRASS_OLIVE, patch(GRASS_OLIVE_COVER, 11.3))
	-- The worn apron round what stands on the top.
	local outside = wornDistance(x, y)
	local wobble = 0.4 * APRON_WIDTH * math.noise(x * 0.3, y * 0.3, 71.3)
	local wear = math.clamp(1 - (outside + wobble) / APRON_WIDTH, 0, 1)
	if wear > 0 then
		local patchy = 0.5 + 0.6 * math.noise(x * 0.55, y * 0.55, 93.1)
		local worn = math.clamp((wear - 0.75 * (1 - patchy)) / 0.2, 0, 1)
		local grit = 0.9 + 0.2 * math.noise(x * 1.7, y * 1.7, 17.9)
		r, g, b = toward(r, g, b, { TRODDEN[1] * grit, TRODDEN[2] * grit, TRODDEN[3] * grit }, worn)
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Grass", nil, GRASS, function(mesh)
	local rim = grassRim()
	local count = #rim
	-- Corners of the turf: rings rounding over from its top edge (the first)
	-- down to its hanging edge (the last), rings curling the hanging edge's
	-- bottom under, the inner bottom of the hanging edge, and the inner edge
	-- where it meets the stone's top.
	local rings, curl, innerBottom, innerTop = {}, {}, {}, {}
	for k = 0, GRASS_ROUND_STEPS do
		rings[k], curl[k] = {}, {}
	end
	local outline = {}
	for i, point in rim do
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_ROUND * (1 - math.sin(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			rings[k][i] = mesh:vertex(x, y, GRASS_HEIGHT - GRASS_ROUND * (1 - math.cos(angle)))
			if k == 0 then
				outline[i] = { x, y }
			end
		end
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_BOTTOM_ROUND * (1 - math.cos(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			curl[k][i] = mesh:vertex(x, y, -point.depth + GRASS_BOTTOM_ROUND * (1 - math.sin(angle)))
		end
		innerBottom[i] = mesh:vertex(point.inner[1], point.inner[2], -point.depth)
		innerTop[i] = mesh:vertex(point.inner[1], point.inner[2], 0)
	end
	local top, edge = rings[0], rings[GRASS_ROUND_STEPS]
	for i = 1, count do
		local j = i % count + 1
		-- The rounded rim, ring by ring, facing out and up.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = rings[k - 1], rings[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Outside, facing out.
		local wallBottom, underEdge = curl[0], curl[GRASS_ROUND_STEPS]
		mesh:face({ wallBottom[j], wallBottom[i], edge[i] })
		mesh:face({ wallBottom[j], edge[i], edge[j] })
		-- The curl under, ring by ring, facing out and down.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = curl[k - 1], curl[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Underside, facing down.
		mesh:face({ underEdge[i], underEdge[j], innerBottom[j] })
		mesh:face({ underEdge[i], innerBottom[j], innerBottom[i] })
		-- Inside, facing the stone.
		mesh:face({ innerBottom[i], innerBottom[j], innerTop[j] })
		mesh:face({ innerBottom[i], innerTop[j], innerTop[i] })
	end
	-- The turf's top, facing up, cut into GRASS_TOP_CELL squares so no
	-- piece spans the island and the chunker can keep each texture small:
	-- the outline clipped to each square in turn, one edge at a time.
	local function clipped(points, axis: number, at: number, below: boolean)
		local kept = {}
		for i, a in points do
			local b = points[i % #points + 1]
			local aIn, bIn = (a[axis] <= at) == below, (b[axis] <= at) == below
			if aIn then
				table.insert(kept, a)
			end
			if aIn ~= bIn then
				local t = (at - a[axis]) / (b[axis] - a[axis])
				table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
			end
		end
		return kept
	end
	-- Outline corners keep their ring vertex, so the top meets the rounded
	-- edge without a seam.
	local cornerOf = {}
	for i, p in outline do
		cornerOf[p] = top[i]
	end
	local low, high = { math.huge, math.huge }, { -math.huge, -math.huge }
	for _, p in outline do
		for axis = 1, 2 do
			low[axis], high[axis] = math.min(low[axis], p[axis]), math.max(high[axis], p[axis])
		end
	end
	-- A piece is buried when every corner of it lies deep in the worn ground.
	local function buried(piece): boolean
		for _, p in piece do
			if wornDistance(p[1], p[2]) > -COVER_INSET then
				return false
			end
		end
		return true
	end
	for cx = math.floor(low[1] / GRASS_TOP_CELL), math.floor(high[1] / GRASS_TOP_CELL) do
		for cy = math.floor(low[2] / GRASS_TOP_CELL), math.floor(high[2] / GRASS_TOP_CELL) do
			local piece = clipped(outline, 1, cx * GRASS_TOP_CELL, false)
			piece = clipped(piece, 1, (cx + 1) * GRASS_TOP_CELL, true)
			piece = clipped(piece, 2, cy * GRASS_TOP_CELL, false)
			piece = clipped(piece, 2, (cy + 1) * GRASS_TOP_CELL, true)
			if #piece >= 3 and not buried(piece) then
				local corners = {}
				for i, p in piece do
					corners[i] = cornerOf[p] or mesh:vertex(p[1], p[2], GRASS_HEIGHT)
				end
				for _, t in earClip(piece) do
					mesh:face({ corners[t[3]], corners[t[2]], corners[t[1]] })
				end
			end
		end
	end
end, nil, paintGrass, true, EDGE_REACH)

-- The chunks are shaded here rather than by finishParts, which has no corner
-- taper: highlights run full width at a corner and thin toward the middle of
-- an edge, as finishParts would otherwise shade them. Chunks of the island
-- count as one surface, so their seams shade like any other edge.
local chunks = {}
for _, entry in parts do
	table.insert(chunks, entry.mesh)
end
for _, entry in parts do
	local group = {}
	for _, other in parts do
		if other ~= entry then
			table.insert(group, other.mesh)
		end
	end
	local kind = string.match(entry.name, "^%a+")
	local soft = kind == "Grass" or kind == "Dirt"
	entry.mesh:paintShading(entry.image, {
		highlight = if soft then EDGE_HIGHLIGHT * SOFT_SHADING else EDGE_HIGHLIGHT,
		shadow = if soft then CONTACT_SHADOW * SOFT_SHADING else CONTACT_SHADOW,
		gradient = GRADIENT,
		blend = EDGE_BLEND,
		group = group,
		name = entry.name,
		paint = entry.paint,
		-- The rock paint is cached under the item's key, since its code is not hashed.
		custom = entry.custom,
		salt = CACHE_KEY,
		rust = entry.rust * WEAR,
		reach = EDGE_REACH,
		highlightWidth = HIGHLIGHT_WIDTH,
		cornerTaper = CORNER_TAPER,
		heightRange = entry.heightRange,
		strokes = if string.sub(entry.name, 1, 4) == "Dirt" then crackStrokes else nil,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
end
buildKeys[buildHubSectionA] = "HubSectionA-aba92d994c6f0c69"
local function buildHubSectionB()
local CACHE_KEY = "HubSectionB-dd31c3a9342d2ebb"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Hub Section B: the middle stretch of the Scrap Line's hub, a rounded slab of
-- floating island from the shared column generator (shared/ColumnIsland.luau).
-- The hub is five of these in a row along x, overlapping at their ends.
local RADIUS = 56
local PEAK = 64
local SEED = 29
-- The rim is a rounded rectangle: at least HALF_LENGTH along the Line (x) and
-- HALF_WIDTH across it once the rim's wobble is taken off.
local RIM_WOBBLE = 0.05
local HALF_LENGTH, HALF_WIDTH = 58.5, 64.5
local function rimShape(angle: number): number
	local c, s = math.abs(math.cos(angle)) / HALF_LENGTH, math.abs(math.sin(angle)) / HALF_WIDTH
	return (c ^ 8 + s ^ 8) ^ (-1 / 8) / HALF_LENGTH
end
-- What stands on it (ServerMap.luau): the Line's paved deck, DECK_HALF either
-- side of the middle, running the section's whole length.
local DECK_HALF = 56.5
-- The deck buries the turf under it.
local COVER_INSET = 2
-- How far a point lies outside the deck.
local function wornDistance(x: number, y: number): number
	return math.abs(y) - DECK_HALF
end

-- Column Island: the generator for the map's floating islands, a mountain
-- of stone columns turned upside down, so a flat grassy top hangs over a
-- rocky cone that tapers to a point below. The columns, of every size and
-- shape, are packed edge to edge like cracked basalt; each hangs as deep as
-- the cone at its centre with a low faceted tip, so the underside steps down
-- in uneven tiers to the lowest point and a shallower shoulder. The columns
-- are the cells of a weighted Voronoi diagram (a power diagram) over
-- scattered stones, so big stones claim big cells. Stones grow from small
-- near the tip to big at the rim, and the big rim stones give the top its
-- lobed outline. Each column is carved, a few angled planes chiselling
-- chunks off its lower corners and edges. The model is built the mountain
-- way up (heights, summit, foot) and flipped as it is written out. Centered
-- on the origin, stone top at z = 0, turf GRASS_HEIGHT above it.
--
-- The item including this sets:
--   RADIUS        the island's radius;
--   PEAK          how far the cone hangs below the top;
--   SEED          which scatter of stones it gets;
--   wornDistance(x, y)  how far a point on the top lies outside the ground
--                 worn by what stands on it (math.huge where nothing does);
--                 the grass wears to dirt within about APRON_WIDTH of it;
--   COVER_INSET   turf lying more than this many studs inside the worn
--                 ground is buried under what stands there and left out
--                 (math.huge keeps it all);
--   RIM_WOBBLE    how far the rim swells and dips, as a share of its radius;
--   rimShape(angle)  how far out the rim stands at an angle, as a multiple
--                 of the round rim: 1 all round for a round island, never
--                 under 1, more toward the corners of a squarer one.
-- Stone sizes at the summit and at the foot, as shares of the radius, so
-- a bigger island has bigger stones rather than more of them.
local SMALLEST, LARGEST = 0.055 * RADIUS, 0.34 * RADIUS
-- Every other size in studs below was tuned on stones up to 4.5 studs
-- across and is multiplied by DETAIL, so an island with bigger stones looks
-- the same, only bigger: chips, slabs, cookie stones, cracks, rounding,
-- grass and the paint's blotches all grow with the stones.
local DETAIL = LARGEST / 4.5
-- The rim the columns are trimmed to: a circle of RIM_PUSH * RADIUS
-- swelling and dipping by up to RIM_WOBBLE of it in broad waves, so the top
-- is a dependable surface rather than sharp lobes and bays, and standing
-- rimShape times as far out at each angle. RIM_SIDES flat facets make it up,
-- so the rim stones end in cut faces.
local RIM_SIDES = 192
-- The rim stands RIM_PUSH times RADIUS out.
local RIM_PUSH = 1.1
-- The top tier of dirt, this deep under the grass, stays a clean wall
-- straight down from the rim the grass follows: chisel cuts, chips and bare
-- rock slabs all start below it.
local DIRT_CONFORM = 1.5 * DETAIL
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before they are trimmed to it.
local RIM_REACH = 1
for i = 0, RIM_SIDES - 1 do
	RIM_REACH = math.max(RIM_REACH, rimShape(i / RIM_SIDES * 2 * math.pi))
end
local SCATTER = RIM_PUSH * RADIUS * RIM_REACH + LARGEST
-- Shortest a column hangs, so the rim stones read as a thick slab; a
-- share of the radius like the stone sizes.
local MIN_LENGTH = 0.2 * RADIUS
-- Chisel cuts per column, at most, and how deep one bites as a share of
-- the stone's size.
local MAX_CUTS = 3
local CUT_DEPTH = { 0.2, 0.55 }
-- Fine chips per column (fewest, most) and how deep one bites, in studs.
local CHIPS = { 3, 6 }
local CHIP_DEPTH = { 0.15 * DETAIL, 0.45 * DETAIL }
-- How far a cut's heading may swing from straight out, in radians.
local CUT_SPREAD = math.rad(55)

local STONE = { 0.46, 0.45, 0.5 }
-- Under the grass the island is all dirt, until rocks start breaking
-- through it at the first share of the island's depth in DIRT_TRANSITION,
-- more and more of them going down, until from the second share it is all
-- rock. Each rock comes through the dirt at its own depth in that range. The
-- dirt's bottom edge is bevelled back DIRT_BEVEL studs on its outer side, so
-- the rock it sits on stands proud.
local DIRT = { 0.33, 0.24, 0.18 }
local DIRT_TRANSITION = { 0.2, 0.65 }
-- Where a rock comes through, the line between its dirt and its stone tilts
-- by up to DIRT_TILT radians, each rock its own way, so the line wanders
-- round the island instead of stepping level.
local DIRT_TILT = math.rad(25)
-- Above that, rock already shows through the dirt in slabs: a rock still
-- under dirt may have up to PATCHES slabs of its faces bare below tilted
-- lines, each facing out from the island's centre within PATCH_SPREAD
-- radians. The chance of each rises from nothing at PATCH_FROM of the depth
-- to certain at PATCH_FULL. A slab is PATCH_THICKNESS studs deep, its back
-- leaning in or out by up to PATCH_LEAN, and its top line tilted by up to
-- PATCH_TILT; PATCH_PEAKED of the slabs have a second top line, so the bare
-- rock comes up to a point through the dirt.
local PATCHES = 2
local PATCH_FROM = 0.04
local PATCH_FULL = 0.25
local PATCH_SPREAD = math.rad(45)
local PATCH_THICKNESS = { 0.4 * DETAIL, 1.4 * DETAIL }
local PATCH_LEAN = 0.5
local PATCH_TILT = 0.8
local PATCH_PEAKED = 0.6
-- The bare rock of a slab is chiselled into a rough stone: this many chips
-- (fewest, most), each biting this deep (studs) off its outer side at its
-- own angle, up to PATCH_CHIP_SPREAD radians off straight out.
local PATCH_CHIPS = { 4, 8 }
local PATCH_CHIP_DEPTH = { 0.3 * DETAIL, 0.8 * DETAIL }
local PATCH_CHIP_SPREAD = math.rad(65)
-- The colours blend too, over a wider share of the depth: dirt greys toward
-- stone and stone keeps a dirty tint across COLOR_TRANSITION, the line
-- wandering by COLOR_WOBBLE of the depth. At any depth the dirt stays
-- DIRT_LEAD further toward dirt than the stone, so the two still read apart.
local COLOR_TRANSITION = { 0.08, 0.55 }
local COLOR_WOBBLE = 0.06
local DIRT_LEAD = 0.45
-- Traces of dirt stay on the stone just under each rock's dirt line, as
-- patchy blotches thinning out over DIRT_TRACE studs below it. Bare rock
-- breaking through above the line keeps DIRT_DUSTING of them.
local DIRT_TRACE = 4 * DETAIL
local DIRT_DUSTING = 0.35
-- Grime and dead grey lichen crust the stone in patches, thickest where
-- the dirt gives way to rock and thinning out to nothing by GRIME_REACH of
-- the island's depth.
-- GRIME_COVER is the most of the stone it covers.
local GRIME = { 0.21, 0.22, 0.19 }
local GRIME_REACH = 0.8
local GRIME_COVER = 0.45

-- Small whole stones half sunk in the dirt, like crushed cookie in ice
-- cream: STONE_BITS of them per square stud of dirt near the top, rising to
-- the second number where the dirt gives way to rock. Each is STONE_BIT_SIZE
-- studs across, most of them small and a few big (STONE_BIT_SKEW over 1), a
-- chipped box, and stands out of the dirt by STONE_BIT_RISE
-- of its size. None sit within STONE_BIT_CLEAR studs of the top, under the
-- grass's lip. With bigger stones (DETAIL) they are bigger and sparser.
local PEBBLE = { 0.47, 0.46, 0.49 }
local STONE_BITS = { 0.035 / DETAIL ^ 2, 0.17 / DETAIL ^ 2 }
local STONE_BIT_SIZE = { 0.45 * DETAIL, 1.9 * DETAIL }
local STONE_BIT_SKEW = 2
local STONE_BIT_RISE = { 0.3, 0.4 }
local STONE_BIT_CLEAR = 1.2 * DETAIL
-- The stones are stained with dirt: solid where they come out of it,
-- breaking into blotches up to STONE_BIT_STAIN of their height.
local STONE_BIT_STAIN = 1.6

-- Drawn cracks in the dirt, running out from the stones sunk in it, as if
-- pushing them in split it: CRACK_CHANCE of the stones have them, up to
-- CRACKS each, CRACK_LENGTH studs long in CRACK_SEGMENTS jagged steps,
-- CRACK_WIDTH wide at the stone and thinning steadily to nothing at its end.
-- CRACK_BRANCH of the cracks fork once.
local CRACK = { 0.17, 0.12, 0.08 }
-- Each crack is drawn in depth: a pale lip where light catches its lower
-- edge (CRACK_LIP), the crack over it, and a darker core down its middle
-- (CRACK_CORE, CRACK_CORE_WIDTH of the crack's width).
local CRACK_LIP = { 0.66, 0.53, 0.4 }
local CRACK_CORE = { 0.06, 0.04, 0.03 }
local CRACK_CORE_WIDTH = 0.45
local CRACK_CHANCE = 1
local CRACKS = 3
local CRACK_LENGTH = { 0.6 * DETAIL, 1.8 * DETAIL }
local CRACK_SEGMENTS = 4
local CRACK_WIDTH = { 0.1 * DETAIL, 0.18 * DETAIL }
local CRACK_BRANCH = 0.4
local DIRT_BEVEL = { 0.3 * DETAIL, 0.6 * DETAIL }
-- How steeply each rock's bevel slants, in radians up from flat; each rock
-- takes its own angle in this range, so the bevels don't all match.
local DIRT_BEVEL_LIFT = { math.rad(25), math.rad(65) }
-- The dirt's outer edges and corners are rounded off on this radius, each
-- edge in this many facets, so it reads soft rather than jagged.
local DIRT_ROUND = 0.6 * DETAIL
local DIRT_ROUND_STEPS = 4
-- Each rock shades from STONE times the first where it meets the top to
-- STONE times the second at its tip.
local ROCK_GRADIENT = { 1.1, 0.6 }
-- Brush splotches in the stone: one may sit in each cell of a 3D grid
-- (`cell` studs, with `chance`), a lobed blot `radius` studs across that
-- shifts the stone's tone by up to `tone` and its tint by up to `tint`. The
-- coat's brush strokes lay them on as dabs.
local SPLOTCH = { cell = 1.8 * DETAIL, chance = 1, radius = { DETAIL, 2 * DETAIL }, tone = 0.1, tint = 0.02 }
-- Texture pixels per stud; chunks are 1024 texels across at this density.
local TEXEL_DENSITY = 16
-- Edge highlights: how far edge paint reaches from an edge, in studs, and how
-- many times wider than the default the highlight strokes are.
local EDGE_REACH = DETAIL
local HIGHLIGHT_WIDTH = 4
-- Studs over which a highlight thins from full width at a corner.
local CORNER_TAPER = 0.5 * DETAIL
-- Grass and dirt are soft, so their edge highlights and contact shadows run
-- at this share of the stone's.
local SOFT_SHADING = 0.12

-- Grass over the top: a turf slab GRASS_HEIGHT thick, pushed GRASS_OUTSET
-- past the rim, whose edge hangs down as a lip (shallowest and deepest, in
-- studs) hung all along with tongues of grass dripping further down, each
-- DRIP_WIDTH across and DRIP_LENGTH below the lip. Neighbouring drips
-- overlap by DRIP_OVERLAP of their widths, so the edge runs as one
-- unbroken wave with no flat stretch between drips.
local GRASS = { 0.74, 0.63, 0.4 }
local GRASS_HEIGHT = 0.45 * DETAIL
local GRASS_OUTSET = 0.25 * DETAIL
local GRASS_LIP = { 0.3 * DETAIL, 0.6 * DETAIL }
local DRIP_WIDTH = { 1.6 * DETAIL, 4 * DETAIL }
local DRIP_LENGTH = { 0.3 * DETAIL, 1.1 * DETAIL }
local DRIP_OVERLAP = 0.35
-- A finer octave of wobble over the wave: how far it moves the edge up or
-- down, in studs, and how fast it changes along the rim.
local DRIP_DETAIL = 0.3 * DETAIL
local DRIP_DETAIL_FREQUENCY = 1.1 / DETAIL
-- Spacing of the points the rim is walked in, in studs.
local GRASS_STEP = 0.25 * DETAIL
-- The turf's top rolls over into its hanging edge on a quarter circle this
-- many studs across, in this many facets.
local GRASS_ROUND = 0.42 * DETAIL
local GRASS_ROUND_STEPS = 4
-- The hanging edge's bottom curls under into its underside on this radius.
local GRASS_BOTTOM_ROUND = 0.2 * DETAIL
-- The rim's corners in plan are rounded off by blurring its outline over
-- about this many studs, just enough to soften each stone's jog while the
-- grass still follows the stones, pushed out GRASS_OUTSET past them. The drips' depth is
-- blurred over GRASS_DEPTH_BLUR studs, so neighbouring tongues meet in soft
-- dips rather than sharp notches.
local GRASS_CORNER_BLUR = 0.2 * DETAIL
local GRASS_DEPTH_BLUR = 0.3 * DETAIL
-- The turf's flat top is cut into squares this many studs across, to keep
-- its texture chunks small; this one doesn't grow with DETAIL.
local GRASS_TOP_CELL = 8
-- How much the grass darkens toward the tip of the deepest drip.
local DRIP_SHADE = 0.35
-- The grass is dead: straw GRASS drifting into a dull olive where a little
-- life hangs on (GRASS_OLIVE_COVER of it), in soft noise patches this many
-- studs across.
local GRASS_OLIVE = { 0.6, 0.57, 0.35 }
local GRASS_OLIVE_COVER = 0.3
local GRASS_PATCH_SIZE = 6 * DETAIL
-- Within about APRON_WIDTH studs of what stands on the top (wornDistance)
-- the grass is worn down to TRODDEN dirt and gravel, in patches toward the
-- outside. These follow what stands there, not the stones, so DETAIL leaves
-- them alone.
local APRON_WIDTH = 6
local TRODDEN = { 0.47, 0.4, 0.31 }

-- Fixed per-column jitter, so the columns look uneven but every build matches.
local function hash(i: number, j: number): number
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
end

local seed = SEED
local function random(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

-- Height of the slope at a point: the main cone, ridges running down from
-- the summit, and a lower shoulder peak off to one side. The cone is
-- rounded BOWL of the way toward a dome, so the underside reads as a
-- shallow bowl rather than a spike under a flat shelf.
local BOWL = 0.4
local function heightAt(x: number, y: number): number
	local r = math.sqrt(x * x + y * y) / RADIUS
	local angle = math.atan2(y, x)
	local ridges = 1 + 0.12 * math.cos(angle * 5) * r
	local out = math.min(r * ridges, 1)
	local cone = (1 - out) ^ 1.25
	local dome = math.sqrt(1 - out * out)
	local main = PEAK * (cone + (dome - cone) * BOWL)
	local sx, sy = x - 8, y + 5
	local shoulder = 19 * math.max(0, 1 - math.sqrt(sx * sx + sy * sy) / 11) ^ 1.1
	return math.max(main, shoulder)
end

-- The rim's radius at an angle.
local function rimAt(angle: number): number
	local phase = SEED * 1.7
	local wave = 0.5 * math.sin(2 * angle + phase) + 0.3 * math.sin(3 * angle + 2 * phase) + 0.2 * math.sin(5 * angle + 3 * phase)
	return RIM_PUSH * RADIUS * rimShape(angle) * (1 + RIM_WOBBLE * wave)
end

-- Stones scattered by dart throwing, none crowding another, sized by how
-- high on the slope they sit: x, y and size.
local stones = {}
for _ = 1, 8000 do
	local angle, reach = random() * TAU, math.sqrt(random()) * SCATTER
	local x, y = reach * math.cos(angle), reach * math.sin(angle)
	local height = math.clamp(heightAt(x, y) / PEAK, 0, 1)
	local size = (LARGEST + (SMALLEST - LARGEST) * height ^ 0.5) * (0.8 + 0.4 * random())
	local clear = true
	for _, other in stones do
		local dx, dy = x - other[1], y - other[2]
		if dx * dx + dy * dy < ((size + other[3]) * 0.72) ^ 2 then
			clear = false
			break
		end
	end
	if clear then
		table.insert(stones, { x, y, size })
	end
end

-- Cuts a cell outline down to the side of stone q's boundary nearer stone
-- p. Each corner carries the stone across the edge that starts there (nil
-- on the outer rim), so walls can find their neighbour.
local function clip(outline, p, q, neighbour)
	local nx, ny = q[1] - p[1], q[2] - p[2]
	local limit = (q[1] ^ 2 + q[2] ^ 2 - p[1] ^ 2 - p[2] ^ 2 - q[3] ^ 2 + p[3] ^ 2) / 2
	local function side(point)
		return point[1] * nx + point[2] * ny - limit
	end
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = side(a), side(b)
		local crossing = if (sa <= 0) ~= (sb <= 0)
			then { a[1] + (b[1] - a[1]) * sa / (sa - sb), a[2] + (b[2] - a[2]) * sa / (sa - sb) }
			else nil
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
			if crossing then
				table.insert(kept, { crossing[1], crossing[2], neighbour })
			end
		elseif crossing then
			table.insert(kept, { crossing[1], crossing[2], a[3] })
		end
	end
	return kept
end

-- The rim's corners, then each of its sides as a plane n . p <= limit,
-- in order round from angle 0.
local rimSides = {}
do
	local rim = {}
	for i = 0, RIM_SIDES - 1 do
		local angle = i / RIM_SIDES * TAU
		local r = rimAt(angle)
		rim[i + 1] = { r * math.cos(angle), r * math.sin(angle) }
	end
	for i, a in rim do
		local b = rim[i % #rim + 1]
		-- Counter-clockwise, so out is to the right of each side.
		local nx, ny = b[2] - a[2], a[1] - b[1]
		table.insert(rimSides, { nx, ny, nx * a[1] + ny * a[2] })
	end
end

-- Cuts a cell outline down to the inside of one rim side; corners where it
-- crosses carry nil, as on the outer rim.
local function clipToRim(outline, side)
	local nx, ny, limit = side[1], side[2], side[3]
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = a[1] * nx + a[2] * ny - limit, b[1] * nx + b[2] * ny - limit
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
		end
		if (sa <= 0) ~= (sb <= 0) then
			local t = sa / (sa - sb)
			table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, if sa <= 0 then nil else a[3] })
		end
	end
	return kept
end

-- Each stone's column: its outline and its top corners on a slanted plane.
local columns = {}
for index, stone in stones do
	local outline = {}
	for i = 0, 31 do
		local angle = i / 32 * TAU
		table.insert(outline, { SCATTER * math.cos(angle), SCATTER * math.sin(angle), nil })
	end
	for other, neighbour in stones do
		if other ~= index and #outline >= 3 then
			local dx, dy = neighbour[1] - stone[1], neighbour[2] - stone[2]
			if dx * dx + dy * dy < (LARGEST * 3) ^ 2 then
				outline = clip(outline, stone, neighbour, other)
			end
		end
	end
	-- Every cell is trimmed to the rim sides it faces (the rim isn't convex,
	-- so the far sides would cut into its swells); those left with nothing
	-- inside the rim are dropped. A cell's sides are those over the angles
	-- its corners span, and a few either way so neighbours trim alike.
	local low, high, farthest = math.huge, -math.huge, 0
	local heading = math.atan2(stone[2], stone[1])
	for _, corner in outline do
		local offset = (math.atan2(corner[2], corner[1]) - heading + math.pi) % TAU - math.pi
		low, high = math.min(low, offset), math.max(high, offset)
		farthest = math.max(farthest, math.sqrt(corner[1] ^ 2 + corner[2] ^ 2))
	end
	if farthest > RIM_PUSH * RADIUS * (1 - RIM_WOBBLE) then
		local first = math.floor((heading + low) / TAU * RIM_SIDES) - 8
		local last = math.ceil((heading + high) / TAU * RIM_SIDES) + 8
		for k = first, last do
			if #outline < 3 then
				break
			end
			outline = clipToRim(outline, rimSides[k % RIM_SIDES + 1])
		end
	end
	local area = 0
	for i, a in outline do
		local b = outline[i % #outline + 1]
		area += (a[1] * b[2] - b[1] * a[2]) / 2
	end
	-- Only cells the rim leaves nothing of are dropped; a small one kept at
	-- the rim fills its stretch so the edge doesn't notch.
	if #outline < 3 or math.abs(area) < 1e-3 then
		continue
	end
	local cx, cy = 0, 0
	for _, corner in outline do
		cx, cy = cx + corner[1] / #outline, cy + corner[2] / #outline
	end
	local rise = math.max(MIN_LENGTH * (0.8 + 0.4 * hash(index, 5)), heightAt(cx, cy) + (hash(index, 1) - 0.5) * (1 + stone[3]))
	local tiltX, tiltY = (hash(index, 2) - 0.5) * 0.45, (hash(index, 3) - 0.5) * 0.45
	local corners = {}
	-- Neighbouring columns share their edges exactly, so no gap opens
	-- between them.
	for i, corner in outline do
		local z = rise + (corner[1] - cx) * tiltX + (corner[2] - cy) * tiltY
		corners[i] = { corner[1], corner[2], z, corner[3] }
	end
	columns[index] = {
		index = index,
		size = stone[3],
		corners = corners,
		-- The top rises to a low ridge point, so it reads as broken stone.
		peak = { cx, cy, rise + 0.15 * stone[3] * (0.5 + hash(index, 4)) },
	}
end

-- A column as a closed solid: faces as lists of points, wound outward,
-- from the foot (z = 0) up to its slanted top and the low point above it.
local function solidOf(column)
	local bottom = 0
	local corners, peak = column.corners, column.peak
	local count = #corners
	local faces = {}
	local base = {}
	for i = count, 1, -1 do
		table.insert(base, { corners[i][1], corners[i][2], bottom })
	end
	table.insert(faces, base)
	for i = 1, count do
		local a, b = corners[i], corners[i % count + 1]
		table.insert(faces, { { a[1], a[2], bottom }, { b[1], b[2], bottom }, { b[1], b[2], b[3] }, { a[1], a[2], a[3] } })
		table.insert(faces, { { peak[1], peak[2], peak[3] }, { a[1], a[2], a[3] }, { b[1], b[2], b[3] } })
	end
	return faces
end

-- Cuts away everything on the far side of the plane n . p = d, closing the
-- wound with a cap facing along n.
local function carve(faces, n, d)
	local kept, cut = {}, {}
	for _, face in faces do
		local out = {}
		for i, a in face do
			local b = face[i % #face + 1]
			local sa = a[1] * n[1] + a[2] * n[2] + a[3] * n[3] - d
			local sb = b[1] * n[1] + b[2] * n[2] + b[3] * n[3] - d
			if sa <= 0 then
				table.insert(out, a)
			end
			if (sa <= 0) ~= (sb <= 0) then
				local t = sa / (sa - sb)
				local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
				table.insert(out, p)
				table.insert(cut, p)
			end
		end
		if #out >= 3 then
			table.insert(kept, out)
		end
	end
	if #cut < 3 then
		return kept
	end
	-- The cap's corners, sorted round their centre in the plane.
	local mx, my, mz = 0, 0, 0
	for _, p in cut do
		mx, my, mz = mx + p[1] / #cut, my + p[2] / #cut, mz + p[3] / #cut
	end
	local ux, uy, uz = if math.abs(n[3]) < 0.9 then -n[2] else 0, if math.abs(n[3]) < 0.9 then n[1] else -n[3], if math.abs(n[3]) < 0.9 then 0 else n[2]
	local length = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / length, uy / length, uz / length
	local vx, vy, vz = n[2] * uz - n[3] * uy, n[3] * ux - n[1] * uz, n[1] * uy - n[2] * ux
	local cap = {}
	for _, p in cut do
		local ox, oy, oz = p[1] - mx, p[2] - my, p[3] - mz
		local angle = math.atan2(ox * vx + oy * vy + oz * vz, ox * ux + oy * uy + oz * uz)
		local duplicate = false
		for _, other in cap do
			duplicate = duplicate or math.abs(other[2] - angle) < 1e-4
		end
		if not duplicate then
			table.insert(cap, { p, angle })
		end
	end
	table.sort(cap, function(a, b)
		return a[2] < b[2]
	end)
	if #cap >= 3 then
		local face = {}
		for i, entry in cap do
			face[i] = entry[1]
		end
		table.insert(kept, face)
	end
	return kept
end

-- Carve every column first, so walls can be cut against their
-- neighbours' finished shapes.
for _, column in columns do
	local corners, index = column.corners, column.index
	local faces = solidOf(column)
	local outward = math.atan2(column.peak[2], column.peak[1])

	-- Chisel cuts: each faces out and up at its own angle, from a low
	-- slant (shaving a side edge) to steep (bevelling the top), and
	-- bites a set depth in from the farthest point along it. None is
	-- near level, which would open holes down between columns. Every cut
	-- faces away from the island's centre, within CUT_SPREAD either side,
	-- so the carving shows on the outside and never faces inward.
	-- The cuts to make: heading, lift and depth. The big chisel cuts come
	-- first, then fine chips that knock small corners off what is left.
	local cuts = {}
	for k = 1, 1 + math.floor(hash(index, 40) * MAX_CUTS) do
		table.insert(cuts, {
			outward + (hash(index, 40 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 50 + k) * 0.85,
			column.size * (CUT_DEPTH[1] + (CUT_DEPTH[2] - CUT_DEPTH[1]) * hash(index, 60 + k)),
		})
	end
	for k = 1, CHIPS[1] + math.floor(hash(index, 70) * (CHIPS[2] - CHIPS[1] + 1)) do
		table.insert(cuts, {
			outward + (hash(index, 70 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 80 + k) * 1.05,
			CHIP_DEPTH[1] + (CHIP_DEPTH[2] - CHIP_DEPTH[1]) * hash(index, 90 + k),
		})
	end
	for _, cut in cuts do
		local heading, lift, depth = cut[1], cut[2], cut[3]
		local n = { math.cos(heading) * math.cos(lift), math.sin(heading) * math.cos(lift), math.sin(lift) }
		local farthest = -math.huge
		for _, face in faces do
			for _, p in face do
				farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
			end
		end
		-- A cut stops short of the top tier, which follows the grass, so
		-- the wall under the grass is never carved into.
		local tiermost = -math.huge
		for _, corner in corners do
			tiermost = math.max(tiermost, corner[1] * n[1] + corner[2] * n[2] + DIRT_CONFORM * n[3])
		end
		local plane = math.max(farthest - depth, tiermost + 0.3)
		if plane < farthest then
			faces = carve(faces, n, plane)
		end
	end

	column.faces = faces

	-- Where the column's carved underside begins: the shallowest point of
	-- any face that isn't a side wall or its foot.
	column.surfaceFrom = math.huge
	for _, face in faces do
		local foot, nz = true, 0
		for i, p in face do
			local q = face[i % #face + 1]
			foot = foot and p[3] == 0
			nz += (p[1] - q[1]) * (p[2] + q[2])
		end
		if not foot and math.abs(nz) > 1e-3 then
			for _, p in face do
				column.surfaceFrom = math.min(column.surfaceFrom, p[3])
			end
		end
	end
end

-- How deep each column hides behind the tier around it: it comes into view
-- where its shallowest neighbour's underside begins, or at the top if it
-- faces the open edge.
for _, column in columns do
	column.shownFrom = math.huge
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		column.shownFrom = math.min(column.shownFrom, if neighbour then neighbour.surfaceFrom else 0)
	end
end

-- How deep the island hangs at its lowest point.
local islandDepth = 0
for _, column in columns do
	islandDepth = math.max(islandDepth, column.peak[3])
end

-- How far a solid reaches along a direction.
local function farthestAlong(faces, n): number
	local farthest = -math.huge
	for _, face in faces do
		for _, p in face do
			farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
		end
	end
	return farthest
end

-- Cuts a solid's outer bottom edge off, `depth` studs in along a slant facing
-- out from the island's centre and down, `lift` radians up from flat.
local function bevelled(faces, outward: number, depth: number, lift: number)
	local n = { math.cos(outward) * math.cos(lift), math.sin(outward) * math.cos(lift), math.sin(lift) }
	return carve(faces, n, farthestAlong(faces, n) - depth)
end

-- Each rock is dirt down to where it comes through, and stone below, split
-- into a dirt solid and a stone one. The dirt's outer bottom edge is
-- bevelled off, so the stone under it stands proud. Higher up, a patch of a
-- rock's outer face may already show through: the dirt is split into the
-- slab on its outer face and the rest, and the slab into bare stone below a
-- tilted line and dirt above, bevelled like the rest.
for _, column in columns do
	local index, faces = column.index, column.faces
	local share = DIRT_TRANSITION[1] + (DIRT_TRANSITION[2] - DIRT_TRANSITION[1]) * hash(index, 30)
	local dirtLine = islandDepth * share
	column.dirtLine = dirtLine
	if dirtLine <= column.shownFrom then
		column.solids = { { faces = faces, dirt = false } }
		continue
	end
	local shown = column.shownFrom
	local outward = math.atan2(column.peak[2], column.peak[1])
	local bevel = DIRT_BEVEL[1] + (DIRT_BEVEL[2] - DIRT_BEVEL[1]) * hash(index, 31)
	local lift = DIRT_BEVEL_LIFT[1] + (DIRT_BEVEL_LIFT[2] - DIRT_BEVEL_LIFT[1]) * hash(index, 34)
	-- The tilted line passes through dirtLine under the rock's tip.
	local tilt, heading = DIRT_TILT * hash(index, 32), hash(index, 33) * 2 * math.pi
	local down = { math.sin(tilt) * math.cos(heading), math.sin(tilt) * math.sin(heading), math.cos(tilt) }
	local line = down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * dirtLine
	local dirt = bevelled(carve(faces, down, line), outward, bevel, lift)
	local stone = carve(faces, { -down[1], -down[2], -down[3] }, -line)
	column.solids = { { faces = dirt, dirt = true }, { faces = stone, dirt = false } }
	-- The stone shows from below the dirt.
	column.shownFrom = math.min(dirtLine, column.peak[3])

	local middle = (shown + dirtLine) / 2 / islandDepth
	local chance = math.clamp((middle - PATCH_FROM) / (PATCH_FULL - PATCH_FROM), 0, 1)
	if dirtLine - shown <= 1 then
		continue
	end
	-- Each slab is cut from the dirt left after the last, so they sit side
	-- by side round the rock.
	local rest, solids = dirt, { { faces = stone, dirt = false } }
	for k = 1, PATCHES do
		if hash(index, 204 + k * 10) >= chance then
			continue
		end
		local heading = outward + (hash(index, 205 + k * 10) - 0.5) * 2 * PATCH_SPREAD
		local lean = (hash(index, 300 + k * 10) - 0.5) * 2 * PATCH_LEAN
		local size = math.sqrt(1 + lean * lean)
		local across = { math.cos(heading) / size, math.sin(heading) / size, lean / size }
		local thickness = PATCH_THICKNESS[1] + (PATCH_THICKNESS[2] - PATCH_THICKNESS[1]) * hash(index, 206 + k * 10)
		local face = farthestAlong(rest, across) - thickness
		local slab = carve(rest, { -across[1], -across[2], -across[3] }, -face)
		rest = carve(rest, across, face)
		-- The slab's top line, tilted, somewhere down what shows of the rock:
		-- above it dirt, below it bare rock.
		local function topLine(seed: number)
			local top = shown + (dirtLine - shown) * (0.05 + 0.45 * hash(index, seed))
			local tx = (hash(index, seed + 1) - 0.5) * 2 * PATCH_TILT
			local ty = (hash(index, seed + 2) - 0.5) * 2 * PATCH_TILT
			local length = math.sqrt(tx * tx + ty * ty + 1)
			local down = { tx / length, ty / length, 1 / length }
			-- Never above the top tier anywhere across the slab.
			local level = -math.huge
			for _, f in slab do
				for _, p in f do
					level = math.max(level, down[1] * p[1] + down[2] * p[2] + down[3] * DIRT_CONFORM)
				end
			end
			return down, math.max(down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * top, level)
		end
		local down, line = topLine(207 + k * 10)
		table.insert(solids, { faces = bevelled(carve(slab, down, line), heading, bevel * 0.7, lift), dirt = true })
		local bare = carve(slab, { -down[1], -down[2], -down[3] }, -line)
		-- A second line peaks the rock: the dirt it cuts off stays dirt.
		if hash(index, 320 + k * 10) < PATCH_PEAKED then
			local second, secondLine = topLine(330 + k * 10)
			table.insert(solids, { faces = bevelled(carve(bare, second, secondLine), heading, bevel * 0.7, lift), dirt = true })
			bare = carve(bare, { -second[1], -second[2], -second[3] }, -secondLine)
		end
		-- Chipped into a rough stone rather than a flat slab.
		local chips = PATCH_CHIPS[1] + math.floor(hash(index, 400 + k * 10) * (PATCH_CHIPS[2] - PATCH_CHIPS[1] + 1))
		for c = 1, chips do
			local seed = 500 + k * 100 + c * 7
			local yaw = heading + (hash(index, seed) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local pitch = (hash(index, seed + 1) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local n = { math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch) }
			local depth = PATCH_CHIP_DEPTH[1] + (PATCH_CHIP_DEPTH[2] - PATCH_CHIP_DEPTH[1]) * hash(index, seed + 2)
			local plane = farthestAlong(bare, n) - depth
			if plane > -math.huge then
				bare = carve(bare, n, plane)
			end
		end
		table.insert(solids, { faces = bare, dirt = false })
	end
	table.insert(solids, { faces = rest, dirt = true })
	column.solids = solids
end

-- Each face's plane, as a unit normal pointing out and its distance.
local function planeOf(face)
	local nx, ny, nz = 0, 0, 0
	for i, a in face do
		local b = face[i % #face + 1]
		nx += (a[2] - b[2]) * (a[3] + b[3])
		ny += (a[3] - b[3]) * (a[1] + b[1])
		nz += (a[1] - b[1]) * (a[2] + b[2])
	end
	local length = math.sqrt(nx * nx + ny * ny + nz * nz)
	if length < 1e-9 then
		return nil
	end
	nx, ny, nz = nx / length, ny / length, nz / length
	local p = face[1]
	return { nx, ny, nz, nx * p[1] + ny * p[2] + nz * p[3] }
end

-- Splits a face by a plane into the part outside it and the part inside.
local EPSILON = 1e-5
local function split(face, plane)
	local outside, inside = {}, {}
	local function side(p)
		local s = plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
		return if math.abs(s) < EPSILON then 0 else s
	end
	for i, a in face do
		local b = face[i % #face + 1]
		local sa, sb = side(a), side(b)
		if sa >= 0 then
			table.insert(outside, a)
		end
		if sa <= 0 then
			table.insert(inside, a)
		end
		if (sa > 0 and sb < 0) or (sa < 0 and sb > 0) then
			local t = sa / (sa - sb)
			local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
			table.insert(outside, p)
			table.insert(inside, p)
		end
	end
	return outside, inside
end

local function area(face): number
	local plane = planeOf(face)
	if not plane or #face < 3 then
		return 0
	end
	local total = 0
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
		total += ((uy * vz - uz * vy) * plane[1] + (uz * vx - ux * vz) * plane[2] + (ux * vy - uy * vx) * plane[3]) / 2
	end
	return total
end

-- The parts of a face that don't lie inside a neighbour. Only a face lying
-- against one of the neighbour's own faces can touch it; that face's plane
-- is skipped, and the face is carved by the rest, every piece that falls
-- outside one of them showing.
local function uncovered(face, neighbour)
	local own = planeOf(face)
	if not own then
		return {}
	end
	local touching, planes = false, {}
	for _, other in neighbour.faces do
		local plane = planeOf(other)
		if plane then
			local facing = own[1] * plane[1] + own[2] * plane[2] + own[3] * plane[3] < -0.9999
			local p = face[1]
			if facing and math.abs(plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]) < 1e-4 then
				touching = true
			else
				table.insert(planes, plane)
			end
		end
	end
	if not touching then
		return { face }
	end
	local shown, rest = {}, face
	for _, plane in planes do
		local outside, inside = split(rest, plane)
		if #outside >= 3 and area(outside) > 1e-4 then
			table.insert(shown, outside)
		end
		rest = inside
		if #rest < 3 or area(rest) <= 1e-4 then
			break
		end
	end
	return shown
end

-- Columns bucketed by the 2-stud cells their outlines cover, so paint can
-- find the rock under a point without testing them all.
local CELL = 2
local cells = {}
for _, column in columns do
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, corner in column.corners do
		x0, y0 = math.min(x0, corner[1]), math.min(y0, corner[2])
		x1, y1 = math.max(x1, corner[1]), math.max(y1, corner[2])
	end
	for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
		for cy = math.floor(y0 / CELL), math.floor(y1 / CELL) do
			local cellKey = `{cx},{cy}`
			cells[cellKey] = cells[cellKey] or {}
			table.insert(cells[cellKey], column)
		end
	end
end

-- The rock a point on the island belongs to. On a wall two rocks share,
-- the deeper one owns it, since only its wall shows there.
local function rockAt(x: number, y: number)
	local found = nil
	for _, column in cells[`{math.floor(x / CELL)},{math.floor(y / CELL)}`] or {} do
		local corners, within = column.corners, true
		for i, a in corners do
			local b = corners[i % #corners + 1]
			if (b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1]) < -1e-3 then
				within = false
				break
			end
		end
		if within and (found == nil or column.peak[3] > found.peak[3]) then
			found = column
		end
	end
	return found
end

-- The splotch on top at a point, as its tone and warmth shifts (0, 0 where
-- none reaches). Of the splotches covering a point, the one laid last wins.
local function splotchAt(x: number, y: number, z: number): (number, number)
	local size = SPLOTCH.cell
	local gx, gy, gz = math.floor(x / size), math.floor(y / size), math.floor(z / size)
	local tone, warm, order = 0, 0, -1
	for i = gx - 1, gx + 1 do
		for j = gy - 1, gy + 1 do
			for k = gz - 1, gz + 1 do
				local seed = i * 7.31 + k * 3.17
				if hash(seed, j + 101) < SPLOTCH.chance then
					local cx = (i + hash(seed, j + 201)) * size
					local cy = (j + hash(seed, j + 301)) * size
					local cz = (k + hash(seed, j + 401)) * size
					local radius = SPLOTCH.radius[1] + (SPLOTCH.radius[2] - SPLOTCH.radius[1]) * hash(seed, j + 501)
					local dx, dy, dz = x - cx, y - cy, z - cz
					-- Lobed rim, so a blot isn't a clean circle.
					local lobes = 1 + 0.25 * math.noise(dx / radius * 1.5 + i, dy / radius * 1.5 + j, dz / radius * 1.5 + k)
					local laid = hash(seed, j + 601)
					if dx * dx + dy * dy + dz * dz < (radius * lobes) ^ 2 and laid > order then
						order = laid
						tone = (hash(seed, j + 701) - 0.5) * 2 * SPLOTCH.tone
						warm = (hash(seed, j + 801) - 0.5) * 2 * SPLOTCH.tint
					end
				end
			end
		end
	end
	return tone, warm
end

-- Per-rock gradient over the part of a rock that shows: light where it
-- comes out from behind the tier around it, darkening toward its tip. The
-- island hangs below z = 0, so depth is -z. Near the top the rock is dirt,
-- fading to stone further down.
-- How far from dirt toward stone the colour has blended at a point, 0 to 1.
local function stoneAt(x: number, y: number, z: number): number
	local share = -z / islandDepth + COLOR_WOBBLE * math.noise(x * 0.15 / DETAIL, y * 0.15 / DETAIL, z * 0.15 / DETAIL)
	local t = math.clamp((share - COLOR_TRANSITION[1]) / (COLOR_TRANSITION[2] - COLOR_TRANSITION[1]), 0, 1)
	return t * t * (3 - 2 * t)
end

-- A colour between dirt and stone, `t` of the way to stone.
local function soil(t: number): (number, number, number)
	return DIRT[1] + (STONE[1] - DIRT[1]) * t, DIRT[2] + (STONE[2] - DIRT[2]) * t, DIRT[3] + (STONE[3] - DIRT[3]) * t
end

local paintRock = rusting(0.1, function(x, y, z)
	local rock = rockAt(x, y)
	local depth = if rock
		then math.clamp((-z - rock.shownFrom) / math.max(rock.peak[3] - rock.shownFrom, 0.5), 0, 1)
		else 0
	local shade = ROCK_GRADIENT[1] + (ROCK_GRADIENT[2] - ROCK_GRADIENT[1]) * depth ^ 0.8
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local blend = stoneAt(x, y, z)
	local r, g, b = soil(DIRT_LEAD + (1 - DIRT_LEAD) * blend)
	-- Dirt traces: blotches whose share of the stone shrinks below the line.
	if rock then
		local below = -z - rock.dirtLine
		local amount = if below < 0 then DIRT_DUSTING else math.max(0, 1 - below / DIRT_TRACE) ^ 1.5
		local f = 0.7 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f) + 0.25 * math.noise(x * f * 3, y * f * 3, z * f * 3)
		local trace = math.clamp((blot - (1 - 0.7 * amount)) / 0.08, 0, 1)
		if trace > 0 then
			local dr, dg, db = soil(0.25 * blend)
			r, g, b = r + (dr - r) * trace, g + (dg - g) * trace, b + (db - b) * trace
		end
	end
	local share = -z / islandDepth
	-- Grime: soft-edged patches, less of them deeper down.
	local growth = math.clamp((GRIME_REACH - share) / (GRIME_REACH - DIRT_TRANSITION[1]), 0, 1)
	if growth > 0 then
		local f = 0.45 / DETAIL
		local patch = 0.5 + 0.5 * math.noise(x * f + 31, y * f, z * f) + 0.2 * math.noise(x * f * 3.6, y * f * 3.6 + 17, z * f * 3.6)
		local grime = math.clamp((patch - (1 - GRIME_COVER * growth)) / 0.1, 0, 1)
		r, g, b = r + (GRIME[1] - r) * grime, g + (GRIME[2] - g) * grime, b + (GRIME[3] - b) * grime
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Dirt darkens a little with depth, greys toward stone, and is splotched
-- like the stone.
local paintDirt = rusting(0.05, function(x, y, z)
	local shade = 1.05 - 0.3 * math.clamp(-z / (islandDepth * DIRT_TRANSITION[2]), 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local r, g, b = soil((1 - DIRT_LEAD) * stoneAt(x, y, z))
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Flipped upside down as it is written out: z mirrors, and the winding
-- reverses so faces still point outward. The foot becomes the island's top.
local function addFlipped(mesh, face)
	local verts = {}
	for i, p in face do
		verts[#face + 1 - i] = mesh:vertex(p[1], p[2], -p[3])
	end
	mesh:face(verts)
end

-- The island is split into cubic chunks, each with its own texture, so the
-- stone reads sharp at one density everywhere.
useTexelDensity(TEXEL_DENSITY)

-- A unit vector along x, y, z, and the cross product of two vectors.
local function unit(x: number, y: number, z: number)
	local length = math.max(math.sqrt(x * x + y * y + z * z), 1e-9)
	return { x / length, y / length, z / length }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The solids that may cover a solid of a column: the column's other pieces
-- and its neighbours'.
local function coverersOf(column, solid)
	local others = {}
	for _, other in column.solids do
		if other ~= solid then
			table.insert(others, other)
		end
	end
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		if neighbour then
			for _, other in neighbour.solids do
				table.insert(others, other)
			end
		end
	end
	return others
end

-- What of a face no other solid covers.
local function exposed(face, others)
	local pieces = { face }
	for _, other in others do
		local kept = {}
		for _, piece in pieces do
			for _, part in uncovered(piece, other) do
				table.insert(kept, part)
			end
		end
		pieces = kept
	end
	return pieces
end

local function isFoot(face): boolean
	for _, p in face do
		if p[3] ~= 0 then
			return false
		end
	end
	return true
end

-- Rounds a convex solid's edges and corners where faces that show meet, on
-- DIRT_ROUND. Each such edge is cut by planes turning from one face to the
-- other, each touching a cylinder of that radius set in from both faces;
-- each such corner by one plane facing out between its faces.
local function rounded(faces, shows)
	local planes = {}
	for i, face in faces do
		planes[i] = planeOf(face)
	end
	local function key(p)
		return `{math.round(p[1] * 1e4)},{math.round(p[2] * 1e4)},{math.round(p[3] * 1e4)}`
	end
	local edgeFaces, cornerFaces, points = {}, {}, {}
	for i, face in faces do
		if not planes[i] or not shows[i] then
			continue
		end
		for k, a in face do
			local b = face[k % #face + 1]
			local ka, kb = key(a), key(b)
			points[ka] = a
			local edge = if ka < kb then `{ka}|{kb}` else `{kb}|{ka}`
			edgeFaces[edge] = edgeFaces[edge] or { a = a }
			table.insert(edgeFaces[edge], i)
			cornerFaces[ka] = cornerFaces[ka] or {}
			cornerFaces[ka][i] = true
		end
	end
	local cuts = {}
	for _, edge in edgeFaces do
		if #edge ~= 2 then
			continue
		end
		local n1, n2 = planes[edge[1]], planes[edge[2]]
		local cosine = n1[1] * n2[1] + n1[2] * n2[2] + n1[3] * n2[3]
		if cosine > 0.985 then
			continue
		end
		local p = edge.a
		local inset = DIRT_ROUND / (1 + cosine)
		local centre = { p[1] - (n1[1] + n2[1]) * inset, p[2] - (n1[2] + n2[2]) * inset, p[3] - (n1[3] + n2[3]) * inset }
		for k = 1, DIRT_ROUND_STEPS do
			local t = k / (DIRT_ROUND_STEPS + 1)
			local m = unit(n1[1] + (n2[1] - n1[1]) * t, n1[2] + (n2[2] - n1[2]) * t, n1[3] + (n2[3] - n1[3]) * t)
			table.insert(cuts, { m, m[1] * centre[1] + m[2] * centre[2] + m[3] * centre[3] + DIRT_ROUND })
		end
	end
	for corner, touching in cornerFaces do
		local sum, count = { 0, 0, 0 }, 0
		for i in touching do
			sum = { sum[1] + planes[i][1], sum[2] + planes[i][2], sum[3] + planes[i][3] }
			count += 1
		end
		if count >= 3 then
			local m = unit(sum[1], sum[2], sum[3])
			local v = points[corner]
			table.insert(cuts, { m, m[1] * v[1] + m[2] * v[2] + m[3] * v[3] - DIRT_ROUND * 0.6 })
		end
	end
	for _, cut in cuts do
		faces = carve(faces, cut[1], cut[2])
	end
	return faces
end

-- Round the dirt where it shows: which faces show is settled for every
-- solid first, so rounding one doesn't change what its neighbours see.
do
	local plans = {}
	for _, column in columns do
		for _, solid in column.solids do
			if not solid.dirt then
				continue
			end
			local others, shows = coverersOf(column, solid), {}
			for i, face in solid.faces do
				local whole = area(face)
				if whole > 1e-4 and not isFoot(face) then
					local open = 0
					for _, piece in exposed(face, others) do
						open += area(piece)
					end
					shows[i] = open > whole * 0.5
				end
			end
			table.insert(plans, { solid = solid, shows = shows })
		end
	end
	for _, plan in plans do
		plan.solid.faces = rounded(plan.solid.faces, plan.shows)
	end
end

-- The faces of every column's dirt or stone that show. Only what no other
-- solid covers is kept, another piece of its own column or a neighbour's,
-- so nothing lies buried inside the island. The flat top is left open: the
-- grass covers it.
local function visibleRock(dirt: boolean)
	local shown = {}
	for _, column in columns do
		for _, solid in column.solids do
			if solid.dirt ~= dirt then
				continue
			end
			local others = coverersOf(column, solid)
			for _, face in solid.faces do
				if isFoot(face) then
					continue
				end
				for _, piece in exposed(face, others) do
					table.insert(shown, piece)
				end
			end
		end
	end
	return shown
end

local dirtFaces = visibleRock(true)

-- A box around a centre, `r` from it each way, its faces wound outward.
local function boxAround(c, r)
	local x0, x1, y0, y1, z0, z1 = c[1] - r, c[1] + r, c[2] - r, c[2] + r, c[3] - r, c[3] + r
	return {
		{ { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 }, { x1, y0, z0 } },
		{ { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } },
		{ { x0, y0, z0 }, { x1, y0, z0 }, { x1, y0, z1 }, { x0, y0, z1 } },
		{ { x0, y1, z0 }, { x0, y1, z1 }, { x1, y1, z1 }, { x1, y1, z0 } },
		{ { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } },
		{ { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 }, { x1, y0, z1 } },
	}
end

-- The stones in the dirt, each as the faces that stand out of it. A stone
-- is a box turned at random and chipped at its corners, sunk into a dirt
-- face, and cut off at that face so nothing of it lies buried.
local pebbleSeed = 7
local function pebbleRandom(): number
	pebbleSeed = (pebbleSeed * 16807) % 2147483647
	return pebbleSeed / 2147483647
end
-- How far a point lies from the nearest edge of a face.
local function edgeDistance(face, p): number
	local nearest = math.huge
	for i, a in face do
		local b = face[i % #face + 1]
		local ab = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local length = ab[1] ^ 2 + ab[2] ^ 2 + ab[3] ^ 2
		local t = if length > 0 then math.clamp(((p[1] - a[1]) * ab[1] + (p[2] - a[2]) * ab[2] + (p[3] - a[3]) * ab[3]) / length, 0, 1) else 0
		local dx, dy, dz = p[1] - a[1] - ab[1] * t, p[2] - a[2] - ab[2] * t, p[3] - a[3] - ab[3] * t
		nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy + dz * dz))
	end
	return nearest
end

local pebbles = {}
-- Where cracks start: each stone's face, normal, centre on the dirt and how
-- far its rim reaches.
local crackOrigins = {}
-- Each stone as where it meets the dirt (point and outward normal, already
-- flipped) and how far it stands out, bucketed by 2-stud cell for its paint.
local pebbleCells = {}
local function pebbleCell(x: number, y: number, z: number): string
	return `{math.floor(x / 2)},{math.floor(y / 2)},{math.floor(z / 2)}`
end
for _, face in dirtFaces do
	local plane = planeOf(face)
	if not plane then
		continue
	end
	local n = { plane[1], plane[2], plane[3] }
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local triangle = area({ a, b, c })
		local depth = (a[3] + b[3] + c[3]) / 3
		local toward = math.clamp(depth / (islandDepth * DIRT_TRANSITION[1]), 0, 1)
		local density = STONE_BITS[1] + (STONE_BITS[2] - STONE_BITS[1]) * toward
		local count = math.floor(triangle * density + pebbleRandom())
		for _ = 1, count do
			local u, v = pebbleRandom(), pebbleRandom()
			if u + v > 1 then
				u, v = 1 - u, 1 - v
			end
			local p = {
				a[1] + (b[1] - a[1]) * u + (c[1] - a[1]) * v,
				a[2] + (b[2] - a[2]) * u + (c[2] - a[2]) * v,
				a[3] + (b[3] - a[3]) * u + (c[3] - a[3]) * v,
			}
			local size = STONE_BIT_SIZE[1] + (STONE_BIT_SIZE[2] - STONE_BIT_SIZE[1]) * pebbleRandom() ^ STONE_BIT_SKEW
			-- A stone too big for the room it has on its face is made smaller,
			-- so it never hangs off an edge.
			size = math.min(size, edgeDistance(face, p) * 2.2)
			local r = size / 2
			if p[3] < STONE_BIT_CLEAR or size < STONE_BIT_SIZE[1] * 0.8 then
				continue
			end
			local rise = STONE_BIT_RISE[1] + (STONE_BIT_RISE[2] - STONE_BIT_RISE[1]) * pebbleRandom()
			table.insert(crackOrigins, { face = face, normal = n, at = p, rim = r * 1.0 })
			local centre = { p[1] + n[1] * r * (2 * rise - 1), p[2] + n[2] * r * (2 * rise - 1), p[3] + n[3] * r * (2 * rise - 1) }
			-- A box turned at random: start big, and cut each side in to r.
			local x = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
			local y = cross(x, unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5))
			y = unit(y[1], y[2], y[3])
			local z = cross(x, y)
			local stone = boxAround(centre, size * 2)
			for _, axis in { x, y, z } do
				for _, sign in { 1, -1 } do
					local d = { axis[1] * sign, axis[2] * sign, axis[3] * sign }
					local reach = r * (0.75 + 0.35 * pebbleRandom())
					stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + reach)
				end
			end
			-- Chips knock its corners off.
			for _ = 1, 9 do
				local d = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
				stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + r * (0.65 + 0.25 * pebbleRandom()))
			end
			-- Cut off at the dirt: only what stands out of it is kept, and the
			-- cap the cut leaves lies against the dirt, so it goes too.
			local level = n[1] * p[1] + n[2] * p[2] + n[3] * p[3]
			stone = carve(stone, { -n[1], -n[2], -n[3] }, -level)
			local record = { point = { p[1], p[2], -p[3] }, normal = { n[1], n[2], -n[3] }, height = size * rise, reach = size }
			for cx = -1, 1 do
				for cy = -1, 1 do
					for cz = -1, 1 do
						local key = pebbleCell(p[1] + cx * 2, p[2] + cy * 2, -p[3] + cz * 2)
						pebbleCells[key] = pebbleCells[key] or {}
						table.insert(pebbleCells[key], record)
					end
				end
			end
			for _, piece in stone do
				local onDirt = true
				for _, q in piece do
					onDirt = onDirt and math.abs(n[1] * q[1] + n[2] * q[2] + n[3] * q[3] - level) < 1e-6
				end
				if not onDirt then
					table.insert(pebbles, piece)
				end
			end
		end
	end
end

-- The cracks, drawn over the dirt's coat as tapering brush strokes, one per
-- step of a crack (already flipped).
local crackStrokes = {}
local crackSeed = 3
local function crackRandom(): number
	crackSeed = (crackSeed * 16807) % 2147483647
	return crackSeed / 2147483647
end
-- Whether a point lies inside a convex face, `margin` studs in from its edges.
local function insideFace(face, n, p, margin: number): boolean
	for i, a in face do
		local b = face[i % #face + 1]
		local edge = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local inward = unit(table.unpack(cross(n, edge)))
		if (p[1] - a[1]) * inward[1] + (p[2] - a[2]) * inward[2] + (p[3] - a[3]) * inward[3] < margin then
			return false
		end
	end
	return true
end
-- A direction turned by `angle` about the face's normal.
local function turned(v, n, angle: number)
	local side = cross(n, v)
	local c, s = math.cos(angle), math.sin(angle)
	return { v[1] * c + side[1] * s, v[2] * c + side[2] * s, v[3] * c + side[3] * s }
end
-- A jagged line from `start` heading along `heading` in a face, stopping
-- short of its edges.
local function crackLine(face, n, start, heading, length: number)
	local points = { start }
	local step = length / CRACK_SEGMENTS
	local at, way = start, heading
	for _ = 1, CRACK_SEGMENTS do
		way = turned(way, n, (crackRandom() - 0.5) * 1.1)
		local nextAt = { at[1] + way[1] * step, at[2] + way[2] * step, at[3] + way[3] * step }
		if not insideFace(face, n, nextAt, 0.04 * DETAIL) then
			break
		end
		table.insert(points, nextAt)
		at = nextAt
	end
	return points
end
-- Lays a line down as a crack `width` wide at its start, thinning evenly
-- along its length to nothing at its end.
local function addCrack(points, normal, width: number)
	if #points < 2 then
		return
	end
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	local travelled = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		local widthA = width * (1 - travelled / total)
		local widthB = width * (1 - (travelled + length) / total)
		travelled += length
		local start = { a[1], a[2], -a[3] }
		local along = { (b[1] - a[1]) / length, (b[2] - a[2]) / length, -(b[3] - a[3]) / length }
		local facing = { normal[1], normal[2], -normal[3] }
		local function stroke(at, width: number, color)
			table.insert(crackStrokes, { start = at, along = along, normal = facing, length = length, width = width, tail = widthB / widthA, color = color })
		end
		-- The lip sits on the crack's lower side, half a crack's width over.
		local across = cross(facing, along)
		local side = if across[3] > 0 then -1 else 1
		local shift = widthA * 0.5 * side
		stroke({ start[1] + across[1] * shift, start[2] + across[2] * shift, start[3] + across[3] * shift }, widthA * 0.8, CRACK_LIP)
		stroke(start, widthA, CRACK)
		stroke(start, widthA * CRACK_CORE_WIDTH, CRACK_CORE)
	end
end

for _, origin in crackOrigins do
	if crackRandom() >= CRACK_CHANCE then
		continue
	end
	local face, n, at = origin.face, origin.normal, origin.at
	-- Some way across the face, to turn into each crack's heading.
	local first = face[1]
	local outward = unit(first[1] - at[1], first[2] - at[2], first[3] - at[3])
	for _ = 1, 1 + math.floor(crackRandom() * CRACKS) do
		local heading = turned(outward, n, crackRandom() * TAU)
		local start = { at[1] + heading[1] * origin.rim, at[2] + heading[2] * origin.rim, at[3] + heading[3] * origin.rim }
		if not insideFace(face, n, start, 0.04 * DETAIL) then
			continue
		end
		local length = CRACK_LENGTH[1] + (CRACK_LENGTH[2] - CRACK_LENGTH[1]) * crackRandom()
		local width = CRACK_WIDTH[1] + (CRACK_WIDTH[2] - CRACK_WIDTH[1]) * crackRandom()
		local line = crackLine(face, n, start, heading, length)
		addCrack(line, n, width)
		-- A fork off partway along, thinner and shorter.
		if #line >= 3 and crackRandom() < CRACK_BRANCH then
			local from = line[2]
			local share = 1 / (#line - 1)
			local away = unit(line[3][1] - from[1], line[3][2] - from[2], line[3][3] - from[3])
			local fork = turned(away, n, (if crackRandom() < 0.5 then -1 else 1) * (0.5 + 0.4 * crackRandom()))
			addCrack(crackLine(face, n, from, fork, length * 0.5), n, width * (1 - share) * 0.8)
		end
	end
end


-- The stones are grey, splotched like the rest and stained with the dirt
-- they sit in: solid at the dirt line, in blotches higher up.
local paintPebble = rusting(0.1, function(x, y, z)
	local tone, warm = splotchAt(x, y, z)
	local shade = 1 + tone * 1.5
	local r, g, b = PEBBLE[1], PEBBLE[2], PEBBLE[3]
	-- The stone this point is on: the nearest whose dirt line it sits above.
	local height, best = math.huge, math.huge
	for _, record in pebbleCells[pebbleCell(x, y, z)] or {} do
		local q, n = record.point, record.normal
		local dx, dy, dz = x - q[1], y - q[2], z - q[3]
		local distance = dx * dx + dy * dy + dz * dz
		if distance < record.reach * record.reach and distance < best then
			best = distance
			height = (dx * n[1] + dy * n[2] + dz * n[3]) / math.max(record.height, 0.05)
		end
	end
	if height < STONE_BIT_STAIN then
		local f = 2.2 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f)
		local stain = math.clamp((blot - height / STONE_BIT_STAIN) / 0.12, 0, 1)
		local dr, dg, db = soil(0.15 * stoneAt(x, y, z))
		r, g, b = r + (dr - r) * stain, g + (dg - g) * stain, b + (db - b) * stain
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Columns", nil, STONE, function(mesh)
	for _, piece in visibleRock(false) do
		addFlipped(mesh, piece)
	end
end, false, paintRock, true, EDGE_REACH)

chunkedPart("Dirt", nil, DIRT, function(mesh)
	for _, piece in dirtFaces do
		addFlipped(mesh, piece)
	end
end, nil, paintDirt, true, EDGE_REACH)

chunkedPart("Pebbles", nil, PEBBLE, function(mesh)
	for _, piece in pebbles do
		addFlipped(mesh, piece)
	end
end, false, paintPebble, true, EDGE_REACH)

-- The rim walked in even steps, each point pushed out from the stone by the
-- grass's outset (outer) and a hair's width (inner), with how deep the grass
-- hangs there.
local function grassRim()
	-- The rim the stones are trimmed to, walked clockwise seen from above
	-- in GRASS_STEP strides, so the grass follows it exactly.
	local points = {}
	local steps = math.ceil(TAU * RIM_PUSH * RADIUS * RIM_REACH * (1 + RIM_WOBBLE) / GRASS_STEP)
	for k = 0, steps - 1 do
		local angle = -k / steps * TAU
		local r = rimAt(angle)
		table.insert(points, { r * math.cos(angle), r * math.sin(angle) })
	end
	local count = #points

	-- Blurs a list of numbers round the loop: repeated passes of a 1-2-1
	-- average, each spreading it by half a step squared, until it spreads
	-- `studs`.
	local function blurLoop(values: { number }, studs: number)
		for _ = 1, math.round(2 * (studs / GRASS_STEP) ^ 2) do
			local before = table.clone(values)
			for i = 1, #values do
				values[i] = (before[(i - 2) % #values + 1] + 2 * before[i] + before[i % #values + 1]) / 4
			end
		end
	end
	local raw = table.clone(points)
	for axis = 1, 2 do
		local coordinates = {}
		for i, p in points do
			coordinates[i] = p[axis]
		end
		blurLoop(coordinates, GRASS_CORNER_BLUR)
		for i = 1, count do
			points[i] = table.clone(points[i])
			points[i][axis] = coordinates[i]
		end
	end
	-- Blurring cuts the outside corners in, uncovering the stone there, so
	-- the rim swells back out round each one: by the most it was cut in
	-- anywhere near, blurred so the swell has no edge of its own.
	local cut, outward = {}, {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		outward[i] = { -dy / length, dx / length }
		cut[i] = math.max(0, (raw[i][1] - p[1]) * outward[i][1] + (raw[i][2] - p[2]) * outward[i][2])
	end
	local reach = math.ceil(2 * GRASS_CORNER_BLUR / GRASS_STEP)
	local swell = {}
	for i = 1, count do
		local most = 0
		for k = -reach, reach do
			most = math.max(most, cut[(i + k - 1) % count + 1])
		end
		swell[i] = most
	end
	blurLoop(swell, GRASS_CORNER_BLUR)
	for i, p in points do
		p[1] += outward[i][1] * swell[i]
		p[2] += outward[i][2] * swell[i]
	end

	-- The lip wanders between its shallowest and deepest, and drips hang
	-- from it as rounded tongues, each overlapping the next.
	local along, travelled = {}, 0
	for i, p in points do
		along[i] = travelled
		local q = points[i % count + 1]
		travelled += math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
	end
	local function halfWidth(n)
		return (DRIP_WIDTH[1] + (DRIP_WIDTH[2] - DRIP_WIDTH[1]) * hash(n, 21)) / 2
	end
	local drips, at, n = {}, 0, 0
	while at < travelled do
		n += 1
		table.insert(drips, { at, halfWidth(n), DRIP_LENGTH[1] + (DRIP_LENGTH[2] - DRIP_LENGTH[1]) * hash(n, 22) })
		at += (halfWidth(n) + halfWidth(n + 1)) * (1 - DRIP_OVERLAP)
	end

	-- The outline is wound clockwise seen from above, so out is to the left
	-- of each step. A point's way out averages the steps either side of it.
	local rim = {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		local ox, oy = -dy / length, dx / length
		local s = along[i]
		local depth = GRASS_LIP[1] + (GRASS_LIP[2] - GRASS_LIP[1]) * (0.5 + 0.5 * math.noise(s * 0.3 / DETAIL, 3.7))
		for _, drip in drips do
			-- The distance round the rim either way, so drips near the
			-- start also reach the end.
			local gap = math.abs(s - drip[1])
			gap = math.min(gap, travelled - gap)
			if gap < drip[2] then
				depth = math.max(depth, GRASS_LIP[1] + drip[3] * math.sqrt(1 - (gap / drip[2]) ^ 2))
			end
		end
		-- The finer octave never lifts the edge above the stone's top.
		depth = math.max(depth + DRIP_DETAIL * math.noise(s * DRIP_DETAIL_FREQUENCY, 8.1), 0.15 * DETAIL)
		table.insert(rim, {
			outer = { p[1] + ox * GRASS_OUTSET, p[2] + oy * GRASS_OUTSET },
			out = { ox, oy },
			inner = { p[1] + ox * 0.02 * DETAIL, p[2] + oy * 0.02 * DETAIL },
			depth = depth,
		})
	end

	local depths = {}
	for i, point in rim do
		depths[i] = point.depth
	end
	blurLoop(depths, GRASS_DEPTH_BLUR)
	for i, point in rim do
		point.depth = depths[i]
	end

	-- Pushed out of a sharp inward notch, the outer line crosses itself; the
	-- loop it makes is cut away at the crossing.
	local function crossing(a, b, c, d)
		local rx, ry, sx, sy = b[1] - a[1], b[2] - a[2], d[1] - c[1], d[2] - c[2]
		local denominator = rx * sy - ry * sx
		if math.abs(denominator) < 1e-12 then
			return nil
		end
		local t = ((c[1] - a[1]) * sy - (c[2] - a[2]) * sx) / denominator
		local u = ((c[1] - a[1]) * ry - (c[2] - a[2]) * rx) / denominator
		if t <= 0 or t >= 1 or u <= 0 or u >= 1 then
			return nil
		end
		return { a[1] + rx * t, a[2] + ry * t }
	end
	local i = 1
	while i < #rim do
		for k = 2, 12 do
			local j = i + k
			if j + 1 > #rim then
				break
			end
			local hit = crossing(rim[i].outer, rim[i + 1].outer, rim[j].outer, rim[j + 1].outer)
			if hit then
				local kept = rim[i]
				for _ = i + 1, j do
					table.remove(rim, i + 1)
				end
				table.insert(rim, i + 1, { outer = hit, out = kept.out, inner = kept.inner, depth = kept.depth })
				break
			end
		end
		i += 1
	end
	return rim
end

-- How deep the deepest drip hangs, for the grass's shading.
local GRASS_DEEPEST = GRASS_LIP[1] + DRIP_LENGTH[2]

-- Grass is dead straw with olive patches, darkening down
-- the hanging edge toward the drip tips, and splotched like the stone.
local paintGrass = rusting(0, function(x, y, z)
	local shade = 1 - DRIP_SHADE * math.clamp(-z / GRASS_DEEPEST, 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	-- Patch strength from soft noise: 0 outside, 1 well inside a patch
	-- covering `cover` of the grass.
	local function patch(cover: number, seed: number): number
		local u, v = x / GRASS_PATCH_SIZE + seed, y / GRASS_PATCH_SIZE
		local n = 0.5 + math.noise(u, v, seed) + 0.3 * math.noise(u * 3, v * 3, seed + 5)
		return math.clamp((n - (1 - cover)) / 0.12, 0, 1)
	end
	local function toward(r, g, b, c, t)
		return r + (c[1] - r) * t, g + (c[2] - g) * t, b + (c[3] - b) * t
	end
	local r, g, b = toward(GRASS[1], GRASS[2], GRASS[3], GRASS_OLIVE, patch(GRASS_OLIVE_COVER, 11.3))
	-- The worn apron round what stands on the top.
	local outside = wornDistance(x, y)
	local wobble = 0.4 * APRON_WIDTH * math.noise(x * 0.3, y * 0.3, 71.3)
	local wear = math.clamp(1 - (outside + wobble) / APRON_WIDTH, 0, 1)
	if wear > 0 then
		local patchy = 0.5 + 0.6 * math.noise(x * 0.55, y * 0.55, 93.1)
		local worn = math.clamp((wear - 0.75 * (1 - patchy)) / 0.2, 0, 1)
		local grit = 0.9 + 0.2 * math.noise(x * 1.7, y * 1.7, 17.9)
		r, g, b = toward(r, g, b, { TRODDEN[1] * grit, TRODDEN[2] * grit, TRODDEN[3] * grit }, worn)
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Grass", nil, GRASS, function(mesh)
	local rim = grassRim()
	local count = #rim
	-- Corners of the turf: rings rounding over from its top edge (the first)
	-- down to its hanging edge (the last), rings curling the hanging edge's
	-- bottom under, the inner bottom of the hanging edge, and the inner edge
	-- where it meets the stone's top.
	local rings, curl, innerBottom, innerTop = {}, {}, {}, {}
	for k = 0, GRASS_ROUND_STEPS do
		rings[k], curl[k] = {}, {}
	end
	local outline = {}
	for i, point in rim do
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_ROUND * (1 - math.sin(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			rings[k][i] = mesh:vertex(x, y, GRASS_HEIGHT - GRASS_ROUND * (1 - math.cos(angle)))
			if k == 0 then
				outline[i] = { x, y }
			end
		end
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_BOTTOM_ROUND * (1 - math.cos(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			curl[k][i] = mesh:vertex(x, y, -point.depth + GRASS_BOTTOM_ROUND * (1 - math.sin(angle)))
		end
		innerBottom[i] = mesh:vertex(point.inner[1], point.inner[2], -point.depth)
		innerTop[i] = mesh:vertex(point.inner[1], point.inner[2], 0)
	end
	local top, edge = rings[0], rings[GRASS_ROUND_STEPS]
	for i = 1, count do
		local j = i % count + 1
		-- The rounded rim, ring by ring, facing out and up.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = rings[k - 1], rings[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Outside, facing out.
		local wallBottom, underEdge = curl[0], curl[GRASS_ROUND_STEPS]
		mesh:face({ wallBottom[j], wallBottom[i], edge[i] })
		mesh:face({ wallBottom[j], edge[i], edge[j] })
		-- The curl under, ring by ring, facing out and down.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = curl[k - 1], curl[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Underside, facing down.
		mesh:face({ underEdge[i], underEdge[j], innerBottom[j] })
		mesh:face({ underEdge[i], innerBottom[j], innerBottom[i] })
		-- Inside, facing the stone.
		mesh:face({ innerBottom[i], innerBottom[j], innerTop[j] })
		mesh:face({ innerBottom[i], innerTop[j], innerTop[i] })
	end
	-- The turf's top, facing up, cut into GRASS_TOP_CELL squares so no
	-- piece spans the island and the chunker can keep each texture small:
	-- the outline clipped to each square in turn, one edge at a time.
	local function clipped(points, axis: number, at: number, below: boolean)
		local kept = {}
		for i, a in points do
			local b = points[i % #points + 1]
			local aIn, bIn = (a[axis] <= at) == below, (b[axis] <= at) == below
			if aIn then
				table.insert(kept, a)
			end
			if aIn ~= bIn then
				local t = (at - a[axis]) / (b[axis] - a[axis])
				table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
			end
		end
		return kept
	end
	-- Outline corners keep their ring vertex, so the top meets the rounded
	-- edge without a seam.
	local cornerOf = {}
	for i, p in outline do
		cornerOf[p] = top[i]
	end
	local low, high = { math.huge, math.huge }, { -math.huge, -math.huge }
	for _, p in outline do
		for axis = 1, 2 do
			low[axis], high[axis] = math.min(low[axis], p[axis]), math.max(high[axis], p[axis])
		end
	end
	-- A piece is buried when every corner of it lies deep in the worn ground.
	local function buried(piece): boolean
		for _, p in piece do
			if wornDistance(p[1], p[2]) > -COVER_INSET then
				return false
			end
		end
		return true
	end
	for cx = math.floor(low[1] / GRASS_TOP_CELL), math.floor(high[1] / GRASS_TOP_CELL) do
		for cy = math.floor(low[2] / GRASS_TOP_CELL), math.floor(high[2] / GRASS_TOP_CELL) do
			local piece = clipped(outline, 1, cx * GRASS_TOP_CELL, false)
			piece = clipped(piece, 1, (cx + 1) * GRASS_TOP_CELL, true)
			piece = clipped(piece, 2, cy * GRASS_TOP_CELL, false)
			piece = clipped(piece, 2, (cy + 1) * GRASS_TOP_CELL, true)
			if #piece >= 3 and not buried(piece) then
				local corners = {}
				for i, p in piece do
					corners[i] = cornerOf[p] or mesh:vertex(p[1], p[2], GRASS_HEIGHT)
				end
				for _, t in earClip(piece) do
					mesh:face({ corners[t[3]], corners[t[2]], corners[t[1]] })
				end
			end
		end
	end
end, nil, paintGrass, true, EDGE_REACH)

-- The chunks are shaded here rather than by finishParts, which has no corner
-- taper: highlights run full width at a corner and thin toward the middle of
-- an edge, as finishParts would otherwise shade them. Chunks of the island
-- count as one surface, so their seams shade like any other edge.
local chunks = {}
for _, entry in parts do
	table.insert(chunks, entry.mesh)
end
for _, entry in parts do
	local group = {}
	for _, other in parts do
		if other ~= entry then
			table.insert(group, other.mesh)
		end
	end
	local kind = string.match(entry.name, "^%a+")
	local soft = kind == "Grass" or kind == "Dirt"
	entry.mesh:paintShading(entry.image, {
		highlight = if soft then EDGE_HIGHLIGHT * SOFT_SHADING else EDGE_HIGHLIGHT,
		shadow = if soft then CONTACT_SHADOW * SOFT_SHADING else CONTACT_SHADOW,
		gradient = GRADIENT,
		blend = EDGE_BLEND,
		group = group,
		name = entry.name,
		paint = entry.paint,
		-- The rock paint is cached under the item's key, since its code is not hashed.
		custom = entry.custom,
		salt = CACHE_KEY,
		rust = entry.rust * WEAR,
		reach = EDGE_REACH,
		highlightWidth = HIGHLIGHT_WIDTH,
		cornerTaper = CORNER_TAPER,
		heightRange = entry.heightRange,
		strokes = if string.sub(entry.name, 1, 4) == "Dirt" then crackStrokes else nil,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
end
buildKeys[buildHubSectionB] = "HubSectionB-9d1e1b9f547142af"
local function buildHubSectionEnd()
local CACHE_KEY = "HubSectionEnd-136fa7952b3f42be"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Hub Section End: an end of the Scrap Line's hub, a rounded slab of
-- floating island from the shared column generator (shared/ColumnIsland.luau).
-- The hub is five of these in a row along x, overlapping at their ends.
local RADIUS = 56
local PEAK = 64
local SEED = 71
-- The rim is a rounded rectangle: at least HALF_LENGTH along the Line (x) and
-- HALF_WIDTH across it once the rim's wobble is taken off.
local RIM_WOBBLE = 0.05
local HALF_LENGTH, HALF_WIDTH = 58.5, 64.5
local function rimShape(angle: number): number
	local c, s = math.abs(math.cos(angle)) / HALF_LENGTH, math.abs(math.sin(angle)) / HALF_WIDTH
	return (c ^ 8 + s ^ 8) ^ (-1 / 8) / HALF_LENGTH
end
-- What stands on it (ServerMap.luau): the Line's paved deck, DECK_HALF either
-- side of the middle, ending DECK_END studs out toward +x
-- where the end plaza stops.
local DECK_HALF = 56.5
local DECK_END = 48.5

-- The deck buries the turf under it.
local COVER_INSET = 2
-- How far a point lies outside the deck.
local function wornDistance(x: number, y: number): number
	return math.max(math.abs(y) - DECK_HALF, x - DECK_END)
end

-- Column Island: the generator for the map's floating islands, a mountain
-- of stone columns turned upside down, so a flat grassy top hangs over a
-- rocky cone that tapers to a point below. The columns, of every size and
-- shape, are packed edge to edge like cracked basalt; each hangs as deep as
-- the cone at its centre with a low faceted tip, so the underside steps down
-- in uneven tiers to the lowest point and a shallower shoulder. The columns
-- are the cells of a weighted Voronoi diagram (a power diagram) over
-- scattered stones, so big stones claim big cells. Stones grow from small
-- near the tip to big at the rim, and the big rim stones give the top its
-- lobed outline. Each column is carved, a few angled planes chiselling
-- chunks off its lower corners and edges. The model is built the mountain
-- way up (heights, summit, foot) and flipped as it is written out. Centered
-- on the origin, stone top at z = 0, turf GRASS_HEIGHT above it.
--
-- The item including this sets:
--   RADIUS        the island's radius;
--   PEAK          how far the cone hangs below the top;
--   SEED          which scatter of stones it gets;
--   wornDistance(x, y)  how far a point on the top lies outside the ground
--                 worn by what stands on it (math.huge where nothing does);
--                 the grass wears to dirt within about APRON_WIDTH of it;
--   COVER_INSET   turf lying more than this many studs inside the worn
--                 ground is buried under what stands there and left out
--                 (math.huge keeps it all);
--   RIM_WOBBLE    how far the rim swells and dips, as a share of its radius;
--   rimShape(angle)  how far out the rim stands at an angle, as a multiple
--                 of the round rim: 1 all round for a round island, never
--                 under 1, more toward the corners of a squarer one.
-- Stone sizes at the summit and at the foot, as shares of the radius, so
-- a bigger island has bigger stones rather than more of them.
local SMALLEST, LARGEST = 0.055 * RADIUS, 0.34 * RADIUS
-- Every other size in studs below was tuned on stones up to 4.5 studs
-- across and is multiplied by DETAIL, so an island with bigger stones looks
-- the same, only bigger: chips, slabs, cookie stones, cracks, rounding,
-- grass and the paint's blotches all grow with the stones.
local DETAIL = LARGEST / 4.5
-- The rim the columns are trimmed to: a circle of RIM_PUSH * RADIUS
-- swelling and dipping by up to RIM_WOBBLE of it in broad waves, so the top
-- is a dependable surface rather than sharp lobes and bays, and standing
-- rimShape times as far out at each angle. RIM_SIDES flat facets make it up,
-- so the rim stones end in cut faces.
local RIM_SIDES = 192
-- The rim stands RIM_PUSH times RADIUS out.
local RIM_PUSH = 1.1
-- The top tier of dirt, this deep under the grass, stays a clean wall
-- straight down from the rim the grass follows: chisel cuts, chips and bare
-- rock slabs all start below it.
local DIRT_CONFORM = 1.5 * DETAIL
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before they are trimmed to it.
local RIM_REACH = 1
for i = 0, RIM_SIDES - 1 do
	RIM_REACH = math.max(RIM_REACH, rimShape(i / RIM_SIDES * 2 * math.pi))
end
local SCATTER = RIM_PUSH * RADIUS * RIM_REACH + LARGEST
-- Shortest a column hangs, so the rim stones read as a thick slab; a
-- share of the radius like the stone sizes.
local MIN_LENGTH = 0.2 * RADIUS
-- Chisel cuts per column, at most, and how deep one bites as a share of
-- the stone's size.
local MAX_CUTS = 3
local CUT_DEPTH = { 0.2, 0.55 }
-- Fine chips per column (fewest, most) and how deep one bites, in studs.
local CHIPS = { 3, 6 }
local CHIP_DEPTH = { 0.15 * DETAIL, 0.45 * DETAIL }
-- How far a cut's heading may swing from straight out, in radians.
local CUT_SPREAD = math.rad(55)

local STONE = { 0.46, 0.45, 0.5 }
-- Under the grass the island is all dirt, until rocks start breaking
-- through it at the first share of the island's depth in DIRT_TRANSITION,
-- more and more of them going down, until from the second share it is all
-- rock. Each rock comes through the dirt at its own depth in that range. The
-- dirt's bottom edge is bevelled back DIRT_BEVEL studs on its outer side, so
-- the rock it sits on stands proud.
local DIRT = { 0.33, 0.24, 0.18 }
local DIRT_TRANSITION = { 0.2, 0.65 }
-- Where a rock comes through, the line between its dirt and its stone tilts
-- by up to DIRT_TILT radians, each rock its own way, so the line wanders
-- round the island instead of stepping level.
local DIRT_TILT = math.rad(25)
-- Above that, rock already shows through the dirt in slabs: a rock still
-- under dirt may have up to PATCHES slabs of its faces bare below tilted
-- lines, each facing out from the island's centre within PATCH_SPREAD
-- radians. The chance of each rises from nothing at PATCH_FROM of the depth
-- to certain at PATCH_FULL. A slab is PATCH_THICKNESS studs deep, its back
-- leaning in or out by up to PATCH_LEAN, and its top line tilted by up to
-- PATCH_TILT; PATCH_PEAKED of the slabs have a second top line, so the bare
-- rock comes up to a point through the dirt.
local PATCHES = 2
local PATCH_FROM = 0.04
local PATCH_FULL = 0.25
local PATCH_SPREAD = math.rad(45)
local PATCH_THICKNESS = { 0.4 * DETAIL, 1.4 * DETAIL }
local PATCH_LEAN = 0.5
local PATCH_TILT = 0.8
local PATCH_PEAKED = 0.6
-- The bare rock of a slab is chiselled into a rough stone: this many chips
-- (fewest, most), each biting this deep (studs) off its outer side at its
-- own angle, up to PATCH_CHIP_SPREAD radians off straight out.
local PATCH_CHIPS = { 4, 8 }
local PATCH_CHIP_DEPTH = { 0.3 * DETAIL, 0.8 * DETAIL }
local PATCH_CHIP_SPREAD = math.rad(65)
-- The colours blend too, over a wider share of the depth: dirt greys toward
-- stone and stone keeps a dirty tint across COLOR_TRANSITION, the line
-- wandering by COLOR_WOBBLE of the depth. At any depth the dirt stays
-- DIRT_LEAD further toward dirt than the stone, so the two still read apart.
local COLOR_TRANSITION = { 0.08, 0.55 }
local COLOR_WOBBLE = 0.06
local DIRT_LEAD = 0.45
-- Traces of dirt stay on the stone just under each rock's dirt line, as
-- patchy blotches thinning out over DIRT_TRACE studs below it. Bare rock
-- breaking through above the line keeps DIRT_DUSTING of them.
local DIRT_TRACE = 4 * DETAIL
local DIRT_DUSTING = 0.35
-- Grime and dead grey lichen crust the stone in patches, thickest where
-- the dirt gives way to rock and thinning out to nothing by GRIME_REACH of
-- the island's depth.
-- GRIME_COVER is the most of the stone it covers.
local GRIME = { 0.21, 0.22, 0.19 }
local GRIME_REACH = 0.8
local GRIME_COVER = 0.45

-- Small whole stones half sunk in the dirt, like crushed cookie in ice
-- cream: STONE_BITS of them per square stud of dirt near the top, rising to
-- the second number where the dirt gives way to rock. Each is STONE_BIT_SIZE
-- studs across, most of them small and a few big (STONE_BIT_SKEW over 1), a
-- chipped box, and stands out of the dirt by STONE_BIT_RISE
-- of its size. None sit within STONE_BIT_CLEAR studs of the top, under the
-- grass's lip. With bigger stones (DETAIL) they are bigger and sparser.
local PEBBLE = { 0.47, 0.46, 0.49 }
local STONE_BITS = { 0.035 / DETAIL ^ 2, 0.17 / DETAIL ^ 2 }
local STONE_BIT_SIZE = { 0.45 * DETAIL, 1.9 * DETAIL }
local STONE_BIT_SKEW = 2
local STONE_BIT_RISE = { 0.3, 0.4 }
local STONE_BIT_CLEAR = 1.2 * DETAIL
-- The stones are stained with dirt: solid where they come out of it,
-- breaking into blotches up to STONE_BIT_STAIN of their height.
local STONE_BIT_STAIN = 1.6

-- Drawn cracks in the dirt, running out from the stones sunk in it, as if
-- pushing them in split it: CRACK_CHANCE of the stones have them, up to
-- CRACKS each, CRACK_LENGTH studs long in CRACK_SEGMENTS jagged steps,
-- CRACK_WIDTH wide at the stone and thinning steadily to nothing at its end.
-- CRACK_BRANCH of the cracks fork once.
local CRACK = { 0.17, 0.12, 0.08 }
-- Each crack is drawn in depth: a pale lip where light catches its lower
-- edge (CRACK_LIP), the crack over it, and a darker core down its middle
-- (CRACK_CORE, CRACK_CORE_WIDTH of the crack's width).
local CRACK_LIP = { 0.66, 0.53, 0.4 }
local CRACK_CORE = { 0.06, 0.04, 0.03 }
local CRACK_CORE_WIDTH = 0.45
local CRACK_CHANCE = 1
local CRACKS = 3
local CRACK_LENGTH = { 0.6 * DETAIL, 1.8 * DETAIL }
local CRACK_SEGMENTS = 4
local CRACK_WIDTH = { 0.1 * DETAIL, 0.18 * DETAIL }
local CRACK_BRANCH = 0.4
local DIRT_BEVEL = { 0.3 * DETAIL, 0.6 * DETAIL }
-- How steeply each rock's bevel slants, in radians up from flat; each rock
-- takes its own angle in this range, so the bevels don't all match.
local DIRT_BEVEL_LIFT = { math.rad(25), math.rad(65) }
-- The dirt's outer edges and corners are rounded off on this radius, each
-- edge in this many facets, so it reads soft rather than jagged.
local DIRT_ROUND = 0.6 * DETAIL
local DIRT_ROUND_STEPS = 4
-- Each rock shades from STONE times the first where it meets the top to
-- STONE times the second at its tip.
local ROCK_GRADIENT = { 1.1, 0.6 }
-- Brush splotches in the stone: one may sit in each cell of a 3D grid
-- (`cell` studs, with `chance`), a lobed blot `radius` studs across that
-- shifts the stone's tone by up to `tone` and its tint by up to `tint`. The
-- coat's brush strokes lay them on as dabs.
local SPLOTCH = { cell = 1.8 * DETAIL, chance = 1, radius = { DETAIL, 2 * DETAIL }, tone = 0.1, tint = 0.02 }
-- Texture pixels per stud; chunks are 1024 texels across at this density.
local TEXEL_DENSITY = 16
-- Edge highlights: how far edge paint reaches from an edge, in studs, and how
-- many times wider than the default the highlight strokes are.
local EDGE_REACH = DETAIL
local HIGHLIGHT_WIDTH = 4
-- Studs over which a highlight thins from full width at a corner.
local CORNER_TAPER = 0.5 * DETAIL
-- Grass and dirt are soft, so their edge highlights and contact shadows run
-- at this share of the stone's.
local SOFT_SHADING = 0.12

-- Grass over the top: a turf slab GRASS_HEIGHT thick, pushed GRASS_OUTSET
-- past the rim, whose edge hangs down as a lip (shallowest and deepest, in
-- studs) hung all along with tongues of grass dripping further down, each
-- DRIP_WIDTH across and DRIP_LENGTH below the lip. Neighbouring drips
-- overlap by DRIP_OVERLAP of their widths, so the edge runs as one
-- unbroken wave with no flat stretch between drips.
local GRASS = { 0.74, 0.63, 0.4 }
local GRASS_HEIGHT = 0.45 * DETAIL
local GRASS_OUTSET = 0.25 * DETAIL
local GRASS_LIP = { 0.3 * DETAIL, 0.6 * DETAIL }
local DRIP_WIDTH = { 1.6 * DETAIL, 4 * DETAIL }
local DRIP_LENGTH = { 0.3 * DETAIL, 1.1 * DETAIL }
local DRIP_OVERLAP = 0.35
-- A finer octave of wobble over the wave: how far it moves the edge up or
-- down, in studs, and how fast it changes along the rim.
local DRIP_DETAIL = 0.3 * DETAIL
local DRIP_DETAIL_FREQUENCY = 1.1 / DETAIL
-- Spacing of the points the rim is walked in, in studs.
local GRASS_STEP = 0.25 * DETAIL
-- The turf's top rolls over into its hanging edge on a quarter circle this
-- many studs across, in this many facets.
local GRASS_ROUND = 0.42 * DETAIL
local GRASS_ROUND_STEPS = 4
-- The hanging edge's bottom curls under into its underside on this radius.
local GRASS_BOTTOM_ROUND = 0.2 * DETAIL
-- The rim's corners in plan are rounded off by blurring its outline over
-- about this many studs, just enough to soften each stone's jog while the
-- grass still follows the stones, pushed out GRASS_OUTSET past them. The drips' depth is
-- blurred over GRASS_DEPTH_BLUR studs, so neighbouring tongues meet in soft
-- dips rather than sharp notches.
local GRASS_CORNER_BLUR = 0.2 * DETAIL
local GRASS_DEPTH_BLUR = 0.3 * DETAIL
-- The turf's flat top is cut into squares this many studs across, to keep
-- its texture chunks small; this one doesn't grow with DETAIL.
local GRASS_TOP_CELL = 8
-- How much the grass darkens toward the tip of the deepest drip.
local DRIP_SHADE = 0.35
-- The grass is dead: straw GRASS drifting into a dull olive where a little
-- life hangs on (GRASS_OLIVE_COVER of it), in soft noise patches this many
-- studs across.
local GRASS_OLIVE = { 0.6, 0.57, 0.35 }
local GRASS_OLIVE_COVER = 0.3
local GRASS_PATCH_SIZE = 6 * DETAIL
-- Within about APRON_WIDTH studs of what stands on the top (wornDistance)
-- the grass is worn down to TRODDEN dirt and gravel, in patches toward the
-- outside. These follow what stands there, not the stones, so DETAIL leaves
-- them alone.
local APRON_WIDTH = 6
local TRODDEN = { 0.47, 0.4, 0.31 }

-- Fixed per-column jitter, so the columns look uneven but every build matches.
local function hash(i: number, j: number): number
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
end

local seed = SEED
local function random(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

-- Height of the slope at a point: the main cone, ridges running down from
-- the summit, and a lower shoulder peak off to one side. The cone is
-- rounded BOWL of the way toward a dome, so the underside reads as a
-- shallow bowl rather than a spike under a flat shelf.
local BOWL = 0.4
local function heightAt(x: number, y: number): number
	local r = math.sqrt(x * x + y * y) / RADIUS
	local angle = math.atan2(y, x)
	local ridges = 1 + 0.12 * math.cos(angle * 5) * r
	local out = math.min(r * ridges, 1)
	local cone = (1 - out) ^ 1.25
	local dome = math.sqrt(1 - out * out)
	local main = PEAK * (cone + (dome - cone) * BOWL)
	local sx, sy = x - 8, y + 5
	local shoulder = 19 * math.max(0, 1 - math.sqrt(sx * sx + sy * sy) / 11) ^ 1.1
	return math.max(main, shoulder)
end

-- The rim's radius at an angle.
local function rimAt(angle: number): number
	local phase = SEED * 1.7
	local wave = 0.5 * math.sin(2 * angle + phase) + 0.3 * math.sin(3 * angle + 2 * phase) + 0.2 * math.sin(5 * angle + 3 * phase)
	return RIM_PUSH * RADIUS * rimShape(angle) * (1 + RIM_WOBBLE * wave)
end

-- Stones scattered by dart throwing, none crowding another, sized by how
-- high on the slope they sit: x, y and size.
local stones = {}
for _ = 1, 8000 do
	local angle, reach = random() * TAU, math.sqrt(random()) * SCATTER
	local x, y = reach * math.cos(angle), reach * math.sin(angle)
	local height = math.clamp(heightAt(x, y) / PEAK, 0, 1)
	local size = (LARGEST + (SMALLEST - LARGEST) * height ^ 0.5) * (0.8 + 0.4 * random())
	local clear = true
	for _, other in stones do
		local dx, dy = x - other[1], y - other[2]
		if dx * dx + dy * dy < ((size + other[3]) * 0.72) ^ 2 then
			clear = false
			break
		end
	end
	if clear then
		table.insert(stones, { x, y, size })
	end
end

-- Cuts a cell outline down to the side of stone q's boundary nearer stone
-- p. Each corner carries the stone across the edge that starts there (nil
-- on the outer rim), so walls can find their neighbour.
local function clip(outline, p, q, neighbour)
	local nx, ny = q[1] - p[1], q[2] - p[2]
	local limit = (q[1] ^ 2 + q[2] ^ 2 - p[1] ^ 2 - p[2] ^ 2 - q[3] ^ 2 + p[3] ^ 2) / 2
	local function side(point)
		return point[1] * nx + point[2] * ny - limit
	end
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = side(a), side(b)
		local crossing = if (sa <= 0) ~= (sb <= 0)
			then { a[1] + (b[1] - a[1]) * sa / (sa - sb), a[2] + (b[2] - a[2]) * sa / (sa - sb) }
			else nil
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
			if crossing then
				table.insert(kept, { crossing[1], crossing[2], neighbour })
			end
		elseif crossing then
			table.insert(kept, { crossing[1], crossing[2], a[3] })
		end
	end
	return kept
end

-- The rim's corners, then each of its sides as a plane n . p <= limit,
-- in order round from angle 0.
local rimSides = {}
do
	local rim = {}
	for i = 0, RIM_SIDES - 1 do
		local angle = i / RIM_SIDES * TAU
		local r = rimAt(angle)
		rim[i + 1] = { r * math.cos(angle), r * math.sin(angle) }
	end
	for i, a in rim do
		local b = rim[i % #rim + 1]
		-- Counter-clockwise, so out is to the right of each side.
		local nx, ny = b[2] - a[2], a[1] - b[1]
		table.insert(rimSides, { nx, ny, nx * a[1] + ny * a[2] })
	end
end

-- Cuts a cell outline down to the inside of one rim side; corners where it
-- crosses carry nil, as on the outer rim.
local function clipToRim(outline, side)
	local nx, ny, limit = side[1], side[2], side[3]
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = a[1] * nx + a[2] * ny - limit, b[1] * nx + b[2] * ny - limit
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
		end
		if (sa <= 0) ~= (sb <= 0) then
			local t = sa / (sa - sb)
			table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, if sa <= 0 then nil else a[3] })
		end
	end
	return kept
end

-- Each stone's column: its outline and its top corners on a slanted plane.
local columns = {}
for index, stone in stones do
	local outline = {}
	for i = 0, 31 do
		local angle = i / 32 * TAU
		table.insert(outline, { SCATTER * math.cos(angle), SCATTER * math.sin(angle), nil })
	end
	for other, neighbour in stones do
		if other ~= index and #outline >= 3 then
			local dx, dy = neighbour[1] - stone[1], neighbour[2] - stone[2]
			if dx * dx + dy * dy < (LARGEST * 3) ^ 2 then
				outline = clip(outline, stone, neighbour, other)
			end
		end
	end
	-- Every cell is trimmed to the rim sides it faces (the rim isn't convex,
	-- so the far sides would cut into its swells); those left with nothing
	-- inside the rim are dropped. A cell's sides are those over the angles
	-- its corners span, and a few either way so neighbours trim alike.
	local low, high, farthest = math.huge, -math.huge, 0
	local heading = math.atan2(stone[2], stone[1])
	for _, corner in outline do
		local offset = (math.atan2(corner[2], corner[1]) - heading + math.pi) % TAU - math.pi
		low, high = math.min(low, offset), math.max(high, offset)
		farthest = math.max(farthest, math.sqrt(corner[1] ^ 2 + corner[2] ^ 2))
	end
	if farthest > RIM_PUSH * RADIUS * (1 - RIM_WOBBLE) then
		local first = math.floor((heading + low) / TAU * RIM_SIDES) - 8
		local last = math.ceil((heading + high) / TAU * RIM_SIDES) + 8
		for k = first, last do
			if #outline < 3 then
				break
			end
			outline = clipToRim(outline, rimSides[k % RIM_SIDES + 1])
		end
	end
	local area = 0
	for i, a in outline do
		local b = outline[i % #outline + 1]
		area += (a[1] * b[2] - b[1] * a[2]) / 2
	end
	-- Only cells the rim leaves nothing of are dropped; a small one kept at
	-- the rim fills its stretch so the edge doesn't notch.
	if #outline < 3 or math.abs(area) < 1e-3 then
		continue
	end
	local cx, cy = 0, 0
	for _, corner in outline do
		cx, cy = cx + corner[1] / #outline, cy + corner[2] / #outline
	end
	local rise = math.max(MIN_LENGTH * (0.8 + 0.4 * hash(index, 5)), heightAt(cx, cy) + (hash(index, 1) - 0.5) * (1 + stone[3]))
	local tiltX, tiltY = (hash(index, 2) - 0.5) * 0.45, (hash(index, 3) - 0.5) * 0.45
	local corners = {}
	-- Neighbouring columns share their edges exactly, so no gap opens
	-- between them.
	for i, corner in outline do
		local z = rise + (corner[1] - cx) * tiltX + (corner[2] - cy) * tiltY
		corners[i] = { corner[1], corner[2], z, corner[3] }
	end
	columns[index] = {
		index = index,
		size = stone[3],
		corners = corners,
		-- The top rises to a low ridge point, so it reads as broken stone.
		peak = { cx, cy, rise + 0.15 * stone[3] * (0.5 + hash(index, 4)) },
	}
end

-- A column as a closed solid: faces as lists of points, wound outward,
-- from the foot (z = 0) up to its slanted top and the low point above it.
local function solidOf(column)
	local bottom = 0
	local corners, peak = column.corners, column.peak
	local count = #corners
	local faces = {}
	local base = {}
	for i = count, 1, -1 do
		table.insert(base, { corners[i][1], corners[i][2], bottom })
	end
	table.insert(faces, base)
	for i = 1, count do
		local a, b = corners[i], corners[i % count + 1]
		table.insert(faces, { { a[1], a[2], bottom }, { b[1], b[2], bottom }, { b[1], b[2], b[3] }, { a[1], a[2], a[3] } })
		table.insert(faces, { { peak[1], peak[2], peak[3] }, { a[1], a[2], a[3] }, { b[1], b[2], b[3] } })
	end
	return faces
end

-- Cuts away everything on the far side of the plane n . p = d, closing the
-- wound with a cap facing along n.
local function carve(faces, n, d)
	local kept, cut = {}, {}
	for _, face in faces do
		local out = {}
		for i, a in face do
			local b = face[i % #face + 1]
			local sa = a[1] * n[1] + a[2] * n[2] + a[3] * n[3] - d
			local sb = b[1] * n[1] + b[2] * n[2] + b[3] * n[3] - d
			if sa <= 0 then
				table.insert(out, a)
			end
			if (sa <= 0) ~= (sb <= 0) then
				local t = sa / (sa - sb)
				local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
				table.insert(out, p)
				table.insert(cut, p)
			end
		end
		if #out >= 3 then
			table.insert(kept, out)
		end
	end
	if #cut < 3 then
		return kept
	end
	-- The cap's corners, sorted round their centre in the plane.
	local mx, my, mz = 0, 0, 0
	for _, p in cut do
		mx, my, mz = mx + p[1] / #cut, my + p[2] / #cut, mz + p[3] / #cut
	end
	local ux, uy, uz = if math.abs(n[3]) < 0.9 then -n[2] else 0, if math.abs(n[3]) < 0.9 then n[1] else -n[3], if math.abs(n[3]) < 0.9 then 0 else n[2]
	local length = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / length, uy / length, uz / length
	local vx, vy, vz = n[2] * uz - n[3] * uy, n[3] * ux - n[1] * uz, n[1] * uy - n[2] * ux
	local cap = {}
	for _, p in cut do
		local ox, oy, oz = p[1] - mx, p[2] - my, p[3] - mz
		local angle = math.atan2(ox * vx + oy * vy + oz * vz, ox * ux + oy * uy + oz * uz)
		local duplicate = false
		for _, other in cap do
			duplicate = duplicate or math.abs(other[2] - angle) < 1e-4
		end
		if not duplicate then
			table.insert(cap, { p, angle })
		end
	end
	table.sort(cap, function(a, b)
		return a[2] < b[2]
	end)
	if #cap >= 3 then
		local face = {}
		for i, entry in cap do
			face[i] = entry[1]
		end
		table.insert(kept, face)
	end
	return kept
end

-- Carve every column first, so walls can be cut against their
-- neighbours' finished shapes.
for _, column in columns do
	local corners, index = column.corners, column.index
	local faces = solidOf(column)
	local outward = math.atan2(column.peak[2], column.peak[1])

	-- Chisel cuts: each faces out and up at its own angle, from a low
	-- slant (shaving a side edge) to steep (bevelling the top), and
	-- bites a set depth in from the farthest point along it. None is
	-- near level, which would open holes down between columns. Every cut
	-- faces away from the island's centre, within CUT_SPREAD either side,
	-- so the carving shows on the outside and never faces inward.
	-- The cuts to make: heading, lift and depth. The big chisel cuts come
	-- first, then fine chips that knock small corners off what is left.
	local cuts = {}
	for k = 1, 1 + math.floor(hash(index, 40) * MAX_CUTS) do
		table.insert(cuts, {
			outward + (hash(index, 40 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 50 + k) * 0.85,
			column.size * (CUT_DEPTH[1] + (CUT_DEPTH[2] - CUT_DEPTH[1]) * hash(index, 60 + k)),
		})
	end
	for k = 1, CHIPS[1] + math.floor(hash(index, 70) * (CHIPS[2] - CHIPS[1] + 1)) do
		table.insert(cuts, {
			outward + (hash(index, 70 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 80 + k) * 1.05,
			CHIP_DEPTH[1] + (CHIP_DEPTH[2] - CHIP_DEPTH[1]) * hash(index, 90 + k),
		})
	end
	for _, cut in cuts do
		local heading, lift, depth = cut[1], cut[2], cut[3]
		local n = { math.cos(heading) * math.cos(lift), math.sin(heading) * math.cos(lift), math.sin(lift) }
		local farthest = -math.huge
		for _, face in faces do
			for _, p in face do
				farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
			end
		end
		-- A cut stops short of the top tier, which follows the grass, so
		-- the wall under the grass is never carved into.
		local tiermost = -math.huge
		for _, corner in corners do
			tiermost = math.max(tiermost, corner[1] * n[1] + corner[2] * n[2] + DIRT_CONFORM * n[3])
		end
		local plane = math.max(farthest - depth, tiermost + 0.3)
		if plane < farthest then
			faces = carve(faces, n, plane)
		end
	end

	column.faces = faces

	-- Where the column's carved underside begins: the shallowest point of
	-- any face that isn't a side wall or its foot.
	column.surfaceFrom = math.huge
	for _, face in faces do
		local foot, nz = true, 0
		for i, p in face do
			local q = face[i % #face + 1]
			foot = foot and p[3] == 0
			nz += (p[1] - q[1]) * (p[2] + q[2])
		end
		if not foot and math.abs(nz) > 1e-3 then
			for _, p in face do
				column.surfaceFrom = math.min(column.surfaceFrom, p[3])
			end
		end
	end
end

-- How deep each column hides behind the tier around it: it comes into view
-- where its shallowest neighbour's underside begins, or at the top if it
-- faces the open edge.
for _, column in columns do
	column.shownFrom = math.huge
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		column.shownFrom = math.min(column.shownFrom, if neighbour then neighbour.surfaceFrom else 0)
	end
end

-- How deep the island hangs at its lowest point.
local islandDepth = 0
for _, column in columns do
	islandDepth = math.max(islandDepth, column.peak[3])
end

-- How far a solid reaches along a direction.
local function farthestAlong(faces, n): number
	local farthest = -math.huge
	for _, face in faces do
		for _, p in face do
			farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
		end
	end
	return farthest
end

-- Cuts a solid's outer bottom edge off, `depth` studs in along a slant facing
-- out from the island's centre and down, `lift` radians up from flat.
local function bevelled(faces, outward: number, depth: number, lift: number)
	local n = { math.cos(outward) * math.cos(lift), math.sin(outward) * math.cos(lift), math.sin(lift) }
	return carve(faces, n, farthestAlong(faces, n) - depth)
end

-- Each rock is dirt down to where it comes through, and stone below, split
-- into a dirt solid and a stone one. The dirt's outer bottom edge is
-- bevelled off, so the stone under it stands proud. Higher up, a patch of a
-- rock's outer face may already show through: the dirt is split into the
-- slab on its outer face and the rest, and the slab into bare stone below a
-- tilted line and dirt above, bevelled like the rest.
for _, column in columns do
	local index, faces = column.index, column.faces
	local share = DIRT_TRANSITION[1] + (DIRT_TRANSITION[2] - DIRT_TRANSITION[1]) * hash(index, 30)
	local dirtLine = islandDepth * share
	column.dirtLine = dirtLine
	if dirtLine <= column.shownFrom then
		column.solids = { { faces = faces, dirt = false } }
		continue
	end
	local shown = column.shownFrom
	local outward = math.atan2(column.peak[2], column.peak[1])
	local bevel = DIRT_BEVEL[1] + (DIRT_BEVEL[2] - DIRT_BEVEL[1]) * hash(index, 31)
	local lift = DIRT_BEVEL_LIFT[1] + (DIRT_BEVEL_LIFT[2] - DIRT_BEVEL_LIFT[1]) * hash(index, 34)
	-- The tilted line passes through dirtLine under the rock's tip.
	local tilt, heading = DIRT_TILT * hash(index, 32), hash(index, 33) * 2 * math.pi
	local down = { math.sin(tilt) * math.cos(heading), math.sin(tilt) * math.sin(heading), math.cos(tilt) }
	local line = down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * dirtLine
	local dirt = bevelled(carve(faces, down, line), outward, bevel, lift)
	local stone = carve(faces, { -down[1], -down[2], -down[3] }, -line)
	column.solids = { { faces = dirt, dirt = true }, { faces = stone, dirt = false } }
	-- The stone shows from below the dirt.
	column.shownFrom = math.min(dirtLine, column.peak[3])

	local middle = (shown + dirtLine) / 2 / islandDepth
	local chance = math.clamp((middle - PATCH_FROM) / (PATCH_FULL - PATCH_FROM), 0, 1)
	if dirtLine - shown <= 1 then
		continue
	end
	-- Each slab is cut from the dirt left after the last, so they sit side
	-- by side round the rock.
	local rest, solids = dirt, { { faces = stone, dirt = false } }
	for k = 1, PATCHES do
		if hash(index, 204 + k * 10) >= chance then
			continue
		end
		local heading = outward + (hash(index, 205 + k * 10) - 0.5) * 2 * PATCH_SPREAD
		local lean = (hash(index, 300 + k * 10) - 0.5) * 2 * PATCH_LEAN
		local size = math.sqrt(1 + lean * lean)
		local across = { math.cos(heading) / size, math.sin(heading) / size, lean / size }
		local thickness = PATCH_THICKNESS[1] + (PATCH_THICKNESS[2] - PATCH_THICKNESS[1]) * hash(index, 206 + k * 10)
		local face = farthestAlong(rest, across) - thickness
		local slab = carve(rest, { -across[1], -across[2], -across[3] }, -face)
		rest = carve(rest, across, face)
		-- The slab's top line, tilted, somewhere down what shows of the rock:
		-- above it dirt, below it bare rock.
		local function topLine(seed: number)
			local top = shown + (dirtLine - shown) * (0.05 + 0.45 * hash(index, seed))
			local tx = (hash(index, seed + 1) - 0.5) * 2 * PATCH_TILT
			local ty = (hash(index, seed + 2) - 0.5) * 2 * PATCH_TILT
			local length = math.sqrt(tx * tx + ty * ty + 1)
			local down = { tx / length, ty / length, 1 / length }
			-- Never above the top tier anywhere across the slab.
			local level = -math.huge
			for _, f in slab do
				for _, p in f do
					level = math.max(level, down[1] * p[1] + down[2] * p[2] + down[3] * DIRT_CONFORM)
				end
			end
			return down, math.max(down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * top, level)
		end
		local down, line = topLine(207 + k * 10)
		table.insert(solids, { faces = bevelled(carve(slab, down, line), heading, bevel * 0.7, lift), dirt = true })
		local bare = carve(slab, { -down[1], -down[2], -down[3] }, -line)
		-- A second line peaks the rock: the dirt it cuts off stays dirt.
		if hash(index, 320 + k * 10) < PATCH_PEAKED then
			local second, secondLine = topLine(330 + k * 10)
			table.insert(solids, { faces = bevelled(carve(bare, second, secondLine), heading, bevel * 0.7, lift), dirt = true })
			bare = carve(bare, { -second[1], -second[2], -second[3] }, -secondLine)
		end
		-- Chipped into a rough stone rather than a flat slab.
		local chips = PATCH_CHIPS[1] + math.floor(hash(index, 400 + k * 10) * (PATCH_CHIPS[2] - PATCH_CHIPS[1] + 1))
		for c = 1, chips do
			local seed = 500 + k * 100 + c * 7
			local yaw = heading + (hash(index, seed) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local pitch = (hash(index, seed + 1) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local n = { math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch) }
			local depth = PATCH_CHIP_DEPTH[1] + (PATCH_CHIP_DEPTH[2] - PATCH_CHIP_DEPTH[1]) * hash(index, seed + 2)
			local plane = farthestAlong(bare, n) - depth
			if plane > -math.huge then
				bare = carve(bare, n, plane)
			end
		end
		table.insert(solids, { faces = bare, dirt = false })
	end
	table.insert(solids, { faces = rest, dirt = true })
	column.solids = solids
end

-- Each face's plane, as a unit normal pointing out and its distance.
local function planeOf(face)
	local nx, ny, nz = 0, 0, 0
	for i, a in face do
		local b = face[i % #face + 1]
		nx += (a[2] - b[2]) * (a[3] + b[3])
		ny += (a[3] - b[3]) * (a[1] + b[1])
		nz += (a[1] - b[1]) * (a[2] + b[2])
	end
	local length = math.sqrt(nx * nx + ny * ny + nz * nz)
	if length < 1e-9 then
		return nil
	end
	nx, ny, nz = nx / length, ny / length, nz / length
	local p = face[1]
	return { nx, ny, nz, nx * p[1] + ny * p[2] + nz * p[3] }
end

-- Splits a face by a plane into the part outside it and the part inside.
local EPSILON = 1e-5
local function split(face, plane)
	local outside, inside = {}, {}
	local function side(p)
		local s = plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
		return if math.abs(s) < EPSILON then 0 else s
	end
	for i, a in face do
		local b = face[i % #face + 1]
		local sa, sb = side(a), side(b)
		if sa >= 0 then
			table.insert(outside, a)
		end
		if sa <= 0 then
			table.insert(inside, a)
		end
		if (sa > 0 and sb < 0) or (sa < 0 and sb > 0) then
			local t = sa / (sa - sb)
			local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
			table.insert(outside, p)
			table.insert(inside, p)
		end
	end
	return outside, inside
end

local function area(face): number
	local plane = planeOf(face)
	if not plane or #face < 3 then
		return 0
	end
	local total = 0
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
		total += ((uy * vz - uz * vy) * plane[1] + (uz * vx - ux * vz) * plane[2] + (ux * vy - uy * vx) * plane[3]) / 2
	end
	return total
end

-- The parts of a face that don't lie inside a neighbour. Only a face lying
-- against one of the neighbour's own faces can touch it; that face's plane
-- is skipped, and the face is carved by the rest, every piece that falls
-- outside one of them showing.
local function uncovered(face, neighbour)
	local own = planeOf(face)
	if not own then
		return {}
	end
	local touching, planes = false, {}
	for _, other in neighbour.faces do
		local plane = planeOf(other)
		if plane then
			local facing = own[1] * plane[1] + own[2] * plane[2] + own[3] * plane[3] < -0.9999
			local p = face[1]
			if facing and math.abs(plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]) < 1e-4 then
				touching = true
			else
				table.insert(planes, plane)
			end
		end
	end
	if not touching then
		return { face }
	end
	local shown, rest = {}, face
	for _, plane in planes do
		local outside, inside = split(rest, plane)
		if #outside >= 3 and area(outside) > 1e-4 then
			table.insert(shown, outside)
		end
		rest = inside
		if #rest < 3 or area(rest) <= 1e-4 then
			break
		end
	end
	return shown
end

-- Columns bucketed by the 2-stud cells their outlines cover, so paint can
-- find the rock under a point without testing them all.
local CELL = 2
local cells = {}
for _, column in columns do
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, corner in column.corners do
		x0, y0 = math.min(x0, corner[1]), math.min(y0, corner[2])
		x1, y1 = math.max(x1, corner[1]), math.max(y1, corner[2])
	end
	for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
		for cy = math.floor(y0 / CELL), math.floor(y1 / CELL) do
			local cellKey = `{cx},{cy}`
			cells[cellKey] = cells[cellKey] or {}
			table.insert(cells[cellKey], column)
		end
	end
end

-- The rock a point on the island belongs to. On a wall two rocks share,
-- the deeper one owns it, since only its wall shows there.
local function rockAt(x: number, y: number)
	local found = nil
	for _, column in cells[`{math.floor(x / CELL)},{math.floor(y / CELL)}`] or {} do
		local corners, within = column.corners, true
		for i, a in corners do
			local b = corners[i % #corners + 1]
			if (b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1]) < -1e-3 then
				within = false
				break
			end
		end
		if within and (found == nil or column.peak[3] > found.peak[3]) then
			found = column
		end
	end
	return found
end

-- The splotch on top at a point, as its tone and warmth shifts (0, 0 where
-- none reaches). Of the splotches covering a point, the one laid last wins.
local function splotchAt(x: number, y: number, z: number): (number, number)
	local size = SPLOTCH.cell
	local gx, gy, gz = math.floor(x / size), math.floor(y / size), math.floor(z / size)
	local tone, warm, order = 0, 0, -1
	for i = gx - 1, gx + 1 do
		for j = gy - 1, gy + 1 do
			for k = gz - 1, gz + 1 do
				local seed = i * 7.31 + k * 3.17
				if hash(seed, j + 101) < SPLOTCH.chance then
					local cx = (i + hash(seed, j + 201)) * size
					local cy = (j + hash(seed, j + 301)) * size
					local cz = (k + hash(seed, j + 401)) * size
					local radius = SPLOTCH.radius[1] + (SPLOTCH.radius[2] - SPLOTCH.radius[1]) * hash(seed, j + 501)
					local dx, dy, dz = x - cx, y - cy, z - cz
					-- Lobed rim, so a blot isn't a clean circle.
					local lobes = 1 + 0.25 * math.noise(dx / radius * 1.5 + i, dy / radius * 1.5 + j, dz / radius * 1.5 + k)
					local laid = hash(seed, j + 601)
					if dx * dx + dy * dy + dz * dz < (radius * lobes) ^ 2 and laid > order then
						order = laid
						tone = (hash(seed, j + 701) - 0.5) * 2 * SPLOTCH.tone
						warm = (hash(seed, j + 801) - 0.5) * 2 * SPLOTCH.tint
					end
				end
			end
		end
	end
	return tone, warm
end

-- Per-rock gradient over the part of a rock that shows: light where it
-- comes out from behind the tier around it, darkening toward its tip. The
-- island hangs below z = 0, so depth is -z. Near the top the rock is dirt,
-- fading to stone further down.
-- How far from dirt toward stone the colour has blended at a point, 0 to 1.
local function stoneAt(x: number, y: number, z: number): number
	local share = -z / islandDepth + COLOR_WOBBLE * math.noise(x * 0.15 / DETAIL, y * 0.15 / DETAIL, z * 0.15 / DETAIL)
	local t = math.clamp((share - COLOR_TRANSITION[1]) / (COLOR_TRANSITION[2] - COLOR_TRANSITION[1]), 0, 1)
	return t * t * (3 - 2 * t)
end

-- A colour between dirt and stone, `t` of the way to stone.
local function soil(t: number): (number, number, number)
	return DIRT[1] + (STONE[1] - DIRT[1]) * t, DIRT[2] + (STONE[2] - DIRT[2]) * t, DIRT[3] + (STONE[3] - DIRT[3]) * t
end

local paintRock = rusting(0.1, function(x, y, z)
	local rock = rockAt(x, y)
	local depth = if rock
		then math.clamp((-z - rock.shownFrom) / math.max(rock.peak[3] - rock.shownFrom, 0.5), 0, 1)
		else 0
	local shade = ROCK_GRADIENT[1] + (ROCK_GRADIENT[2] - ROCK_GRADIENT[1]) * depth ^ 0.8
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local blend = stoneAt(x, y, z)
	local r, g, b = soil(DIRT_LEAD + (1 - DIRT_LEAD) * blend)
	-- Dirt traces: blotches whose share of the stone shrinks below the line.
	if rock then
		local below = -z - rock.dirtLine
		local amount = if below < 0 then DIRT_DUSTING else math.max(0, 1 - below / DIRT_TRACE) ^ 1.5
		local f = 0.7 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f) + 0.25 * math.noise(x * f * 3, y * f * 3, z * f * 3)
		local trace = math.clamp((blot - (1 - 0.7 * amount)) / 0.08, 0, 1)
		if trace > 0 then
			local dr, dg, db = soil(0.25 * blend)
			r, g, b = r + (dr - r) * trace, g + (dg - g) * trace, b + (db - b) * trace
		end
	end
	local share = -z / islandDepth
	-- Grime: soft-edged patches, less of them deeper down.
	local growth = math.clamp((GRIME_REACH - share) / (GRIME_REACH - DIRT_TRANSITION[1]), 0, 1)
	if growth > 0 then
		local f = 0.45 / DETAIL
		local patch = 0.5 + 0.5 * math.noise(x * f + 31, y * f, z * f) + 0.2 * math.noise(x * f * 3.6, y * f * 3.6 + 17, z * f * 3.6)
		local grime = math.clamp((patch - (1 - GRIME_COVER * growth)) / 0.1, 0, 1)
		r, g, b = r + (GRIME[1] - r) * grime, g + (GRIME[2] - g) * grime, b + (GRIME[3] - b) * grime
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Dirt darkens a little with depth, greys toward stone, and is splotched
-- like the stone.
local paintDirt = rusting(0.05, function(x, y, z)
	local shade = 1.05 - 0.3 * math.clamp(-z / (islandDepth * DIRT_TRANSITION[2]), 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local r, g, b = soil((1 - DIRT_LEAD) * stoneAt(x, y, z))
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Flipped upside down as it is written out: z mirrors, and the winding
-- reverses so faces still point outward. The foot becomes the island's top.
local function addFlipped(mesh, face)
	local verts = {}
	for i, p in face do
		verts[#face + 1 - i] = mesh:vertex(p[1], p[2], -p[3])
	end
	mesh:face(verts)
end

-- The island is split into cubic chunks, each with its own texture, so the
-- stone reads sharp at one density everywhere.
useTexelDensity(TEXEL_DENSITY)

-- A unit vector along x, y, z, and the cross product of two vectors.
local function unit(x: number, y: number, z: number)
	local length = math.max(math.sqrt(x * x + y * y + z * z), 1e-9)
	return { x / length, y / length, z / length }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The solids that may cover a solid of a column: the column's other pieces
-- and its neighbours'.
local function coverersOf(column, solid)
	local others = {}
	for _, other in column.solids do
		if other ~= solid then
			table.insert(others, other)
		end
	end
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		if neighbour then
			for _, other in neighbour.solids do
				table.insert(others, other)
			end
		end
	end
	return others
end

-- What of a face no other solid covers.
local function exposed(face, others)
	local pieces = { face }
	for _, other in others do
		local kept = {}
		for _, piece in pieces do
			for _, part in uncovered(piece, other) do
				table.insert(kept, part)
			end
		end
		pieces = kept
	end
	return pieces
end

local function isFoot(face): boolean
	for _, p in face do
		if p[3] ~= 0 then
			return false
		end
	end
	return true
end

-- Rounds a convex solid's edges and corners where faces that show meet, on
-- DIRT_ROUND. Each such edge is cut by planes turning from one face to the
-- other, each touching a cylinder of that radius set in from both faces;
-- each such corner by one plane facing out between its faces.
local function rounded(faces, shows)
	local planes = {}
	for i, face in faces do
		planes[i] = planeOf(face)
	end
	local function key(p)
		return `{math.round(p[1] * 1e4)},{math.round(p[2] * 1e4)},{math.round(p[3] * 1e4)}`
	end
	local edgeFaces, cornerFaces, points = {}, {}, {}
	for i, face in faces do
		if not planes[i] or not shows[i] then
			continue
		end
		for k, a in face do
			local b = face[k % #face + 1]
			local ka, kb = key(a), key(b)
			points[ka] = a
			local edge = if ka < kb then `{ka}|{kb}` else `{kb}|{ka}`
			edgeFaces[edge] = edgeFaces[edge] or { a = a }
			table.insert(edgeFaces[edge], i)
			cornerFaces[ka] = cornerFaces[ka] or {}
			cornerFaces[ka][i] = true
		end
	end
	local cuts = {}
	for _, edge in edgeFaces do
		if #edge ~= 2 then
			continue
		end
		local n1, n2 = planes[edge[1]], planes[edge[2]]
		local cosine = n1[1] * n2[1] + n1[2] * n2[2] + n1[3] * n2[3]
		if cosine > 0.985 then
			continue
		end
		local p = edge.a
		local inset = DIRT_ROUND / (1 + cosine)
		local centre = { p[1] - (n1[1] + n2[1]) * inset, p[2] - (n1[2] + n2[2]) * inset, p[3] - (n1[3] + n2[3]) * inset }
		for k = 1, DIRT_ROUND_STEPS do
			local t = k / (DIRT_ROUND_STEPS + 1)
			local m = unit(n1[1] + (n2[1] - n1[1]) * t, n1[2] + (n2[2] - n1[2]) * t, n1[3] + (n2[3] - n1[3]) * t)
			table.insert(cuts, { m, m[1] * centre[1] + m[2] * centre[2] + m[3] * centre[3] + DIRT_ROUND })
		end
	end
	for corner, touching in cornerFaces do
		local sum, count = { 0, 0, 0 }, 0
		for i in touching do
			sum = { sum[1] + planes[i][1], sum[2] + planes[i][2], sum[3] + planes[i][3] }
			count += 1
		end
		if count >= 3 then
			local m = unit(sum[1], sum[2], sum[3])
			local v = points[corner]
			table.insert(cuts, { m, m[1] * v[1] + m[2] * v[2] + m[3] * v[3] - DIRT_ROUND * 0.6 })
		end
	end
	for _, cut in cuts do
		faces = carve(faces, cut[1], cut[2])
	end
	return faces
end

-- Round the dirt where it shows: which faces show is settled for every
-- solid first, so rounding one doesn't change what its neighbours see.
do
	local plans = {}
	for _, column in columns do
		for _, solid in column.solids do
			if not solid.dirt then
				continue
			end
			local others, shows = coverersOf(column, solid), {}
			for i, face in solid.faces do
				local whole = area(face)
				if whole > 1e-4 and not isFoot(face) then
					local open = 0
					for _, piece in exposed(face, others) do
						open += area(piece)
					end
					shows[i] = open > whole * 0.5
				end
			end
			table.insert(plans, { solid = solid, shows = shows })
		end
	end
	for _, plan in plans do
		plan.solid.faces = rounded(plan.solid.faces, plan.shows)
	end
end

-- The faces of every column's dirt or stone that show. Only what no other
-- solid covers is kept, another piece of its own column or a neighbour's,
-- so nothing lies buried inside the island. The flat top is left open: the
-- grass covers it.
local function visibleRock(dirt: boolean)
	local shown = {}
	for _, column in columns do
		for _, solid in column.solids do
			if solid.dirt ~= dirt then
				continue
			end
			local others = coverersOf(column, solid)
			for _, face in solid.faces do
				if isFoot(face) then
					continue
				end
				for _, piece in exposed(face, others) do
					table.insert(shown, piece)
				end
			end
		end
	end
	return shown
end

local dirtFaces = visibleRock(true)

-- A box around a centre, `r` from it each way, its faces wound outward.
local function boxAround(c, r)
	local x0, x1, y0, y1, z0, z1 = c[1] - r, c[1] + r, c[2] - r, c[2] + r, c[3] - r, c[3] + r
	return {
		{ { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 }, { x1, y0, z0 } },
		{ { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } },
		{ { x0, y0, z0 }, { x1, y0, z0 }, { x1, y0, z1 }, { x0, y0, z1 } },
		{ { x0, y1, z0 }, { x0, y1, z1 }, { x1, y1, z1 }, { x1, y1, z0 } },
		{ { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } },
		{ { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 }, { x1, y0, z1 } },
	}
end

-- The stones in the dirt, each as the faces that stand out of it. A stone
-- is a box turned at random and chipped at its corners, sunk into a dirt
-- face, and cut off at that face so nothing of it lies buried.
local pebbleSeed = 7
local function pebbleRandom(): number
	pebbleSeed = (pebbleSeed * 16807) % 2147483647
	return pebbleSeed / 2147483647
end
-- How far a point lies from the nearest edge of a face.
local function edgeDistance(face, p): number
	local nearest = math.huge
	for i, a in face do
		local b = face[i % #face + 1]
		local ab = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local length = ab[1] ^ 2 + ab[2] ^ 2 + ab[3] ^ 2
		local t = if length > 0 then math.clamp(((p[1] - a[1]) * ab[1] + (p[2] - a[2]) * ab[2] + (p[3] - a[3]) * ab[3]) / length, 0, 1) else 0
		local dx, dy, dz = p[1] - a[1] - ab[1] * t, p[2] - a[2] - ab[2] * t, p[3] - a[3] - ab[3] * t
		nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy + dz * dz))
	end
	return nearest
end

local pebbles = {}
-- Where cracks start: each stone's face, normal, centre on the dirt and how
-- far its rim reaches.
local crackOrigins = {}
-- Each stone as where it meets the dirt (point and outward normal, already
-- flipped) and how far it stands out, bucketed by 2-stud cell for its paint.
local pebbleCells = {}
local function pebbleCell(x: number, y: number, z: number): string
	return `{math.floor(x / 2)},{math.floor(y / 2)},{math.floor(z / 2)}`
end
for _, face in dirtFaces do
	local plane = planeOf(face)
	if not plane then
		continue
	end
	local n = { plane[1], plane[2], plane[3] }
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local triangle = area({ a, b, c })
		local depth = (a[3] + b[3] + c[3]) / 3
		local toward = math.clamp(depth / (islandDepth * DIRT_TRANSITION[1]), 0, 1)
		local density = STONE_BITS[1] + (STONE_BITS[2] - STONE_BITS[1]) * toward
		local count = math.floor(triangle * density + pebbleRandom())
		for _ = 1, count do
			local u, v = pebbleRandom(), pebbleRandom()
			if u + v > 1 then
				u, v = 1 - u, 1 - v
			end
			local p = {
				a[1] + (b[1] - a[1]) * u + (c[1] - a[1]) * v,
				a[2] + (b[2] - a[2]) * u + (c[2] - a[2]) * v,
				a[3] + (b[3] - a[3]) * u + (c[3] - a[3]) * v,
			}
			local size = STONE_BIT_SIZE[1] + (STONE_BIT_SIZE[2] - STONE_BIT_SIZE[1]) * pebbleRandom() ^ STONE_BIT_SKEW
			-- A stone too big for the room it has on its face is made smaller,
			-- so it never hangs off an edge.
			size = math.min(size, edgeDistance(face, p) * 2.2)
			local r = size / 2
			if p[3] < STONE_BIT_CLEAR or size < STONE_BIT_SIZE[1] * 0.8 then
				continue
			end
			local rise = STONE_BIT_RISE[1] + (STONE_BIT_RISE[2] - STONE_BIT_RISE[1]) * pebbleRandom()
			table.insert(crackOrigins, { face = face, normal = n, at = p, rim = r * 1.0 })
			local centre = { p[1] + n[1] * r * (2 * rise - 1), p[2] + n[2] * r * (2 * rise - 1), p[3] + n[3] * r * (2 * rise - 1) }
			-- A box turned at random: start big, and cut each side in to r.
			local x = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
			local y = cross(x, unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5))
			y = unit(y[1], y[2], y[3])
			local z = cross(x, y)
			local stone = boxAround(centre, size * 2)
			for _, axis in { x, y, z } do
				for _, sign in { 1, -1 } do
					local d = { axis[1] * sign, axis[2] * sign, axis[3] * sign }
					local reach = r * (0.75 + 0.35 * pebbleRandom())
					stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + reach)
				end
			end
			-- Chips knock its corners off.
			for _ = 1, 9 do
				local d = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
				stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + r * (0.65 + 0.25 * pebbleRandom()))
			end
			-- Cut off at the dirt: only what stands out of it is kept, and the
			-- cap the cut leaves lies against the dirt, so it goes too.
			local level = n[1] * p[1] + n[2] * p[2] + n[3] * p[3]
			stone = carve(stone, { -n[1], -n[2], -n[3] }, -level)
			local record = { point = { p[1], p[2], -p[3] }, normal = { n[1], n[2], -n[3] }, height = size * rise, reach = size }
			for cx = -1, 1 do
				for cy = -1, 1 do
					for cz = -1, 1 do
						local key = pebbleCell(p[1] + cx * 2, p[2] + cy * 2, -p[3] + cz * 2)
						pebbleCells[key] = pebbleCells[key] or {}
						table.insert(pebbleCells[key], record)
					end
				end
			end
			for _, piece in stone do
				local onDirt = true
				for _, q in piece do
					onDirt = onDirt and math.abs(n[1] * q[1] + n[2] * q[2] + n[3] * q[3] - level) < 1e-6
				end
				if not onDirt then
					table.insert(pebbles, piece)
				end
			end
		end
	end
end

-- The cracks, drawn over the dirt's coat as tapering brush strokes, one per
-- step of a crack (already flipped).
local crackStrokes = {}
local crackSeed = 3
local function crackRandom(): number
	crackSeed = (crackSeed * 16807) % 2147483647
	return crackSeed / 2147483647
end
-- Whether a point lies inside a convex face, `margin` studs in from its edges.
local function insideFace(face, n, p, margin: number): boolean
	for i, a in face do
		local b = face[i % #face + 1]
		local edge = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local inward = unit(table.unpack(cross(n, edge)))
		if (p[1] - a[1]) * inward[1] + (p[2] - a[2]) * inward[2] + (p[3] - a[3]) * inward[3] < margin then
			return false
		end
	end
	return true
end
-- A direction turned by `angle` about the face's normal.
local function turned(v, n, angle: number)
	local side = cross(n, v)
	local c, s = math.cos(angle), math.sin(angle)
	return { v[1] * c + side[1] * s, v[2] * c + side[2] * s, v[3] * c + side[3] * s }
end
-- A jagged line from `start` heading along `heading` in a face, stopping
-- short of its edges.
local function crackLine(face, n, start, heading, length: number)
	local points = { start }
	local step = length / CRACK_SEGMENTS
	local at, way = start, heading
	for _ = 1, CRACK_SEGMENTS do
		way = turned(way, n, (crackRandom() - 0.5) * 1.1)
		local nextAt = { at[1] + way[1] * step, at[2] + way[2] * step, at[3] + way[3] * step }
		if not insideFace(face, n, nextAt, 0.04 * DETAIL) then
			break
		end
		table.insert(points, nextAt)
		at = nextAt
	end
	return points
end
-- Lays a line down as a crack `width` wide at its start, thinning evenly
-- along its length to nothing at its end.
local function addCrack(points, normal, width: number)
	if #points < 2 then
		return
	end
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	local travelled = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		local widthA = width * (1 - travelled / total)
		local widthB = width * (1 - (travelled + length) / total)
		travelled += length
		local start = { a[1], a[2], -a[3] }
		local along = { (b[1] - a[1]) / length, (b[2] - a[2]) / length, -(b[3] - a[3]) / length }
		local facing = { normal[1], normal[2], -normal[3] }
		local function stroke(at, width: number, color)
			table.insert(crackStrokes, { start = at, along = along, normal = facing, length = length, width = width, tail = widthB / widthA, color = color })
		end
		-- The lip sits on the crack's lower side, half a crack's width over.
		local across = cross(facing, along)
		local side = if across[3] > 0 then -1 else 1
		local shift = widthA * 0.5 * side
		stroke({ start[1] + across[1] * shift, start[2] + across[2] * shift, start[3] + across[3] * shift }, widthA * 0.8, CRACK_LIP)
		stroke(start, widthA, CRACK)
		stroke(start, widthA * CRACK_CORE_WIDTH, CRACK_CORE)
	end
end

for _, origin in crackOrigins do
	if crackRandom() >= CRACK_CHANCE then
		continue
	end
	local face, n, at = origin.face, origin.normal, origin.at
	-- Some way across the face, to turn into each crack's heading.
	local first = face[1]
	local outward = unit(first[1] - at[1], first[2] - at[2], first[3] - at[3])
	for _ = 1, 1 + math.floor(crackRandom() * CRACKS) do
		local heading = turned(outward, n, crackRandom() * TAU)
		local start = { at[1] + heading[1] * origin.rim, at[2] + heading[2] * origin.rim, at[3] + heading[3] * origin.rim }
		if not insideFace(face, n, start, 0.04 * DETAIL) then
			continue
		end
		local length = CRACK_LENGTH[1] + (CRACK_LENGTH[2] - CRACK_LENGTH[1]) * crackRandom()
		local width = CRACK_WIDTH[1] + (CRACK_WIDTH[2] - CRACK_WIDTH[1]) * crackRandom()
		local line = crackLine(face, n, start, heading, length)
		addCrack(line, n, width)
		-- A fork off partway along, thinner and shorter.
		if #line >= 3 and crackRandom() < CRACK_BRANCH then
			local from = line[2]
			local share = 1 / (#line - 1)
			local away = unit(line[3][1] - from[1], line[3][2] - from[2], line[3][3] - from[3])
			local fork = turned(away, n, (if crackRandom() < 0.5 then -1 else 1) * (0.5 + 0.4 * crackRandom()))
			addCrack(crackLine(face, n, from, fork, length * 0.5), n, width * (1 - share) * 0.8)
		end
	end
end


-- The stones are grey, splotched like the rest and stained with the dirt
-- they sit in: solid at the dirt line, in blotches higher up.
local paintPebble = rusting(0.1, function(x, y, z)
	local tone, warm = splotchAt(x, y, z)
	local shade = 1 + tone * 1.5
	local r, g, b = PEBBLE[1], PEBBLE[2], PEBBLE[3]
	-- The stone this point is on: the nearest whose dirt line it sits above.
	local height, best = math.huge, math.huge
	for _, record in pebbleCells[pebbleCell(x, y, z)] or {} do
		local q, n = record.point, record.normal
		local dx, dy, dz = x - q[1], y - q[2], z - q[3]
		local distance = dx * dx + dy * dy + dz * dz
		if distance < record.reach * record.reach and distance < best then
			best = distance
			height = (dx * n[1] + dy * n[2] + dz * n[3]) / math.max(record.height, 0.05)
		end
	end
	if height < STONE_BIT_STAIN then
		local f = 2.2 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f)
		local stain = math.clamp((blot - height / STONE_BIT_STAIN) / 0.12, 0, 1)
		local dr, dg, db = soil(0.15 * stoneAt(x, y, z))
		r, g, b = r + (dr - r) * stain, g + (dg - g) * stain, b + (db - b) * stain
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Columns", nil, STONE, function(mesh)
	for _, piece in visibleRock(false) do
		addFlipped(mesh, piece)
	end
end, false, paintRock, true, EDGE_REACH)

chunkedPart("Dirt", nil, DIRT, function(mesh)
	for _, piece in dirtFaces do
		addFlipped(mesh, piece)
	end
end, nil, paintDirt, true, EDGE_REACH)

chunkedPart("Pebbles", nil, PEBBLE, function(mesh)
	for _, piece in pebbles do
		addFlipped(mesh, piece)
	end
end, false, paintPebble, true, EDGE_REACH)

-- The rim walked in even steps, each point pushed out from the stone by the
-- grass's outset (outer) and a hair's width (inner), with how deep the grass
-- hangs there.
local function grassRim()
	-- The rim the stones are trimmed to, walked clockwise seen from above
	-- in GRASS_STEP strides, so the grass follows it exactly.
	local points = {}
	local steps = math.ceil(TAU * RIM_PUSH * RADIUS * RIM_REACH * (1 + RIM_WOBBLE) / GRASS_STEP)
	for k = 0, steps - 1 do
		local angle = -k / steps * TAU
		local r = rimAt(angle)
		table.insert(points, { r * math.cos(angle), r * math.sin(angle) })
	end
	local count = #points

	-- Blurs a list of numbers round the loop: repeated passes of a 1-2-1
	-- average, each spreading it by half a step squared, until it spreads
	-- `studs`.
	local function blurLoop(values: { number }, studs: number)
		for _ = 1, math.round(2 * (studs / GRASS_STEP) ^ 2) do
			local before = table.clone(values)
			for i = 1, #values do
				values[i] = (before[(i - 2) % #values + 1] + 2 * before[i] + before[i % #values + 1]) / 4
			end
		end
	end
	local raw = table.clone(points)
	for axis = 1, 2 do
		local coordinates = {}
		for i, p in points do
			coordinates[i] = p[axis]
		end
		blurLoop(coordinates, GRASS_CORNER_BLUR)
		for i = 1, count do
			points[i] = table.clone(points[i])
			points[i][axis] = coordinates[i]
		end
	end
	-- Blurring cuts the outside corners in, uncovering the stone there, so
	-- the rim swells back out round each one: by the most it was cut in
	-- anywhere near, blurred so the swell has no edge of its own.
	local cut, outward = {}, {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		outward[i] = { -dy / length, dx / length }
		cut[i] = math.max(0, (raw[i][1] - p[1]) * outward[i][1] + (raw[i][2] - p[2]) * outward[i][2])
	end
	local reach = math.ceil(2 * GRASS_CORNER_BLUR / GRASS_STEP)
	local swell = {}
	for i = 1, count do
		local most = 0
		for k = -reach, reach do
			most = math.max(most, cut[(i + k - 1) % count + 1])
		end
		swell[i] = most
	end
	blurLoop(swell, GRASS_CORNER_BLUR)
	for i, p in points do
		p[1] += outward[i][1] * swell[i]
		p[2] += outward[i][2] * swell[i]
	end

	-- The lip wanders between its shallowest and deepest, and drips hang
	-- from it as rounded tongues, each overlapping the next.
	local along, travelled = {}, 0
	for i, p in points do
		along[i] = travelled
		local q = points[i % count + 1]
		travelled += math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
	end
	local function halfWidth(n)
		return (DRIP_WIDTH[1] + (DRIP_WIDTH[2] - DRIP_WIDTH[1]) * hash(n, 21)) / 2
	end
	local drips, at, n = {}, 0, 0
	while at < travelled do
		n += 1
		table.insert(drips, { at, halfWidth(n), DRIP_LENGTH[1] + (DRIP_LENGTH[2] - DRIP_LENGTH[1]) * hash(n, 22) })
		at += (halfWidth(n) + halfWidth(n + 1)) * (1 - DRIP_OVERLAP)
	end

	-- The outline is wound clockwise seen from above, so out is to the left
	-- of each step. A point's way out averages the steps either side of it.
	local rim = {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		local ox, oy = -dy / length, dx / length
		local s = along[i]
		local depth = GRASS_LIP[1] + (GRASS_LIP[2] - GRASS_LIP[1]) * (0.5 + 0.5 * math.noise(s * 0.3 / DETAIL, 3.7))
		for _, drip in drips do
			-- The distance round the rim either way, so drips near the
			-- start also reach the end.
			local gap = math.abs(s - drip[1])
			gap = math.min(gap, travelled - gap)
			if gap < drip[2] then
				depth = math.max(depth, GRASS_LIP[1] + drip[3] * math.sqrt(1 - (gap / drip[2]) ^ 2))
			end
		end
		-- The finer octave never lifts the edge above the stone's top.
		depth = math.max(depth + DRIP_DETAIL * math.noise(s * DRIP_DETAIL_FREQUENCY, 8.1), 0.15 * DETAIL)
		table.insert(rim, {
			outer = { p[1] + ox * GRASS_OUTSET, p[2] + oy * GRASS_OUTSET },
			out = { ox, oy },
			inner = { p[1] + ox * 0.02 * DETAIL, p[2] + oy * 0.02 * DETAIL },
			depth = depth,
		})
	end

	local depths = {}
	for i, point in rim do
		depths[i] = point.depth
	end
	blurLoop(depths, GRASS_DEPTH_BLUR)
	for i, point in rim do
		point.depth = depths[i]
	end

	-- Pushed out of a sharp inward notch, the outer line crosses itself; the
	-- loop it makes is cut away at the crossing.
	local function crossing(a, b, c, d)
		local rx, ry, sx, sy = b[1] - a[1], b[2] - a[2], d[1] - c[1], d[2] - c[2]
		local denominator = rx * sy - ry * sx
		if math.abs(denominator) < 1e-12 then
			return nil
		end
		local t = ((c[1] - a[1]) * sy - (c[2] - a[2]) * sx) / denominator
		local u = ((c[1] - a[1]) * ry - (c[2] - a[2]) * rx) / denominator
		if t <= 0 or t >= 1 or u <= 0 or u >= 1 then
			return nil
		end
		return { a[1] + rx * t, a[2] + ry * t }
	end
	local i = 1
	while i < #rim do
		for k = 2, 12 do
			local j = i + k
			if j + 1 > #rim then
				break
			end
			local hit = crossing(rim[i].outer, rim[i + 1].outer, rim[j].outer, rim[j + 1].outer)
			if hit then
				local kept = rim[i]
				for _ = i + 1, j do
					table.remove(rim, i + 1)
				end
				table.insert(rim, i + 1, { outer = hit, out = kept.out, inner = kept.inner, depth = kept.depth })
				break
			end
		end
		i += 1
	end
	return rim
end

-- How deep the deepest drip hangs, for the grass's shading.
local GRASS_DEEPEST = GRASS_LIP[1] + DRIP_LENGTH[2]

-- Grass is dead straw with olive patches, darkening down
-- the hanging edge toward the drip tips, and splotched like the stone.
local paintGrass = rusting(0, function(x, y, z)
	local shade = 1 - DRIP_SHADE * math.clamp(-z / GRASS_DEEPEST, 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	-- Patch strength from soft noise: 0 outside, 1 well inside a patch
	-- covering `cover` of the grass.
	local function patch(cover: number, seed: number): number
		local u, v = x / GRASS_PATCH_SIZE + seed, y / GRASS_PATCH_SIZE
		local n = 0.5 + math.noise(u, v, seed) + 0.3 * math.noise(u * 3, v * 3, seed + 5)
		return math.clamp((n - (1 - cover)) / 0.12, 0, 1)
	end
	local function toward(r, g, b, c, t)
		return r + (c[1] - r) * t, g + (c[2] - g) * t, b + (c[3] - b) * t
	end
	local r, g, b = toward(GRASS[1], GRASS[2], GRASS[3], GRASS_OLIVE, patch(GRASS_OLIVE_COVER, 11.3))
	-- The worn apron round what stands on the top.
	local outside = wornDistance(x, y)
	local wobble = 0.4 * APRON_WIDTH * math.noise(x * 0.3, y * 0.3, 71.3)
	local wear = math.clamp(1 - (outside + wobble) / APRON_WIDTH, 0, 1)
	if wear > 0 then
		local patchy = 0.5 + 0.6 * math.noise(x * 0.55, y * 0.55, 93.1)
		local worn = math.clamp((wear - 0.75 * (1 - patchy)) / 0.2, 0, 1)
		local grit = 0.9 + 0.2 * math.noise(x * 1.7, y * 1.7, 17.9)
		r, g, b = toward(r, g, b, { TRODDEN[1] * grit, TRODDEN[2] * grit, TRODDEN[3] * grit }, worn)
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Grass", nil, GRASS, function(mesh)
	local rim = grassRim()
	local count = #rim
	-- Corners of the turf: rings rounding over from its top edge (the first)
	-- down to its hanging edge (the last), rings curling the hanging edge's
	-- bottom under, the inner bottom of the hanging edge, and the inner edge
	-- where it meets the stone's top.
	local rings, curl, innerBottom, innerTop = {}, {}, {}, {}
	for k = 0, GRASS_ROUND_STEPS do
		rings[k], curl[k] = {}, {}
	end
	local outline = {}
	for i, point in rim do
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_ROUND * (1 - math.sin(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			rings[k][i] = mesh:vertex(x, y, GRASS_HEIGHT - GRASS_ROUND * (1 - math.cos(angle)))
			if k == 0 then
				outline[i] = { x, y }
			end
		end
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_BOTTOM_ROUND * (1 - math.cos(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			curl[k][i] = mesh:vertex(x, y, -point.depth + GRASS_BOTTOM_ROUND * (1 - math.sin(angle)))
		end
		innerBottom[i] = mesh:vertex(point.inner[1], point.inner[2], -point.depth)
		innerTop[i] = mesh:vertex(point.inner[1], point.inner[2], 0)
	end
	local top, edge = rings[0], rings[GRASS_ROUND_STEPS]
	for i = 1, count do
		local j = i % count + 1
		-- The rounded rim, ring by ring, facing out and up.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = rings[k - 1], rings[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Outside, facing out.
		local wallBottom, underEdge = curl[0], curl[GRASS_ROUND_STEPS]
		mesh:face({ wallBottom[j], wallBottom[i], edge[i] })
		mesh:face({ wallBottom[j], edge[i], edge[j] })
		-- The curl under, ring by ring, facing out and down.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = curl[k - 1], curl[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Underside, facing down.
		mesh:face({ underEdge[i], underEdge[j], innerBottom[j] })
		mesh:face({ underEdge[i], innerBottom[j], innerBottom[i] })
		-- Inside, facing the stone.
		mesh:face({ innerBottom[i], innerBottom[j], innerTop[j] })
		mesh:face({ innerBottom[i], innerTop[j], innerTop[i] })
	end
	-- The turf's top, facing up, cut into GRASS_TOP_CELL squares so no
	-- piece spans the island and the chunker can keep each texture small:
	-- the outline clipped to each square in turn, one edge at a time.
	local function clipped(points, axis: number, at: number, below: boolean)
		local kept = {}
		for i, a in points do
			local b = points[i % #points + 1]
			local aIn, bIn = (a[axis] <= at) == below, (b[axis] <= at) == below
			if aIn then
				table.insert(kept, a)
			end
			if aIn ~= bIn then
				local t = (at - a[axis]) / (b[axis] - a[axis])
				table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
			end
		end
		return kept
	end
	-- Outline corners keep their ring vertex, so the top meets the rounded
	-- edge without a seam.
	local cornerOf = {}
	for i, p in outline do
		cornerOf[p] = top[i]
	end
	local low, high = { math.huge, math.huge }, { -math.huge, -math.huge }
	for _, p in outline do
		for axis = 1, 2 do
			low[axis], high[axis] = math.min(low[axis], p[axis]), math.max(high[axis], p[axis])
		end
	end
	-- A piece is buried when every corner of it lies deep in the worn ground.
	local function buried(piece): boolean
		for _, p in piece do
			if wornDistance(p[1], p[2]) > -COVER_INSET then
				return false
			end
		end
		return true
	end
	for cx = math.floor(low[1] / GRASS_TOP_CELL), math.floor(high[1] / GRASS_TOP_CELL) do
		for cy = math.floor(low[2] / GRASS_TOP_CELL), math.floor(high[2] / GRASS_TOP_CELL) do
			local piece = clipped(outline, 1, cx * GRASS_TOP_CELL, false)
			piece = clipped(piece, 1, (cx + 1) * GRASS_TOP_CELL, true)
			piece = clipped(piece, 2, cy * GRASS_TOP_CELL, false)
			piece = clipped(piece, 2, (cy + 1) * GRASS_TOP_CELL, true)
			if #piece >= 3 and not buried(piece) then
				local corners = {}
				for i, p in piece do
					corners[i] = cornerOf[p] or mesh:vertex(p[1], p[2], GRASS_HEIGHT)
				end
				for _, t in earClip(piece) do
					mesh:face({ corners[t[3]], corners[t[2]], corners[t[1]] })
				end
			end
		end
	end
end, nil, paintGrass, true, EDGE_REACH)

-- The chunks are shaded here rather than by finishParts, which has no corner
-- taper: highlights run full width at a corner and thin toward the middle of
-- an edge, as finishParts would otherwise shade them. Chunks of the island
-- count as one surface, so their seams shade like any other edge.
local chunks = {}
for _, entry in parts do
	table.insert(chunks, entry.mesh)
end
for _, entry in parts do
	local group = {}
	for _, other in parts do
		if other ~= entry then
			table.insert(group, other.mesh)
		end
	end
	local kind = string.match(entry.name, "^%a+")
	local soft = kind == "Grass" or kind == "Dirt"
	entry.mesh:paintShading(entry.image, {
		highlight = if soft then EDGE_HIGHLIGHT * SOFT_SHADING else EDGE_HIGHLIGHT,
		shadow = if soft then CONTACT_SHADOW * SOFT_SHADING else CONTACT_SHADOW,
		gradient = GRADIENT,
		blend = EDGE_BLEND,
		group = group,
		name = entry.name,
		paint = entry.paint,
		-- The rock paint is cached under the item's key, since its code is not hashed.
		custom = entry.custom,
		salt = CACHE_KEY,
		rust = entry.rust * WEAR,
		reach = EDGE_REACH,
		highlightWidth = HIGHLIGHT_WIDTH,
		cornerTaper = CORNER_TAPER,
		heightRange = entry.heightRange,
		strokes = if string.sub(entry.name, 1, 4) == "Dirt" then crackStrokes else nil,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
end
buildKeys[buildHubSectionEnd] = "HubSectionEnd-2e7b86a45fce066c"
local function buildYardIsland()
local CACHE_KEY = "YardIsland-a20f5454b9eeafc4"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Yard Island: the floating island a player's yard stands on, from the
-- shared column generator (shared/ColumnIsland.luau).
local RADIUS = 51.7
local PEAK = 65
local SEED = 11
-- The yard (YardLayout.luau) is a plot YARD_HALF_WIDTH by YARD_HALF_DEPTH
-- studs either side of the middle, with its gate toward -y and a track
-- TRACK_HALF studs either side of the middle running from the gate to the
-- rim.
local YARD_HALF_WIDTH, YARD_HALF_DEPTH = 48, 56
local TRACK_HALF = 4.5
-- The rim is a rounded rectangle that leaves at least 6 studs of grass
-- outside the fence along each side and 10 at the front and back, once the
-- rim's wobble is taken off. The sides are kept narrow so neighbouring yard
-- islands stand too far apart to jump between.
local RIM_WOBBLE = 0.05
local HALF_WIDTH, HALF_DEPTH = 54, 66
local function rimShape(angle: number): number
	local c, s = math.abs(math.cos(angle)) / HALF_WIDTH, math.abs(math.sin(angle)) / HALF_DEPTH
	return (c ^ 8 + s ^ 8) ^ (-1 / 8) / HALF_WIDTH
end

-- The plot's ground buries the turf under it.
local COVER_INSET = 2
-- How far a point lies outside the plot (with rounded corners) or the
-- gate's track.
local function wornDistance(x: number, y: number): number
	local dx, dy = math.abs(x) - YARD_HALF_WIDTH, math.abs(y) - YARD_HALF_DEPTH
	local outside = if dx > 0 and dy > 0 then math.sqrt(dx * dx + dy * dy) else math.max(dx, dy)
	if y < 0 then
		outside = math.min(outside, math.max(math.abs(x) - TRACK_HALF, 0))
	end
	return outside
end

-- Column Island: the generator for the map's floating islands, a mountain
-- of stone columns turned upside down, so a flat grassy top hangs over a
-- rocky cone that tapers to a point below. The columns, of every size and
-- shape, are packed edge to edge like cracked basalt; each hangs as deep as
-- the cone at its centre with a low faceted tip, so the underside steps down
-- in uneven tiers to the lowest point and a shallower shoulder. The columns
-- are the cells of a weighted Voronoi diagram (a power diagram) over
-- scattered stones, so big stones claim big cells. Stones grow from small
-- near the tip to big at the rim, and the big rim stones give the top its
-- lobed outline. Each column is carved, a few angled planes chiselling
-- chunks off its lower corners and edges. The model is built the mountain
-- way up (heights, summit, foot) and flipped as it is written out. Centered
-- on the origin, stone top at z = 0, turf GRASS_HEIGHT above it.
--
-- The item including this sets:
--   RADIUS        the island's radius;
--   PEAK          how far the cone hangs below the top;
--   SEED          which scatter of stones it gets;
--   wornDistance(x, y)  how far a point on the top lies outside the ground
--                 worn by what stands on it (math.huge where nothing does);
--                 the grass wears to dirt within about APRON_WIDTH of it;
--   COVER_INSET   turf lying more than this many studs inside the worn
--                 ground is buried under what stands there and left out
--                 (math.huge keeps it all);
--   RIM_WOBBLE    how far the rim swells and dips, as a share of its radius;
--   rimShape(angle)  how far out the rim stands at an angle, as a multiple
--                 of the round rim: 1 all round for a round island, never
--                 under 1, more toward the corners of a squarer one.
-- Stone sizes at the summit and at the foot, as shares of the radius, so
-- a bigger island has bigger stones rather than more of them.
local SMALLEST, LARGEST = 0.055 * RADIUS, 0.34 * RADIUS
-- Every other size in studs below was tuned on stones up to 4.5 studs
-- across and is multiplied by DETAIL, so an island with bigger stones looks
-- the same, only bigger: chips, slabs, cookie stones, cracks, rounding,
-- grass and the paint's blotches all grow with the stones.
local DETAIL = LARGEST / 4.5
-- The rim the columns are trimmed to: a circle of RIM_PUSH * RADIUS
-- swelling and dipping by up to RIM_WOBBLE of it in broad waves, so the top
-- is a dependable surface rather than sharp lobes and bays, and standing
-- rimShape times as far out at each angle. RIM_SIDES flat facets make it up,
-- so the rim stones end in cut faces.
local RIM_SIDES = 192
-- The rim stands RIM_PUSH times RADIUS out.
local RIM_PUSH = 1.1
-- The top tier of dirt, this deep under the grass, stays a clean wall
-- straight down from the rim the grass follows: chisel cuts, chips and bare
-- rock slabs all start below it.
local DIRT_CONFORM = 1.5 * DETAIL
-- Stones are scattered a stone's width past the rim, so rim cells close
-- on real neighbours before they are trimmed to it.
local RIM_REACH = 1
for i = 0, RIM_SIDES - 1 do
	RIM_REACH = math.max(RIM_REACH, rimShape(i / RIM_SIDES * 2 * math.pi))
end
local SCATTER = RIM_PUSH * RADIUS * RIM_REACH + LARGEST
-- Shortest a column hangs, so the rim stones read as a thick slab; a
-- share of the radius like the stone sizes.
local MIN_LENGTH = 0.2 * RADIUS
-- Chisel cuts per column, at most, and how deep one bites as a share of
-- the stone's size.
local MAX_CUTS = 3
local CUT_DEPTH = { 0.2, 0.55 }
-- Fine chips per column (fewest, most) and how deep one bites, in studs.
local CHIPS = { 3, 6 }
local CHIP_DEPTH = { 0.15 * DETAIL, 0.45 * DETAIL }
-- How far a cut's heading may swing from straight out, in radians.
local CUT_SPREAD = math.rad(55)

local STONE = { 0.46, 0.45, 0.5 }
-- Under the grass the island is all dirt, until rocks start breaking
-- through it at the first share of the island's depth in DIRT_TRANSITION,
-- more and more of them going down, until from the second share it is all
-- rock. Each rock comes through the dirt at its own depth in that range. The
-- dirt's bottom edge is bevelled back DIRT_BEVEL studs on its outer side, so
-- the rock it sits on stands proud.
local DIRT = { 0.33, 0.24, 0.18 }
local DIRT_TRANSITION = { 0.2, 0.65 }
-- Where a rock comes through, the line between its dirt and its stone tilts
-- by up to DIRT_TILT radians, each rock its own way, so the line wanders
-- round the island instead of stepping level.
local DIRT_TILT = math.rad(25)
-- Above that, rock already shows through the dirt in slabs: a rock still
-- under dirt may have up to PATCHES slabs of its faces bare below tilted
-- lines, each facing out from the island's centre within PATCH_SPREAD
-- radians. The chance of each rises from nothing at PATCH_FROM of the depth
-- to certain at PATCH_FULL. A slab is PATCH_THICKNESS studs deep, its back
-- leaning in or out by up to PATCH_LEAN, and its top line tilted by up to
-- PATCH_TILT; PATCH_PEAKED of the slabs have a second top line, so the bare
-- rock comes up to a point through the dirt.
local PATCHES = 2
local PATCH_FROM = 0.04
local PATCH_FULL = 0.25
local PATCH_SPREAD = math.rad(45)
local PATCH_THICKNESS = { 0.4 * DETAIL, 1.4 * DETAIL }
local PATCH_LEAN = 0.5
local PATCH_TILT = 0.8
local PATCH_PEAKED = 0.6
-- The bare rock of a slab is chiselled into a rough stone: this many chips
-- (fewest, most), each biting this deep (studs) off its outer side at its
-- own angle, up to PATCH_CHIP_SPREAD radians off straight out.
local PATCH_CHIPS = { 4, 8 }
local PATCH_CHIP_DEPTH = { 0.3 * DETAIL, 0.8 * DETAIL }
local PATCH_CHIP_SPREAD = math.rad(65)
-- The colours blend too, over a wider share of the depth: dirt greys toward
-- stone and stone keeps a dirty tint across COLOR_TRANSITION, the line
-- wandering by COLOR_WOBBLE of the depth. At any depth the dirt stays
-- DIRT_LEAD further toward dirt than the stone, so the two still read apart.
local COLOR_TRANSITION = { 0.08, 0.55 }
local COLOR_WOBBLE = 0.06
local DIRT_LEAD = 0.45
-- Traces of dirt stay on the stone just under each rock's dirt line, as
-- patchy blotches thinning out over DIRT_TRACE studs below it. Bare rock
-- breaking through above the line keeps DIRT_DUSTING of them.
local DIRT_TRACE = 4 * DETAIL
local DIRT_DUSTING = 0.35
-- Grime and dead grey lichen crust the stone in patches, thickest where
-- the dirt gives way to rock and thinning out to nothing by GRIME_REACH of
-- the island's depth.
-- GRIME_COVER is the most of the stone it covers.
local GRIME = { 0.21, 0.22, 0.19 }
local GRIME_REACH = 0.8
local GRIME_COVER = 0.45

-- Small whole stones half sunk in the dirt, like crushed cookie in ice
-- cream: STONE_BITS of them per square stud of dirt near the top, rising to
-- the second number where the dirt gives way to rock. Each is STONE_BIT_SIZE
-- studs across, most of them small and a few big (STONE_BIT_SKEW over 1), a
-- chipped box, and stands out of the dirt by STONE_BIT_RISE
-- of its size. None sit within STONE_BIT_CLEAR studs of the top, under the
-- grass's lip. With bigger stones (DETAIL) they are bigger and sparser.
local PEBBLE = { 0.47, 0.46, 0.49 }
local STONE_BITS = { 0.035 / DETAIL ^ 2, 0.17 / DETAIL ^ 2 }
local STONE_BIT_SIZE = { 0.45 * DETAIL, 1.9 * DETAIL }
local STONE_BIT_SKEW = 2
local STONE_BIT_RISE = { 0.3, 0.4 }
local STONE_BIT_CLEAR = 1.2 * DETAIL
-- The stones are stained with dirt: solid where they come out of it,
-- breaking into blotches up to STONE_BIT_STAIN of their height.
local STONE_BIT_STAIN = 1.6

-- Drawn cracks in the dirt, running out from the stones sunk in it, as if
-- pushing them in split it: CRACK_CHANCE of the stones have them, up to
-- CRACKS each, CRACK_LENGTH studs long in CRACK_SEGMENTS jagged steps,
-- CRACK_WIDTH wide at the stone and thinning steadily to nothing at its end.
-- CRACK_BRANCH of the cracks fork once.
local CRACK = { 0.17, 0.12, 0.08 }
-- Each crack is drawn in depth: a pale lip where light catches its lower
-- edge (CRACK_LIP), the crack over it, and a darker core down its middle
-- (CRACK_CORE, CRACK_CORE_WIDTH of the crack's width).
local CRACK_LIP = { 0.66, 0.53, 0.4 }
local CRACK_CORE = { 0.06, 0.04, 0.03 }
local CRACK_CORE_WIDTH = 0.45
local CRACK_CHANCE = 1
local CRACKS = 3
local CRACK_LENGTH = { 0.6 * DETAIL, 1.8 * DETAIL }
local CRACK_SEGMENTS = 4
local CRACK_WIDTH = { 0.1 * DETAIL, 0.18 * DETAIL }
local CRACK_BRANCH = 0.4
local DIRT_BEVEL = { 0.3 * DETAIL, 0.6 * DETAIL }
-- How steeply each rock's bevel slants, in radians up from flat; each rock
-- takes its own angle in this range, so the bevels don't all match.
local DIRT_BEVEL_LIFT = { math.rad(25), math.rad(65) }
-- The dirt's outer edges and corners are rounded off on this radius, each
-- edge in this many facets, so it reads soft rather than jagged.
local DIRT_ROUND = 0.6 * DETAIL
local DIRT_ROUND_STEPS = 4
-- Each rock shades from STONE times the first where it meets the top to
-- STONE times the second at its tip.
local ROCK_GRADIENT = { 1.1, 0.6 }
-- Brush splotches in the stone: one may sit in each cell of a 3D grid
-- (`cell` studs, with `chance`), a lobed blot `radius` studs across that
-- shifts the stone's tone by up to `tone` and its tint by up to `tint`. The
-- coat's brush strokes lay them on as dabs.
local SPLOTCH = { cell = 1.8 * DETAIL, chance = 1, radius = { DETAIL, 2 * DETAIL }, tone = 0.1, tint = 0.02 }
-- Texture pixels per stud; chunks are 1024 texels across at this density.
local TEXEL_DENSITY = 16
-- Edge highlights: how far edge paint reaches from an edge, in studs, and how
-- many times wider than the default the highlight strokes are.
local EDGE_REACH = DETAIL
local HIGHLIGHT_WIDTH = 4
-- Studs over which a highlight thins from full width at a corner.
local CORNER_TAPER = 0.5 * DETAIL
-- Grass and dirt are soft, so their edge highlights and contact shadows run
-- at this share of the stone's.
local SOFT_SHADING = 0.12

-- Grass over the top: a turf slab GRASS_HEIGHT thick, pushed GRASS_OUTSET
-- past the rim, whose edge hangs down as a lip (shallowest and deepest, in
-- studs) hung all along with tongues of grass dripping further down, each
-- DRIP_WIDTH across and DRIP_LENGTH below the lip. Neighbouring drips
-- overlap by DRIP_OVERLAP of their widths, so the edge runs as one
-- unbroken wave with no flat stretch between drips.
local GRASS = { 0.74, 0.63, 0.4 }
local GRASS_HEIGHT = 0.45 * DETAIL
local GRASS_OUTSET = 0.25 * DETAIL
local GRASS_LIP = { 0.3 * DETAIL, 0.6 * DETAIL }
local DRIP_WIDTH = { 1.6 * DETAIL, 4 * DETAIL }
local DRIP_LENGTH = { 0.3 * DETAIL, 1.1 * DETAIL }
local DRIP_OVERLAP = 0.35
-- A finer octave of wobble over the wave: how far it moves the edge up or
-- down, in studs, and how fast it changes along the rim.
local DRIP_DETAIL = 0.3 * DETAIL
local DRIP_DETAIL_FREQUENCY = 1.1 / DETAIL
-- Spacing of the points the rim is walked in, in studs.
local GRASS_STEP = 0.25 * DETAIL
-- The turf's top rolls over into its hanging edge on a quarter circle this
-- many studs across, in this many facets.
local GRASS_ROUND = 0.42 * DETAIL
local GRASS_ROUND_STEPS = 4
-- The hanging edge's bottom curls under into its underside on this radius.
local GRASS_BOTTOM_ROUND = 0.2 * DETAIL
-- The rim's corners in plan are rounded off by blurring its outline over
-- about this many studs, just enough to soften each stone's jog while the
-- grass still follows the stones, pushed out GRASS_OUTSET past them. The drips' depth is
-- blurred over GRASS_DEPTH_BLUR studs, so neighbouring tongues meet in soft
-- dips rather than sharp notches.
local GRASS_CORNER_BLUR = 0.2 * DETAIL
local GRASS_DEPTH_BLUR = 0.3 * DETAIL
-- The turf's flat top is cut into squares this many studs across, to keep
-- its texture chunks small; this one doesn't grow with DETAIL.
local GRASS_TOP_CELL = 8
-- How much the grass darkens toward the tip of the deepest drip.
local DRIP_SHADE = 0.35
-- The grass is dead: straw GRASS drifting into a dull olive where a little
-- life hangs on (GRASS_OLIVE_COVER of it), in soft noise patches this many
-- studs across.
local GRASS_OLIVE = { 0.6, 0.57, 0.35 }
local GRASS_OLIVE_COVER = 0.3
local GRASS_PATCH_SIZE = 6 * DETAIL
-- Within about APRON_WIDTH studs of what stands on the top (wornDistance)
-- the grass is worn down to TRODDEN dirt and gravel, in patches toward the
-- outside. These follow what stands there, not the stones, so DETAIL leaves
-- them alone.
local APRON_WIDTH = 6
local TRODDEN = { 0.47, 0.4, 0.31 }

-- Fixed per-column jitter, so the columns look uneven but every build matches.
local function hash(i: number, j: number): number
	local n = math.sin(i * 127.1 + j * 311.7) * 43758.5453
	return n - math.floor(n)
end

local seed = SEED
local function random(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

-- Height of the slope at a point: the main cone, ridges running down from
-- the summit, and a lower shoulder peak off to one side. The cone is
-- rounded BOWL of the way toward a dome, so the underside reads as a
-- shallow bowl rather than a spike under a flat shelf.
local BOWL = 0.4
local function heightAt(x: number, y: number): number
	local r = math.sqrt(x * x + y * y) / RADIUS
	local angle = math.atan2(y, x)
	local ridges = 1 + 0.12 * math.cos(angle * 5) * r
	local out = math.min(r * ridges, 1)
	local cone = (1 - out) ^ 1.25
	local dome = math.sqrt(1 - out * out)
	local main = PEAK * (cone + (dome - cone) * BOWL)
	local sx, sy = x - 8, y + 5
	local shoulder = 19 * math.max(0, 1 - math.sqrt(sx * sx + sy * sy) / 11) ^ 1.1
	return math.max(main, shoulder)
end

-- The rim's radius at an angle.
local function rimAt(angle: number): number
	local phase = SEED * 1.7
	local wave = 0.5 * math.sin(2 * angle + phase) + 0.3 * math.sin(3 * angle + 2 * phase) + 0.2 * math.sin(5 * angle + 3 * phase)
	return RIM_PUSH * RADIUS * rimShape(angle) * (1 + RIM_WOBBLE * wave)
end

-- Stones scattered by dart throwing, none crowding another, sized by how
-- high on the slope they sit: x, y and size.
local stones = {}
for _ = 1, 8000 do
	local angle, reach = random() * TAU, math.sqrt(random()) * SCATTER
	local x, y = reach * math.cos(angle), reach * math.sin(angle)
	local height = math.clamp(heightAt(x, y) / PEAK, 0, 1)
	local size = (LARGEST + (SMALLEST - LARGEST) * height ^ 0.5) * (0.8 + 0.4 * random())
	local clear = true
	for _, other in stones do
		local dx, dy = x - other[1], y - other[2]
		if dx * dx + dy * dy < ((size + other[3]) * 0.72) ^ 2 then
			clear = false
			break
		end
	end
	if clear then
		table.insert(stones, { x, y, size })
	end
end

-- Cuts a cell outline down to the side of stone q's boundary nearer stone
-- p. Each corner carries the stone across the edge that starts there (nil
-- on the outer rim), so walls can find their neighbour.
local function clip(outline, p, q, neighbour)
	local nx, ny = q[1] - p[1], q[2] - p[2]
	local limit = (q[1] ^ 2 + q[2] ^ 2 - p[1] ^ 2 - p[2] ^ 2 - q[3] ^ 2 + p[3] ^ 2) / 2
	local function side(point)
		return point[1] * nx + point[2] * ny - limit
	end
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = side(a), side(b)
		local crossing = if (sa <= 0) ~= (sb <= 0)
			then { a[1] + (b[1] - a[1]) * sa / (sa - sb), a[2] + (b[2] - a[2]) * sa / (sa - sb) }
			else nil
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
			if crossing then
				table.insert(kept, { crossing[1], crossing[2], neighbour })
			end
		elseif crossing then
			table.insert(kept, { crossing[1], crossing[2], a[3] })
		end
	end
	return kept
end

-- The rim's corners, then each of its sides as a plane n . p <= limit,
-- in order round from angle 0.
local rimSides = {}
do
	local rim = {}
	for i = 0, RIM_SIDES - 1 do
		local angle = i / RIM_SIDES * TAU
		local r = rimAt(angle)
		rim[i + 1] = { r * math.cos(angle), r * math.sin(angle) }
	end
	for i, a in rim do
		local b = rim[i % #rim + 1]
		-- Counter-clockwise, so out is to the right of each side.
		local nx, ny = b[2] - a[2], a[1] - b[1]
		table.insert(rimSides, { nx, ny, nx * a[1] + ny * a[2] })
	end
end

-- Cuts a cell outline down to the inside of one rim side; corners where it
-- crosses carry nil, as on the outer rim.
local function clipToRim(outline, side)
	local nx, ny, limit = side[1], side[2], side[3]
	local kept = {}
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local sa, sb = a[1] * nx + a[2] * ny - limit, b[1] * nx + b[2] * ny - limit
		if sa <= 0 then
			table.insert(kept, { a[1], a[2], a[3] })
		end
		if (sa <= 0) ~= (sb <= 0) then
			local t = sa / (sa - sb)
			table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, if sa <= 0 then nil else a[3] })
		end
	end
	return kept
end

-- Each stone's column: its outline and its top corners on a slanted plane.
local columns = {}
for index, stone in stones do
	local outline = {}
	for i = 0, 31 do
		local angle = i / 32 * TAU
		table.insert(outline, { SCATTER * math.cos(angle), SCATTER * math.sin(angle), nil })
	end
	for other, neighbour in stones do
		if other ~= index and #outline >= 3 then
			local dx, dy = neighbour[1] - stone[1], neighbour[2] - stone[2]
			if dx * dx + dy * dy < (LARGEST * 3) ^ 2 then
				outline = clip(outline, stone, neighbour, other)
			end
		end
	end
	-- Every cell is trimmed to the rim sides it faces (the rim isn't convex,
	-- so the far sides would cut into its swells); those left with nothing
	-- inside the rim are dropped. A cell's sides are those over the angles
	-- its corners span, and a few either way so neighbours trim alike.
	local low, high, farthest = math.huge, -math.huge, 0
	local heading = math.atan2(stone[2], stone[1])
	for _, corner in outline do
		local offset = (math.atan2(corner[2], corner[1]) - heading + math.pi) % TAU - math.pi
		low, high = math.min(low, offset), math.max(high, offset)
		farthest = math.max(farthest, math.sqrt(corner[1] ^ 2 + corner[2] ^ 2))
	end
	if farthest > RIM_PUSH * RADIUS * (1 - RIM_WOBBLE) then
		local first = math.floor((heading + low) / TAU * RIM_SIDES) - 8
		local last = math.ceil((heading + high) / TAU * RIM_SIDES) + 8
		for k = first, last do
			if #outline < 3 then
				break
			end
			outline = clipToRim(outline, rimSides[k % RIM_SIDES + 1])
		end
	end
	local area = 0
	for i, a in outline do
		local b = outline[i % #outline + 1]
		area += (a[1] * b[2] - b[1] * a[2]) / 2
	end
	-- Only cells the rim leaves nothing of are dropped; a small one kept at
	-- the rim fills its stretch so the edge doesn't notch.
	if #outline < 3 or math.abs(area) < 1e-3 then
		continue
	end
	local cx, cy = 0, 0
	for _, corner in outline do
		cx, cy = cx + corner[1] / #outline, cy + corner[2] / #outline
	end
	local rise = math.max(MIN_LENGTH * (0.8 + 0.4 * hash(index, 5)), heightAt(cx, cy) + (hash(index, 1) - 0.5) * (1 + stone[3]))
	local tiltX, tiltY = (hash(index, 2) - 0.5) * 0.45, (hash(index, 3) - 0.5) * 0.45
	local corners = {}
	-- Neighbouring columns share their edges exactly, so no gap opens
	-- between them.
	for i, corner in outline do
		local z = rise + (corner[1] - cx) * tiltX + (corner[2] - cy) * tiltY
		corners[i] = { corner[1], corner[2], z, corner[3] }
	end
	columns[index] = {
		index = index,
		size = stone[3],
		corners = corners,
		-- The top rises to a low ridge point, so it reads as broken stone.
		peak = { cx, cy, rise + 0.15 * stone[3] * (0.5 + hash(index, 4)) },
	}
end

-- A column as a closed solid: faces as lists of points, wound outward,
-- from the foot (z = 0) up to its slanted top and the low point above it.
local function solidOf(column)
	local bottom = 0
	local corners, peak = column.corners, column.peak
	local count = #corners
	local faces = {}
	local base = {}
	for i = count, 1, -1 do
		table.insert(base, { corners[i][1], corners[i][2], bottom })
	end
	table.insert(faces, base)
	for i = 1, count do
		local a, b = corners[i], corners[i % count + 1]
		table.insert(faces, { { a[1], a[2], bottom }, { b[1], b[2], bottom }, { b[1], b[2], b[3] }, { a[1], a[2], a[3] } })
		table.insert(faces, { { peak[1], peak[2], peak[3] }, { a[1], a[2], a[3] }, { b[1], b[2], b[3] } })
	end
	return faces
end

-- Cuts away everything on the far side of the plane n . p = d, closing the
-- wound with a cap facing along n.
local function carve(faces, n, d)
	local kept, cut = {}, {}
	for _, face in faces do
		local out = {}
		for i, a in face do
			local b = face[i % #face + 1]
			local sa = a[1] * n[1] + a[2] * n[2] + a[3] * n[3] - d
			local sb = b[1] * n[1] + b[2] * n[2] + b[3] * n[3] - d
			if sa <= 0 then
				table.insert(out, a)
			end
			if (sa <= 0) ~= (sb <= 0) then
				local t = sa / (sa - sb)
				local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
				table.insert(out, p)
				table.insert(cut, p)
			end
		end
		if #out >= 3 then
			table.insert(kept, out)
		end
	end
	if #cut < 3 then
		return kept
	end
	-- The cap's corners, sorted round their centre in the plane.
	local mx, my, mz = 0, 0, 0
	for _, p in cut do
		mx, my, mz = mx + p[1] / #cut, my + p[2] / #cut, mz + p[3] / #cut
	end
	local ux, uy, uz = if math.abs(n[3]) < 0.9 then -n[2] else 0, if math.abs(n[3]) < 0.9 then n[1] else -n[3], if math.abs(n[3]) < 0.9 then 0 else n[2]
	local length = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / length, uy / length, uz / length
	local vx, vy, vz = n[2] * uz - n[3] * uy, n[3] * ux - n[1] * uz, n[1] * uy - n[2] * ux
	local cap = {}
	for _, p in cut do
		local ox, oy, oz = p[1] - mx, p[2] - my, p[3] - mz
		local angle = math.atan2(ox * vx + oy * vy + oz * vz, ox * ux + oy * uy + oz * uz)
		local duplicate = false
		for _, other in cap do
			duplicate = duplicate or math.abs(other[2] - angle) < 1e-4
		end
		if not duplicate then
			table.insert(cap, { p, angle })
		end
	end
	table.sort(cap, function(a, b)
		return a[2] < b[2]
	end)
	if #cap >= 3 then
		local face = {}
		for i, entry in cap do
			face[i] = entry[1]
		end
		table.insert(kept, face)
	end
	return kept
end

-- Carve every column first, so walls can be cut against their
-- neighbours' finished shapes.
for _, column in columns do
	local corners, index = column.corners, column.index
	local faces = solidOf(column)
	local outward = math.atan2(column.peak[2], column.peak[1])

	-- Chisel cuts: each faces out and up at its own angle, from a low
	-- slant (shaving a side edge) to steep (bevelling the top), and
	-- bites a set depth in from the farthest point along it. None is
	-- near level, which would open holes down between columns. Every cut
	-- faces away from the island's centre, within CUT_SPREAD either side,
	-- so the carving shows on the outside and never faces inward.
	-- The cuts to make: heading, lift and depth. The big chisel cuts come
	-- first, then fine chips that knock small corners off what is left.
	local cuts = {}
	for k = 1, 1 + math.floor(hash(index, 40) * MAX_CUTS) do
		table.insert(cuts, {
			outward + (hash(index, 40 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 50 + k) * 0.85,
			column.size * (CUT_DEPTH[1] + (CUT_DEPTH[2] - CUT_DEPTH[1]) * hash(index, 60 + k)),
		})
	end
	for k = 1, CHIPS[1] + math.floor(hash(index, 70) * (CHIPS[2] - CHIPS[1] + 1)) do
		table.insert(cuts, {
			outward + (hash(index, 70 + k) - 0.5) * 2 * CUT_SPREAD,
			0.35 + hash(index, 80 + k) * 1.05,
			CHIP_DEPTH[1] + (CHIP_DEPTH[2] - CHIP_DEPTH[1]) * hash(index, 90 + k),
		})
	end
	for _, cut in cuts do
		local heading, lift, depth = cut[1], cut[2], cut[3]
		local n = { math.cos(heading) * math.cos(lift), math.sin(heading) * math.cos(lift), math.sin(lift) }
		local farthest = -math.huge
		for _, face in faces do
			for _, p in face do
				farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
			end
		end
		-- A cut stops short of the top tier, which follows the grass, so
		-- the wall under the grass is never carved into.
		local tiermost = -math.huge
		for _, corner in corners do
			tiermost = math.max(tiermost, corner[1] * n[1] + corner[2] * n[2] + DIRT_CONFORM * n[3])
		end
		local plane = math.max(farthest - depth, tiermost + 0.3)
		if plane < farthest then
			faces = carve(faces, n, plane)
		end
	end

	column.faces = faces

	-- Where the column's carved underside begins: the shallowest point of
	-- any face that isn't a side wall or its foot.
	column.surfaceFrom = math.huge
	for _, face in faces do
		local foot, nz = true, 0
		for i, p in face do
			local q = face[i % #face + 1]
			foot = foot and p[3] == 0
			nz += (p[1] - q[1]) * (p[2] + q[2])
		end
		if not foot and math.abs(nz) > 1e-3 then
			for _, p in face do
				column.surfaceFrom = math.min(column.surfaceFrom, p[3])
			end
		end
	end
end

-- How deep each column hides behind the tier around it: it comes into view
-- where its shallowest neighbour's underside begins, or at the top if it
-- faces the open edge.
for _, column in columns do
	column.shownFrom = math.huge
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		column.shownFrom = math.min(column.shownFrom, if neighbour then neighbour.surfaceFrom else 0)
	end
end

-- How deep the island hangs at its lowest point.
local islandDepth = 0
for _, column in columns do
	islandDepth = math.max(islandDepth, column.peak[3])
end

-- How far a solid reaches along a direction.
local function farthestAlong(faces, n): number
	local farthest = -math.huge
	for _, face in faces do
		for _, p in face do
			farthest = math.max(farthest, p[1] * n[1] + p[2] * n[2] + p[3] * n[3])
		end
	end
	return farthest
end

-- Cuts a solid's outer bottom edge off, `depth` studs in along a slant facing
-- out from the island's centre and down, `lift` radians up from flat.
local function bevelled(faces, outward: number, depth: number, lift: number)
	local n = { math.cos(outward) * math.cos(lift), math.sin(outward) * math.cos(lift), math.sin(lift) }
	return carve(faces, n, farthestAlong(faces, n) - depth)
end

-- Each rock is dirt down to where it comes through, and stone below, split
-- into a dirt solid and a stone one. The dirt's outer bottom edge is
-- bevelled off, so the stone under it stands proud. Higher up, a patch of a
-- rock's outer face may already show through: the dirt is split into the
-- slab on its outer face and the rest, and the slab into bare stone below a
-- tilted line and dirt above, bevelled like the rest.
for _, column in columns do
	local index, faces = column.index, column.faces
	local share = DIRT_TRANSITION[1] + (DIRT_TRANSITION[2] - DIRT_TRANSITION[1]) * hash(index, 30)
	local dirtLine = islandDepth * share
	column.dirtLine = dirtLine
	if dirtLine <= column.shownFrom then
		column.solids = { { faces = faces, dirt = false } }
		continue
	end
	local shown = column.shownFrom
	local outward = math.atan2(column.peak[2], column.peak[1])
	local bevel = DIRT_BEVEL[1] + (DIRT_BEVEL[2] - DIRT_BEVEL[1]) * hash(index, 31)
	local lift = DIRT_BEVEL_LIFT[1] + (DIRT_BEVEL_LIFT[2] - DIRT_BEVEL_LIFT[1]) * hash(index, 34)
	-- The tilted line passes through dirtLine under the rock's tip.
	local tilt, heading = DIRT_TILT * hash(index, 32), hash(index, 33) * 2 * math.pi
	local down = { math.sin(tilt) * math.cos(heading), math.sin(tilt) * math.sin(heading), math.cos(tilt) }
	local line = down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * dirtLine
	local dirt = bevelled(carve(faces, down, line), outward, bevel, lift)
	local stone = carve(faces, { -down[1], -down[2], -down[3] }, -line)
	column.solids = { { faces = dirt, dirt = true }, { faces = stone, dirt = false } }
	-- The stone shows from below the dirt.
	column.shownFrom = math.min(dirtLine, column.peak[3])

	local middle = (shown + dirtLine) / 2 / islandDepth
	local chance = math.clamp((middle - PATCH_FROM) / (PATCH_FULL - PATCH_FROM), 0, 1)
	if dirtLine - shown <= 1 then
		continue
	end
	-- Each slab is cut from the dirt left after the last, so they sit side
	-- by side round the rock.
	local rest, solids = dirt, { { faces = stone, dirt = false } }
	for k = 1, PATCHES do
		if hash(index, 204 + k * 10) >= chance then
			continue
		end
		local heading = outward + (hash(index, 205 + k * 10) - 0.5) * 2 * PATCH_SPREAD
		local lean = (hash(index, 300 + k * 10) - 0.5) * 2 * PATCH_LEAN
		local size = math.sqrt(1 + lean * lean)
		local across = { math.cos(heading) / size, math.sin(heading) / size, lean / size }
		local thickness = PATCH_THICKNESS[1] + (PATCH_THICKNESS[2] - PATCH_THICKNESS[1]) * hash(index, 206 + k * 10)
		local face = farthestAlong(rest, across) - thickness
		local slab = carve(rest, { -across[1], -across[2], -across[3] }, -face)
		rest = carve(rest, across, face)
		-- The slab's top line, tilted, somewhere down what shows of the rock:
		-- above it dirt, below it bare rock.
		local function topLine(seed: number)
			local top = shown + (dirtLine - shown) * (0.05 + 0.45 * hash(index, seed))
			local tx = (hash(index, seed + 1) - 0.5) * 2 * PATCH_TILT
			local ty = (hash(index, seed + 2) - 0.5) * 2 * PATCH_TILT
			local length = math.sqrt(tx * tx + ty * ty + 1)
			local down = { tx / length, ty / length, 1 / length }
			-- Never above the top tier anywhere across the slab.
			local level = -math.huge
			for _, f in slab do
				for _, p in f do
					level = math.max(level, down[1] * p[1] + down[2] * p[2] + down[3] * DIRT_CONFORM)
				end
			end
			return down, math.max(down[1] * column.peak[1] + down[2] * column.peak[2] + down[3] * top, level)
		end
		local down, line = topLine(207 + k * 10)
		table.insert(solids, { faces = bevelled(carve(slab, down, line), heading, bevel * 0.7, lift), dirt = true })
		local bare = carve(slab, { -down[1], -down[2], -down[3] }, -line)
		-- A second line peaks the rock: the dirt it cuts off stays dirt.
		if hash(index, 320 + k * 10) < PATCH_PEAKED then
			local second, secondLine = topLine(330 + k * 10)
			table.insert(solids, { faces = bevelled(carve(bare, second, secondLine), heading, bevel * 0.7, lift), dirt = true })
			bare = carve(bare, { -second[1], -second[2], -second[3] }, -secondLine)
		end
		-- Chipped into a rough stone rather than a flat slab.
		local chips = PATCH_CHIPS[1] + math.floor(hash(index, 400 + k * 10) * (PATCH_CHIPS[2] - PATCH_CHIPS[1] + 1))
		for c = 1, chips do
			local seed = 500 + k * 100 + c * 7
			local yaw = heading + (hash(index, seed) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local pitch = (hash(index, seed + 1) - 0.5) * 2 * PATCH_CHIP_SPREAD
			local n = { math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch) }
			local depth = PATCH_CHIP_DEPTH[1] + (PATCH_CHIP_DEPTH[2] - PATCH_CHIP_DEPTH[1]) * hash(index, seed + 2)
			local plane = farthestAlong(bare, n) - depth
			if plane > -math.huge then
				bare = carve(bare, n, plane)
			end
		end
		table.insert(solids, { faces = bare, dirt = false })
	end
	table.insert(solids, { faces = rest, dirt = true })
	column.solids = solids
end

-- Each face's plane, as a unit normal pointing out and its distance.
local function planeOf(face)
	local nx, ny, nz = 0, 0, 0
	for i, a in face do
		local b = face[i % #face + 1]
		nx += (a[2] - b[2]) * (a[3] + b[3])
		ny += (a[3] - b[3]) * (a[1] + b[1])
		nz += (a[1] - b[1]) * (a[2] + b[2])
	end
	local length = math.sqrt(nx * nx + ny * ny + nz * nz)
	if length < 1e-9 then
		return nil
	end
	nx, ny, nz = nx / length, ny / length, nz / length
	local p = face[1]
	return { nx, ny, nz, nx * p[1] + ny * p[2] + nz * p[3] }
end

-- Splits a face by a plane into the part outside it and the part inside.
local EPSILON = 1e-5
local function split(face, plane)
	local outside, inside = {}, {}
	local function side(p)
		local s = plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]
		return if math.abs(s) < EPSILON then 0 else s
	end
	for i, a in face do
		local b = face[i % #face + 1]
		local sa, sb = side(a), side(b)
		if sa >= 0 then
			table.insert(outside, a)
		end
		if sa <= 0 then
			table.insert(inside, a)
		end
		if (sa > 0 and sb < 0) or (sa < 0 and sb > 0) then
			local t = sa / (sa - sb)
			local p = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
			table.insert(outside, p)
			table.insert(inside, p)
		end
	end
	return outside, inside
end

local function area(face): number
	local plane = planeOf(face)
	if not plane or #face < 3 then
		return 0
	end
	local total = 0
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
		total += ((uy * vz - uz * vy) * plane[1] + (uz * vx - ux * vz) * plane[2] + (ux * vy - uy * vx) * plane[3]) / 2
	end
	return total
end

-- The parts of a face that don't lie inside a neighbour. Only a face lying
-- against one of the neighbour's own faces can touch it; that face's plane
-- is skipped, and the face is carved by the rest, every piece that falls
-- outside one of them showing.
local function uncovered(face, neighbour)
	local own = planeOf(face)
	if not own then
		return {}
	end
	local touching, planes = false, {}
	for _, other in neighbour.faces do
		local plane = planeOf(other)
		if plane then
			local facing = own[1] * plane[1] + own[2] * plane[2] + own[3] * plane[3] < -0.9999
			local p = face[1]
			if facing and math.abs(plane[1] * p[1] + plane[2] * p[2] + plane[3] * p[3] - plane[4]) < 1e-4 then
				touching = true
			else
				table.insert(planes, plane)
			end
		end
	end
	if not touching then
		return { face }
	end
	local shown, rest = {}, face
	for _, plane in planes do
		local outside, inside = split(rest, plane)
		if #outside >= 3 and area(outside) > 1e-4 then
			table.insert(shown, outside)
		end
		rest = inside
		if #rest < 3 or area(rest) <= 1e-4 then
			break
		end
	end
	return shown
end

-- Columns bucketed by the 2-stud cells their outlines cover, so paint can
-- find the rock under a point without testing them all.
local CELL = 2
local cells = {}
for _, column in columns do
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, corner in column.corners do
		x0, y0 = math.min(x0, corner[1]), math.min(y0, corner[2])
		x1, y1 = math.max(x1, corner[1]), math.max(y1, corner[2])
	end
	for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
		for cy = math.floor(y0 / CELL), math.floor(y1 / CELL) do
			local cellKey = `{cx},{cy}`
			cells[cellKey] = cells[cellKey] or {}
			table.insert(cells[cellKey], column)
		end
	end
end

-- The rock a point on the island belongs to. On a wall two rocks share,
-- the deeper one owns it, since only its wall shows there.
local function rockAt(x: number, y: number)
	local found = nil
	for _, column in cells[`{math.floor(x / CELL)},{math.floor(y / CELL)}`] or {} do
		local corners, within = column.corners, true
		for i, a in corners do
			local b = corners[i % #corners + 1]
			if (b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1]) < -1e-3 then
				within = false
				break
			end
		end
		if within and (found == nil or column.peak[3] > found.peak[3]) then
			found = column
		end
	end
	return found
end

-- The splotch on top at a point, as its tone and warmth shifts (0, 0 where
-- none reaches). Of the splotches covering a point, the one laid last wins.
local function splotchAt(x: number, y: number, z: number): (number, number)
	local size = SPLOTCH.cell
	local gx, gy, gz = math.floor(x / size), math.floor(y / size), math.floor(z / size)
	local tone, warm, order = 0, 0, -1
	for i = gx - 1, gx + 1 do
		for j = gy - 1, gy + 1 do
			for k = gz - 1, gz + 1 do
				local seed = i * 7.31 + k * 3.17
				if hash(seed, j + 101) < SPLOTCH.chance then
					local cx = (i + hash(seed, j + 201)) * size
					local cy = (j + hash(seed, j + 301)) * size
					local cz = (k + hash(seed, j + 401)) * size
					local radius = SPLOTCH.radius[1] + (SPLOTCH.radius[2] - SPLOTCH.radius[1]) * hash(seed, j + 501)
					local dx, dy, dz = x - cx, y - cy, z - cz
					-- Lobed rim, so a blot isn't a clean circle.
					local lobes = 1 + 0.25 * math.noise(dx / radius * 1.5 + i, dy / radius * 1.5 + j, dz / radius * 1.5 + k)
					local laid = hash(seed, j + 601)
					if dx * dx + dy * dy + dz * dz < (radius * lobes) ^ 2 and laid > order then
						order = laid
						tone = (hash(seed, j + 701) - 0.5) * 2 * SPLOTCH.tone
						warm = (hash(seed, j + 801) - 0.5) * 2 * SPLOTCH.tint
					end
				end
			end
		end
	end
	return tone, warm
end

-- Per-rock gradient over the part of a rock that shows: light where it
-- comes out from behind the tier around it, darkening toward its tip. The
-- island hangs below z = 0, so depth is -z. Near the top the rock is dirt,
-- fading to stone further down.
-- How far from dirt toward stone the colour has blended at a point, 0 to 1.
local function stoneAt(x: number, y: number, z: number): number
	local share = -z / islandDepth + COLOR_WOBBLE * math.noise(x * 0.15 / DETAIL, y * 0.15 / DETAIL, z * 0.15 / DETAIL)
	local t = math.clamp((share - COLOR_TRANSITION[1]) / (COLOR_TRANSITION[2] - COLOR_TRANSITION[1]), 0, 1)
	return t * t * (3 - 2 * t)
end

-- A colour between dirt and stone, `t` of the way to stone.
local function soil(t: number): (number, number, number)
	return DIRT[1] + (STONE[1] - DIRT[1]) * t, DIRT[2] + (STONE[2] - DIRT[2]) * t, DIRT[3] + (STONE[3] - DIRT[3]) * t
end

local paintRock = rusting(0.1, function(x, y, z)
	local rock = rockAt(x, y)
	local depth = if rock
		then math.clamp((-z - rock.shownFrom) / math.max(rock.peak[3] - rock.shownFrom, 0.5), 0, 1)
		else 0
	local shade = ROCK_GRADIENT[1] + (ROCK_GRADIENT[2] - ROCK_GRADIENT[1]) * depth ^ 0.8
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local blend = stoneAt(x, y, z)
	local r, g, b = soil(DIRT_LEAD + (1 - DIRT_LEAD) * blend)
	-- Dirt traces: blotches whose share of the stone shrinks below the line.
	if rock then
		local below = -z - rock.dirtLine
		local amount = if below < 0 then DIRT_DUSTING else math.max(0, 1 - below / DIRT_TRACE) ^ 1.5
		local f = 0.7 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f) + 0.25 * math.noise(x * f * 3, y * f * 3, z * f * 3)
		local trace = math.clamp((blot - (1 - 0.7 * amount)) / 0.08, 0, 1)
		if trace > 0 then
			local dr, dg, db = soil(0.25 * blend)
			r, g, b = r + (dr - r) * trace, g + (dg - g) * trace, b + (db - b) * trace
		end
	end
	local share = -z / islandDepth
	-- Grime: soft-edged patches, less of them deeper down.
	local growth = math.clamp((GRIME_REACH - share) / (GRIME_REACH - DIRT_TRANSITION[1]), 0, 1)
	if growth > 0 then
		local f = 0.45 / DETAIL
		local patch = 0.5 + 0.5 * math.noise(x * f + 31, y * f, z * f) + 0.2 * math.noise(x * f * 3.6, y * f * 3.6 + 17, z * f * 3.6)
		local grime = math.clamp((patch - (1 - GRIME_COVER * growth)) / 0.1, 0, 1)
		r, g, b = r + (GRIME[1] - r) * grime, g + (GRIME[2] - g) * grime, b + (GRIME[3] - b) * grime
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Dirt darkens a little with depth, greys toward stone, and is splotched
-- like the stone.
local paintDirt = rusting(0.05, function(x, y, z)
	local shade = 1.05 - 0.3 * math.clamp(-z / (islandDepth * DIRT_TRANSITION[2]), 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	local r, g, b = soil((1 - DIRT_LEAD) * stoneAt(x, y, z))
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

-- Flipped upside down as it is written out: z mirrors, and the winding
-- reverses so faces still point outward. The foot becomes the island's top.
local function addFlipped(mesh, face)
	local verts = {}
	for i, p in face do
		verts[#face + 1 - i] = mesh:vertex(p[1], p[2], -p[3])
	end
	mesh:face(verts)
end

-- The island is split into cubic chunks, each with its own texture, so the
-- stone reads sharp at one density everywhere.
useTexelDensity(TEXEL_DENSITY)

-- A unit vector along x, y, z, and the cross product of two vectors.
local function unit(x: number, y: number, z: number)
	local length = math.max(math.sqrt(x * x + y * y + z * z), 1e-9)
	return { x / length, y / length, z / length }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The solids that may cover a solid of a column: the column's other pieces
-- and its neighbours'.
local function coverersOf(column, solid)
	local others = {}
	for _, other in column.solids do
		if other ~= solid then
			table.insert(others, other)
		end
	end
	for _, corner in column.corners do
		local neighbour = corner[4] and columns[corner[4]]
		if neighbour then
			for _, other in neighbour.solids do
				table.insert(others, other)
			end
		end
	end
	return others
end

-- What of a face no other solid covers.
local function exposed(face, others)
	local pieces = { face }
	for _, other in others do
		local kept = {}
		for _, piece in pieces do
			for _, part in uncovered(piece, other) do
				table.insert(kept, part)
			end
		end
		pieces = kept
	end
	return pieces
end

local function isFoot(face): boolean
	for _, p in face do
		if p[3] ~= 0 then
			return false
		end
	end
	return true
end

-- Rounds a convex solid's edges and corners where faces that show meet, on
-- DIRT_ROUND. Each such edge is cut by planes turning from one face to the
-- other, each touching a cylinder of that radius set in from both faces;
-- each such corner by one plane facing out between its faces.
local function rounded(faces, shows)
	local planes = {}
	for i, face in faces do
		planes[i] = planeOf(face)
	end
	local function key(p)
		return `{math.round(p[1] * 1e4)},{math.round(p[2] * 1e4)},{math.round(p[3] * 1e4)}`
	end
	local edgeFaces, cornerFaces, points = {}, {}, {}
	for i, face in faces do
		if not planes[i] or not shows[i] then
			continue
		end
		for k, a in face do
			local b = face[k % #face + 1]
			local ka, kb = key(a), key(b)
			points[ka] = a
			local edge = if ka < kb then `{ka}|{kb}` else `{kb}|{ka}`
			edgeFaces[edge] = edgeFaces[edge] or { a = a }
			table.insert(edgeFaces[edge], i)
			cornerFaces[ka] = cornerFaces[ka] or {}
			cornerFaces[ka][i] = true
		end
	end
	local cuts = {}
	for _, edge in edgeFaces do
		if #edge ~= 2 then
			continue
		end
		local n1, n2 = planes[edge[1]], planes[edge[2]]
		local cosine = n1[1] * n2[1] + n1[2] * n2[2] + n1[3] * n2[3]
		if cosine > 0.985 then
			continue
		end
		local p = edge.a
		local inset = DIRT_ROUND / (1 + cosine)
		local centre = { p[1] - (n1[1] + n2[1]) * inset, p[2] - (n1[2] + n2[2]) * inset, p[3] - (n1[3] + n2[3]) * inset }
		for k = 1, DIRT_ROUND_STEPS do
			local t = k / (DIRT_ROUND_STEPS + 1)
			local m = unit(n1[1] + (n2[1] - n1[1]) * t, n1[2] + (n2[2] - n1[2]) * t, n1[3] + (n2[3] - n1[3]) * t)
			table.insert(cuts, { m, m[1] * centre[1] + m[2] * centre[2] + m[3] * centre[3] + DIRT_ROUND })
		end
	end
	for corner, touching in cornerFaces do
		local sum, count = { 0, 0, 0 }, 0
		for i in touching do
			sum = { sum[1] + planes[i][1], sum[2] + planes[i][2], sum[3] + planes[i][3] }
			count += 1
		end
		if count >= 3 then
			local m = unit(sum[1], sum[2], sum[3])
			local v = points[corner]
			table.insert(cuts, { m, m[1] * v[1] + m[2] * v[2] + m[3] * v[3] - DIRT_ROUND * 0.6 })
		end
	end
	for _, cut in cuts do
		faces = carve(faces, cut[1], cut[2])
	end
	return faces
end

-- Round the dirt where it shows: which faces show is settled for every
-- solid first, so rounding one doesn't change what its neighbours see.
do
	local plans = {}
	for _, column in columns do
		for _, solid in column.solids do
			if not solid.dirt then
				continue
			end
			local others, shows = coverersOf(column, solid), {}
			for i, face in solid.faces do
				local whole = area(face)
				if whole > 1e-4 and not isFoot(face) then
					local open = 0
					for _, piece in exposed(face, others) do
						open += area(piece)
					end
					shows[i] = open > whole * 0.5
				end
			end
			table.insert(plans, { solid = solid, shows = shows })
		end
	end
	for _, plan in plans do
		plan.solid.faces = rounded(plan.solid.faces, plan.shows)
	end
end

-- The faces of every column's dirt or stone that show. Only what no other
-- solid covers is kept, another piece of its own column or a neighbour's,
-- so nothing lies buried inside the island. The flat top is left open: the
-- grass covers it.
local function visibleRock(dirt: boolean)
	local shown = {}
	for _, column in columns do
		for _, solid in column.solids do
			if solid.dirt ~= dirt then
				continue
			end
			local others = coverersOf(column, solid)
			for _, face in solid.faces do
				if isFoot(face) then
					continue
				end
				for _, piece in exposed(face, others) do
					table.insert(shown, piece)
				end
			end
		end
	end
	return shown
end

local dirtFaces = visibleRock(true)

-- A box around a centre, `r` from it each way, its faces wound outward.
local function boxAround(c, r)
	local x0, x1, y0, y1, z0, z1 = c[1] - r, c[1] + r, c[2] - r, c[2] + r, c[3] - r, c[3] + r
	return {
		{ { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 }, { x1, y0, z0 } },
		{ { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } },
		{ { x0, y0, z0 }, { x1, y0, z0 }, { x1, y0, z1 }, { x0, y0, z1 } },
		{ { x0, y1, z0 }, { x0, y1, z1 }, { x1, y1, z1 }, { x1, y1, z0 } },
		{ { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } },
		{ { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 }, { x1, y0, z1 } },
	}
end

-- The stones in the dirt, each as the faces that stand out of it. A stone
-- is a box turned at random and chipped at its corners, sunk into a dirt
-- face, and cut off at that face so nothing of it lies buried.
local pebbleSeed = 7
local function pebbleRandom(): number
	pebbleSeed = (pebbleSeed * 16807) % 2147483647
	return pebbleSeed / 2147483647
end
-- How far a point lies from the nearest edge of a face.
local function edgeDistance(face, p): number
	local nearest = math.huge
	for i, a in face do
		local b = face[i % #face + 1]
		local ab = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local length = ab[1] ^ 2 + ab[2] ^ 2 + ab[3] ^ 2
		local t = if length > 0 then math.clamp(((p[1] - a[1]) * ab[1] + (p[2] - a[2]) * ab[2] + (p[3] - a[3]) * ab[3]) / length, 0, 1) else 0
		local dx, dy, dz = p[1] - a[1] - ab[1] * t, p[2] - a[2] - ab[2] * t, p[3] - a[3] - ab[3] * t
		nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy + dz * dz))
	end
	return nearest
end

local pebbles = {}
-- Where cracks start: each stone's face, normal, centre on the dirt and how
-- far its rim reaches.
local crackOrigins = {}
-- Each stone as where it meets the dirt (point and outward normal, already
-- flipped) and how far it stands out, bucketed by 2-stud cell for its paint.
local pebbleCells = {}
local function pebbleCell(x: number, y: number, z: number): string
	return `{math.floor(x / 2)},{math.floor(y / 2)},{math.floor(z / 2)}`
end
for _, face in dirtFaces do
	local plane = planeOf(face)
	if not plane then
		continue
	end
	local n = { plane[1], plane[2], plane[3] }
	for i = 2, #face - 1 do
		local a, b, c = face[1], face[i], face[i + 1]
		local triangle = area({ a, b, c })
		local depth = (a[3] + b[3] + c[3]) / 3
		local toward = math.clamp(depth / (islandDepth * DIRT_TRANSITION[1]), 0, 1)
		local density = STONE_BITS[1] + (STONE_BITS[2] - STONE_BITS[1]) * toward
		local count = math.floor(triangle * density + pebbleRandom())
		for _ = 1, count do
			local u, v = pebbleRandom(), pebbleRandom()
			if u + v > 1 then
				u, v = 1 - u, 1 - v
			end
			local p = {
				a[1] + (b[1] - a[1]) * u + (c[1] - a[1]) * v,
				a[2] + (b[2] - a[2]) * u + (c[2] - a[2]) * v,
				a[3] + (b[3] - a[3]) * u + (c[3] - a[3]) * v,
			}
			local size = STONE_BIT_SIZE[1] + (STONE_BIT_SIZE[2] - STONE_BIT_SIZE[1]) * pebbleRandom() ^ STONE_BIT_SKEW
			-- A stone too big for the room it has on its face is made smaller,
			-- so it never hangs off an edge.
			size = math.min(size, edgeDistance(face, p) * 2.2)
			local r = size / 2
			if p[3] < STONE_BIT_CLEAR or size < STONE_BIT_SIZE[1] * 0.8 then
				continue
			end
			local rise = STONE_BIT_RISE[1] + (STONE_BIT_RISE[2] - STONE_BIT_RISE[1]) * pebbleRandom()
			table.insert(crackOrigins, { face = face, normal = n, at = p, rim = r * 1.0 })
			local centre = { p[1] + n[1] * r * (2 * rise - 1), p[2] + n[2] * r * (2 * rise - 1), p[3] + n[3] * r * (2 * rise - 1) }
			-- A box turned at random: start big, and cut each side in to r.
			local x = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
			local y = cross(x, unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5))
			y = unit(y[1], y[2], y[3])
			local z = cross(x, y)
			local stone = boxAround(centre, size * 2)
			for _, axis in { x, y, z } do
				for _, sign in { 1, -1 } do
					local d = { axis[1] * sign, axis[2] * sign, axis[3] * sign }
					local reach = r * (0.75 + 0.35 * pebbleRandom())
					stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + reach)
				end
			end
			-- Chips knock its corners off.
			for _ = 1, 9 do
				local d = unit(pebbleRandom() - 0.5, pebbleRandom() - 0.5, pebbleRandom() - 0.5)
				stone = carve(stone, d, d[1] * centre[1] + d[2] * centre[2] + d[3] * centre[3] + r * (0.65 + 0.25 * pebbleRandom()))
			end
			-- Cut off at the dirt: only what stands out of it is kept, and the
			-- cap the cut leaves lies against the dirt, so it goes too.
			local level = n[1] * p[1] + n[2] * p[2] + n[3] * p[3]
			stone = carve(stone, { -n[1], -n[2], -n[3] }, -level)
			local record = { point = { p[1], p[2], -p[3] }, normal = { n[1], n[2], -n[3] }, height = size * rise, reach = size }
			for cx = -1, 1 do
				for cy = -1, 1 do
					for cz = -1, 1 do
						local key = pebbleCell(p[1] + cx * 2, p[2] + cy * 2, -p[3] + cz * 2)
						pebbleCells[key] = pebbleCells[key] or {}
						table.insert(pebbleCells[key], record)
					end
				end
			end
			for _, piece in stone do
				local onDirt = true
				for _, q in piece do
					onDirt = onDirt and math.abs(n[1] * q[1] + n[2] * q[2] + n[3] * q[3] - level) < 1e-6
				end
				if not onDirt then
					table.insert(pebbles, piece)
				end
			end
		end
	end
end

-- The cracks, drawn over the dirt's coat as tapering brush strokes, one per
-- step of a crack (already flipped).
local crackStrokes = {}
local crackSeed = 3
local function crackRandom(): number
	crackSeed = (crackSeed * 16807) % 2147483647
	return crackSeed / 2147483647
end
-- Whether a point lies inside a convex face, `margin` studs in from its edges.
local function insideFace(face, n, p, margin: number): boolean
	for i, a in face do
		local b = face[i % #face + 1]
		local edge = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local inward = unit(table.unpack(cross(n, edge)))
		if (p[1] - a[1]) * inward[1] + (p[2] - a[2]) * inward[2] + (p[3] - a[3]) * inward[3] < margin then
			return false
		end
	end
	return true
end
-- A direction turned by `angle` about the face's normal.
local function turned(v, n, angle: number)
	local side = cross(n, v)
	local c, s = math.cos(angle), math.sin(angle)
	return { v[1] * c + side[1] * s, v[2] * c + side[2] * s, v[3] * c + side[3] * s }
end
-- A jagged line from `start` heading along `heading` in a face, stopping
-- short of its edges.
local function crackLine(face, n, start, heading, length: number)
	local points = { start }
	local step = length / CRACK_SEGMENTS
	local at, way = start, heading
	for _ = 1, CRACK_SEGMENTS do
		way = turned(way, n, (crackRandom() - 0.5) * 1.1)
		local nextAt = { at[1] + way[1] * step, at[2] + way[2] * step, at[3] + way[3] * step }
		if not insideFace(face, n, nextAt, 0.04 * DETAIL) then
			break
		end
		table.insert(points, nextAt)
		at = nextAt
	end
	return points
end
-- Lays a line down as a crack `width` wide at its start, thinning evenly
-- along its length to nothing at its end.
local function addCrack(points, normal, width: number)
	if #points < 2 then
		return
	end
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	local travelled = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		local widthA = width * (1 - travelled / total)
		local widthB = width * (1 - (travelled + length) / total)
		travelled += length
		local start = { a[1], a[2], -a[3] }
		local along = { (b[1] - a[1]) / length, (b[2] - a[2]) / length, -(b[3] - a[3]) / length }
		local facing = { normal[1], normal[2], -normal[3] }
		local function stroke(at, width: number, color)
			table.insert(crackStrokes, { start = at, along = along, normal = facing, length = length, width = width, tail = widthB / widthA, color = color })
		end
		-- The lip sits on the crack's lower side, half a crack's width over.
		local across = cross(facing, along)
		local side = if across[3] > 0 then -1 else 1
		local shift = widthA * 0.5 * side
		stroke({ start[1] + across[1] * shift, start[2] + across[2] * shift, start[3] + across[3] * shift }, widthA * 0.8, CRACK_LIP)
		stroke(start, widthA, CRACK)
		stroke(start, widthA * CRACK_CORE_WIDTH, CRACK_CORE)
	end
end

for _, origin in crackOrigins do
	if crackRandom() >= CRACK_CHANCE then
		continue
	end
	local face, n, at = origin.face, origin.normal, origin.at
	-- Some way across the face, to turn into each crack's heading.
	local first = face[1]
	local outward = unit(first[1] - at[1], first[2] - at[2], first[3] - at[3])
	for _ = 1, 1 + math.floor(crackRandom() * CRACKS) do
		local heading = turned(outward, n, crackRandom() * TAU)
		local start = { at[1] + heading[1] * origin.rim, at[2] + heading[2] * origin.rim, at[3] + heading[3] * origin.rim }
		if not insideFace(face, n, start, 0.04 * DETAIL) then
			continue
		end
		local length = CRACK_LENGTH[1] + (CRACK_LENGTH[2] - CRACK_LENGTH[1]) * crackRandom()
		local width = CRACK_WIDTH[1] + (CRACK_WIDTH[2] - CRACK_WIDTH[1]) * crackRandom()
		local line = crackLine(face, n, start, heading, length)
		addCrack(line, n, width)
		-- A fork off partway along, thinner and shorter.
		if #line >= 3 and crackRandom() < CRACK_BRANCH then
			local from = line[2]
			local share = 1 / (#line - 1)
			local away = unit(line[3][1] - from[1], line[3][2] - from[2], line[3][3] - from[3])
			local fork = turned(away, n, (if crackRandom() < 0.5 then -1 else 1) * (0.5 + 0.4 * crackRandom()))
			addCrack(crackLine(face, n, from, fork, length * 0.5), n, width * (1 - share) * 0.8)
		end
	end
end


-- The stones are grey, splotched like the rest and stained with the dirt
-- they sit in: solid at the dirt line, in blotches higher up.
local paintPebble = rusting(0.1, function(x, y, z)
	local tone, warm = splotchAt(x, y, z)
	local shade = 1 + tone * 1.5
	local r, g, b = PEBBLE[1], PEBBLE[2], PEBBLE[3]
	-- The stone this point is on: the nearest whose dirt line it sits above.
	local height, best = math.huge, math.huge
	for _, record in pebbleCells[pebbleCell(x, y, z)] or {} do
		local q, n = record.point, record.normal
		local dx, dy, dz = x - q[1], y - q[2], z - q[3]
		local distance = dx * dx + dy * dy + dz * dz
		if distance < record.reach * record.reach and distance < best then
			best = distance
			height = (dx * n[1] + dy * n[2] + dz * n[3]) / math.max(record.height, 0.05)
		end
	end
	if height < STONE_BIT_STAIN then
		local f = 2.2 / DETAIL
		local blot = 0.5 + 0.5 * math.noise(x * f, y * f, z * f)
		local stain = math.clamp((blot - height / STONE_BIT_STAIN) / 0.12, 0, 1)
		local dr, dg, db = soil(0.15 * stoneAt(x, y, z))
		r, g, b = r + (dr - r) * stain, g + (dg - g) * stain, b + (db - b) * stain
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Columns", nil, STONE, function(mesh)
	for _, piece in visibleRock(false) do
		addFlipped(mesh, piece)
	end
end, false, paintRock, true, EDGE_REACH)

chunkedPart("Dirt", nil, DIRT, function(mesh)
	for _, piece in dirtFaces do
		addFlipped(mesh, piece)
	end
end, nil, paintDirt, true, EDGE_REACH)

chunkedPart("Pebbles", nil, PEBBLE, function(mesh)
	for _, piece in pebbles do
		addFlipped(mesh, piece)
	end
end, false, paintPebble, true, EDGE_REACH)

-- The rim walked in even steps, each point pushed out from the stone by the
-- grass's outset (outer) and a hair's width (inner), with how deep the grass
-- hangs there.
local function grassRim()
	-- The rim the stones are trimmed to, walked clockwise seen from above
	-- in GRASS_STEP strides, so the grass follows it exactly.
	local points = {}
	local steps = math.ceil(TAU * RIM_PUSH * RADIUS * RIM_REACH * (1 + RIM_WOBBLE) / GRASS_STEP)
	for k = 0, steps - 1 do
		local angle = -k / steps * TAU
		local r = rimAt(angle)
		table.insert(points, { r * math.cos(angle), r * math.sin(angle) })
	end
	local count = #points

	-- Blurs a list of numbers round the loop: repeated passes of a 1-2-1
	-- average, each spreading it by half a step squared, until it spreads
	-- `studs`.
	local function blurLoop(values: { number }, studs: number)
		for _ = 1, math.round(2 * (studs / GRASS_STEP) ^ 2) do
			local before = table.clone(values)
			for i = 1, #values do
				values[i] = (before[(i - 2) % #values + 1] + 2 * before[i] + before[i % #values + 1]) / 4
			end
		end
	end
	local raw = table.clone(points)
	for axis = 1, 2 do
		local coordinates = {}
		for i, p in points do
			coordinates[i] = p[axis]
		end
		blurLoop(coordinates, GRASS_CORNER_BLUR)
		for i = 1, count do
			points[i] = table.clone(points[i])
			points[i][axis] = coordinates[i]
		end
	end
	-- Blurring cuts the outside corners in, uncovering the stone there, so
	-- the rim swells back out round each one: by the most it was cut in
	-- anywhere near, blurred so the swell has no edge of its own.
	local cut, outward = {}, {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		outward[i] = { -dy / length, dx / length }
		cut[i] = math.max(0, (raw[i][1] - p[1]) * outward[i][1] + (raw[i][2] - p[2]) * outward[i][2])
	end
	local reach = math.ceil(2 * GRASS_CORNER_BLUR / GRASS_STEP)
	local swell = {}
	for i = 1, count do
		local most = 0
		for k = -reach, reach do
			most = math.max(most, cut[(i + k - 1) % count + 1])
		end
		swell[i] = most
	end
	blurLoop(swell, GRASS_CORNER_BLUR)
	for i, p in points do
		p[1] += outward[i][1] * swell[i]
		p[2] += outward[i][2] * swell[i]
	end

	-- The lip wanders between its shallowest and deepest, and drips hang
	-- from it as rounded tongues, each overlapping the next.
	local along, travelled = {}, 0
	for i, p in points do
		along[i] = travelled
		local q = points[i % count + 1]
		travelled += math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
	end
	local function halfWidth(n)
		return (DRIP_WIDTH[1] + (DRIP_WIDTH[2] - DRIP_WIDTH[1]) * hash(n, 21)) / 2
	end
	local drips, at, n = {}, 0, 0
	while at < travelled do
		n += 1
		table.insert(drips, { at, halfWidth(n), DRIP_LENGTH[1] + (DRIP_LENGTH[2] - DRIP_LENGTH[1]) * hash(n, 22) })
		at += (halfWidth(n) + halfWidth(n + 1)) * (1 - DRIP_OVERLAP)
	end

	-- The outline is wound clockwise seen from above, so out is to the left
	-- of each step. A point's way out averages the steps either side of it.
	local rim = {}
	for i, p in points do
		local a, b = points[(i - 2) % count + 1], points[i % count + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-9)
		local ox, oy = -dy / length, dx / length
		local s = along[i]
		local depth = GRASS_LIP[1] + (GRASS_LIP[2] - GRASS_LIP[1]) * (0.5 + 0.5 * math.noise(s * 0.3 / DETAIL, 3.7))
		for _, drip in drips do
			-- The distance round the rim either way, so drips near the
			-- start also reach the end.
			local gap = math.abs(s - drip[1])
			gap = math.min(gap, travelled - gap)
			if gap < drip[2] then
				depth = math.max(depth, GRASS_LIP[1] + drip[3] * math.sqrt(1 - (gap / drip[2]) ^ 2))
			end
		end
		-- The finer octave never lifts the edge above the stone's top.
		depth = math.max(depth + DRIP_DETAIL * math.noise(s * DRIP_DETAIL_FREQUENCY, 8.1), 0.15 * DETAIL)
		table.insert(rim, {
			outer = { p[1] + ox * GRASS_OUTSET, p[2] + oy * GRASS_OUTSET },
			out = { ox, oy },
			inner = { p[1] + ox * 0.02 * DETAIL, p[2] + oy * 0.02 * DETAIL },
			depth = depth,
		})
	end

	local depths = {}
	for i, point in rim do
		depths[i] = point.depth
	end
	blurLoop(depths, GRASS_DEPTH_BLUR)
	for i, point in rim do
		point.depth = depths[i]
	end

	-- Pushed out of a sharp inward notch, the outer line crosses itself; the
	-- loop it makes is cut away at the crossing.
	local function crossing(a, b, c, d)
		local rx, ry, sx, sy = b[1] - a[1], b[2] - a[2], d[1] - c[1], d[2] - c[2]
		local denominator = rx * sy - ry * sx
		if math.abs(denominator) < 1e-12 then
			return nil
		end
		local t = ((c[1] - a[1]) * sy - (c[2] - a[2]) * sx) / denominator
		local u = ((c[1] - a[1]) * ry - (c[2] - a[2]) * rx) / denominator
		if t <= 0 or t >= 1 or u <= 0 or u >= 1 then
			return nil
		end
		return { a[1] + rx * t, a[2] + ry * t }
	end
	local i = 1
	while i < #rim do
		for k = 2, 12 do
			local j = i + k
			if j + 1 > #rim then
				break
			end
			local hit = crossing(rim[i].outer, rim[i + 1].outer, rim[j].outer, rim[j + 1].outer)
			if hit then
				local kept = rim[i]
				for _ = i + 1, j do
					table.remove(rim, i + 1)
				end
				table.insert(rim, i + 1, { outer = hit, out = kept.out, inner = kept.inner, depth = kept.depth })
				break
			end
		end
		i += 1
	end
	return rim
end

-- How deep the deepest drip hangs, for the grass's shading.
local GRASS_DEEPEST = GRASS_LIP[1] + DRIP_LENGTH[2]

-- Grass is dead straw with olive patches, darkening down
-- the hanging edge toward the drip tips, and splotched like the stone.
local paintGrass = rusting(0, function(x, y, z)
	local shade = 1 - DRIP_SHADE * math.clamp(-z / GRASS_DEEPEST, 0, 1)
	local tone, warm = splotchAt(x, y, z)
	shade *= 1 + tone
	-- Patch strength from soft noise: 0 outside, 1 well inside a patch
	-- covering `cover` of the grass.
	local function patch(cover: number, seed: number): number
		local u, v = x / GRASS_PATCH_SIZE + seed, y / GRASS_PATCH_SIZE
		local n = 0.5 + math.noise(u, v, seed) + 0.3 * math.noise(u * 3, v * 3, seed + 5)
		return math.clamp((n - (1 - cover)) / 0.12, 0, 1)
	end
	local function toward(r, g, b, c, t)
		return r + (c[1] - r) * t, g + (c[2] - g) * t, b + (c[3] - b) * t
	end
	local r, g, b = toward(GRASS[1], GRASS[2], GRASS[3], GRASS_OLIVE, patch(GRASS_OLIVE_COVER, 11.3))
	-- The worn apron round what stands on the top.
	local outside = wornDistance(x, y)
	local wobble = 0.4 * APRON_WIDTH * math.noise(x * 0.3, y * 0.3, 71.3)
	local wear = math.clamp(1 - (outside + wobble) / APRON_WIDTH, 0, 1)
	if wear > 0 then
		local patchy = 0.5 + 0.6 * math.noise(x * 0.55, y * 0.55, 93.1)
		local worn = math.clamp((wear - 0.75 * (1 - patchy)) / 0.2, 0, 1)
		local grit = 0.9 + 0.2 * math.noise(x * 1.7, y * 1.7, 17.9)
		r, g, b = toward(r, g, b, { TRODDEN[1] * grit, TRODDEN[2] * grit, TRODDEN[3] * grit }, worn)
	end
	return r * shade * (1 + warm), g * shade, b * shade * (1 - warm)
end)

chunkedPart("Grass", nil, GRASS, function(mesh)
	local rim = grassRim()
	local count = #rim
	-- Corners of the turf: rings rounding over from its top edge (the first)
	-- down to its hanging edge (the last), rings curling the hanging edge's
	-- bottom under, the inner bottom of the hanging edge, and the inner edge
	-- where it meets the stone's top.
	local rings, curl, innerBottom, innerTop = {}, {}, {}, {}
	for k = 0, GRASS_ROUND_STEPS do
		rings[k], curl[k] = {}, {}
	end
	local outline = {}
	for i, point in rim do
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_ROUND * (1 - math.sin(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			rings[k][i] = mesh:vertex(x, y, GRASS_HEIGHT - GRASS_ROUND * (1 - math.cos(angle)))
			if k == 0 then
				outline[i] = { x, y }
			end
		end
		for k = 0, GRASS_ROUND_STEPS do
			local angle = k / GRASS_ROUND_STEPS * math.pi / 2
			local back = GRASS_BOTTOM_ROUND * (1 - math.cos(angle))
			local x, y = point.outer[1] - point.out[1] * back, point.outer[2] - point.out[2] * back
			curl[k][i] = mesh:vertex(x, y, -point.depth + GRASS_BOTTOM_ROUND * (1 - math.sin(angle)))
		end
		innerBottom[i] = mesh:vertex(point.inner[1], point.inner[2], -point.depth)
		innerTop[i] = mesh:vertex(point.inner[1], point.inner[2], 0)
	end
	local top, edge = rings[0], rings[GRASS_ROUND_STEPS]
	for i = 1, count do
		local j = i % count + 1
		-- The rounded rim, ring by ring, facing out and up.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = rings[k - 1], rings[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Outside, facing out.
		local wallBottom, underEdge = curl[0], curl[GRASS_ROUND_STEPS]
		mesh:face({ wallBottom[j], wallBottom[i], edge[i] })
		mesh:face({ wallBottom[j], edge[i], edge[j] })
		-- The curl under, ring by ring, facing out and down.
		for k = 1, GRASS_ROUND_STEPS do
			local upper, lower = curl[k - 1], curl[k]
			mesh:face({ lower[j], lower[i], upper[i] })
			mesh:face({ lower[j], upper[i], upper[j] })
		end
		-- Underside, facing down.
		mesh:face({ underEdge[i], underEdge[j], innerBottom[j] })
		mesh:face({ underEdge[i], innerBottom[j], innerBottom[i] })
		-- Inside, facing the stone.
		mesh:face({ innerBottom[i], innerBottom[j], innerTop[j] })
		mesh:face({ innerBottom[i], innerTop[j], innerTop[i] })
	end
	-- The turf's top, facing up, cut into GRASS_TOP_CELL squares so no
	-- piece spans the island and the chunker can keep each texture small:
	-- the outline clipped to each square in turn, one edge at a time.
	local function clipped(points, axis: number, at: number, below: boolean)
		local kept = {}
		for i, a in points do
			local b = points[i % #points + 1]
			local aIn, bIn = (a[axis] <= at) == below, (b[axis] <= at) == below
			if aIn then
				table.insert(kept, a)
			end
			if aIn ~= bIn then
				local t = (at - a[axis]) / (b[axis] - a[axis])
				table.insert(kept, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
			end
		end
		return kept
	end
	-- Outline corners keep their ring vertex, so the top meets the rounded
	-- edge without a seam.
	local cornerOf = {}
	for i, p in outline do
		cornerOf[p] = top[i]
	end
	local low, high = { math.huge, math.huge }, { -math.huge, -math.huge }
	for _, p in outline do
		for axis = 1, 2 do
			low[axis], high[axis] = math.min(low[axis], p[axis]), math.max(high[axis], p[axis])
		end
	end
	-- A piece is buried when every corner of it lies deep in the worn ground.
	local function buried(piece): boolean
		for _, p in piece do
			if wornDistance(p[1], p[2]) > -COVER_INSET then
				return false
			end
		end
		return true
	end
	for cx = math.floor(low[1] / GRASS_TOP_CELL), math.floor(high[1] / GRASS_TOP_CELL) do
		for cy = math.floor(low[2] / GRASS_TOP_CELL), math.floor(high[2] / GRASS_TOP_CELL) do
			local piece = clipped(outline, 1, cx * GRASS_TOP_CELL, false)
			piece = clipped(piece, 1, (cx + 1) * GRASS_TOP_CELL, true)
			piece = clipped(piece, 2, cy * GRASS_TOP_CELL, false)
			piece = clipped(piece, 2, (cy + 1) * GRASS_TOP_CELL, true)
			if #piece >= 3 and not buried(piece) then
				local corners = {}
				for i, p in piece do
					corners[i] = cornerOf[p] or mesh:vertex(p[1], p[2], GRASS_HEIGHT)
				end
				for _, t in earClip(piece) do
					mesh:face({ corners[t[3]], corners[t[2]], corners[t[1]] })
				end
			end
		end
	end
end, nil, paintGrass, true, EDGE_REACH)

-- The chunks are shaded here rather than by finishParts, which has no corner
-- taper: highlights run full width at a corner and thin toward the middle of
-- an edge, as finishParts would otherwise shade them. Chunks of the island
-- count as one surface, so their seams shade like any other edge.
local chunks = {}
for _, entry in parts do
	table.insert(chunks, entry.mesh)
end
for _, entry in parts do
	local group = {}
	for _, other in parts do
		if other ~= entry then
			table.insert(group, other.mesh)
		end
	end
	local kind = string.match(entry.name, "^%a+")
	local soft = kind == "Grass" or kind == "Dirt"
	entry.mesh:paintShading(entry.image, {
		highlight = if soft then EDGE_HIGHLIGHT * SOFT_SHADING else EDGE_HIGHLIGHT,
		shadow = if soft then CONTACT_SHADOW * SOFT_SHADING else CONTACT_SHADOW,
		gradient = GRADIENT,
		blend = EDGE_BLEND,
		group = group,
		name = entry.name,
		paint = entry.paint,
		-- The rock paint is cached under the item's key, since its code is not hashed.
		custom = entry.custom,
		salt = CACHE_KEY,
		rust = entry.rust * WEAR,
		reach = EDGE_REACH,
		highlightWidth = HIGHLIGHT_WIDTH,
		cornerTaper = CORNER_TAPER,
		heightRange = entry.heightRange,
		strokes = if string.sub(entry.name, 1, 4) == "Dirt" then crackStrokes else nil,
	})
	model.part(entry.name, entry.mesh, entry.image, { preview = true })
end
end
buildKeys[buildYardIsland] = "YardIsland-2027f38b95772bdb"
local function buildYardFence()
local CACHE_KEY = "YardFence-79638c833401e47a"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part().
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
		end, smooth, 0, texture)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT,
			shadow = CONTACT_SHADOW,
			gradient = GRADIENT,
			blend = EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Yard Fence: one 8-stud panel of a yard's boundary, about 5 studs tall.
-- Corrugated sheets between two posts, held by rails and a diagonal brace
-- behind. Panels tile end to end along x, centered on the origin.
part("Posts", nil, DARK_STEEL, function(mesh)
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.4, 0.4, 5.2)
		box(mesh, x, 0, 5.2, 0.5, 0.5, 0.1)
	end
	for _, z in { 0.8, 4.2 } do
		box(mesh, 0, 0.24, z, 7.6, 0.12, 0.2)
	end
	strut(mesh, -3.7, 0.36, 0.9, 3.7, 0.36, 4.3, 0.14)
end, nil, 0.5)
part("Sheets", nil, STEEL, function(mesh)
	for i = 0, 9 do
		box(mesh, -3.42 + i * 0.76, (i % 2) * 0.1 - 0.05, 0.3, 0.76, 0.06, 4.5)
	end
	for i = 0, 3 do
		bolt(mesh, -3 + i * 2, -0.12, 4.3, "y", 0.07)
		bolt(mesh, -3 + i * 2, -0.12, 0.9, "y", 0.07)
	end
end, nil, 0.7)
part("Fittings", nil, DARK_STEEL, function(mesh)
	-- Base plates anchoring each post, and clamps holding the rails.
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.8, 0.8, 0.08)
		for _, dx in { -0.28, 0.28 } do
			for _, dy in { -0.28, 0.28 } do
				bolt(mesh, x + dx, dy, 0.08, "z", 0.05)
			end
		end
		for _, z in { 0.75, 4.15 } do
			box(mesh, x - math.sign(x) * 0.3, 0.24, z, 0.2, 0.2, 0.3)
			bolt(mesh, x - math.sign(x) * 0.3, 0.34, z + 0.15, "y", 0.05)
		end
	end
end, nil, 0.6)
finishParts()
end
buildKeys[buildYardFence] = "YardFence-c88183b0d565bac1"
local function buildYardFenceHalf()
local CACHE_KEY = "YardFenceHalf-f2ca6d6436d118d5"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part().
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
		end, smooth, 0, texture)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT,
			shadow = CONTACT_SHADOW,
			gradient = GRADIENT,
			blend = EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Yard Fence Half: a 4-stud fence panel for closing the gaps beside a
-- centered yard gate. Same build as YardFence at half length, centered on the
-- origin along x.
part("Posts", nil, DARK_STEEL, function(mesh)
	for _, x in { -2, 2 } do
		box(mesh, x, 0, 0, 0.4, 0.4, 5.2)
		box(mesh, x, 0, 5.2, 0.5, 0.5, 0.1)
	end
	for _, z in { 0.8, 4.2 } do
		box(mesh, 0, 0.24, z, 3.6, 0.12, 0.2)
	end
	strut(mesh, -1.7, 0.36, 0.9, 1.7, 0.36, 4.3, 0.14)
end, nil, 0.5)
part("Sheets", nil, STEEL, function(mesh)
	for i = 0, 4 do
		box(mesh, -1.52 + i * 0.76, (i % 2) * 0.1 - 0.05, 0.3, 0.76, 0.06, 4.5)
	end
	for _, x in { -1, 1 } do
		bolt(mesh, x, -0.12, 4.3, "y", 0.07)
		bolt(mesh, x, -0.12, 0.9, "y", 0.07)
	end
end, nil, 0.7)
part("Fittings", nil, DARK_STEEL, function(mesh)
	-- Base plates anchoring each post, and clamps holding the rails.
	for _, x in { -2, 2 } do
		box(mesh, x, 0, 0, 0.8, 0.8, 0.08)
		for _, dx in { -0.28, 0.28 } do
			for _, dy in { -0.28, 0.28 } do
				bolt(mesh, x + dx, dy, 0.08, "z", 0.05)
			end
		end
		for _, z in { 0.75, 4.15 } do
			box(mesh, x - math.sign(x) * 0.3, 0.24, z, 0.2, 0.2, 0.3)
			bolt(mesh, x - math.sign(x) * 0.3, 0.34, z + 0.15, "y", 0.05)
		end
	end
end, nil, 0.6)
finishParts()
end
buildKeys[buildYardFenceHalf] = "YardFenceHalf-6733b008ab2c3356"
local function buildYardFooting()
local CACHE_KEY = "YardFooting-7df7c30e617afb8a"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
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
end
buildKeys[buildYardFooting] = "YardFooting-c64b2631e78d1f3f"
local function buildYardGate()
local CACHE_KEY = "YardGate-a6bba3472eb4e337"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Yard Gate: the 8-stud fence panel players walk through, two barred doors
-- in a frame with a padlocked hasp where they meet. Matches YardFence so it
-- tiles into a fence line, centered on the origin. The crossbar stands
-- higher than the fence, so in the yard (built 1.5 times its size) it clears
-- a player (5.5 studs) by 4 studs.
local CROSSBAR = 6.5
part("Frame", nil, DARK_STEEL, function(mesh)
	for _, x in { -4, 4 } do
		box(mesh, x, 0, 0, 0.4, 0.4, CROSSBAR + 0.2)
		box(mesh, x, 0, CROSSBAR + 0.2, 0.5, 0.5, 0.1)
	end
	box(mesh, 0, 0, CROSSBAR, 8.4, 0.3, 0.3)
end, nil, 0.5)
part("Doors", nil, STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local cx = side * 1.92
		box(mesh, cx, 0, 0.3, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, 4.4, 3.7, 0.14, 0.16)
		box(mesh, cx, 0, 2.3, 3.7, 0.12, 0.12)
		box(mesh, cx - side * 1.78, 0, 0.3, 0.16, 0.14, 4.26)
		box(mesh, cx + side * 1.78, 0, 0.3, 0.16, 0.14, 4.26)
		for i = 1, 6 do
			box(mesh, cx - 1.8 + i * 0.52, 0, 0.46, 0.06, 0.06, 3.94)
		end
		strut(mesh, cx - side * 1.7, 0.08, 0.45, cx + side * 1.7, 0.08, 4.4, 0.1)
	end
end, nil, 0.6)
part("Padlock", nil, COPPER, function(mesh)
	box(mesh, 0, -0.12, 2.1, 0.5, 0.06, 0.4)
	box(mesh, 0, -0.22, 1.7, 0.26, 0.14, 0.3)
	ring(mesh, 0, -0.22, 2.08, 0.06, 0.11, 0.05, "y", 8)
end, nil, 0.4)
part("Hardware", nil, DARK_STEEL, function(mesh)
	for _, side in { -1, 1 } do
		local hingeX = side * 3.72
		-- Hinge barrels joining each door to its post.
		for _, z in { 0.6, 3.9 } do
			cylinder(mesh, hingeX, 0, z, 0.1, 0.5, "z", 8)
			box(mesh, hingeX - side * 0.3, 0, z + 0.1, 0.5, 0.18, 0.3)
			bolt(mesh, hingeX - side * 0.4, -0.1, z + 0.25, "y", 0.04)
		end
		-- Caster wheel under the free end so the door doesn't sag.
		box(mesh, side * 0.5, 0, 0.12, 0.16, 0.2, 0.2)
		cylinder(mesh, side * 0.5, -0.06, 0.12, 0.12, 0.12, "y", 10)
		-- Post base plates.
		box(mesh, side * 4, 0, 0, 0.8, 0.8, 0.08)
	end
	-- Drop rod on the left door that pins into the ground.
	box(mesh, -0.35, 0.12, 0.2, 0.08, 0.08, 1.4)
	box(mesh, -0.35, 0.12, 0.6, 0.2, 0.12, 0.08)
	box(mesh, -0.35, 0.12, 1.3, 0.2, 0.12, 0.08)
	box(mesh, -0.35, 0.12, 1.6, 0.18, 0.08, 0.06)
end, nil, 0.55)
finishParts()
end
buildKeys[buildYardGate] = "YardGate-c36f5c84837b0df9"
local function buildPlotMarker()
local CACHE_KEY = "PlotMarker-774d90149afa2f90"
-- Rarity accents, in sRGB: grey common, green uncommon, blue rare, gold
-- legendary.
local COMMON = { 0.62, 0.62, 0.6 }
local UNCOMMON = { 0.3, 0.72, 0.3 }
local RARE = { 0.25, 0.5, 0.95 }
local LEGENDARY = { 1.0, 0.72, 0.18 }
local STEEL = { 0.62, 0.64, 0.66 }
local DARK_STEEL = { 0.3, 0.3, 0.32 }
local COPPER = { 0.85, 0.5, 0.25 }
local TAU = 2 * math.pi

-- Edge highlight and feathering, matching the salvage machine.
local EDGE_HIGHLIGHT = 0.6
local CONTACT_SHADOW = 0.425
-- Scales every part's wear (rust, grime, scratches): 57% of what each part asks for.
local WEAR = 0.57
local GRADIENT = 0.5
local EDGE_BLEND = 0.7
local SMOOTH_ANGLE = 30
local TEXTURE = 256

-- Faces are split into a grid about every 0.4 studs so the warp in
-- `part` can bend and dent flat panels.
local GRID = 0.4

-- When set, every part sizes its texture to this many pixels per stud
-- instead of the fixed TEXTURE, so a layout reads at one texel density.
-- A part's own `texture` size still wins.
local texelDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	texelDensity = pixelsPerStud * (TEXEL_SCALE or 1)
end

local function gridFace(mesh, origin, u, v, nu, nv)
	local rows = {}
	for j = 0, nv do
		rows[j] = {}
		for i = 0, nu do
			local a, b = i / nu, j / nv
			rows[j][i] = mesh:vertex(
				origin[1] + u[1] * a + v[1] * b,
				origin[2] + u[2] * a + v[2] * b,
				origin[3] + u[3] * a + v[3] * b
			)
		end
	end
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			mesh:face({ rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i] })
		end
	end
end

local function box(mesh, cx, cy, cz, sx, sy, sz)
	local x0, y0, z0 = cx - sx / 2, cy - sy / 2, cz
	local nx = math.clamp(math.ceil(sx / GRID), 1, 8)
	local ny = math.clamp(math.ceil(sy / GRID), 1, 8)
	local nz = math.clamp(math.ceil(sz / GRID), 1, 8)
	gridFace(mesh, { x0, y0, z0 }, { 0, sy, 0 }, { sx, 0, 0 }, ny, nx)
	gridFace(mesh, { x0, y0, z0 + sz }, { sx, 0, 0 }, { 0, sy, 0 }, nx, ny)
	gridFace(mesh, { x0, y0, z0 }, { sx, 0, 0 }, { 0, 0, sz }, nx, nz)
	gridFace(mesh, { x0, y0 + sy, z0 }, { 0, 0, sz }, { sx, 0, 0 }, nz, nx)
	gridFace(mesh, { x0, y0, z0 }, { 0, 0, sz }, { 0, sy, 0 }, nz, ny)
	gridFace(mesh, { x0 + sx, y0, z0 }, { 0, sy, 0 }, { 0, 0, sz }, ny, nz)
end

-- Cylinder centered at (cx, cy, cz) along axis "x", "y" or "z".
local function cylinder(mesh, cx, cy, cz, radius, length, axis, sides)
	sides = sides or 16
	local a, b = {}, {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		local u, w = math.cos(t) * radius, math.sin(t) * radius
		local h = length / 2
		if axis == "x" then
			a[i + 1] = mesh:vertex(cx - h, cy + u, cz + w)
			b[i + 1] = mesh:vertex(cx + h, cy + u, cz + w)
		elseif axis == "y" then
			a[i + 1] = mesh:vertex(cx + w, cy - h, cz + u)
			b[i + 1] = mesh:vertex(cx + w, cy + h, cz + u)
		else
			a[i + 1] = mesh:vertex(cx + u, cy + w, cz - h)
			b[i + 1] = mesh:vertex(cx + u, cy + w, cz + h)
		end
	end
	for i = 1, sides do
		local j = i % sides + 1
		mesh:face({ a[i], a[j], b[j], b[i] })
	end
	local capA = {}
	for i = sides, 1, -1 do
		table.insert(capA, a[i])
	end
	mesh:face(capA)
	mesh:face(b)
end

-- UV sphere, squashed per axis by (rx, ry, rz).
local function sphere(mesh, cx, cy, cz, rx, ry, rz, rings, sides)
	rings, sides = rings or 8, sides or 16
	local grid = {}
	for r = 0, rings do
		local phi = r / rings * math.pi
		grid[r] = {}
		for s = 0, sides - 1 do
			local t = s / sides * TAU
			local x = math.sin(phi) * math.cos(t)
			local y = math.sin(phi) * math.sin(t)
			grid[r][s] = mesh:vertex(cx + x * rx, cy + y * ry, cz - math.cos(phi) * rz)
		end
	end
	for r = 0, rings - 1 do
		for s = 0, sides - 1 do
			local n = (s + 1) % sides
			mesh:face({ grid[r][s], grid[r][n], grid[r + 1][n], grid[r + 1][s] })
		end
	end
end

-- Flat ring (washer) facing along axis "x", "y" or "z": a rim round an eye,
-- a hub, a hose clamp.
local function ring(mesh, cx, cy, cz, inner, outer, depth, axis, sides)
	sides = sides or 16
	local function at(r, t, d)
		local u, w = math.cos(t) * r, math.sin(t) * r
		if axis == "x" then
			return mesh:vertex(cx + d, cy + u, cz + w)
		elseif axis == "y" then
			return mesh:vertex(cx + w, cy + d, cz + u)
		end
		return mesh:vertex(cx + u, cy + w, cz + d)
	end
	local rows = {}
	for i = 0, sides - 1 do
		local t = i / sides * TAU
		rows[i + 1] = { at(outer, t, -depth / 2), at(outer, t, depth / 2), at(inner, t, depth / 2), at(inner, t, -depth / 2) }
	end
	for i = 1, sides do
		local a, b = rows[i], rows[i % sides + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
end

-- Bolt head: a squat hexagonal stud on a face pointing along axis.
local function bolt(mesh, cx, cy, cz, axis, size)
	size = size or 0.05
	cylinder(mesh, cx, cy, cz, size, size * 0.7, axis, 6)
end

-- Square beam from one point to another, for limbs and antennae.
local function strut(mesh, x0, y0, z0, x1, y1, z1, thick)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / len, dy / len, dz / len
	local ax, ay, az = -dy, dx, 0
	if math.abs(dz) > 0.99 then
		ax, ay, az = 1, 0, 0
	end
	local al = math.sqrt(ax * ax + ay * ay + az * az)
	ax, ay, az = ax / al * thick / 2, ay / al * thick / 2, az / al * thick / 2
	local bx, by, bz = dy * az - dz * ay, dz * ax - dx * az, dx * ay - dy * ax
	local v = {}
	for i = 0, 7 do
		local sa = if i % 2 == 0 then -1 else 1
		local sb = if i // 2 % 2 == 0 then -1 else 1
		local x, y, z = if i // 4 == 0 then x0 else x1, if i // 4 == 0 then y0 else y1, if i // 4 == 0 then z0 else z1
		v[i + 1] = mesh:vertex(x + ax * sa + bx * sb, y + ay * sa + by * sb, z + az * sa + bz * sb)
	end
	for _, f in { { 1, 3, 4, 2 }, { 5, 6, 8, 7 }, { 1, 2, 6, 5 }, { 3, 7, 8, 4 }, { 1, 5, 7, 3 }, { 2, 4, 8, 6 } } do
		mesh:face({ v[f[1]], v[f[2]], v[f[3]], v[f[4]] })
	end
end

-- Points along a circular arc in the x-z plane, from angle a0 to a1 in
-- degrees. Feeds plate outlines; run the angles downward for a clockwise path.
local function arc(cx, cz, radius, a0, a1, steps)
	local points = {}
	for i = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(points, { cx + math.cos(a) * radius, cz + math.sin(a) * radius })
	end
	return points
end

-- Splits a clockwise x-z outline into triangles by ear clipping, so concave
-- silhouettes cap cleanly. Returns index triples into the outline.
local function earClip(outline)
	local left, tris = {}, {}
	for i = 1, #outline do
		left[i] = i
	end
	local function cross(a, b, c)
		return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
	end
	local guard = 0
	while #left > 3 and guard < 10000 do
		guard += 1
		local clipped = false
		for k = 1, #left do
			local i0, i1, i2 = left[(k - 2) % #left + 1], left[k], left[k % #left + 1]
			local a, b, c = outline[i0], outline[i1], outline[i2]
			if cross(a, b, c) < 0 then
				local inside = false
				for _, j in left do
					if j ~= i0 and j ~= i1 and j ~= i2 then
						local p = outline[j]
						if cross(a, b, p) <= 0 and cross(b, c, p) <= 0 and cross(c, a, p) <= 0 then
							inside = true
							break
						end
					end
				end
				if not inside then
					table.insert(tris, { i0, i1, i2 })
					table.remove(left, k)
					clipped = true
					break
				end
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(tris, { left[1], left[2], left[3] })
	end
	return tris
end

-- Flat cut-out plate: a clockwise x-z outline extruded `depth` along y,
-- centred on y, with both faces chamfered inward by `bevel`. Use it for any
-- silhouette (signs, blades, brackets) instead of stacking boxes.
local function plate(mesh, outline, y, depth, bevel)
	local n = #outline
	local inset = {}
	for i = 1, n do
		local p0, p1, p2 = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local function inward(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
			return dz / len, -dx / len
		end
		local n1x, n1z = inward(p0, p1)
		local n2x, n2z = inward(p1, p2)
		local bx, bz = n1x + n2x, n1z + n2z
		local bl = math.max(math.sqrt(bx * bx + bz * bz), 1e-6)
		bx, bz = bx / bl, bz / bl
		local scale = math.min(1 / math.max(bx * n1x + bz * n1z, 0.34), 3) * bevel
		inset[i] = { p1[1] + bx * scale, p1[2] + bz * scale }
	end
	local h = depth / 2
	local layers = {
		{ inset, y - h },
		{ outline, y - h + bevel },
		{ outline, y + h - bevel },
		{ inset, y + h },
	}
	local rows = {}
	for l, layer in layers do
		rows[l] = {}
		for i = 1, n do
			rows[l][i] = mesh:vertex(layer[1][i][1], layer[2], layer[1][i][2])
		end
	end
	for l = 1, 3 do
		for i = 1, n do
			local j = i % n + 1
			mesh:face({ rows[l][i], rows[l][j], rows[l + 1][j], rows[l + 1][i] })
		end
	end
	for _, t in earClip(inset) do
		mesh:face({ rows[1][t[3]], rows[1][t[2]], rows[1][t[1]] })
		mesh:face({ rows[4][t[1]], rows[4][t[2]], rows[4][t[3]] })
	end
end

-- Unit tangent along (tx, ty, tz) plus two unit axes across it, right-handed,
-- the first level with the ground unless the tangent runs nearly vertical.
local function crossFrame(tx, ty, tz)
	local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
	tx, ty, tz = tx / tl, ty / tl, tz / tl
	local ux, uy, uz = -ty, tx, 0
	if math.abs(tz) > 0.9 then
		ux, uy, uz = 0, tz, -ty
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	return tx, ty, tz, ux, uy, uz, ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
end

-- Round tube through `points` ({x, y, z} each), capped at both ends: rope
-- strands, and bolts on curved faces.
local function tube(mesh, points, radius, sides)
	sides = sides or 8
	local rings = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			ring[k + 1] = mesh:vertex(p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n)
		end
		rings[i] = ring
	end
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		for k = 1, sides do
			local n = k % sides + 1
			mesh:face({ a[k], a[n], b[n], b[k] })
		end
	end
	local cap = {}
	for k = sides, 1, -1 do
		table.insert(cap, rings[1][k])
	end
	mesh:face(cap)
	mesh:face(rings[#rings])
end

-- Point in the plane across `axis` at centre (cx, cy, cz): radius r, angle t,
-- offset d along the axis.
local function onAxis(cx, cy, cz, axis, r, t, d)
	local u, w = math.cos(t) * r, math.sin(t) * r
	if axis == "x" then
		return cx + d, cy + u, cz + w
	elseif axis == "y" then
		return cx + w, cy + d, cz + u
	end
	return cx + u, cy + w, cz + d
end

-- Spur gear turning about `axis`, with square teeth and a hole for its shaft.
local function gear(mesh, cx, cy, cz, radius, thick, teeth, axis)
	local steps = teeth * 4
	local rows = {}
	for i = 0, steps - 1 do
		local t = i / steps * TAU
		-- Two samples up on the tooth, two down in the gap.
		local r = if i % 4 < 2 then radius else radius * 0.82
		local hole = radius * 0.25
		rows[i + 1] = {
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, -thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, r, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, thick / 2)),
			mesh:vertex(onAxis(cx, cy, cz, axis, hole, t, -thick / 2)),
		}
	end
	for i = 1, steps do
		local a, b = rows[i], rows[i % steps + 1]
		for k = 1, 4 do
			local l = k % 4 + 1
			mesh:face({ a[k], b[k], b[l], a[l] })
		end
	end
	-- Shaft through the middle.
	cylinder(mesh, cx, cy, cz, radius * 0.25, thick * 1.8, axis, 8)
end

-- Drive belt wrapped round two pulleys turning about `axis`, the first at
-- (ax, ay, az) with radius ra, the second at (bx, by, bz) with radius rb.
local function belt(mesh, axis, ax, ay, az, ra, bx, by, bz, rb, thick)
	thick = thick or 0.025
	-- Work in the plane across the axis as (u, w), matching onAxis.
	local function flat(x, y, z)
		if axis == "x" then
			return y, z
		elseif axis == "y" then
			return z, x
		end
		return x, y
	end
	local au, aw = flat(ax, ay, az)
	local bu, bw = flat(bx, by, bz)
	local heading = math.atan2(bw - aw, bu - au)
	local points = {}
	-- Round the far side of b, then back round the far side of a.
	for i = 0, 8 do
		local t = heading - math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(bx, by, bz, axis, rb + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	for i = 0, 8 do
		local t = heading + math.pi / 2 + i / 8 * math.pi
		local x, y, z = onAxis(ax, ay, az, axis, ra + thick, t, 0)
		table.insert(points, { x, y, z })
	end
	table.insert(points, points[1])
	tube(mesh, points, thick, 4)
end

-- Exhaust pipe along `points`, ending in a flared, soot-black lip.
local function exhaust(mesh, points, radius)
	tube(mesh, points, radius, 10)
	local a, b = points[#points - 1], points[#points]
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / length, dy / length, dz / length
	tube(mesh, {
		{ b[1] - dx * 0.06, b[2] - dy * 0.06, b[3] - dz * 0.06 },
		{ b[1], b[2], b[3] },
	}, radius * 1.3, 10)
end

-- Little engine block: a box crankcase with a finned cylinder on top.
local function engine(mesh, cx, cy, cz, size)
	box(mesh, cx, cy, cz, size * 1.4, size, size * 0.7)
	local top = cz + size * 0.7
	cylinder(mesh, cx, cy, top + size * 0.35, size * 0.3, size * 0.7, "z", 12)
	for i = 0, 3 do
		ring(mesh, cx, cy, top + size * (0.1 + i * 0.17), size * 0.28, size * 0.45, size * 0.05, "z", 12)
	end
	box(mesh, cx, cy, top + size * 0.7, size * 0.5, size * 0.5, size * 0.1)
end

-- Bolt head on a curved face, standing out along the normal (nx, ny, nz).
local function stud(mesh, x, y, z, nx, ny, nz, size)
	size = size or 0.04
	local a, b = -size * 0.2, size * 0.5
	tube(mesh, { { x + nx * a, y + ny * a, z + nz * a }, { x + nx * b, y + ny * b, z + nz * b } }, size, 6)
end

-- Rope along `points`: two strands twisted round each other.
local function rope(mesh, points, radius)
	-- Resample the path finely enough for the twist to turn smoothly.
	local path = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / (radius * 0.8)))
		for k = 0, steps - 1 do
			table.insert(path, { a[1] + dx * k / steps, a[2] + dy * k / steps, a[3] + dz * k / steps })
		end
	end
	table.insert(path, points[#points])
	for strand = 0, 1 do
		local twisted = {}
		for i, p in path do
			local a, b = path[math.max(i - 1, 1)], path[math.min(i + 1, #path)]
			local _, _, _, ux, uy, uz, vx, vy, vz = crossFrame(b[1] - a[1], b[2] - a[2], b[3] - a[3])
			local t = i * 0.7 + strand * math.pi
			local c, n = math.cos(t) * radius * 0.45, math.sin(t) * radius * 0.45
			twisted[i] = { p[1] + ux * c + vx * n, p[2] + uy * c + vy * n, p[3] + uz * c + vz * n }
		end
		tube(mesh, twisted, radius * 0.6, 6)
	end
end

-- Rope lashed round a box at height z, its corners at x = +-halfX and
-- y from y0 to y1, rounded so it sits snug round each corner.
local function lashing(mesh, halfX, y0, y1, z, radius)
	local bend = radius * 3
	-- Corner centres counter-clockwise from (+X, y0), each with its start angle.
	local corners = {
		{ halfX - bend, y0 + bend, -math.pi / 2 },
		{ halfX - bend, y1 - bend, 0 },
		{ -halfX + bend, y1 - bend, math.pi / 2 },
		{ -halfX + bend, y0 + bend, math.pi },
	}
	local points = {}
	for _, c in corners do
		for k = 0, 3 do
			local t = c[3] + k / 3 * math.pi / 2
			table.insert(points, { c[1] + math.cos(t) * bend, c[2] + math.sin(t) * bend, z })
		end
	end
	table.insert(points, points[1])
	rope(mesh, points, radius)
end

-- Flat sheet lying on the face of a box at `axis` = `at`, its outer side toward
-- `sign`, covering a0..a1 along the other level axis and z0..z1 up, bolted at
-- each corner.
local function sheet(mesh, axis, at, sign, a0, a1, z0, z1, thick, boltSize)
	thick, boltSize = thick or 0.03, boltSize or 0.035
	local c = at + sign * thick / 2
	if axis == "x" then
		box(mesh, c, (a0 + a1) / 2, z0, thick, a1 - a0, z1 - z0)
	else
		box(mesh, (a0 + a1) / 2, c, z0, a1 - a0, thick, z1 - z0)
	end
	local inset = boltSize * 2
	for _, a in { a0 + inset, a1 - inset } do
		for _, z in { z0 + inset, z1 - inset } do
			if axis == "x" then
				bolt(mesh, at + sign * thick, a, z, "x", boltSize)
			else
				bolt(mesh, a, at + sign * thick, z, "y", boltSize)
			end
		end
	end
end

-- Angle bracket bent round the vertical box corner at (x, y), outer faces
-- toward sx and sy, legs `size` long, bolted through each leg.
local function cornerBracket(mesh, x, y, sx, sy, z, height, size)
	local t = 0.025
	box(mesh, x + sx * t / 2, y - sy * (size - t) / 2, z, t, size + t, height)
	box(mesh, x - sx * (size - t) / 2, y + sy * t / 2, z, size + t, t, height)
	for _, dz in { 0.25, 0.75 } do
		bolt(mesh, x + sx * t, y - sy * size * 0.6, z + height * dz, "x", 0.03)
		bolt(mesh, x - sx * size * 0.6, y + sy * t, z + height * dz, "y", 0.03)
	end
end

-- Weathering colors, in sRGB. The bake paints the wear itself, stroke by
-- stroke: rust patches, drips, grime and scratches on metal, dust and scuffs
-- on rubber. These are for parts made of the stuff.
local RUST_DARK = { 0.3, 0.2, 0.12 }
local RUST_ORANGE = { 0.62, 0.36, 0.15 }
local RUST_FLAKE = { 0.78, 0.52, 0.3 }
local BARE_METAL = { 0.74, 0.73, 0.7 }

-- How rusty a part painted by its own paint fn is; `rusting` sets it.
local paintRust = setmetatable({}, { __mode = "k" })

-- Marks a paint fn as `rust` worn (0 clean, 1 eaten through), for parts
-- whose coat has its own look but should still rust.
local function rusting(rust, paint)
	paintRust[paint] = rust
	return paint
end

local RUBBER = -1
local DUST = { 0.55, 0.5, 0.42 }
-- Bindings, painted as RUBBER: duct tape and hemp rope.
local TAPE = { 0.58, 0.58, 0.56 }
local RUBBER_BLACK = { 0.12, 0.12, 0.13 }
local ROPE = { 0.62, 0.5, 0.32 }

-- Part following one bone. `smooth` overrides the auto-smooth angle (true
-- for fully round parts like the zapper's body). `rust` sets how worn it
-- is, default 0.4; 0 for glowing eyes and visors; RUBBER for tyres and treads.
local WARP = 0.0385

-- Low-frequency warp so no panel is perfectly flat or square: a smooth sum
-- of sines seeded by the part name, plus a couple of dents.
local function imperfect(mesh, name)
	local seed = 0
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 9973
	end
	local function n(k)
		return math.sin(seed * 12.9898 + k * 78.233) * 0.5 + 0.5
	end
	local function noise(x, y, z, k)
		return math.sin(x * (1.7 + n(k)) + y * 0.9 + n(k + 1) * TAU) * 0.5
			+ math.sin(y * (2.3 + n(k + 2)) - z * 1.3 + n(k + 3) * TAU) * 0.3
			+ math.sin(z * (2.9 + n(k + 4)) + x * 1.1 + n(k + 5) * TAU) * 0.2
	end
	local dents = {}
	for d = 1, 2 do
		local k = d * 10
		dents[d] = { (n(k) - 0.5) * 3, (n(k + 1) - 0.5) * 3, n(k + 2) * 4, 0.3 + n(k + 3) * 0.4 }
	end
	return setmetatable({
		vertex = function(_, x, y, z)
			local dx, dy, dz = noise(x, y, z, 1), noise(y, z, x, 7), noise(z, x, y, 13)
			for _, dent in dents do
				local ox, oy, oz = x - dent[1], y - dent[2], z - dent[3]
				local fall = math.exp(-(ox * ox + oy * oy + oz * oz) / (dent[4] * dent[4]))
				dx -= ox * fall * 0.6
				dy -= oy * fall * 0.6
				dz -= oz * fall * 0.6
			end
			return mesh:vertex(x + dx * WARP, y + dy * WARP, z + dz * WARP)
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				return mesh[key](mesh, ...)
			end
		end,
	})
end

local parts = {}

-- What the bake paints on a part: `paint` gives its coat colors, `rust` how
-- worn it is, and `rubber` that it gathers dust and scuffs instead.
local function setLook(entry, color, rust)
	rust = rust or 0.4
	if type(rust) == "function" then
		entry.paint, entry.rust, entry.custom = rust, paintRust[rust] or 0, true
		return
	end
	entry.paint = function()
		return color[1], color[2], color[3]
	end
	entry.rust = math.max(rust, 0)
	entry.rubber = rust == RUBBER
end

-- `rust` can also be a paint fn for surfaces with their own look.
-- `texture` overrides the texture size for parts that need more detail.
-- `emissive` is a glow strength (like SurfaceAppearance.EmissiveStrength);
-- glowing parts skip painted shading. `flat` skips the warp, for parts so
-- thin it would visibly bend them. `edge` is how far highlights and contact
-- shadows reach from an edge, in studs: bigger surfaces take a wider band.
-- `shade` multiplies the contact shadow strength, for parts that should sit in
-- heavier shadow than the standard wear. `lit` scales the highlight strength
-- and `wide` the width of the highlight brush strokes. Set `painted` on an entry
-- to paint its highlights as bold, fully loaded strokes instead of dry ones,
-- and `blend` (0-1) to tint them from cream toward a lighter part colour.
local function part(name, bone, color, build, smooth, rust, texture: number?, emissive: number?, flat: boolean?, edge: number?, shade: number?, lit: number?, wide: number?)
	local mesh = Mesh.new()
	build(if rust == 0 or flat then mesh else imperfect(mesh, name))
	mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
	local fit = mesh:unwrap()
	local size = if texture then texture
		elseif texelDensity then math.clamp(math.ceil(texelDensity / fit / 4) * 4, 16, 1024)
		else TEXTURE
	local image = Image.new(size, size, color[1], color[2], color[3])
	local entry = { name = name, bone = bone, mesh = mesh, image = image, emissive = emissive, edge = edge, shade = shade, lit = lit, wide = wide }
	setLook(entry, color, rust)
	-- Glowing parts skip the painted bake, so their colors go on as they are.
	if emissive then
		mesh:paint(image, entry.paint)
	end
	table.insert(parts, entry)
end

-- Large surfaces (terrain, roads, floors) are split into cubes 128 studs
-- across, or 1024 texels at the layout's texel density if that is smaller,
-- each its own part with a texture up to 1024, named <name>_<cx>_<cy>_<cz>. The
-- build runs once into a recorder, then each face goes to the chunk holding
-- its centre. Cells sit on the origin across, and centred on z = 0 up and
-- down, so ground near sea level stays in one layer. `flat` skips the warp,
-- as for part(). Every chunk shades against one height range, the whole
-- mesh's z-range or the `heightRange` {bottom, top} given, so the gradient runs
-- on across chunks instead of restarting in each (a flat chunk would go dark).
local function chunkedPart(name, bone, color, build, smooth, rust, flat: boolean?, edge: number?, shade: number?, lit: number?, heightRange: { number }?)
	local CHUNK = if texelDensity then math.min(128, 1024 / texelDensity) else 128
	-- Smallest cell a chunk is halved down to while looking for a split.
	local MIN_CELL = 2
	local positions, faces = {}, {}
	local recorder = {
		vertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		-- A vertex the rust wobble leaves alone, for surfaces that must stay flat.
		exactVertex = function(_, x, y, z)
			table.insert(positions, { x, y, z })
			return #positions
		end,
		face = function(_, verts, uvs)
			table.insert(faces, { verts = verts, uvs = uvs })
		end,
	}
	build(if rust == 0 or flat then recorder else imperfect(recorder, name))
	if not heightRange then
		local bottom, top = math.huge, -math.huge
		for _, p in positions do
			bottom, top = math.min(bottom, p[3]), math.max(top, p[3])
		end
		heightRange = { bottom, top }
	end

	local chunks, order = {}, {}
	for _, f in faces do
		local cx, cy, cz = 0, 0, 0
		for _, v in f.verts do
			local p = positions[v]
			cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
		end
		local n = #f.verts
		local key = `{math.floor(cx / n / CHUNK)}_{math.floor(cy / n / CHUNK)}_{math.floor(cz / n / CHUNK + 0.5)}`
		if not chunks[key] then
			chunks[key] = {}
			table.insert(order, key)
		end
		table.insert(chunks[key], f)
	end

	-- Each chunk becomes a part. With a texel density set, a chunk whose
	-- texture would need more than 1024 texels to hold it is split into
	-- octants until every piece fits, so the whole surface reads at one density.
	local function chunkMesh(chunkFaces)
		local mesh, remap = Mesh.new(), {}
		for _, f in chunkFaces do
			local verts = {}
			for i, v in f.verts do
				if not remap[v] then
					local p = positions[v]
					remap[v] = mesh:vertex(p[1], p[2], p[3])
				end
				verts[i] = remap[v]
			end
			mesh:face(verts, f.uvs)
		end
		return mesh
	end
	local function emit(label, chunkFaces, size)
		local texture = 1024
		if texelDensity then
			local mesh = chunkMesh(chunkFaces)
			mesh:setSmooth(if smooth ~= nil then smooth else SMOOTH_ANGLE)
			local needed = math.ceil(texelDensity / mesh:unwrap() / 4) * 4
			if needed > 1024 and #chunkFaces > 1 then
				local half = size / 2
				local octants, octantOrder = {}, {}
				for _, f in chunkFaces do
					local cx, cy, cz = 0, 0, 0
					for _, v in f.verts do
						local p = positions[v]
						cx, cy, cz = cx + p[1], cy + p[2], cz + p[3]
					end
					local n = #f.verts
					local sub = `{math.floor(cx / n / half) % 2}{math.floor(cy / n / half) % 2}{math.floor(cz / n / half + 0.5) % 2}`
					if not octants[sub] then
						octants[sub] = {}
						table.insert(octantOrder, sub)
					end
					table.insert(octants[sub], f)
				end
				if #octantOrder > 1 then
					for _, sub in octantOrder do
						emit(`{label}_{sub}`, octants[sub], half)
					end
					return
				end
				-- Everything sits in one octant, such as a curved strip whose
				-- unwrap leaves most of the texture empty: halve the cell again
				-- until the faces part.
				if half >= MIN_CELL then
					emit(label, chunkFaces, half)
					return
				end
			end
			texture = math.clamp(needed, 16, 1024)
		end
		part(label, bone, color, function(mesh)
			local handles = {}
			for _, f in chunkFaces do
				local verts = {}
				for i, v in f.verts do
					if not handles[v] then
						local p = positions[v]
						handles[v] = mesh:vertex(p[1], p[2], p[3])
					end
					verts[i] = handles[v]
				end
				mesh:face(verts, f.uvs)
			end
			-- The recorder hands over a triangle soup; weld so the crease angle
			-- can run smooth over a chunk instead of faceting every triangle.
			mesh:weld(1e-4)
		end, smooth, 0, texture, nil, nil, edge, shade, lit)
		-- The warp was applied while recording; the chunk still wears the look.
		setLook(parts[#parts], color, rust)
		-- Chunks of one part share a group, so their edges count as its own.
		parts[#parts].group = name
		parts[#parts].heightRange = heightRange
	end
	for _, key in order do
		emit(`{name}_{key}`, chunks[key], CHUNK)
	end
end

-- Shades every part with all the others as occluders, so parts darken where
-- they touch or tuck under each other, then adds them to the model.
local function finishParts()
	for _, entry in parts do
		if entry.emissive then
			model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true, emissive = entry.emissive })
			continue
		end
		local occluders, group = {}, {}
		for _, other in parts do
			if other ~= entry and entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			rubber = entry.rubber,
			reach = entry.edge,
			highlightWidth = entry.wide,
			paintedHighlights = entry.painted,
			heightRange = entry.heightRange,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
-- Plot Marker: the post at a yard entrance naming its owner, about 2.2
-- studs tall (3.3 in the yard, 60% of a player's height). A short steel
-- post with a sign board bolted flat to its front, a blank face for the
-- owner's name, and a warning lamp on top that will flash on a raid.
-- Nothing reaches out past the post, so there is nothing to walk into.
local HAZARD_YELLOW = { 0.9, 0.72, 0.15 }
local LAMP_RED = { 0.85, 0.18, 0.12 }

part("Post", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, 0, 0, 0.7, 0.7, 0.12)
	box(mesh, 0, 0, 0.12, 0.25, 0.25, 1.68)
	-- Cap the lamp stands on.
	box(mesh, 0, 0, 1.8, 0.34, 0.34, 0.04)
end, nil, 0.5)
part("Sign", nil, HAZARD_YELLOW, function(mesh)
	box(mesh, 0, -0.22, 0.7, 1.5, 0.1, 0.85)
	box(mesh, 0, -0.28, 0.78, 1.24, 0.04, 0.69)
end, nil, 0.45)
part("Lamp", nil, LAMP_RED, function(mesh)
	cylinder(mesh, 0, 0, 1.96, 0.16, 0.24, "z", 12)
	sphere(mesh, 0, 0, 2.08, 0.15, 0.15, 0.12, 6, 12)
end, nil, 0)
part("Fittings", nil, STEEL, function(mesh)
	-- Anchor bolts on the base, and brackets holding the sign to the post.
	for _, x in { -0.24, 0.24 } do
		for _, y in { -0.24, 0.24 } do
			bolt(mesh, x, y, 0.12, "z", 0.05)
		end
	end
	for _, z in { 0.86, 1.36 } do
		box(mesh, 0, -0.15, z, 0.4, 0.1, 0.1)
		for _, x in { -0.5, 0.5 } do
			bolt(mesh, x, -0.28, z + 0.05, "y", 0.04)
		end
	end
	-- Conduit carrying power up the back of the post to the lamp.
	box(mesh, 0, 0.2, 0.3, 0.2, 0.15, 0.25)
	tube(mesh, { { 0, 0.17, 0.55 }, { 0, 0.16, 1.76 }, { 0, 0.08, 1.86 } }, 0.035, 6)
	-- Wire cage guarding the lamp.
	for i = 0, 3 do
		local a = i * TAU / 4 + TAU / 8
		strut(mesh, math.cos(a) * 0.2, math.sin(a) * 0.2, 1.84, math.cos(a) * 0.2, math.sin(a) * 0.2, 2.16, 0.03)
	end
	ring(mesh, 0, 0, 2.16, 0.17, 0.22, 0.035, "z", 12)
	ring(mesh, 0, 0, 1.86, 0.17, 0.23, 0.05, "z", 12)
end, nil, 0.5)
finishParts()
end
buildKeys[buildPlotMarker] = "PlotMarker-53a9068aea07f9ec"
slabKeys[16018] = "87b5bf6b2d213592-cf7e96091024d5cc"
slabKeys[16288] = "87b5bf6b2d213592-7ded6fc62f8b67a3"
slabKeys[16320] = "87b5bf6b2d213592-2f5b4070ee3aa512"
slabKeys[16400] = "87b5bf6b2d213592-7b25a7aa2539d602"
slabKeys[16408] = "87b5bf6b2d213592-107c5c30239027da"
slabKeys[16425] = "87b5bf6b2d213592-18845c9c8b69ea54"
-- uses: HubSectionA HubSectionB HubSectionEnd YardIsland YardFence YardFenceHalf YardFooting YardGate PlotMarker
-- Server Map: one server's whole map, centered on the origin, built as
-- floating islands laid out along a line (the Scrap Line). The hub is a long
-- island running along x, five sections in a row, paved from end to end: a
-- bed down the middle for the belt loop and its crane rails, a walkway along
-- each side of it and a plaza across each end, the west one with the spawn
-- ring. Eight yard islands stand in two rows, four either side of the hub
-- and a tier higher. A concrete ramp climbs from the hub's walkway to each
-- yard's bridge, a level steel span to its gate. That bridge is the only
-- way on or off a yard.
-- Each plot carries only a yard's shell (yardShell() below): players lay
-- their yards out themselves, so pads, bays, the crate and the rest are
-- placed by the game.
-- Labels: HubSection1-HubSection5, Line, Spawn, Island1-Island8,
-- Plot1-Plot8 (1-4 along the north row from the west, 5-8 along the south),
-- Approach1-Approach8, Spoke1-Spoke8, Bridge1-Bridge8 and
-- Yard1_<piece>-Yard8_<piece>, where the
-- pieces are Gate, PlotMarker, and Fence and Footing pieces.

-- Every map part is textured at one density so nothing reads sharper or
-- blurrier than its neighbours. Props keep their own texture sizes.
local MAP_DENSITY = 16
useTexelDensity(MAP_DENSITY)

-- A placed model can set its own texel density while it builds, and it only
-- builds when it isn't cached, so the map's density is set again after each
-- one. Otherwise everything after it bakes at the model's density, or not,
-- depending on what happens to be cached.
-- `scale` builds it that many times its own size (see place()).
local function placeModel(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, scale: number?)
	place(label, build, x, y, z, turn, nil, nil, scale)
	useTexelDensity(MAP_DENSITY)
end

-- Length of each yellow or black block in the bridges' hazard strips.
local HAZARD_BLOCK = 0.6
-- How much wider the bridges are than their 7-stud base design. Every
-- measurement across a bridge (deck, railings, girders, end posts, seats)
-- and the gaps it lands in scale by it; lengths and thicknesses don't.
local BRIDGE_WIDTH = 1.5
-- The Line's deck runs a little above the ground. The yards stand a tier
-- higher, level with their bridges.
local DECK = 2
local YARD_TIER = 6
-- The hub's island sections (HubSection*.luau) stand SECTION_SPACING apart
-- along x, overlapping at their ends. Their turf stands HUB_TURF above
-- their origin, just under the deck.
local SECTION_SPACING = 110
local HUB_TURF = 1.9
local HUB_GROUND = DECK - 0.2
-- The hub's rim stands at least this far from the Line's middle where the
-- yards' bridges start.
local HUB_RIM = 64.3
-- The Line's deck reaches LINE_HALF_LENGTH by LINE_HALF_WIDTH either side of
-- the middle. The belt's bed runs down its middle, BED_HALF_LENGTH by
-- BED_HALF_WIDTH, leaving a walkway 30 studs wide along each side (a player
-- is 4 across) and a plaza 36 deep across each end.
local LINE_HALF_LENGTH, LINE_HALF_WIDTH = 268, 56
local BED_HALF_LENGTH, BED_HALF_WIDTH = 232, 26
-- The yards stand in two rows, YARD_ROW studs either side of the Line, at
-- YARD_COLUMNS along it. A plot is PLOT_WIDTH across and PLOT_DEPTH deep,
-- its gate in the middle of the side facing the Line. A yard island
-- (YardIsland.luau) reaches at least YARD_ISLAND_FRONT studs toward the Line
-- from its middle, where the bridge lands; its turf stands YARD_TURF above
-- its origin. Yard islands are at most 120 across, so neighbours stand over
-- 20 studs apart, more than twice a jump.
local YARD_ROW = 180
local YARD_COLUMNS = { -210, -70, 70, 210 }
local PLOT_WIDTH, PLOT_DEPTH = 96, 112
local YARD_ISLAND_FRONT = 66
local YARD_TURF = 1.76
-- Each end of a yard's bridge sits this far in from where an island's rim
-- is sure to reach. The span is level at the yard tier, so wherever the
-- yard's rim swells further out the deck still rides on top of its turf,
-- and it clears the hub's turf by 4 studs. The climb is the approach ramp's:
-- APPROACH_RUN long on the hub's walkway (leaving 20 studs of it clear, five
-- players abreast), then a level landing under the bridge's end.
local BRIDGE_SEAT = 1.5
local APPROACH_RUN = 14
local APPROACH_HALF = 3.8 * BRIDGE_WIDTH

local ROAD = { 0.42, 0.41, 0.4 }
local CONCRETE = { 0.55, 0.54, 0.5 }
local MARK = { 0.85, 0.65, 0.15 }
local PLOT = { 0.36, 0.33, 0.28 }

-- Places one flat piece built here rather than from a model.
local function slab(label: string, build: () -> (), x: number, y: number, turn: number?)
	placeSlab(label, build, x, y, turn, function()
		finishParts()
		table.clear(parts)
	end)
end

-- Fractal noise: octaves of math.noise, each twice as fine and half as strong.
local function fbm(x: number, y: number, z: number): number
	local total, amplitude = 0, 0.5
	for _ = 1, 4 do
		total += math.noise(x, y, z) * amplitude
		x, y, z, amplitude = x * 2, y * 2, z * 2, amplitude / 2
	end
	return total
end
-- fBm sampled through another fBm, so the wear twists into blotches and
-- streaks instead of even waves.
local function warpedFbm(x: number, y: number, z: number): number
	return fbm(x + 1.8 * fbm(x + 5.2, y + 1.3, z), y + 1.8 * fbm(x + 1.7, y + 9.2, z), z)
end
-- Bridge deck: riveted steel tread plates laid across the span, with dark
-- seams, raised diamond treads worn smooth down the two wheel paths, and
-- grime and rust bleeding in from the edges. (The hazard strips are parts of
-- their own, laid on top; see bridge().) Painted in the bridge's own frame so
-- every bridge wears the same way along its length. `flareAt` says how far the
-- railings have flared at each point along it, and the edges flare with them.
local function bridgeDeck(degrees: number, cx: number, cy: number, flareAt: (number) -> number)
	local angle = math.rad(degrees - 90)
	local c, s = math.cos(angle), math.sin(angle)
	return function(x: number, y: number, _z: number)
		local u = (x - cx) * c + (y - cy) * s
		local v = (y - cy) * c - (x - cx) * s
		local flare = flareAt(v)
		local edge = (3 + 0.5 * flare) * BRIDGE_WIDTH - math.abs(u)
		local wheel = math.exp(-((math.abs(u) - 1.4 * BRIDGE_WIDTH) / 0.5) ^ 2)
		local k = 0.72 + fbm(u / 2, v / 2, 31) * 0.1
		-- Diamond treads alternate direction, flattened where tyres run.
		local du, dv = (u * 5) % 1 - 0.5, (v * 2.5) % 1 - 0.5
		local flip = if math.floor(u * 5) % 2 == math.floor(v * 2.5) % 2 then 1 else -1
		local tread = math.abs(du * 2 + flip * dv * 1.2) < 0.18 and math.abs(du) < 0.38
		if tread then
			k += 0.14 * (1 - wheel * 0.8)
		end
		k += wheel * (0.08 + fbm(u * 3, v / 4, 37) * 0.08)
		-- Plate seams every 2 studs, with a bolt pair near each edge.
		local seam = math.abs((v % 2) - 1)
		if seam > 0.96 then
			k -= 0.35
		elseif seam > 0.86 and math.abs(edge - 0.35) < 0.1 then
			k += 0.25
		end
		-- Edge grime and rust runs.
		local grime = math.clamp(1 - edge / 0.9, 0, 1) * (0.6 + fbm(v / 1.5, u, 41) * 0.8)
		k -= grime * 0.3 + math.max(0, warpedFbm(u / 3, v / 3, 43)) * 0.25
		local rust = math.clamp(grime + math.max(0, fbm(u, v / 1.2, 47)) - 0.35, 0, 1)
		local r, g, b = STEEL[1], STEEL[2], STEEL[3]
		return r * k + rust * 0.12, g * k + rust * 0.02, b * k - rust * 0.06
	end
end
-- Bridge girders: dark paint flaking off in patches to bare rust, with
-- rivet rows along both flanges.
local function bridgeGirders(degrees: number, cx: number, cy: number)
	local angle = math.rad(degrees - 90)
	local c, s = math.cos(angle), math.sin(angle)
	return function(x: number, y: number, z: number)
		local u = (x - cx) * c + (y - cy) * s
		local v = (y - cy) * c - (x - cx) * s
		local k = 1 + fbm(u + v / 2, z * 2, 51) * 0.12
		local flake = warpedFbm(v / 2.5, z * 1.5 + u, 53)
		local rust = math.clamp((flake - 0.1) * 4, 0, 1)
		local flange = math.abs(z + 0.35) < 0.05 or math.abs(z + 1.25) < 0.05
		local rivet = flange and math.abs(((v * 2) % 1) - 0.5) < 0.04
		if rivet then k += 0.45 end
		local r = DARK_STEEL[1] * k * (1 - rust) + 0.42 * rust * k
		local g = DARK_STEEL[2] * k * (1 - rust) + 0.2 * rust * k
		local b = DARK_STEEL[3] * k * (1 - rust) + 0.1 * rust * k
		return r, g, b
	end
end

-- Asphalt at u studs across and v along a road: fine aggregate, darker
-- repair patches, polished tyre lanes, oil drips between them, a web of
-- cracks, and worn paint: white edge lines and a dashed yellow centre line.
local function asphalt(u: number, v: number, half: number, seed: number): (number, number, number)
	local k = 1 + fbm(u * 3, v * 3, seed) * 0.12
	k += (math.noise(u * 9.1, v * 9.1, seed + 1) > 0.35 and 0.1 or 0)
	local patch = warpedFbm(u / 6, v / 6, seed + 2)
	if patch > 0.22 then
		k -= 0.16
	end
	local lane = math.exp(-((math.abs(u) - half / 2) / 0.6) ^ 2)
	k += lane * (0.07 + fbm(u, v / 5, seed + 3) * 0.05)
	local oil = math.max(0, fbm(u / 1.5, v / 3, seed + 4) - 0.15) * (1 - lane)
	k -= oil * 0.9
	local crack = math.abs(warpedFbm(u / 3, v / 3, seed + 5))
	if crack < 0.012 then
		k -= 0.35
	end
	local r, g, b = ROAD[1] * k, ROAD[2] * k, ROAD[3] * k * 1.02
	local fade = math.clamp(0.75 + fbm(u * 2, v / 2, seed + 6) * 1.2 - lane * 0.3, 0, 1)
	local edgeLine = math.abs(math.abs(u) - (half - 0.5)) < 0.1
	if edgeLine then
		return r + (0.82 - r) * fade, g + (0.8 - g) * fade, b + (0.74 - b) * fade
	end
	return r, g, b
end

-- A straight block `width` wide from (ax, ay) to (bx, by), its bottom and
-- top heights at each end given as { bottom, top }, so it can slope.
local function upstand(mesh, ax: number, ay: number, bx: number, by: number, width: number, aHeights: { number }, bHeights: { number })
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	local px, py = -dy / length * width / 2, dx / length * width / 2
	-- Each end's corners: right bottom, left bottom, left top, right top.
	local function corners(x: number, y: number, heights: { number })
		return {
			mesh:vertex(x - px, y - py, heights[1]),
			mesh:vertex(x + px, y + py, heights[1]),
			mesh:vertex(x + px, y + py, heights[2]),
			mesh:vertex(x - px, y - py, heights[2]),
		}
	end
	local a, b = corners(ax, ay, aHeights), corners(bx, by, bHeights)
	mesh:face({ a[4], b[4], b[3], a[3] })
	mesh:face({ a[2], b[2], b[1], a[1] })
	mesh:face({ a[1], b[1], b[4], a[4] })
	mesh:face({ a[2], a[3], b[3], b[2] })
	mesh:face({ a[1], a[4], a[3], a[2] })
	mesh:face({ b[1], b[2], b[3], b[4] })
end
-- A steel bridge on spoke `degrees`, placed at (x, y) and turned so local +y
-- runs along it, from its low end at `to` (on deck level, or at `lowZ`) to
-- its far end at `from`, which climbs to `highZ`. Every part is built flat and then sheared
-- up along its length, so posts stay upright and the end pieces sit level at
-- their own tier. A yard end lands on an apron; at any other end the
-- railings flare out to the kerb ends and stop at end posts. Across the
-- bridge everything is laid out on the 7-stud base design times
-- BRIDGE_WIDTH, through `w`.
local function bridge(label: string, x: number, y: number, degrees: number, from: number, to: number, highZ: number, yardEnd: boolean, lowZ: number?)
	local middle, length = (from + to) / 2, from - to
	local w = BRIDGE_WIDTH
	local low = lowZ or DECK
	local function lift(py: number): number
		return low + (highZ - low) * math.clamp((py - to) / length, 0, 1)
	end
	local function bridgePart(name: string, color, build: (any) -> (), paint, flat: boolean?)
		part(name, nil, color, function(mesh)
			build({
				vertex = function(_, vx, vy, vz)
					return mesh:vertex(vx, vy, vz + lift(vy))
				end,
				face = function(_, corners)
					return mesh:face(corners)
				end,
			})
		end, nil, paint, nil, nil, flat)
	end
	local postCount = math.ceil((length - 0.3) / 2.5)
	local postGap = (length - 0.3) / postCount
	local flareFrom = if yardEnd then from - 0.1 else from - 0.15 - postGap
	local flareTo = to + 0.15 + postGap
	-- Where the railings flare: each end at `edge`, its rails running
	-- inward along +y (`inward` 1) or -y (-1) from the end post.
	local flares = { { to, 1, flareTo } }
	if not yardEnd then
		table.insert(flares, { from, -1, flareFrom })
	end
	local function endPostAt(edge: number, inward: number): number
		return edge + inward * 0.2
	end
	-- How far the railings have flared at `py`: 0 between the flares, 1 at
	-- the end posts and beyond.
	local function flareAt(py: number): number
		local amount = math.clamp((flareTo - py) / (flareTo - endPostAt(to, 1)), 0, 1)
		if yardEnd then
			return amount
		end
		return math.max(amount, math.clamp((py - flareFrom) / (endPostAt(from, -1) - flareFrom), 0, 1))
	end
	-- The deck's top at `py`, above the bridge's line: level along the span,
	-- ramping down over the last stud at a kerb end.
	local function topAt(py: number): number
		local inFromEdge = if yardEnd then py - to else math.min(py - to, from - py)
		return 0.1 * math.clamp(inFromEdge, -0.4, 1)
	end
	slab(label, function()
		-- Steel decking that widens with the railings where they flare, so it
		-- runs under the upstands out to the kerb ends. At a kerb end its top
		-- ramps down to the plaza over the last stud and runs on just under
		-- it, so the walk off the bridge has no lip. Left unwarped so the
		-- walking surface and its seam with the plaza stay true. Built as
		-- rows of vertices across the deck at each station along it.
		bridgePart("Deck", STEEL, function(mesh)
			local stations = { to - 0.4, to, endPostAt(to, 1), to + 1 }
			for n = 0, 8 do
				table.insert(stations, flareTo + (flareFrom - flareTo) * n / 8)
			end
			if yardEnd then
				table.insert(stations, from)
			else
				for _, py in { from - 1, endPostAt(from, -1), from, from + 0.4 } do
					table.insert(stations, py)
				end
			end
			local top, bottom = {}, {}
			for k, py in stations do
				local half = (3 + 0.5 * flareAt(py)) * w
				top[k], bottom[k] = {}, {}
				for i = 0, 8 do
					local px = -half + half * i / 4
					top[k][i] = mesh:vertex(px, py, topAt(py))
					bottom[k][i] = mesh:vertex(px, py, -0.2)
				end
			end
			local last = #stations
			for k = 1, last - 1 do
				for i = 0, 7 do
					mesh:face({ top[k][i], top[k][i + 1], top[k + 1][i + 1], top[k + 1][i] })
					mesh:face({ bottom[k][i], bottom[k + 1][i], bottom[k + 1][i + 1], bottom[k][i + 1] })
				end
				mesh:face({ bottom[k][8], bottom[k + 1][8], top[k + 1][8], top[k][8] })
				mesh:face({ bottom[k][0], top[k][0], top[k + 1][0], bottom[k + 1][0] })
			end
			for i = 0, 7 do
				mesh:face({ bottom[1][i], bottom[1][i + 1], top[1][i + 1], top[1][i] })
				mesh:face({ bottom[last][i], top[last][i], top[last][i + 1], bottom[last][i + 1] })
			end
		end, bridgeDeck(degrees, x, y, flareAt), true)
		-- Hazard strips along both outer plates: blocks of yellow and black laid
		-- just proud of the deck, each colour its own part so the blocks stay
		-- crisp and even. They run from end post to end post and step out with
		-- the railings where they flare.
		local first = endPostAt(to, 1)
		local last = if yardEnd then from - 0.1 else endPostAt(from, -1)
		local blocks = math.max(1, math.round((last - first) / HAZARD_BLOCK))
		for k, colour in { MARK, { 0.08, 0.08, 0.08 } } do
			bridgePart(if k == 1 then "HazardYellow" else "HazardBlack", colour, function(mesh)
				for n = k - 1, blocks - 1, 2 do
					local a = first + (last - first) * n / blocks
					local b = first + (last - first) * (n + 1) / blocks
					for _, side in { -1, 1 } do
						local corners = {}
						for i, py in { a, b } do
							local centre = (2.45 + 0.6 * flareAt(py)) * w
							local z = topAt(py) + 0.015
							corners[i] = { side * (centre - 0.25), side * (centre + 0.25), py, z }
						end
						-- A thin block: its top, and the four sides down to the deck.
						local top, base = {}, {}
						for i, corner in { corners[1], corners[2] } do
							local inner, outer, py, z = corner[1], corner[2], corner[3], corner[4]
							top[i * 2 - 1] = mesh:vertex(inner, py, z)
							top[i * 2] = mesh:vertex(outer, py, z)
							base[i * 2 - 1] = mesh:vertex(inner, py, z - 0.03)
							base[i * 2] = mesh:vertex(outer, py, z - 0.03)
						end
						local quads = {
							{ top[1], top[2], top[4], top[3] },
							{ base[1], base[2], top[2], top[1] },
							{ base[4], base[3], top[3], top[4] },
							{ base[2], base[4], top[4], top[2] },
							{ base[3], base[1], top[1], top[3] },
						}
						for _, quad in quads do
							-- The left side mirrors the right, so it winds the other way.
							mesh:face(if side > 0 then quad else { quad[4], quad[3], quad[2], quad[1] })
						end
					end
				end
			end, 0.1, true)
		end
		bridgePart("Girders", DARK_STEEL, function(mesh)
			-- I-beams: a web between two flanges, ribbed on the outside, with
			-- bolted splice plates where the beam sections join.
			for _, side in { -2.6 * w, 2.6 * w } do
				local out = math.sign(side)
				box(mesh, side, middle, -1.4, 0.2, length, 1.2)
				box(mesh, side, middle, -1.4, 0.6, length, 0.15)
				box(mesh, side, middle, -0.4, 0.6, length, 0.15)
				for n = 0, math.floor(length / 2) do
					box(mesh, side + out * 0.17, to + 1 + n * 2, -1.25, 0.14, 0.1, 0.85)
				end
				for n = 1, math.floor(length / 8) do
					local at = to + n * 8
					box(mesh, side + out * 0.13, at, -1.15, 0.06, 0.9, 0.65)
					for _, dy in { -0.3, 0.3 } do
						for _, dz in { -1.0, -0.65 } do
							box(mesh, side + out * 0.18, at + dy, dz, 0.06, 0.1, 0.1)
						end
					end
				end
			end
			for n = 0, math.floor(length / 4) do
				box(mesh, 0, to + 1 + n * 4, -0.6, 5.6 * w, 0.3, 0.4)
			end
		end, bridgeGirders(degrees, x, y))
		-- Railing posts spaced evenly so both ends get one, each bolted down
		-- on a base plate and capped. A flared end trades its last post for
		-- an end post out at the kerb end.
		bridgePart("Posts", STEEL, function(mesh)
			for _, side in { -2.9 * w, 2.9 * w } do
				for n = 1, if yardEnd then postCount else postCount - 1 do
					local at = to + 0.15 + n * postGap
					box(mesh, side, at, -0.05, 0.36, 0.36, 0.06)
					box(mesh, side, at, 0.01, 0.14, 0.14, 1.27)
					box(mesh, side, at, 1.28, 0.2, 0.2, 0.06)
				end
			end
		end, 0.4)
		-- Handrail on top, a thinner mid rail and a kick plate at the deck,
		-- straight between the flares, then angled out to the end posts.
		bridgePart("Rail", MARK, function(mesh)
			local straight, span = (flareFrom + flareTo) / 2, flareFrom - flareTo
			for _, side in { -2.9 * w, 2.9 * w } do
				local out = math.sign(side)
				box(mesh, side, straight, 1.16, 0.16, span, 0.12)
				box(mesh, side, straight, 0.62, 0.08, span, 0.08)
				box(mesh, side + out * 0.1, straight, -0.05, 0.04, span, 0.22)
				for _, flare in flares do
					local edge, inward, start = flare[1], flare[2], flare[3]
					local postY = endPostAt(edge, inward)
					strut(mesh, side, start, 1.22, out * 3.5 * w, postY, 1.22, 0.14)
					strut(mesh, side, start, 0.66, out * 3.5 * w, postY, 0.66, 0.08)
				end
			end
		end, 0.3)
		-- The kerb wraps round each end: a block over the kerb end, then an
		-- upstand under the flared rail that sinks into the deck where the
		-- flare starts, so the railing grows out of the kerb.
		bridgePart("KerbEnds", CONCRETE, function(mesh)
			for _, side in { -2.9 * w, 2.9 * w } do
				local out = math.sign(side)
				for _, flare in flares do
					local postY = endPostAt(flare[1], flare[2])
					box(mesh, out * 3.5 * w, postY, -0.6, 0.7, 0.7, 0.9)
					upstand(mesh, out * 3.5 * w, postY, side, flare[3], 0.4, { -0.6, 0.3 }, { -0.2, 0.1 })
				end
			end
		end, 0.5)
		-- End posts: heavy dark steel standing on the kerb ends, each bolted
		-- down on a base plate and capped with a broad plate, so the railing
		-- reads as ending.
		bridgePart("EndPosts", DARK_STEEL, function(mesh)
			for _, side in { -3.5 * w, 3.5 * w } do
				for _, flare in flares do
					local postY = endPostAt(flare[1], flare[2])
					box(mesh, side, postY, 0.3, 0.6, 0.6, 0.06)
					box(mesh, side, postY, 0.36, 0.4, 0.4, 1.04)
					box(mesh, side, postY, 1.4, 0.52, 0.52, 0.1)
				end
			end
		end, 0.4)
		-- Each island end rests on a concrete seat set into the island edge,
		-- its top clear of the island's rock top (0.2 under the deck) so the
		-- rock never shows through. A yard end adds a low wing wall either side
		-- for the yard edge to end against; a kerb ends inside an end post.
		bridgePart("Abutments", CONCRETE, function(mesh)
			for _, ends in { { to, -1 }, { from, 1 } } do
				local edge, land = ends[1], ends[2]
				box(mesh, 0, edge + land * 0.75, -3, 7.3 * w, 3.5, 2.92)
				if land == 1 and yardEnd then
					for _, side in { -3.4 * w, 3.4 * w } do
						box(mesh, side, edge - land * 0.5, -3, 0.5, 1, 3.45)
					end
				end
			end
		end, 0.5)
		-- A yard end lands on its apron with a steel plate over the joint.
		if not yardEnd then return end
		bridgePart("JointPlate", STEEL, function(mesh)
			box(mesh, 0, from, 0.1, 6 * w, 0.8, 0.04)
		end, 0.3, true)
		bridgePart("Apron", CONCRETE, function(mesh)
			box(mesh, 0, from + 2.5, 0, 7.3 * w, 5, 0.12)
		end, 0.5)
	end, x, y, degrees - 90)
end

-- Walkway paving at u studs across and v along the Line: poured concrete
-- bays with tooled joints, each bay a shade of its own, under stains and
-- hairline cracks.
local PAVING_BAY = 6
local function paving(u: number, v: number, seed: number): (number, number, number)
	local k = 1 + fbm(u * 2, v * 2, seed) * 0.1 + fbm(u / 7, v / 7, seed + 1) * 0.16
	-- Bays are staggered from one row to the next.
	local row = math.floor(u / PAVING_BAY)
	local along = v + (row % 2) * PAVING_BAY / 2
	k += math.noise(row * 0.71, math.floor(along / PAVING_BAY) * 0.37, seed + 2) * 0.12
	local across = u % PAVING_BAY
	local joint = math.min(across, PAVING_BAY - across, along % PAVING_BAY, PAVING_BAY - along % PAVING_BAY)
	if joint < 0.08 then
		k -= 0.3
	end
	k -= math.max(0, warpedFbm(u / 5, v / 5, seed + 3) - 0.18) * 0.8
	if math.abs(warpedFbm(u / 4, v / 4, seed + 4)) < 0.01 then
		k -= 0.3
	end
	return CONCRETE[1] * k, CONCRETE[2] * k, CONCRETE[3] * k
end

-- A paved block from (x0, y0) to (x1, y1): its top and its four sides, laid
-- in cells no longer than DECK_CELL so chunkedPart can deal them out. It
-- stands on an island, so it has no underside.
local DECK_CELL = 16
local function pavedBlock(mesh, x0: number, y0: number, x1: number, y1: number, bottom: number, top: number)
	local nx, ny = math.ceil((x1 - x0) / DECK_CELL), math.ceil((y1 - y0) / DECK_CELL)
	local low, high = {}, {}
	for i = 0, nx do
		low[i], high[i] = {}, {}
		for j = 0, ny do
			local x, y = x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny
			low[i][j], high[i][j] = mesh:vertex(x, y, bottom), mesh:vertex(x, y, top)
		end
	end
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			mesh:face({ high[i][j], high[i + 1][j], high[i + 1][j + 1], high[i][j + 1] })
		end
		mesh:face({ low[i][0], low[i + 1][0], high[i + 1][0], high[i][0] })
		mesh:face({ low[i + 1][ny], low[i][ny], high[i][ny], high[i + 1][ny] })
	end
	for j = 0, ny - 1 do
		mesh:face({ low[0][j + 1], low[0][j], high[0][j], high[0][j + 1] })
		mesh:face({ low[nx][j], low[nx][j + 1], high[nx][j + 1], high[nx][j] })
	end
end
-- A kerb from (ax, ay) to (bx, by), standing 0.3 over the deck, in pieces
-- no longer than DECK_CELL.
local function kerbRun(mesh, ax: number, ay: number, bx: number, by: number)
	local pieces = math.ceil(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) / DECK_CELL)
	local heights = { DECK - 0.6, DECK + 0.3 }
	for n = 1, pieces do
		local from, to = (n - 1) / pieces, n / pieces
		upstand(mesh, ax + (bx - ax) * from, ay + (by - ay) * from, ax + (bx - ax) * to, ay + (by - ay) * to, 0.6, heights, heights)
	end
end

-- The hub's island sections in a row along x, an end section at each end
-- turned to face outward. Neighbours overlap, so every other one sits a
-- hair lower to keep their turf from z-fighting; the deck hides the step.
local HUB_SECTIONS = {
	{ buildHubSectionEnd, 180 },
	{ buildHubSectionA, 0 },
	{ buildHubSectionB, 0 },
	{ buildHubSectionA, 180 },
	{ buildHubSectionEnd, 0 },
}
for i, section in HUB_SECTIONS do
	placeModel(`HubSection{i}`, section[1], (i - 3) * SECTION_SPACING, 0, HUB_GROUND - HUB_TURF - (i % 2) * 0.05, section[2])
end

-- The Line's deck: concrete walkways along both sides and plazas across
-- both ends, round an asphalt bed for the belt loop. A kerb runs round its
-- edge, broken where each yard's bridge lands. Chunked, as it runs the
-- whole hub.
slab("Line", function()
	chunkedPart("Walk", nil, CONCRETE, function(mesh)
		pavedBlock(mesh, -LINE_HALF_LENGTH, BED_HALF_WIDTH, LINE_HALF_LENGTH, LINE_HALF_WIDTH, DECK - 0.6, DECK)
		pavedBlock(mesh, -LINE_HALF_LENGTH, -LINE_HALF_WIDTH, LINE_HALF_LENGTH, -BED_HALF_WIDTH, DECK - 0.6, DECK)
		pavedBlock(mesh, BED_HALF_LENGTH, -BED_HALF_WIDTH, LINE_HALF_LENGTH, BED_HALF_WIDTH, DECK - 0.6, DECK)
		pavedBlock(mesh, -LINE_HALF_LENGTH, -BED_HALF_WIDTH, -BED_HALF_LENGTH, BED_HALF_WIDTH, DECK - 0.6, DECK)
	end, nil, function(px, py)
		return paving(py, px, 120)
	end, true)
	chunkedPart("Bed", nil, ROAD, function(mesh)
		pavedBlock(mesh, -BED_HALF_LENGTH, -BED_HALF_WIDTH, BED_HALF_LENGTH, BED_HALF_WIDTH, DECK - 0.6, DECK)
	end, nil, function(px, py)
		return asphalt(py, px, BED_HALF_WIDTH, 50)
	end, true)
	-- Each kerb run ends inside a bridge end post, 3.5 * BRIDGE_WIDTH off
	-- the bridge's middle.
	chunkedPart("Kerb", nil, CONCRETE, function(mesh)
		local edge, ends = LINE_HALF_WIDTH + 0.2, LINE_HALF_LENGTH + 0.2
		local gap = 3.5 * BRIDGE_WIDTH
		for _, side in { -1, 1 } do
			local from = -ends
			for _, column in YARD_COLUMNS do
				kerbRun(mesh, from, side * edge, column - gap, side * edge)
				from = column + gap
			end
			kerbRun(mesh, from, side * edge, ends, side * edge)
			kerbRun(mesh, side * ends, -edge, side * ends, edge)
		end
	end, nil, 0.5)
end, 0, 0)

-- New players start on a ring painted on the west plaza.
slab("Spawn", function()
	part("Pad", nil, MARK, function(mesh)
		ring(mesh, 0, 0, DECK + 0.05, 8, 9, 0.1, "z", 48)
	end, nil, 0)
end, -(BED_HALF_LENGTH + LINE_HALF_LENGTH) / 2, 0)

-- Packed dirt for a yard's floor at (u, v): trodden and uneven, with old
-- concrete slabs showing through in patches and grit scattered over it.
local YARD_DIRT = { 0.42, 0.36, 0.28 }
local function yardGround(u: number, v: number, seed: number): (number, number, number)
	local slab = warpedFbm(u / 9, v / 9, seed + 2)
	if slab > 0.2 then
		local k = 1 + fbm(u, v, seed + 3) * 0.12
		if math.min(u % 4, 4 - u % 4, v % 4, 4 - v % 4) < 0.06 then
			k -= 0.25
		end
		return 0.56 * k, 0.55 * k, 0.52 * k
	end
	local k = 1 + fbm(u / 3, v / 3, seed) * 0.2 + fbm(u * 2, v * 2, seed + 1) * 0.08
	if slab > 0.17 then
		k -= 0.2
	end
	if math.noise(u * 4.3, v * 4.3, seed + 4) > 0.42 then
		k += 0.12
	end
	return YARD_DIRT[1] * k, YARD_DIRT[2] * k, YARD_DIRT[3] * k
end

-- Builds one yard's shell on the plot at (x, y), turned `turn` so its gate
-- (local -y) faces the Line: the fence, the gate and the plot marker. Pieces
-- are placed in studs in the yard's frame, each built `scale` times its
-- own size.
local function yardShell(index: number, x: number, y: number, turn: number)
	local c, s = math.cos(math.rad(turn)), math.sin(math.rad(turn))
	local function piece(name: string, build: () -> (), scale: number, px: number, py: number, pz: number?, pturn: number?, stretch: number?, axis: string?)
		place(`Yard{index}_{name}`, build, x + px * c - py * s, y + px * s + py * c, YARD_TIER + (pz or 0), turn + (pturn or 0), stretch, axis, scale)
		useTexelDensity(MAP_DENSITY)
	end
	-- Fences: eight panels along the back, nine down each side stretched to
	-- fill the plot's depth, and three and a half either side of the gate.
	local FENCE = 1.5
	local sidePanel = PLOT_DEPTH / 9
	for n = 1, 8 do
		local px = -PLOT_WIDTH / 2 + (n - 0.5) * 12
		piece(`FenceBack{n}`, buildYardFence, FENCE, px, PLOT_DEPTH / 2, 0, 180)
		piece(`FootingBack{n}`, buildYardFooting, FENCE, px, PLOT_DEPTH / 2)
	end
	for n = 1, 9 do
		local py = -PLOT_DEPTH / 2 + (n - 0.5) * sidePanel
		piece(`FenceLeft{n}`, buildYardFence, FENCE, -PLOT_WIDTH / 2, py, 0, 270, sidePanel / 12)
		piece(`FenceRight{n}`, buildYardFence, FENCE, PLOT_WIDTH / 2, py, 0, 90, sidePanel / 12)
		piece(`FootingLeft{n}`, buildYardFooting, FENCE, -PLOT_WIDTH / 2, py, 0, 90, sidePanel / 12)
		piece(`FootingRight{n}`, buildYardFooting, FENCE, PLOT_WIDTH / 2, py, 0, 90, sidePanel / 12)
	end
	for n, side in { -1, 1 } do
		for k = 1, 3 do
			piece(`FenceFront{(n - 1) * 3 + k}`, buildYardFence, FENCE, side * (k * 12), -PLOT_DEPTH / 2)
			piece(`FootingFront{(n - 1) * 3 + k}`, buildYardFooting, FENCE, side * (k * 12), -PLOT_DEPTH / 2)
		end
		piece(`FenceFrontHalf{n}`, buildYardFenceHalf, FENCE, side * 45, -PLOT_DEPTH / 2)
		piece(`FootingFrontHalf{n}`, buildYardFooting, FENCE, side * 45, -PLOT_DEPTH / 2, 0, 0, 0.5)
	end
	piece("Gate", buildYardGate, FENCE, 0, -PLOT_DEPTH / 2)
	piece("PlotMarker", buildPlotMarker, FENCE, 9, -PLOT_DEPTH / 2 - 2.25)
end

-- The yards stand in two rows either side of the Line, each island turned
-- so its gate (local -y) faces it. A short road runs from the gate to the
-- island's edge, and a level steel bridge carries it across the gap to the
-- top of an approach ramp on the hub. The bridge's deck is 9 studs wide, 8.7
-- between the railings, and the ramp 10.2 between its walls: two players
-- pass on either.
local BRIDGE_FROM, BRIDGE_TO = -(YARD_ISLAND_FRONT - BRIDGE_SEAT), -(YARD_ROW - HUB_RIM + BRIDGE_SEAT)
for i = 1, 8 do
	local degrees = if i <= 4 then 90 else 270
	local x, y = YARD_COLUMNS[(i - 1) % 4 + 1], if i <= 4 then YARD_ROW else -YARD_ROW
	placeModel(`Island{i}`, buildYardIsland, x, y, YARD_TIER - YARD_TURF, degrees - 90)
	local c, s = math.cos(math.rad(degrees - 90)), math.sin(math.rad(degrees - 90))
	-- The ground stands a hair over the island's turf, which runs on under
	-- its edges.
	slab(`Plot{i}`, function()
		chunkedPart("Ground", nil, YARD_DIRT, function(mesh)
			pavedBlock(mesh, -PLOT_WIDTH / 2, -PLOT_DEPTH / 2, PLOT_WIDTH / 2, PLOT_DEPTH / 2, YARD_TIER - 0.3, YARD_TIER + 0.03)
		end, nil, function(px, py)
			return yardGround((px - x) * c + (py - y) * s, (py - y) * c - (px - x) * s, 200 + i * 7)
		end, true)
	end, x, y, degrees - 90)
	yardShell(i, x, y, degrees - 90)
	slab(`Spoke{i}`, function()
		part("Road", nil, ROAD, function(mesh)
			local from, to = -(YARD_ISLAND_FRONT - BRIDGE_SEAT), -PLOT_DEPTH / 2
			box(mesh, 0, (from + to) / 2, YARD_TIER, 6 * BRIDGE_WIDTH, to - from, 0.1)
		end, nil, function(px, py)
			local u = (px - x) * c + (py - y) * s
			local v = (py - y) * c - (px - x) * s
			return asphalt(u, v, 3, 70 + i)
		end)
	end, x, y, degrees - 90)
	bridge(`Bridge{i}`, x, y, degrees, BRIDGE_FROM, BRIDGE_TO, YARD_TIER, true, YARD_TIER)
	-- The approach: a concrete ramp from the walkway up to a landing the
	-- bridge's end rests on, with a low wall down each side. Built in the
	-- bridge's frame from the Line's middle, +y toward the yard.
	local landing = HUB_RIM - BRIDGE_SEAT + 0.6
	local crest = landing - 3.4
	local foot = crest - APPROACH_RUN
	slab(`Approach{i}`, function()
		part("Ramp", nil, CONCRETE, function(mesh)
			local profile = { { foot, DECK - 0.6 }, { foot, DECK }, { crest, YARD_TIER }, { landing, YARD_TIER }, { landing, DECK - 0.6 } }
			local left, right = {}, {}
			for k, point in profile do
				left[k] = mesh:vertex(-APPROACH_HALF, point[1], point[2])
				right[k] = mesh:vertex(APPROACH_HALF, point[1], point[2])
			end
			for k = 1, 4 do
				mesh:face({ left[k], right[k], right[k + 1], left[k + 1] })
			end
			mesh:face({ left[1], left[2], left[3], left[4], left[5] })
			mesh:face({ right[5], right[4], right[3], right[2], right[1] })
		end, nil, function(px, py)
			return paving(px, py, 130 + i)
		end, nil, nil, true)
		part("Walls", nil, CONCRETE, function(mesh)
			for _, side in { -1, 1 } do
				local wall = side * (APPROACH_HALF - 0.3)
				upstand(mesh, wall, foot, wall, crest, 0.6, { DECK - 0.6, DECK + 1.3 }, { DECK - 0.6, YARD_TIER + 1.3 })
				upstand(mesh, wall, crest, wall, landing - 1, 0.6, { DECK - 0.6, YARD_TIER + 1.3 }, { DECK - 0.6, YARD_TIER + 1.3 })
			end
		end, nil, 0.5)
		part("WallCaps", nil, MARK, function(mesh)
			for _, side in { -1, 1 } do
				local wall = side * (APPROACH_HALF - 0.3)
				upstand(mesh, wall, foot, wall, crest, 0.8, { DECK + 1.3, DECK + 1.45 }, { YARD_TIER + 1.3, YARD_TIER + 1.45 })
				upstand(mesh, wall, crest, wall, landing - 1, 0.8, { YARD_TIER + 1.3, YARD_TIER + 1.45 }, { YARD_TIER + 1.3, YARD_TIER + 1.45 })
			end
		end, nil, 0.3)
	end, x, y - (if i <= 4 then YARD_ROW else -YARD_ROW), degrees - 90)
end
