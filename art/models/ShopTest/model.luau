local SHARD_COSTS = { ["ShopConceptContainer 1 x"] = 51, ["ShopConceptContainer 1 x #split"] = 1,  } local PAINT_COSTS: { [string]: number } = {  } local PAINT_DEAL = ""
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

-- While a split model builds, an image is a promise of one: its size is known
-- at once, for the deal, and its pixels are made when something first paints
-- or reads them. A shard keeps only its share of a split model's parts, so it
-- never makes the pixels of the rest.
local function promisedImage(width: number, height: number, ...)
	local made = nil
	local colour = table.pack(...)
	local function real()
		if not made then
			made = RealImage.new(width, height, table.unpack(colour, 1, colour.n))
		end
		return made
	end
	return setmetatable({
		_real = real,
		width = function()
			return width
		end,
		height = function()
			return height
		end,
		size = function()
			return width, height
		end,
	}, {
		__index = function(_, key)
			return function(_, ...)
				local image = real()
				return image[key](image, ...)
			end
		end,
	})
end

local function unwrapImage(image)
	return if type(image) == "table" and image._real then image._real() else image
end

Image = setmetatable({
	new = function(width, height, ...)
		if splitImages then
			local image = promisedImage(width, height, ...)
			table.insert(splitImages, image)
			return image
		end
		return RealImage.new(width, height, ...)
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
				return real:paintShading(unwrapImage(image), options)
			end,
			paint = function(_, image, ...)
				return real:paint(unwrapImage(image), ...)
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
--
-- Texels are a poor guide to paint time (a ground chunk paints seven times
-- faster than a dirt chunk of the same size), so once paint times have been
-- measured (PAINT_COSTS, from the assembler's <Layout>PaintCosts.txt, which
-- scripts/paint-costs.sh writes from a build's logs) parts are dealt by those
-- instead. A chunk's paint also shades the chunks next to it unless this
-- shard has shaded them already (bake.rs), so neighbours belong on one shard:
-- the measured parts named for a place on the chunk grid (<Kind>_<x>_<y>_<z>,
-- as chunkedPart names them) are put in order by 2 x 2 block of cells, then
-- cell, and that line is cut into one run of equal paint time per share
-- (plannedShares). Any other part, as its paint is asked for, goes to the
-- share with the least paint time so far; one with no measured time counts as
-- its texels at the measured average rate. Every shard asks for the same
-- paints in the same order, so they still deal alike.
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

local paintRate: number? = PAINT_COSTS["#rate"]

-- What a part's paint weighs in the deal: its measured seconds, or its texels
-- when no paint times have been measured.
local function paintWeight(name: string?, image: any): number
	if not paintRate then
		return texelsOf(image)
	end
	return (name and PAINT_COSTS[name]) or texelsOf(image) * paintRate
end

-- The measured chunk parts' shares for a split into `count`, by name, and the
-- paint time each share is given by them.
local sharePlans: { [number]: { owners: { [string]: number }, loads: { number } } } = {}
local function plannedShares(count: number)
	if sharePlans[count] then
		return sharePlans[count]
	end
	local chunks, total = {}, 0
	for name, seconds in PAINT_COSTS do
		local x, y, z = string.match(name, "^%a+_(%-?%d+)_(%-?%d+)_(%-?%d+)")
		if x then
			x, y, z = tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number
			table.insert(chunks, { name = name, seconds = seconds, key = { x // 2, y // 2, x, y, z } })
			total += seconds
		end
	end
	table.sort(chunks, function(a, b)
		for i = 1, 5 do
			if a.key[i] ~= b.key[i] then
				return a.key[i] < b.key[i]
			end
		end
		return a.name < b.name
	end)
	local plan = { owners = {}, loads = table.create(count, 0) }
	local before = 0
	for _, chunk in chunks do
		-- By the middle of its own time, so a long paint lands on the run it mostly lies in.
		local share = math.min(count, (before + chunk.seconds / 2) * count // total + 1)
		plan.owners[chunk.name] = share
		plan.loads[share] += chunk.seconds
		before += chunk.seconds
	end
	sharePlans[count] = plan
	return plan
end

-- Gives an image to the share with the least weight (texels, or seconds) so far.
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
			if paintRate then
				-- By measured paint time: the chunk parts' runs are planned,
				-- and the rest are dealt one by one, as each is asked for.
				partShare.owners = {}
				partShare.texels = table.clone(plannedShares(partShare.count).loads)
			else
				dealImages(partShare)
			end
		end
		local owners = partShare.owners :: { [any]: number }
		local owner = owners[image]
		if not owner then
			local planned = if paintRate then plannedShares(partShare.count).owners[name] else nil
			if planned then
				owners[image] = planned
				owner = planned
			else
				owner = dealImage(partShare, image, paintWeight(name, image))
			end
		end
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
		table.insert(builtParts, { name = name, mesh = unwrapMesh(mesh), image = unwrapImage(image), preview = preview, emissive = options and options.emissive })
		return
	end
	addPart(name, unwrapMesh(mesh), unwrapImage(image), preview, options and options.emissive)
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
-- Set while a slab builds. A slab's cache key leaves out the models the
-- layout uses (scripts/assemble-model.sh), so a slab must not place one.
local slabBuilding: string? = nil

local function place(label: string, build: () -> (), x: number, y: number, z: number?, turn: number?, stretch: number?, axis: string?, scale: number?)
	if slabBuilding then
		error(`slab {slabBuilding} places {label}: place models outside slabs, as a slab's cache key doesn't follow model changes`)
	end
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
		-- The deal by measured paint times follows from those too.
		if PAINT_DEAL ~= "" then
			key = `{key} deal {PAINT_DEAL}`
		end
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
			slabBuilding = label
			build()
			if finish then
				finish()
			end
			slabBuilding = nil
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
-- The density the layout asked for, before TEXEL_SCALE: chunk sizes follow
-- this one, so a max-detail preview keeps the chunks it would ship with.
local layoutDensity: number? = nil

-- Previews build at a fraction of the density the layout asks for (TEXEL_SCALE).
local function useTexelDensity(pixelsPerStud: number)
	layoutDensity = pixelsPerStud
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
	local function unit(a, b)
		local x, y, z = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local length = math.sqrt(x * x + y * y + z * z)
		if length < 1e-6 then
			return nil
		end
		return { x / length, y / length, z / length }
	end
	local rings = {}
	local carried
	for i, p in points do
		local before, after = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local into, out = i > 1 and unit(before, p) or nil, i < #points and unit(p, after) or nil
		-- Each ring lies across the bisector of its bend.
		local dx, dy, dz = after[1] - before[1], after[2] - before[2], after[3] - before[3]
		if into and out then
			local x, y, z = into[1] + out[1], into[2] + out[2], into[3] + out[3]
			if x * x + y * y + z * z > 1e-6 then
				dx, dy, dz = x, y, z
			end
		end
		local tx, ty, tz, ux, uy, uz, vx, vy, vz = crossFrame(dx, dy, dz)
		-- Carry the last ring's frame round the bend, so the tube can't twist.
		if carried then
			local along = carried[1] * tx + carried[2] * ty + carried[3] * tz
			local x, y, z = carried[1] - tx * along, carried[2] - ty * along, carried[3] - tz * along
			local length = math.sqrt(x * x + y * y + z * z)
			if length > 1e-6 then
				ux, uy, uz = x / length, y / length, z / length
				vx, vy, vz = ty * uz - tz * uy, tz * ux - tx * uz, tx * uy - ty * ux
			end
		end
		carried = { ux, uy, uz }
		-- A ring across a bend is widened toward the bend's outside, or the tube
		-- would pinch there.
		local stretch, bx, by, bz = 1, 0, 0, 0
		if into and out then
			local x, y, z = out[1] - into[1], out[2] - into[2], out[3] - into[3]
			local length = math.sqrt(x * x + y * y + z * z)
			if length > 1e-6 then
				bx, by, bz = x / length, y / length, z / length
				stretch = 1 / math.max(tx * out[1] + ty * out[2] + tz * out[3], 0.5)
			end
		end
		local ring = {}
		for k = 0, sides - 1 do
			local t = k / sides * TAU
			local c, n = math.cos(t) * radius, math.sin(t) * radius
			local x, y, z = ux * c + vx * n, uy * c + vy * n, uz * c + vz * n
			local extra = (x * bx + y * by + z * bz) * (stretch - 1)
			ring[k + 1] = mesh:vertex(p[1] + x + bx * extra, p[2] + y + by * extra, p[3] + z + bz * extra)
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

-- `points` with each inner corner replaced by a curve starting up to `reach`
-- studs before it, for wires and hoses that shouldn't have sharp elbows.
local function roundedPath(points, reach, steps)
	steps = steps or 4
	local path = { points[1] }
	for i = 2, #points - 1 do
		local a, p, b = points[i - 1], points[i], points[i + 1]
		local function towards(q)
			local x, y, z = q[1] - p[1], q[2] - p[2], q[3] - p[3]
			local length = math.sqrt(x * x + y * y + z * z)
			local r = math.min(reach, length / 2) / length
			return { p[1] + x * r, p[2] + y * r, p[3] + z * r }
		end
		local first, last = towards(a), towards(b)
		for s = 0, steps do
			local t = s / steps
			local m0, m1, m2 = (1 - t) ^ 2, 2 * t * (1 - t), t * t
			table.insert(path, {
				first[1] * m0 + p[1] * m1 + last[1] * m2,
				first[2] * m0 + p[2] * m1 + last[2] * m2,
				first[3] * m0 + p[3] * m1 + last[3] * m2,
			})
		end
	end
	table.insert(path, points[#points])
	return path
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

local HAND_EDGE_MOTION = { rock = "feather", wood = "flick", metal = "worn" }

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
-- `blend` (0-1) to tint them from cream toward a lighter part colour, and
-- `taper` (studs) to run them full width at corners, thinning along each edge.
-- `softLit` (0-1) adds a wide, very soft highlight under the strokes, fading
-- out over `softEdge` studs from each edge; `softUneven` (0-1) makes its width
-- wander along the edge and `softTaper` (studs) thins it away from corners.
-- `softToZero` lets that thinning reach nothing, and `softPower` steepens the fade.
-- `strokes` lists brush strokes painted over the coat ({start, along, normal,
-- length, width, tail, color, brush}, color in sRGB), such as cracks or dabs;
-- `brush` is "taper" (crisp lines, the default), "round" or "sponge".
-- `stamps` lays the coat with scanned stroke shapes instead of the flat brush.
-- `hand` ("rock", "wood" or "metal") paints the coat the way a hand would, and
-- `handFocus` ({x, y, z, radius}) is where it gathers its finest strokes.
-- `handTune` sets any of its numbers by name (settings! in tools/modelkit/src/hand.rs).
-- `litMotion` draws the hard edge highlight with a moving hand, `litTune` sets its
-- numbers by name (tools/modelkit/src/marks.rs). A hand-painted part gets its
-- material's motion unless it names another, or `false` for the default strokes.
-- `brushes` draws any layer with a motion: edge, shade, soft, coat, grime, rust,
-- drip or scratch, each {motion = "press", tune = {name = value}}. A `strokes`
-- entry takes `motion` and `tune` the same way.
-- With `hand` as well, `crisp` keeps the shapes exact and takes only the brushwork's tone.
-- `crisp` lays the coat on texel by texel in the paint fn's exact colours
-- instead of brush strokes, for machine finishes (hazard tape, ribbed
-- rubber) that strokes would smear; shading still goes over it.
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
	local CHUNK = if layoutDensity then math.min(128, 1024 / layoutDensity) else 128
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
			-- Split by the layout's density; the scale only sizes the texture.
			local unwrap = mesh:unwrap()
			local needed = math.ceil((layoutDensity or texelDensity) / unwrap / 4) * 4
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
			texture = math.clamp(math.ceil(texelDensity / unwrap / 4) * 4, 16, 1024)
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
		-- Chunks of one part share a group, so their edges count as its own,
		-- and carry the part's name, so a finish never has to parse theirs.
		parts[#parts].group = name
		parts[#parts].chunkOf = name
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
		-- A grouped part (the chunks of one chunkedPart) is painted with every
		-- member of its group, itself included and in this order, so the bake
		-- lays one set of strokes over the whole part and each chunk takes the
		-- ones that fall on it; each member's texture size goes along for its
		-- shade layer.
		local occluders, group, groupSizes, groupIndex = {}, {}, {}, nil
		for _, other in parts do
			if entry.group and other.group == entry.group then
				table.insert(group, other.mesh)
				table.insert(groupSizes, { other.image:width(), other.image:height() })
				if other == entry then
					groupIndex = #group
				end
			elseif other ~= entry then
				table.insert(occluders, other.mesh)
			end
		end
		entry.mesh:paintShading(entry.image, {
			highlight = EDGE_HIGHLIGHT * (entry.lit or 1),
			shadow = CONTACT_SHADOW * (entry.shade or 1),
			gradient = entry.gradient or GRADIENT,
			blend = entry.blend or EDGE_BLEND,
			occluders = occluders,
			group = group,
			groupSizes = groupSizes,
			groupIndex = groupIndex,
			name = entry.name,
			paint = entry.paint,
			-- A custom paint fn is cached under the item's key, since its code is not hashed.
			custom = entry.custom,
			salt = if entry.custom then CACHE_KEY else nil,
			rust = entry.rust * WEAR,
			stamps = entry.stamps,
			hand = entry.hand,
			handFocus = entry.handFocus,
			handTune = entry.handTune,
			rubber = entry.rubber,
			rustEdges = entry.rustEdges,
			reach = entry.edge,
			bevelReach = entry.bevelReach,
			bevelFold = entry.bevelFold,
			bevelTilt = entry.bevelTilt,
			roughnessBase = entry.roughnessBase,
			roughnessEdge = entry.roughnessEdge,
			roughnessCrease = entry.roughnessCrease,
			roughnessWear = entry.roughnessWear,
			metalnessOn = entry.metalnessBase ~= nil,
			metalnessBase = entry.metalnessBase,
			metalnessEdge = entry.metalnessEdge,
			metalnessCrease = entry.metalnessCrease,
			metalnessWear = entry.metalnessWear,
			highlightWidth = entry.wide,
			highlightUneven = entry.litUneven,
			highlightUnevenStep = entry.litUnevenStep,
			highlightMotion = if entry.litMotion == nil then (entry.hand and HAND_EDGE_MOTION[entry.hand]) else (entry.litMotion or nil),
			highlightMotionTune = entry.litTune,
			highlightToZero = entry.litToZero,
			highlightEnd = entry.litEnd,
			paintedHighlights = entry.painted,
			cornerTaper = entry.taper,
			softHighlight = entry.softLit,
			softReach = entry.softEdge,
			softUneven = entry.softUneven,
			softTaper = entry.softTaper,
			softToZero = entry.softToZero,
			softPower = entry.softPower,
			softEnd = entry.softEnd,
			strokes = entry.strokes,
			brushes = entry.brushes,
			heightRange = entry.heightRange,
			crisp = entry.crisp,
		})
		model.part(entry.name, entry.mesh, entry.image, { bone = entry.bone, preview = true })
	end
end
function buildShopConceptContainer()
local CACHE_KEY = "ShopConceptContainer-6558ebfd0e67d87c"
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
-- Shop concept: the shipping container with a pipe wrench sign on its roof frame,
-- scrap stock piled round the doors and a drum by the steps. The shell is shared
-- with the other shops; this file sets its colours and adds the signage. Local -y
-- is the front.
local PAINT = { 0.7, 0.18, 0.12 }
local PLANK = { 0.5, 0.36, 0.22 }
local CRATE = { 0.55, 0.42, 0.28 }
local CONCRETE = { 0.55, 0.54, 0.5 }
local GLOW = { 1, 0.85, 0.5 }

-- The shipping container shell shared by the shop concepts: a rusted box with
-- its long side cut open, the cut panel propped up as an awning on pipe legs and
-- chains, a plank counter in the opening, shelves and a workbench inside, and a
-- roof frame with bulbs. Each item sets its colours before including this, and
-- adds its own signage and decoration. Local -y is the front.
-- One texel density for every part, so wear patterns line up across seams.
useTexelDensity(128)
local DIM = { 0.16, 0.14, 0.13 }

-- Container shell: x -4..4, y -1.45..1.45, z 0..3.1.
local HX, HY, TOP = 4, 1.45, 3.1
-- Serving opening cut in the front wall.
local OX, OZ0, OZ1 = 2.8, 1.0, 2.9

-- The corner posts and rails stand this far proud of the walls, so the
-- corrugation stops short of them instead of poking through.
local TRIM = 0.08
-- How far an out rib stands from the wall, kept just inside the trim.
local RIB = 0.045

-- Ribs along a wall at y, alternating in and out, between x0 and x1.
local function ribsY(mesh, y, sign, x0, x1, z0, z1)
	local n = math.floor((x1 - x0) / 0.3)
	for k = 0, n - 1 do
		box(mesh, x0 + (k + 0.5) * (x1 - x0) / n, y + sign * (k % 2) * RIB, z0, (x1 - x0) / n, 0.06, z1 - z0)
	end
end

local function ribsX(mesh, x, sign, y0, y1, z0, z1)
	local n = math.floor((y1 - y0) / 0.3)
	for k = 0, n - 1 do
		box(mesh, x + sign * (k % 2) * RIB, y0 + (k + 0.5) * (y1 - y0) / n, z0, 0.06, (y1 - y0) / n, z1 - z0)
	end
end

chunkedPart("Container", nil, PAINT, function(mesh)
	ribsY(mesh, HY, 1, -HX + TRIM, HX - TRIM, 0.15, TOP - 0.23)
	ribsX(mesh, -HX, -1, -HY + TRIM, HY - TRIM, 0.15, TOP - 0.23)
	ribsY(mesh, -HY, -1, -HX + TRIM, HX - TRIM, 0.15, OZ0)
	ribsY(mesh, -HY, -1, -HX + TRIM, -OX, OZ0, TOP - 0.23)
	ribsY(mesh, -HY, -1, OX, HX - TRIM, OZ0, TOP - 0.23)
	-- Roof panel with shallow dents.
	box(mesh, 0, 0, TOP - 0.1, 2 * HX, 2 * HY, 0.1)
	for k = 0, 6 do
		box(mesh, -3.4 + k * 1.13, 0, TOP, 0.8, 2.6, 0.04)
	end
end, nil, 0.75)

-- How far the ajar cargo door has swung open on its outer hinge.
local DOOR_SWING = math.rad(35)
-- The ajar leaf's top hinge has snapped, so it sags about its bottom hinge
-- and leans out from the frame.
local DOOR_SAG = math.rad(4)
local DOOR_LEAN = 0.06
local SAG_PIVOT = 0.5

-- Moves a point built on the shut ajar leaf to where the broken leaf hangs.
local function leafAt(x, y, z)
	local u, dz = HY - y, z - SAG_PIVOT
	local c, s = math.cos(DOOR_SAG), math.sin(DOOR_SAG)
	local sagU, sagZ = u * c + dz * s, SAG_PIVOT + dz * c - u * s
	local dx = x - HX + sagZ * DOOR_LEAN
	local cs, ss = math.cos(DOOR_SWING), math.sin(DOOR_SWING)
	return HX + dx * cs + sagU * ss, HY + dx * ss - sagU * cs, sagZ
end

-- Builds into `mesh` as if on the shut ajar leaf, landing on the broken one.
local function onLeaf(mesh)
	return {
		vertex = function(_, x, y, z)
			return mesh:vertex(leafAt(x, y, z))
		end,
		face = function(_, verts, uvs)
			return mesh:face(verts, uvs)
		end,
	}
end

part("Doors", nil, PAINT, function(mesh)
	-- Cargo doors on the +x end, one hanging slightly ajar.
	ribsX(mesh, HX, 1, -HY, -0.02, 0.15, TOP - 0.15)
	-- The ajar leaf is the same ribbed wall, hanging off its last hinge.
	ribsX(onLeaf(mesh), HX, 1, 0.02, HY, 0.15, TOP - 0.15)
end, nil, 0.75)

chunkedPart("Frame", nil, DARK_STEEL, function(mesh)
	-- Rails along every edge and cast corner blocks.
	for _, y in { -HY, HY } do
		for _, z in { 0, TOP - 0.15 } do
			box(mesh, 0, y, z, 2 * HX + 0.1, 0.16, 0.16)
		end
	end
	for _, x in { -HX, HX } do
		for _, z in { 0, TOP - 0.15 } do
			box(mesh, x, 0, z, 0.16, 2 * HY, 0.16)
		end
		for _, y in { -HY, HY } do
			box(mesh, x, y, 0, 0.16, 0.16, TOP)
			for _, z in { 0, TOP - 0.25 } do
				box(mesh, x, y, z, 0.3, 0.3, 0.25)
			end
		end
	end
	-- Rough cut frame round the opening, welded angle.
	box(mesh, 0, -HY - 0.05, OZ0 - 0.08, 2 * OX + 0.2, 0.12, 0.1)
	box(mesh, 0, -HY - 0.05, OZ1, 2 * OX + 0.2, 0.12, 0.1)
	for _, x in { -OX, OX } do
		box(mesh, x, -HY - 0.05, OZ0, 0.12, 0.12, OZ1 - OZ0)
	end
	-- Door lock bars and handles, the ajar leaf's carried along with it.
	-- Each bar rides in bolted keepers on the ribs, its handle clamped to it.
	for _, target in { mesh, onLeaf(mesh) } do
		local y = if target == mesh then -0.6 else HY - 0.9
		cylinder(target, HX + 0.12, y, TOP / 2, 0.04, TOP - 0.2, "z", 8)
		for _, z in { 0.35, 1.55, 2.7 } do
			box(target, HX + 0.09, y, z, 0.1, 0.16, 0.08)
			for _, dy in { -0.06, 0.06 } do
				bolt(target, HX + 0.14, y + dy, z + 0.04, "x", 0.025)
			end
		end
		cylinder(target, HX + 0.12, y, 0.08, 0.055, 0.08, "z", 8)
		cylinder(target, HX + 0.12, y, TOP - 0.18, 0.055, 0.08, "z", 8)
		box(target, HX + 0.15, y - 0.03, 1.25, 0.08, 0.1, 0.1)
		box(target, HX + 0.18, y - 0.2, 1.27, 0.05, 0.36, 0.05)
		cylinder(target, HX + 0.18, y - 0.36, 1.295, 0.035, 0.12, "x", 6)
	end
	-- Hinges: the shut leaf's are whole, each a strap bolted to the leaf.
	for _, z in { 0.5, 1.5, 2.5 } do
		cylinder(mesh, HX + 0.12, -HY + 0.12, z, 0.05, 0.25, "z", 8)
		cylinder(mesh, HX + 0.12, -HY + 0.12, z, 0.02, 0.33, "z", 6)
		box(mesh, HX + 0.07, -HY + 0.32, z - 0.08, 0.06, 0.38, 0.16)
		for _, dy in { 0.28, 0.44 } do
			bolt(mesh, HX + 0.1, -HY + dy, z, "x", 0.03)
		end
	end
	-- The ajar leaf hangs off its bottom hinge; the middle one has torn
	-- loose and the top one has snapped, leaving a stub on the frame.
	cylinder(mesh, HX + 0.12, HY - 0.05, 0.5, 0.05, 0.25, "z", 6)
	cylinder(onLeaf(mesh), HX + 0.12, HY - 0.05, 1.5, 0.05, 0.25, "z", 6)
	box(mesh, HX + 0.12, HY - 0.05, 2.45, 0.1, 0.1, 0.08)
	box(onLeaf(mesh), HX + 0.12, HY - 0.05, 2.4, 0.08, 0.08, 0.1)
	-- A crude strap plate welded from the corner post across to the leaf.
	local sx, sy, sz = leafAt(HX + 0.05, HY - 0.35, 2.3)
	strut(mesh, HX + 0.1, HY, 2.45, sx, sy, sz, 0.12)
	-- Wire lashing from the free top corner back to the corner casting.
	local fx, fy, fz = leafAt(HX + 0.04, 0.05, TOP - 0.25)
	rope(mesh, { { fx, fy, fz }, { (fx + HX) / 2 + 0.05, (fy + HY) / 2, (fz + TOP) / 2 - 0.15 }, { HX + 0.15, HY + 0.15, TOP - 0.12 } }, 0.025)
end, nil, 0.6)

part("DoorProp", nil, PLANK, function(mesh)
	-- A timber leaning in against the free edge to hold the leaf up, with a
	-- block wedged under its sagging corner.
	local px, py, pz = leafAt(HX + 0.08, 0.15, 2.1)
	local nx, ny = math.cos(DOOR_SWING), math.sin(DOOR_SWING)
	strut(mesh, px + nx * 1.3, py + ny * 1.3 - 0.2, 0, px, py, pz, 0.14)
	local bx, by = leafAt(HX + 0.1, 0.3, 0)
	box(mesh, bx, by, 0, 0.35, 0.3, 0.18)
end, nil, 0.7)

-- Oval twistlock holes in the outer faces of each corner casting.
part("CastingHoles", nil, DIM, function(mesh)
	for _, x in { -HX, HX } do
		for _, y in { -HY, HY } do
			for _, z in { 0, TOP - 0.25 } do
				box(mesh, x + math.sign(x) * 0.15, y, z + 0.07, 0.02, 0.07, 0.11)
				box(mesh, x, y + math.sign(y) * 0.15, z + 0.07, 0.11, 0.02, 0.11)
			end
			box(mesh, x, y, TOP + 0.001, 0.07, 0.13, 0.01)
		end
	end
end, nil, 0.2)

chunkedPart("Interior", nil, DIM, function(mesh)
	box(mesh, 0, 0, 0.15, 2 * HX - 0.2, 2 * HY - 0.2, 0.05)
	box(mesh, 0, HY - 0.12, OZ0, 2 * OX, 0.04, OZ1 - OZ0)
end, nil, 0.2)

chunkedPart("Flap", nil, PAINT, function(mesh)
	-- The cut panel hinged at the opening's top edge, propped out and down.
	local ribs = 18
	for k = 0, ribs - 1 do
		local x = -OX + (k + 0.5) * 2 * OX / ribs
		local lift = (k % 2) * 0.06
		strut(mesh, x, -HY - 0.08, OZ1 + 0.1 + lift, x, -HY - 2.2, OZ1 - 0.45 + lift, 2 * OX / ribs)
	end
end, nil, 0.7)

chunkedPart("FlapFrame", nil, DARK_STEEL, function(mesh)
	strut(mesh, -OX, -HY - 0.08, OZ1 + 0.02, OX, -HY - 0.08, OZ1 + 0.02, 0.12)
	strut(mesh, -OX, -HY - 2.2, OZ1 - 0.53, OX, -HY - 2.2, OZ1 - 0.53, 0.12)
	for _, x in { -OX, OX } do
		strut(mesh, x, -HY - 0.08, OZ1 + 0.02, x, -HY - 2.2, OZ1 - 0.53, 0.12)
	end
	-- Hinges.
	for _, x in { -2, 0, 2 } do
		cylinder(mesh, x, -HY - 0.1, OZ1 + 0.05, 0.07, 0.4, "x", 8)
		cylinder(mesh, x, -HY - 0.1, OZ1 + 0.05, 0.03, 0.5, "x", 6)
		for _, dx in { -0.12, 0.12 } do
			box(mesh, x + dx, -HY - 0.02, OZ1 + 0.05, 0.12, 0.08, 0.2)
			bolt(mesh, x + dx, -HY - 0.06, OZ1 + 0.15, "y", 0.025)
		end
	end
	-- Pipe legs with base plates and clamps.
	for _, x in { -OX + 0.2, OX - 0.2 } do
		cylinder(mesh, x, -HY - 2.05, (OZ1 - 0.5) / 2, 0.07, OZ1 - 0.5, "z", 8)
		box(mesh, x, -HY - 2.05, 0, 0.4, 0.4, 0.05)
		for _, d in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			bolt(mesh, x + d[1] * 0.14, -HY - 2.05 + d[2] * 0.14, 0.05, "z", 0.04)
		end
		-- Saddle clamp gripping the flap's underside, with a gusset.
		cylinder(mesh, x, -HY - 2.05, OZ1 - 0.6, 0.1, 0.16, "z", 8)
		box(mesh, x, -HY - 2.05, OZ1 - 0.55, 0.26, 0.26, 0.06)
		strut(mesh, x, -HY - 2.05, OZ1 - 1.0, x, -HY - 1.75, OZ1 - 0.5, 0.05)
		ring(mesh, x, -HY - 2.05, 0.3, 0.07, 0.1, 0.06, "z", 8)
	end
	-- Taut chains from pad-eyes on the roof rail to pad-eyes on the flap's
	-- outer corners, each link hooked through the one before.
	local LINKS = 30
	for _, x in { -OX + 0.1, OX - 0.1 } do
		local y0, z0, y1, z1 = -HY - 0.06, TOP + 0.03, -HY - 2.1, OZ1 - 0.2
		for k = 0, LINKS do
			local t = k / LINKS
			local isEye = k == 0 or k == LINKS
			ring(mesh, x, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t, if isEye then 0.025 else 0.03, if isEye then 0.06 else 0.055, if isEye then 0.04 else 0.025, if k % 2 == 0 then "x" else "z", 8)
		end
		box(mesh, x, y0, TOP - 0.03, 0.05, 0.1, 0.05)
		box(mesh, x, y1, z1 - 0.1, 0.05, 0.12, 0.08)
	end
end, nil, 0.6)

chunkedPart("Counter", nil, PLANK, function(mesh)
	for k = 0, 3 do
		box(mesh, 0, -HY - 0.55 + k * 0.24, OZ0 + 0.02, 2 * OX - 0.1, 0.22, 0.08)
	end
	-- Rounded front lip and battens under the planks.
	cylinder(mesh, 0, -HY - 0.66, OZ0 + 0.06, 0.05, 2 * OX - 0.1, "x", 8)
	for _, x in { -OX + 0.2, 0, OX - 0.2 } do
		box(mesh, x, -HY - 0.2, OZ0 - 0.06, 0.12, 0.8, 0.08)
	end
	-- Inner shelves on the back wall.
	for _, z in { 1.6, 2.3 } do
		box(mesh, 0, HY - 0.35, z, 2 * OX - 0.4, 0.5, 0.06)
		box(mesh, 0, HY - 0.6, z - 0.04, 2 * OX - 0.4, 0.04, 0.12)
	end
	-- Workbench at the left end.
	for k = 0, 3 do
		box(mesh, -3.2, -0.2 + k * 0.4, 1.0, 1.2, 0.38, 0.1)
	end
	box(mesh, -3.2, 0.4, 0.4, 1.0, 1.4, 0.04)
	-- Battens under the bench planks, resting on the leg tops.
	for _, x in { -3.65, -2.75 } do
		box(mesh, x, 0.4, 0.92, 0.1, 1.58, 0.09)
	end
end, nil, 0.3)

part("CounterIron", nil, DARK_STEEL, function(mesh)
	box(mesh, 0, -HY - 0.6, OZ0, 2 * OX, 0.05, 0.12)
	for _, x in { -2.3, -0.8, 0.8, 2.3 } do
		strut(mesh, x, -HY - 0.05, OZ0 - 0.5, x, -HY - 0.5, OZ0, 0.06)
	end
	for _, z in { 1.6, 2.3 } do
		for _, x in { -2, 0, 2 } do
			strut(mesh, x, HY - 0.08, z - 0.3, x, HY - 0.5, z, 0.04)
		end
	end
	for _, x in { -3.7, -2.7 } do
		for _, y in { -0.3, 1.1 } do
			box(mesh, x, y, 0.15, 0.08, 0.08, 0.85)
		end
	end
	-- Nail heads where the planks cross their battens.
	for k = 0, 3 do
		for _, x in { -OX + 0.2, 0, OX - 0.2 } do
			bolt(mesh, x, -HY - 0.55 + k * 0.24, OZ0 + 0.1, "z", 0.02)
		end
		for _, x in { -3.65, -2.75 } do
			bolt(mesh, x, -0.2 + k * 0.4, 1.1, "z", 0.02)
		end
	end
	-- Bench vice.
	box(mesh, -2.75, -0.25, 1.09, 0.3, 0.2, 0.22)
	cylinder(mesh, -2.75, -0.45, 1.2, 0.03, 0.3, "y", 6)
end, nil, 0.6)

part("Wares", nil, STEEL, function(mesh)
	-- Spanners laid out on the counter.
	for k = 0, 4 do
		local x = -2.2 + k * 0.42
		strut(mesh, x, -HY - 0.6, OZ0 + 0.13, x + 0.12, -HY - 0.1, OZ0 + 0.13, 0.06)
		ring(mesh, x + 0.14, -HY - 0.02, OZ0 + 0.13, 0.04, 0.09, 0.04, "z", 8)
	end
	-- Pipe lengths and a hacksaw.
	for k = 0, 2 do
		cylinder(mesh, 1.2, -HY - 0.45 + k * 0.14, OZ0 + 0.17, 0.07, 1.6, "x", 8)
	end
	strut(mesh, 0.2, -HY - 0.2, OZ0 + 0.13, 0.9, -HY - 0.2, OZ0 + 0.13, 0.03)
	strut(mesh, 0.2, -HY - 0.2, OZ0 + 0.13, 0.2, -HY - 0.2, OZ0 + 0.35, 0.04)
	strut(mesh, 0.9, -HY - 0.2, OZ0 + 0.13, 0.9, -HY - 0.2, OZ0 + 0.35, 0.04)
	strut(mesh, 0.2, -HY - 0.2, OZ0 + 0.35, 0.9, -HY - 0.2, OZ0 + 0.35, 0.04)
	-- Shelf stock: blades, cans, gears and bars.
	for k = 0, 5 do
		cylinder(mesh, -2.2 + k * 0.85, HY - 0.35, 1.8, 0.13, 0.3, "z", 8)
		ring(mesh, -2.2 + k * 0.85, HY - 0.35, 1.95, 0.1, 0.14, 0.03, "z", 8)
	end
	for k = 0, 3 do
		gear(mesh, -2 + k * 1.3, HY - 0.25, 2.58, 0.25, 0.06, 9, "y")
	end
	for k = 0, 5 do
		strut(mesh, 1 + k * 0.1, HY - 0.35, 2.34, 1 + k * 0.1, HY - 0.35, 2.34 + 0.4, 0.05)
	end
	-- Grinder on the bench.
	cylinder(mesh, -3.4, 0.6, 1.3, 0.12, 0.4, "x", 10)
	cylinder(mesh, -3.4, 0.6, 1.3, 0.2, 0.03, "x", 14)
	-- Motor body bolted to a foot plate, with a half guard over the disc.
	box(mesh, -3.4, 0.6, 1.08, 0.3, 0.2, 0.12)
	cylinder(mesh, -3.4, 0.82, 1.3, 0.1, 0.32, "y", 10)
	box(mesh, -3.4, 0.82, 1.08, 0.14, 0.18, 0.14)
	for _, dx in { -0.11, 0.11 } do
		bolt(mesh, -3.4 + dx, 0.6, 1.2, "z", 0.025)
	end
	ring(mesh, -3.4, 0.6, 1.3, 0.21, 0.24, 0.05, "x", 14)
end, nil, 0.5)

part("Roof", nil, DARK_STEEL, function(mesh)
	-- Vent stack and a cable run to the sign.
	cylinder(mesh, 2.8, 0.7, TOP + 0.35, 0.18, 0.7, "z", 10)
	ring(mesh, 2.8, 0.7, TOP + 0.05, 0.18, 0.26, 0.06, "z", 10)
	ring(mesh, 2.8, 0.7, TOP + 0.55, 0.18, 0.21, 0.04, "z", 10)
	for a = 0, 2 do
		local r = a * 2 * math.pi / 3
		strut(mesh, 2.8 + math.cos(r) * 0.17, 0.7 + math.sin(r) * 0.17, TOP + 0.68, 2.8 + math.cos(r) * 0.22, 0.7 + math.sin(r) * 0.22, TOP + 0.76, 0.03)
	end
	cylinder(mesh, 2.8, 0.7, TOP + 0.8, 0.3, 0.06, "z", 10)
	cylinder(mesh, 2.8, 0.7, TOP + 0.86, 0.15, 0.06, "z", 10)
	tube(mesh, { { 2.6, 0.7, TOP + 0.05 }, { 1.8, 0.4, TOP + 0.08 }, { 1.7, -0.25, TOP + 0.4 }, { 1.6, -0.3, TOP + 1.0 } }, 0.03, 6)
	-- Drum on the roof.
	cylinder(mesh, -3, 0.6, TOP + 0.45, 0.4, 0.9, "z", 14)
	for _, z in { TOP + 0.02, TOP + 0.3, TOP + 0.6, TOP + 0.88 } do
		ring(mesh, -3, 0.6, z, 0.4, 0.43, 0.05, "z", 14)
	end
	cylinder(mesh, -2.82, 0.6, TOP + 0.92, 0.06, 0.04, "z", 8)
end, nil, 0.7)

-- Wire sags from the flap's front rail; bulbs hang straight off it.
local function wireZ(x)
	return OZ1 - 0.58 - math.sin((x + OX) / (2 * OX) * math.pi) * 0.9
end

part("Bulbs", nil, GLOW, function(mesh)
	for k = 0, 8 do
		local x = -OX + 0.3 + k * (2 * OX - 0.6) / 8
		sphere(mesh, x, -HY - 2.2, wireZ(x) - 0.09, 0.07, 0.07, 0.1, 4, 6)
	end
end, nil, 0, nil, 0.5)

part("Wire", nil, RUBBER_BLACK, function(mesh)
	local points = {}
	for k = 0, 16 do
		local x = -OX + k * 2 * OX / 16
		table.insert(points, { x, -HY - 2.2, wireZ(x) })
	end
	tube(mesh, points, 0.02, 4)
	-- Lamp holders clamped on the wire, each holding its bulb.
	for k = 0, 8 do
		local x = -OX + 0.3 + k * (2 * OX - 0.6) / 8
		cylinder(mesh, x, -HY - 2.2, wireZ(x) - 0.03, 0.035, 0.08, "z", 6)
	end
end, nil, 0.1)


part("Blades", nil, BARE_METAL, function(mesh)
	-- Saw blades strung up as ornaments beside the opening, each on a wire
	-- dropped from the top rail and hooked through a tooth gap.
	local HANG_Y = -HY - 0.14
	local RAIL = TOP - 0.23
	local function hung(x, z, radius, teeth)
		gear(mesh, x, HANG_Y, z, radius, 0.03, teeth, "y")
		-- Eye round the blade's top edge, and the wire up to the rail.
		ring(mesh, x, HANG_Y, z + radius, 0.03, 0.06, 0.03, "y", 8)
		cylinder(mesh, x, HANG_Y, (z + radius + 0.06 + RAIL) / 2, 0.015, RAIL - z - radius - 0.06, "z", 6)
	end
	hung(-3.4, 2.1, 0.32, 16)
	hung(3.4, 2.2, 0.38, 18)
	hung(3.35, 1.4, 0.25, 14)
end, nil, 0.3)

-- The sign is laid out at half size with its bottom edge at SIGN_BOTTOM, then
-- doubled about that edge, set down to SIGN_BASE and tilted up towards the
-- jaws, pivoting on the handle end.
local SIGN_BOTTOM = TOP + 0.81
local SIGN_SCALE, SIGN_BASE, SIGN_PIVOT = 2, TOP + 0.3, -4.8
local SIGN_TILT = math.rad(22)
-- Slides the tilted sign right so it sits centred over the container.
local SIGN_SHIFT = 0.5
local function enlarged(mesh)
	return {
		vertex = function(_, x, y, z)
			local dx, dz = x * SIGN_SCALE - SIGN_PIVOT, (z - SIGN_BOTTOM) * SIGN_SCALE
			local c, s = math.cos(SIGN_TILT), math.sin(SIGN_TILT)
			return mesh:vertex(SIGN_SHIFT + SIGN_PIVOT + dx * c - dz * s, -0.35 + (y + 0.35) * SIGN_SCALE, SIGN_BASE + dx * s + dz * c)
		end,
		face = function(_, face)
			return mesh:face(face)
		end,
	}
end

local function rect(x0, z0, x1, z1)
	return { { x0, z0 }, { x0, z1 }, { x1, z1 }, { x1, z0 } }
end

part("SignFrame", nil, DARK_STEEL, function(mesh)
	-- Lattice frame on the roof holding the sign up; posts reach the tilted handle.
	for _, x in { -1.7, 1.7 } do
		local top = SIGN_BASE + (x - SIGN_SHIFT - SIGN_PIVOT) * math.tan(SIGN_TILT) + 0.3
		strut(mesh, x, -0.3, TOP, x, -0.3, top, 0.1)
		strut(mesh, x, 0.5, TOP, x, -0.3, top - 0.3, 0.07)
		box(mesh, x, 0.1, TOP, 0.3, 1.0, 0.05)
	end
	strut(mesh, -1.7, -0.3, TOP + 0.1, 1.7, -0.3, TOP + 0.6, 0.05)
	strut(mesh, 1.7, -0.3, TOP + 0.1, -1.7, -0.3, TOP + 0.6, 0.05)
end, nil, 0.6)

part("Sign", nil, { 0.62, 0.3, 0.18 }, function(mesh)
	mesh = enlarged(mesh)
	-- A giant pipe wrench: notched handle with a hex hole, and the heel jaw.
	local z = TOP + 1.25
	local handle = { { -2.4, -0.28 }, { -2.4, -0.12 }, { -2.36, -0.08 } }
	for k = 0, 5 do
		local x = -0.45 + k * 0.2
		for _, p in { { x, -0.05 }, { x + 0.02, -0.085 }, { x + 0.08, -0.085 }, { x + 0.1, -0.05 } } do
			table.insert(handle, p)
		end
	end
	for _, p in { { 0.78, -0.05 }, { 0.78, -0.35 }, { -2.36, -0.32 } } do
		table.insert(handle, p)
	end
	local heel = { { 1.3, -0.12 }, { 1.3, 0.28 }, { 1.36, 0.34 }, { 1.68, 0.34 } }
	for k = 0, 5 do
		local dz = 0.3 - k * 0.07
		table.insert(heel, { 1.72, dz })
		table.insert(heel, { 1.755, dz - 0.035 })
	end
	table.insert(heel, { 1.72, -0.12 })
	for _, outline in { handle, heel } do
		for _, p in outline do
			p[2] += z
		end
		plate(mesh, outline, -0.35, 0.18, 0.04)
	end
end, nil, 0.7)

part("SignJaw", nil, { 0.56, 0.27, 0.20 }, function(mesh)
	mesh = enlarged(mesh)
	-- The hooked top jaw, toothed on its inner face.
	local z = TOP + 1.25
	local outline = {}
	for k = 0, 5 do
		local dz = -0.14 + k * 0.08
		table.insert(outline, { 1.95, dz })
		table.insert(outline, { 1.915, dz + 0.04 })
	end
	for _, p in {
		{ 1.95, 0.4 }, { 1.88, 0.48 }, { 1.93, 0.56 }, { 2.26, 0.56 }, { 2.34, 0.48 },
		{ 2.34, -0.26 }, { 2.28, -0.32 }, { 0.72, -0.32 }, { 0.72, -0.14 },
	} do
		table.insert(outline, p)
	end
	for _, p in outline do
		p[2] += z
	end
	plate(mesh, outline, -0.35, 0.18, 0.04)
end, nil, 0.7)

part("SignHousing", nil, PAINT, function(mesh)
	mesh = enlarged(mesh)
	-- Red spring housing framing a window onto the coil.
	local z = TOP + 1.25
	for _, r in { { 0.68, -0.44, 0.78, 0.06 }, { 1.26, -0.44, 1.36, 0.06 }, { 0.78, -0.44, 1.26, -0.38 }, { 0.78, -0.04, 1.26, 0.06 } } do
		plate(mesh, rect(r[1], z + r[2], r[3], z + r[4]), -0.35, 0.32, 0.03)
	end
end, nil, 0.6)

part("SignSpring", nil, BARE_METAL, function(mesh)
	mesh = enlarged(mesh)
	-- Coil spring seen through the housing window.
	local z = TOP + 1.25
	local points = {}
	for i = 0, 84 do
		local t = i / 12 * 2 * math.pi
		table.insert(points, { 0.8 + i / 84 * 0.46, -0.35 + math.sin(t) * 0.13, z - 0.23 + math.cos(t) * 0.13 })
	end
	tube(mesh, points, 0.022, 6)
end, nil, 0.3)

chunkedPart("SignBolts", nil, DARK_STEEL, function(mesh)
	mesh = enlarged(mesh)
	-- Housing corner bolts and the edge rails along the handle.
	local z = TOP + 1.25
	for _, x in { 0.73, 1.31 } do
		for _, dz in { -0.41, 0.01 } do
			cylinder(mesh, x, -0.52, z + dz, 0.035, 0.05, "y", 6)
		end
	end
	for _, dz in { -0.1, -0.3 } do
		plate(mesh, rect(-2.0, z + dz - 0.012, 0.62, z + dz + 0.012), -0.455, 0.03, 0.006)
	end
end, nil, 0.8)

part("SignRecesses", nil, DIM, function(mesh)
	mesh = enlarged(mesh)
	-- Hex hole through the handle end, and the dark back of the housing window.
	local z = TOP + 1.25
	cylinder(mesh, -2.2, -0.35, z - 0.2, 0.075, 0.2, "y", 6)
	plate(mesh, rect(0.78, z - 0.38, 1.26, z - 0.04), -0.23, 0.04, 0.01)
end, nil, 0.1)
-- LED sockets on the sign's front face: a row down the handle, and the two jaws.
-- Each socket is a cylinder whose front face is inset and pushed back into a cup.
local SOCKET_FRONT, SOCKET_BACK, SOCKET_FLOOR = -0.5, -0.43, -0.48
local SOCKET_OUTER, SOCKET_INNER, SOCKET_SIDES = 0.078, 0.05, 12
local signSockets = {}
for k = 0, 12 do
	table.insert(signSockets, { -1.95 + k * 0.2, -0.2 })
end
for _, p in { { 1.51, 0 }, { 1.51, 0.2 }, { 2.15, -0.2 }, { 2.15, 0 }, { 2.15, 0.2 }, { 2.15, 0.4 } } do
	table.insert(signSockets, p)
end

local function signSocket(mesh, x, z)
	-- Profile from the cup floor edge out to the back rim, swept round the y axis.
	local profile = {
		{ SOCKET_INNER, SOCKET_FLOOR },
		{ SOCKET_INNER, SOCKET_FRONT },
		{ SOCKET_OUTER, SOCKET_FRONT },
		{ SOCKET_OUTER, SOCKET_BACK },
	}
	local rows = {}
	for i = 0, SOCKET_SIDES - 1 do
		local t = i / SOCKET_SIDES * 2 * math.pi
		local row = {}
		for k, p in profile do
			row[k] = mesh:vertex(x + math.sin(t) * p[1], p[2], z + math.cos(t) * p[1])
		end
		rows[i + 1] = row
	end
	for i = 1, SOCKET_SIDES do
		local a, b = rows[i], rows[i % SOCKET_SIDES + 1]
		for k = 1, #profile - 1 do
			mesh:face({ a[k], b[k], b[k + 1], a[k + 1] })
		end
	end
	-- Cup floor as a triangle fan so it never depends on n-gon handling.
	local centre = mesh:vertex(x, SOCKET_FLOOR, z)
	for i = 1, SOCKET_SIDES do
		mesh:face({ centre, rows[i % SOCKET_SIDES + 1][1], rows[i][1] })
	end
	local back = {}
	for i = 1, SOCKET_SIDES do
		table.insert(back, rows[i][#profile])
	end
	mesh:face(back)
end

part("SignSockets", nil, DARK_STEEL, function(mesh)
	mesh = enlarged(mesh)
	local z = TOP + 1.25
	for _, p in signSockets do
		signSocket(mesh, p[1], z + p[2])
	end
end, nil, 0)

-- Glowing LED disc just in front of each cup floor; sockets and LEDs are rust-free so the jitter never buries a disc.
part("SignLeds", nil, GLOW, function(mesh)
	mesh = enlarged(mesh)
	local z = TOP + 1.25
	for _, p in signSockets do
		local x, y, cz = p[1], SOCKET_FLOOR - 0.004, z + p[2]
		local centre = mesh:vertex(x, y, cz)
		local edge = {}
		for i = 0, SOCKET_SIDES - 1 do
			local t = i / SOCKET_SIDES * 2 * math.pi
			edge[i + 1] = mesh:vertex(x + math.sin(t) * SOCKET_INNER, y, cz + math.cos(t) * SOCKET_INNER)
		end
		for i = 1, SOCKET_SIDES do
			mesh:face({ centre, edge[i % SOCKET_SIDES + 1], edge[i] })
		end
	end
end, nil, 0, nil, 1)

part("Yard", nil, CRATE, function(mesh)
	-- Crates stacked by the doors and a pallet out front.
	box(mesh, 5.2, -2.1, 0, 1.0, 1.0, 0.8)
	box(mesh, 5.1, -2.05, 0.8, 0.8, 0.8, 0.6)
	-- Corner battens and a cross brace on each crate face.
	for _, c in { { 5.2, -2.1, 0, 1.0, 0.8 }, { 5.1, -2.05, 0.8, 0.8, 0.6 } } do
		local x, y, z, s, h = c[1], c[2], c[3], c[4] / 2 + 0.02, c[5]
		for _, d in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			box(mesh, x + d[1] * (s - 0.05), y + d[2] * (s - 0.05), z, 0.12, 0.12, h)
		end
		for _, d in { { 0, -1 }, { -1, 0 } } do
			box(mesh, x + d[1] * s, y + d[2] * s, z + 0.02, if d[1] == 0 then 2 * s else 0.04, if d[1] == 0 then 0.04 else 2 * s, 0.1)
			box(mesh, x + d[1] * s, y + d[2] * s, z + h - 0.12, if d[1] == 0 then 2 * s else 0.04, if d[1] == 0 then 0.04 else 2 * s, 0.1)
			strut(mesh, x + d[1] * s + (if d[1] == 0 then -s + 0.08 else 0), y + d[2] * s + (if d[1] == 0 then 0 else -s + 0.08), z + 0.12, x + d[1] * s + (if d[1] == 0 then s - 0.08 else 0), y + d[2] * s + (if d[1] == 0 then 0 else s - 0.08), z + h - 0.12, 0.06)
		end
	end
	for k = 0, 4 do
		box(mesh, -4.9, -2.3 + k * 0.28, 0.1, 1.4, 0.2, 0.06)
	end
	for _, y in { -2.4, -1.8, -1.2 } do
		box(mesh, -4.9, y, 0, 1.4, 0.12, 0.1)
		for _, x in { -5.5, -4.9, -4.3 } do
			box(mesh, x, y, 0, 0.16, 0.16, 0.1)
		end
	end
end, nil, 0.3)

part("Stock", nil, RUST_ORANGE, function(mesh)
	-- Pipes and rebar bundled on the pallet.
	for k = 0, 5 do
		local y, z = -2.3 + (k % 3) * 0.3, 0.3 + math.floor(k / 3) * 0.24
		cylinder(mesh, -4.9, y, z, 0.12, 1.7, "x", 8)
		ring(mesh, -4.9 + 0.86, y, z, 0.07, 0.125, 0.03, "x", 8)
	end
	-- Strapping round the bundle.
	for _, x in { -5.4, -4.4 } do
		box(mesh, x, -2, 0.16, 0.05, 0.86, 0.5)
	end
end, nil, 0.8)

-- Flat steel band round the drum between radii r0 and r1, half height h,
-- with its outer corners bevelled so the top edge paints light and the
-- bottom edge dark. The section is swept once round the drum axis.
local DRUM_SIDES = 14
-- Every lip has the same section.
local LIP_INNER, LIP_OUTER, LIP_HALF = 0.4, 0.465, 0.035
local function drumLip(mesh, z, r0, r1, h)
	local b = math.min(0.02, (r1 - r0) / 2)
	local section = { { r0, z - h }, { r1 - b, z - h }, { r1, z - h + b }, { r1, z + h - b }, { r1 - b, z + h }, { r0, z + h } }
	local rings = {}
	for k = 0, DRUM_SIDES - 1 do
		local t = k / DRUM_SIDES * math.pi * 2
		rings[k] = {}
		for i, s in section do
			rings[k][i] = mesh:vertex(5.4 + math.cos(t) * s[1], 2.0 + math.sin(t) * s[1], s[2])
		end
	end
	for k = 0, DRUM_SIDES - 1 do
		local a, c = rings[k], rings[(k + 1) % DRUM_SIDES]
		for i = 1, #section do
			local j = i % #section + 1
			mesh:face({ a[i], c[i], c[j], a[j] })
		end
	end
end

local DRUM_BLUE = { 0.2, 0.3, 0.42 }

-- Painted form shading lit from above, so each lip has a bright top
-- running round into a shaded underside. The drum rusts like other metal.
local drumPaint = rusting(0.6, function(_x, _y, _z, _nx, _ny, nz)
	local k = if nz >= 0 then 1 + nz * 0.3 else 1 + nz * 0.9
	return DRUM_BLUE[1] * k, DRUM_BLUE[2] * k, DRUM_BLUE[3] * k
end)

part("Drum", nil, DRUM_BLUE, function(mesh)
	cylinder(mesh, 5.4, 2.0, 0.65, 0.42, 1.3, "z", DRUM_SIDES)
	for _, z in { 0.25, 1.0 } do
		drumLip(mesh, z, LIP_INNER, LIP_OUTER, LIP_HALF)
	end
	-- Chime lips round the lid and the base, the base one sat on the ground.
	drumLip(mesh, 1.3, LIP_INNER, LIP_OUTER, LIP_HALF)
	drumLip(mesh, LIP_HALF, LIP_INNER, LIP_OUTER, LIP_HALF)
	cylinder(mesh, 5.25, 2.0, 1.32, 0.06, 0.05, "z", 8)
	cylinder(mesh, 5.6, 2.0, 1.31, 0.04, 0.04, "z", 6)
end, nil, drumPaint, 1024)

part("Steps", nil, CONCRETE, function(mesh)
	-- Cinder block step under the counter.
	for k = 0, 2 do
		box(mesh, -1.2 + k * 1.2, -HY - 0.9, 0, 1.0, 0.5, 0.35)
	end
	box(mesh, -0.6, -HY - 0.9, 0.35, 1.0, 0.5, 0.35)
	-- Raised webs around the blocks' hollow cores.
	for _, b in { { -1.2, 0.35 }, { 0, 0.35 }, { 1.2, 0.35 }, { -0.6, 0.7 } } do
		for _, dx in { -0.22, 0.22 } do
			ring(mesh, b[1] + dx, -HY - 0.9, b[2], 0.1, 0.17, 0.02, "z", 4)
		end
	end
end, nil, 0.4)

part("Stencil", nil, { 0.9, 0.86, 0.78 }, function(mesh)
	-- Painted ID patch on the end wall.
	box(mesh, -HX - 0.1, -0.5, 2.0, 0.03, 1.2, 0.35)
	box(mesh, -HX - 0.1, 0.5, 1.6, 0.03, 0.5, 0.6)
end, nil, 0.6)

finishParts()
end
buildKeys[buildShopConceptContainer] = "ShopConceptContainer-911175d17539cb26"
-- uses: ShopConceptContainer
-- Shop Test: the shop container on its own, for timing a split build of one
-- heavy prop (build-map-shards with layout ShopTest).
place("Shop", buildShopConceptContainer, 0, 0)
