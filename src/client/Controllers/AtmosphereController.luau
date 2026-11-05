--!strict
--[[
	AtmosphereController

	The world around the islands, built on this client only, from art baked
	ahead of time (nothing is generated here but where things go):

	- The sky: a hand-painted gradient skybox, saturated blue overhead and
	  pale at the horizon, with no sun disc, moon or stars.
	- Clouds: a hundred painted anime cumulus (Assets.UI.CloudNNN_K, from
	  scripts/paint-clouds.py) on SurfaceGuis, always far off, drifting
	  slowly round the map, and a floor of clouds painted from above
	  (CloudBelowNN_K) lying flat under the map. Each cloud is a stack of
	  slices set apart in depth, and the clouds sit in layers that follow
	  the camera by different amounts, both for parallax.
	- Solid bodies, from the models tools/studio/PlaceSky.luau puts in
	  ReplicatedStorage.SkyModels (art/src/items/Sky*): a pastel banded
	  planet with a glinting ring system, a great cog turning half hidden
	  behind it, a ringed moon orbiting it, a red-orange moon and two pale
	  moons, floating islands with trees, loose rocks, and windmills
	  turning on the horizon. A MeshPart can't be bigger than 2048 studs,
	  so each is shown as a SpecialMesh of the model's mesh and texture,
	  scaled up as far as it needs, in a Persistent model so none of it
	  ever streams out.
	- A spiral galaxy wisp, painted, high in the sky.
	- Life on the islands: dust motes drifting around the camera, flecks of
	  gulls crossing the sky every few minutes, and a shimmer of glints
	  along each island's edge.

	Public API: none.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)

local SKY_MODELS = "SkyModels"
-- SurfaceGuis stop drawing past their MaxDistance; the sky is far past it.
local FAR = 1e6

-- How much farther out space (the planet, its moons and the cog) is than
-- the numbers below say. Every distance and size there is multiplied by
-- it, so space looks the same from the map but is far beyond everything
-- else in the sky: islands and clouds never pass behind it. Past about
-- 40,000 studs the engine hazes everything toward the sky, so the cog (the
-- farthest) stays inside that.
local SPACE_DEPTH = 2.3

local PLANET_AT = Vector3.new(9000, 2900, -7000) * SPACE_DEPTH
-- The art is 10 studs in radius.
local PLANET_SCALE = 230 * SPACE_DEPTH
-- The sun washes the pastels out; this holds the planet's colours back.
local PLANET_TINT = Vector3.new(0.76, 0.76, 0.8)
local RING_TINT = Vector3.new(0.76, 0.72, 0.9)
-- The ring bands' inner and outer radius in the art, for the glints.
local RING_INNER, RING_OUTER = 13.4, 22.2
local RING_GLINTS = 28
local GLINT_SECONDS = NumberRange.new(0.8, 2.4)

-- How wide the ringed moon swings behind the planet.
local ORBIT_RADIUS = 6500 * SPACE_DEPTH
-- How far behind the planet the loop is centred, and how flat it is.
local ORBIT_BEHIND = 3500 * SPACE_DEPTH
local ORBIT_FLAT = 0.3

local COG_AT = Vector3.new(10100, 4231, -13003) * SPACE_DEPTH
-- The art is 8.5 studs in radius.
local COG_SCALE = 492 * SPACE_DEPTH

-- Side-on clouds round the horizon: how many hang there, out of how many
-- painted variants (Assets.UI.CloudNNN).
local CLOUDS = 100
local CLOUD_VARIANTS = 100
local CLOUD_HEIGHT = NumberRange.new(-200, 2200)
-- Kept under 2048 so the back slice, scaled up to line up, still fits a part.
local CLOUD_WIDTH = NumberRange.new(1200, 1750)
-- Each cloud is a stack of slices (CloudNNN_1 front to _3 back) set this
-- far apart in depth, each scaled so the stack lines up seen from the map.
local CLOUD_SLICES = 3
local CLOUD_SLICE_GAP = 350
-- Parallax: a cloud layer follows this share of the camera's sideways
-- movement, so the deeper a layer the more it hangs back while nearer ones
-- slide past. Each also turns round the map at its own pace (radians a
-- second), the near ones fastest. The side-on clouds' layers, near to far:
local CLOUD_LAYERS = {
	{ distance = NumberRange.new(4500, 6000), follow = 0.25, drift = 0.0034 },
	{ distance = NumberRange.new(6000, 7500), follow = 0.45, drift = 0.0024 },
	{ distance = NumberRange.new(7500, 9000), follow = 0.65, drift = 0.0016 },
}
-- The layer of clouds below the map, painted from above (Assets.UI.
-- CloudBelowNN), lying flat and facing up, round the map's middle.
local BELOW_CLOUDS = 70
local BELOW_VARIANTS = 30
local BELOW_CENTER = Vector3.new(280, 0, 0)
local BELOW_REACH = NumberRange.new(0, 3600)
local BELOW_WIDTH = NumberRange.new(700, 1700)
-- Each is a stack of horizontal slices (CloudBelowNN_1 lowest to _4 top)
-- this far apart in height.
local BELOW_SLICES = 4
local BELOW_SLICE_GAP = 45
-- The layer's bands, near (just under the map) to deep; deeper clouds are
-- painted a little bigger so they still read.
local BELOW_LAYERS = {
	{ height = NumberRange.new(-480, -360), follow = 0.1, drift = 0.004, grow = 1 },
	{ height = NumberRange.new(-700, -580), follow = 0.3, drift = 0.0028, grow = 1.15 },
	{ height = NumberRange.new(-960, -840), follow = 0.5, drift = 0.0018, grow = 1.2 },
}

local ISLANDS = 9
local ROCKS = 22
-- Islands sit out among the far clouds; the art is about 44 studs across.
local ISLAND_DISTANCE = NumberRange.new(5500, 9000)
local ISLAND_HEIGHT = NumberRange.new(-300, 2000)
local ISLAND_SCALE = NumberRange.new(11, 20)
local ROCK_DISTANCE = NumberRange.new(3000, 6500)
local ROCK_HEIGHT = NumberRange.new(-400, 1500)
local ROCK_SCALE = NumberRange.new(7, 16)
local WINDMILLS = 4

local GULL_EVERY = NumberRange.new(90, 200)
local GULL_HEIGHT = 140
local GULL_SECONDS = 30
local MOTE_BOX = Vector3.new(120, 40, 120)

local AtmosphereController = {}

local world: Model
local random = Random.new(11)

-- Things that turn in place: `turn` maps seconds to the rotation laid over
-- `base`, about the first part's own middle.
type Spinner = { parts: { BasePart }, offsets: { CFrame }, base: CFrame, turn: (number) -> CFrame }
local spinners: { Spinner } = {}
-- Things that circle a point: the body's parts ride `spinner.base`.
type Orbiter = { spinner: Spinner, center: Vector3, radius: number, tilt: CFrame, speed: number, phase: number }
local orbiters: { Orbiter } = {}
-- Sky meshes: where each one's mesh should stand; its part is a host near
-- the camera (see fileMesh).
local hosted: { [BasePart]: { mesh: SpecialMesh, target: CFrame } } = {}
-- How far in front of the camera the host parts stand.
local HOST_AHEAD = 20
-- Cloud layers, each turning round the map at its own pace.
-- Cloud layers, each turning round `center` at its own pace and following
-- `follow` of the camera's sideways movement from there (parallax).
type CloudLayer = { model: Model, speed: number, center: CFrame, follow: number }
local cloudLayers: { CloudLayer } = {}

local function meshPart(
	kind: Enum.MeshType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	transparency: number?
): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.one
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = kind
	mesh.Scale = size
	mesh.Parent = part
	part.Parent = parent
	return part
end

local function model(name: string): Model
	local group = Instance.new("Model")
	group.Name = name
	group.Parent = world
	return group
end

-- A template MeshPart shown as a SpecialMesh `scale` times the art's size.
-- The part itself is only a host: each frame it is moved just in front of
-- the camera, and the mesh is pushed out to `cframe` with its Offset, so
-- the engine never culls a tiny part thousands of studs away.
local function fileMesh(source: MeshPart, cframe: CFrame, scale: number, parent: Instance): BasePart
	local part = meshPart(Enum.MeshType.FileMesh, Vector3.one, cframe, Color3.new(1, 1, 1), parent)
	part.Name = source.Name
	local mesh = part:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh
	mesh.MeshId = source.MeshId
	mesh.TextureId = source.TextureID
	mesh.Scale = source.Size / source.MeshSize * scale
	hosted[part] = { mesh = mesh, target = cframe }
	return part
end

-- A whole template model, `scale` times its size, with `anchor` (one of
-- its parts, whose middle is the art's origin) standing at `cframe`.
-- Returns the parts and each one's place relative to `cframe`. Everything
-- is measured from the anchor, so it doesn't matter where the template
-- stands or which way it faces.
local function fileModel(
	template: Model,
	anchor: MeshPart,
	cframe: CFrame,
	scale: number,
	parent: Instance
): ({ BasePart }, { CFrame })
	local parts, offsets = {}, {}
	for _, source in template:GetDescendants() do
		if source:IsA("MeshPart") then
			local relative = anchor.CFrame:ToObjectSpace(source.CFrame)
			local offset = CFrame.new(relative.Position * scale) * relative.Rotation
			table.insert(parts, fileMesh(source, cframe * offset, scale, parent))
			table.insert(offsets, offset)
		end
	end
	return parts, offsets
end

local function spin(parts: { BasePart }, offsets: { CFrame }, base: CFrame, turn: (number) -> CFrame): Spinner
	local spinner = { parts = parts, offsets = offsets, base = base, turn = turn }
	table.insert(spinners, spinner)
	return spinner
end

-- A painted sprite standing at `cframe`, facing along its look direction,
-- `size` studs across. A part can't be bigger than 2048 studs.
local function sprite(image: string, size: Vector2, cframe: CFrame, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(size.X, size.Y, 1)
	part.CFrame = cframe
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.MaxDistance = FAR
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(512, 512 * size.Y / size.X)
	gui.Parent = part
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Image = image
	label.Parent = gui
	part.Parent = parent
	return part
end

local function buildSky()
	-- The painted gradient is the skybox itself, with nothing in it to
	-- compete with the sky's own bodies.
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	local side, up, down = Assets.UI.SkySide, Assets.UI.SkyUp, Assets.UI.SkyDown
	if Assets.isSet(side) and Assets.isSet(up) and Assets.isSet(down) then
		sky.SkyboxBk, sky.SkyboxFt, sky.SkyboxLf, sky.SkyboxRt = side, side, side, side
		sky.SkyboxUp, sky.SkyboxDn = up, down
	end
	sky.CelestialBodiesShown = false
	sky.SunAngularSize = 0
	sky.MoonAngularSize = 0
	sky.StarCount = 0
end

-- The planet turns slowly under its rings, tilted toward the map. Glints
-- come and go along the rings.
local function buildPlanet(templates: Instance)
	local template = templates:FindFirstChild("SkyPlanet")
	local ringSource = template and template:FindFirstChild("Ring", true)
	if not (template and template:IsA("Model") and ringSource and ringSource:IsA("MeshPart")) then
		return
	end
	local planet = model("Planet")
	-- Facing the map, then tipped so the rings open toward it.
	local base = CFrame.lookAt(PLANET_AT, Vector3.zero) * CFrame.Angles(math.rad(-20), 0, math.rad(-16))
	local parts, offsets = fileModel(template, ringSource, base, PLANET_SCALE, planet)
	for _, part in parts do
		local mesh = part:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh
		mesh.VertexColor = if part.Name == ringSource.Name then RING_TINT else PLANET_TINT
	end
	spin(parts, offsets, base, function(now)
		return CFrame.Angles(0, now * 0.004, 0)
	end)

	local twinkle = Assets.UI.Twinkle
	if not Assets.isSet(twinkle) then
		return
	end
	local glints = model("RingGlints")
	for _ = 1, RING_GLINTS do
		local angle = random:NextNumber(0, math.pi * 2)
		local reach = random:NextNumber(RING_INNER, RING_OUTER) * PLANET_SCALE
		local at = (base * CFrame.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)).Position
		local size = random:NextNumber(900, 1900) * SPACE_DEPTH
		-- Billboards, since a part (and so a SurfaceGui) stops at 2048 studs.
		local point = Instance.new("Attachment")
		point.WorldPosition = at
		point.Parent = Workspace.Terrain
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(size, size)
		gui.LightInfluence = 0
		gui.MaxDistance = FAR
		gui.Adornee = point
		gui.Parent = glints
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Image = twinkle
		label.Parent = gui
		label.ImageTransparency = 1
		-- Each glint swells in and fades out at its own pace, forever.
		local seconds = random:NextNumber(GLINT_SECONDS.Min, GLINT_SECONDS.Max)
		task.delay(random:NextNumber(0, 3), function()
			TweenService:Create(
				label,
				TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ ImageTransparency = 0 }
			):Play()
		end)
	end
end

-- The cog stands just behind the planet, offset enough that the planet
-- hides its near side but not its hub, and never stops turning. The rings
-- lie nearly edge-on to the map, so they reach far back past the planet:
-- the cog stands farther back still (and is scaled up to match), clear of
-- them, turned only a little off face-on so it stays thin from front to back.
local function buildCog(templates: Instance)
	local template = templates:FindFirstChild("SkyCog")
	local hub = template and template:FindFirstChild("Hub", true)
	if not (template and template:IsA("Model") and hub and hub:IsA("MeshPart")) then
		return
	end
	local base = CFrame.lookAt(COG_AT, Vector3.zero) * CFrame.Angles(0, math.rad(12), 0)
	local parts, offsets = fileModel(template, hub, base, COG_SCALE, model("Cog"))
	spin(parts, offsets, base, function(now)
		return CFrame.Angles(0, 0, now * 0.02)
	end)
end

-- One moon of the set, by name, with the ring that shares its middle.
local function moonParts(templates: Instance, name: string, at: CFrame, scale: number): ({ BasePart }, { CFrame })
	local parts, offsets = {}, {}
	local template = templates:FindFirstChild("SkyMoons")
	for _, suffix in { "", "Ring" } do
		local source = template and template:FindFirstChild(name .. suffix, true)
		if source and source:IsA("MeshPart") then
			table.insert(parts, fileMesh(source, at, scale, model(name .. suffix)))
			table.insert(offsets, CFrame.identity)
		end
	end
	return parts, offsets
end

local function buildMoons(templates: Instance)
	-- The lone moons hang where they are, turning on their own axes.
	local lone = {
		{ name = "RedMoon", at = Vector3.new(-7000, 5200, -9000), scale = 62 },
		{ name = "PaleMoon1", at = Vector3.new(-11000, 3000, -2500), scale = 30 },
		{ name = "PaleMoon2", at = Vector3.new(3000, 6500, -12000), scale = 22 },
	}
	for _, moon in lone do
		moon.at *= SPACE_DEPTH
		moon.scale *= SPACE_DEPTH
	end
	for _, moon in lone do
		local base = CFrame.new(moon.at) * CFrame.Angles(math.rad(12), 0, math.rad(-18))
		local parts, offsets = moonParts(templates, moon.name, base, moon.scale)
		spin(parts, offsets, base, function(now)
			return CFrame.Angles(0, now * 0.01, 0)
		end)
	end

	-- The ringed moon circles a point just behind the planet, on a flattened
	-- loop facing the map and tipped like the planet's rings, so it swings
	-- out to either side and passes behind the planet, spinning as it goes.
	local tilt = CFrame.lookAt(PLANET_AT, Vector3.zero) * CFrame.Angles(math.rad(-20), 0, math.rad(-16))
	local parts, offsets = moonParts(templates, "RingMoon", tilt, 42 * SPACE_DEPTH)
	local spinner = spin(parts, offsets, tilt, function(now)
		return CFrame.Angles(0, now * 0.12, 0)
	end)
	table.insert(orbiters, {
		spinner = spinner,
		center = PLANET_AT + PLANET_AT.Unit * ORBIT_BEHIND,
		radius = ORBIT_RADIUS,
		tilt = CFrame.lookAt(PLANET_AT, Vector3.zero).Rotation * CFrame.Angles(0, 0, math.rad(-16)),
		speed = 0.012,
		phase = 2,
	})
end

-- A direction on the horizon ring, as a point `distance` out and `height` up.
local function around(angle: number, distance: number, height: number): Vector3
	return Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
end

-- Floating islands and loose rocks, each a baked variant picked in turn
-- and turned its own way, bobbing a little.
local function buildIslands(templates: Instance)
	local template = templates:FindFirstChild("SkyIslands")
	if not template then
		return
	end
	-- Each variant's parts, by the name before any "_" (Island03_Ground and
	-- Island03_Trees are one island), its first part first.
	local islands, rocks = {}, {}
	local byName: { [string]: { MeshPart } } = {}
	for _, source in template:GetDescendants() do
		if not source:IsA("MeshPart") then
			continue
		end
		local name = string.match(source.Name, "^[^_]+") :: string
		if not byName[name] then
			byName[name] = {}
			table.insert(if string.match(name, "^Island") then islands else rocks, byName[name])
		end
		local variant = byName[name]
		-- The ground (or the lone rock) leads, so the others hang off it.
		if string.match(source.Name, "_Ground$") then
			table.insert(variant, 1, source)
		else
			table.insert(variant, source)
		end
	end
	local function scatter(
		variants: { { MeshPart } },
		count: number,
		group: Model,
		distance: NumberRange,
		height: NumberRange,
		scale: NumberRange
	)
		if #variants == 0 then
			return
		end
		for index = 1, count do
			local variant = variants[(index - 1) % #variants + 1]
			local angle = (index + random:NextNumber(-0.35, 0.35)) / count * math.pi * 2
			local at =
				around(angle, random:NextNumber(distance.Min, distance.Max), random:NextNumber(height.Min, height.Max))
			local base = CFrame.new(at) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
			local size = random:NextNumber(scale.Min, scale.Max)
			local parts, offsets = {}, {}
			for _, source in variant do
				local relative = variant[1].CFrame:ToObjectSpace(source.CFrame)
				local offset = CFrame.new(relative.Position * size) * relative.Rotation
				table.insert(parts, fileMesh(source, base * offset, size, group))
				table.insert(offsets, offset)
			end
			local phase, rise = random:NextNumber(0, 6), size * 0.6
			spin(parts, offsets, base, function(now)
				return CFrame.new(0, math.sin(now * 0.15 + phase) * rise, 0)
			end)
		end
	end
	scatter(islands, ISLANDS, model("Islands"), ISLAND_DISTANCE, ISLAND_HEIGHT, ISLAND_SCALE)
	scatter(rocks, ROCKS, model("Rocks"), ROCK_DISTANCE, ROCK_HEIGHT, ROCK_SCALE)
end

-- Windmills far out on the horizon, their rotors turning.
local function buildWindmills(templates: Instance)
	local template = templates:FindFirstChild("SkyWindmill")
	local tower = template and template:FindFirstChild("Tower", true)
	local rotor = template and template:FindFirstChild("Rotor", true)
	if not (template and tower and tower:IsA("MeshPart") and rotor and rotor:IsA("MeshPart")) then
		return
	end
	-- Each stands on a floating rock, if the island set has any.
	local rocks = {}
	local islandSet = templates:FindFirstChild("SkyIslands")
	for _, source in if islandSet then islandSet:GetDescendants() else {} do
		if source:IsA("MeshPart") and source.Name:match("^Rock") then
			table.insert(rocks, source)
		end
	end
	local group = model("Windmills")
	for index = 1, WINDMILLS do
		local angle = (index + random:NextNumber(-0.3, 0.3)) / WINDMILLS * math.pi * 2 + 0.6
		local at = around(angle, random:NextNumber(6500, 8500), random:NextNumber(200, 900))
		local scale = random:NextNumber(40, 60)
		-- Facing the map, give or take.
		local base = CFrame.lookAt(at, Vector3.new(0, at.Y, 0)) * CFrame.Angles(0, random:NextNumber(-0.5, 0.5), 0)
		fileMesh(tower, base, scale, group)
		local rock = rocks[(index - 1) % math.max(#rocks, 1) + 1]
		if rock then
			-- Wide enough to carry the tower's feet, its top at their level.
			local rockScale = scale * tower.Size.X * 2.2 / rock.Size.X
			local drop = tower.Size.Y / 2 * scale + rock.Size.Y * 0.42 * rockScale
			fileMesh(rock, base * CFrame.new(0, -drop, 0), rockScale, group)
		end
		local hub = CFrame.new(tower.CFrame:ToObjectSpace(rotor.CFrame).Position * scale)
		local speed, phase = random:NextNumber(0.25, 0.5), random:NextNumber(0, 6)
		local part = fileMesh(rotor, base * hub, scale, group)
		spin({ part }, { CFrame.identity }, base * hub, function(now)
			return CFrame.Angles(0, 0, now * speed + phase)
		end)
	end
end

local function buildGalaxy()
	local image = Assets.UI.Galaxy
	if not Assets.isSet(image) then
		return
	end
	-- A sprite can't be wider than 2048 studs, so it hangs nearer than the
	-- moons to look as big as it should.
	local at = Vector3.new(-2000, 1900, -1400)
	sprite(
		image,
		Vector2.new(2048, 1024),
		CFrame.lookAt(at, Vector3.zero) * CFrame.Angles(0, 0, math.rad(-20)),
		model("Galaxy")
	)
end

-- Painted clouds, always far off, each facing the map, in layers that
-- drift round it at different paces.
local function buildClouds()
	local layers = {}
	for index, layer in CLOUD_LAYERS do
		local group = model("Clouds" .. index)
		group.WorldPivot = CFrame.identity
		local entry = { model = group, speed = layer.drift, center = CFrame.identity, follow = layer.follow }
		table.insert(cloudLayers, entry)
		layers[index] = entry
	end
	for index = 1, CLOUDS do
		local variant = (index - 1) % CLOUD_VARIANTS + 1
		local angle = (index + random:NextNumber(-0.4, 0.4)) / CLOUDS * math.pi * 2
		local band = (index - 1) % #CLOUD_LAYERS + 1
		local range = CLOUD_LAYERS[band].distance
		local distance = random:NextNumber(range.Min, range.Max)
		-- Most sit low, near the horizon; a few ride high.
		local height = CLOUD_HEIGHT.Min + (CLOUD_HEIGHT.Max - CLOUD_HEIGHT.Min) * random:NextNumber() ^ 2
		local width = random:NextNumber(CLOUD_WIDTH.Min, CLOUD_WIDTH.Max)
		for slice = 1, CLOUD_SLICES do
			local image = (Assets.UI :: { [string]: string })[string.format("Cloud%03d_%d", variant, slice)]
			if not Assets.isSet(image) then
				continue
			end
			-- Further out and bigger by the same share, so from the map the
			-- slices line up into one cloud.
			local grow = (distance + (slice - 1) * CLOUD_SLICE_GAP) / distance
			local at = around(angle, distance * grow, height * grow)
			-- The SurfaceGui is on the part's front, which looks along -Z.
			local facing = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
			sprite(image, Vector2.new(width, width / 2) * grow, facing, layers[band].model)
		end
	end
end

-- A floor of clouds under the map, seen from above: each lies flat facing
-- up, turned any way, and the whole layer drifts slowly round the map.
local function buildCloudsBelow()
	local center = CFrame.new(BELOW_CENTER)
	local layers = {}
	for index, layer in BELOW_LAYERS do
		local group = model("CloudsBelow" .. index)
		group.WorldPivot = center
		local entry = { model = group, speed = layer.drift, center = center, follow = layer.follow }
		table.insert(cloudLayers, entry)
		layers[index] = entry
	end
	for index = 1, BELOW_CLOUDS do
		local variant = (index - 1) % BELOW_VARIANTS + 1
		local band = (index - 1) % #BELOW_LAYERS + 1
		local layer = BELOW_LAYERS[band]
		local angle = random:NextNumber(0, math.pi * 2)
		-- Spread evenly over the disc rather than bunched in the middle.
		local reach = BELOW_REACH.Min + (BELOW_REACH.Max - BELOW_REACH.Min) * math.sqrt(random:NextNumber())
		local at = BELOW_CENTER + around(angle, reach, random:NextNumber(layer.height.Min, layer.height.Max))
		local width = math.min(random:NextNumber(BELOW_WIDTH.Min, BELOW_WIDTH.Max) * layer.grow, 2048)
		local turn = random:NextNumber(0, math.pi * 2)
		for slice = 1, BELOW_SLICES do
			local image = (Assets.UI :: { [string]: string })[string.format("CloudBelow%02d_%d", variant, slice)]
			if not Assets.isSet(image) then
				continue
			end
			local lift = Vector3.yAxis * (slice - 1) * BELOW_SLICE_GAP
			local facing = CFrame.lookAt(at + lift, at + lift + Vector3.yAxis) * CFrame.Angles(0, 0, turn)
			sprite(image, Vector2.new(width, width / 2), facing, layers[band].model)
		end
	end
end

local function animate()
	local now = os.clock()
	for _, orbiter in orbiters do
		local angle = orbiter.phase + now * orbiter.speed
		local at = orbiter.tilt
			* Vector3.new(math.cos(angle) * orbiter.radius, math.sin(angle) * orbiter.radius * ORBIT_FLAT, 0)
		orbiter.spinner.base = CFrame.new(orbiter.center + at) * orbiter.spinner.base.Rotation
	end
	for _, spinner in spinners do
		local turned = spinner.base * spinner.turn(now)
		for index, part in spinner.parts do
			local entry = hosted[part]
			if entry then
				entry.target = turned * spinner.offsets[index]
			end
		end
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, layer in cloudLayers do
		-- Only sideways: following the camera up and down would carry the
		-- clouds below up past the map.
		local away = (eye - layer.center.Position) * Vector3.new(1, 0, 1)
		layer.model:PivotTo(CFrame.new(away * layer.follow) * layer.center * CFrame.Angles(0, now * layer.speed, 0))
	end

	-- Hosts stand just in front of the camera, turned as their meshes are;
	-- the Offset (in the host's own space) carries each mesh out to its place.
	local ahead = camera.CFrame.Position + camera.CFrame.LookVector * HOST_AHEAD
	for part, entry in hosted do
		local host = CFrame.new(ahead) * entry.target.Rotation
		part.CFrame = host
		entry.mesh.Offset = host:PointToObjectSpace(entry.target.Position)
	end
end

-- Dust motes in a box that follows the camera.
local function buildMotes()
	local box = Instance.new("Part")
	box.Name = "DustMotes"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = MOTE_BOX
	box.Parent = world

	local motes = Instance.new("ParticleEmitter")
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	motes.Color = ColorSequence.new(Color3.fromRGB(255, 245, 220))
	motes.LightEmission = 0.6
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.12),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new(0.3)
	motes.Lifetime = NumberRange.new(6, 10)
	motes.Rate = 25
	motes.Speed = NumberRange.new(0.2, 0.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0.3, 0.05, 0.1)
	motes.Parent = box

	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			box.CFrame = CFrame.new(camera.CFrame.Position)
		end
	end)
end

-- A small flock of V-shaped flecks crossing the sky once.
local function flyGulls()
	local camera = Workspace.CurrentCamera
	local center = if camera then camera.CFrame.Position * Vector3.new(1, 0, 1) else Vector3.zero
	local heading = math.random() * math.pi * 2
	local direction = Vector3.new(math.cos(heading), 0, math.sin(heading))
	local from = center - direction * 600 + Vector3.new(0, GULL_HEIGHT, 0)
	local to = center + direction * 600 + Vector3.new(0, GULL_HEIGHT + 30, 0)

	for index = 1, math.random(3, 6) do
		local gull = Instance.new("Model")
		gull.Name = "Gull"
		local offset = Vector3.new(math.random(-20, 20), math.random(-6, 6), math.random(-20, 20))
		local facing = CFrame.lookAt(from + offset, from + offset + direction)
		local wings = {}
		for side = -1, 1, 2 do
			local wing = meshPart(
				Enum.MeshType.Brick,
				Vector3.new(2.4, 0.15, 0.6),
				facing * CFrame.new(side * 1.1, 0, 0),
				Color3.fromRGB(60, 60, 70),
				gull
			)
			table.insert(wings, { part = wing, side = side })
		end
		gull.Parent = world

		local startedAt = os.clock() + index * 0.3
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			local alpha = (os.clock() - startedAt) / GULL_SECONDS
			if alpha > 1 then
				connection:Disconnect()
				gull:Destroy()
				return
			end
			local base = CFrame.lookAt(from:Lerp(to, math.max(alpha, 0)) + offset, to + offset)
			local flap = math.sin(os.clock() * 8 + index) * 0.5
			for _, wing in wings do
				wing.part.CFrame = base * CFrame.Angles(0, 0, wing.side * flap) * CFrame.new(wing.side * 1.1, 0, 0)
			end
		end)
	end
end

-- Glints along the rim of each island, where its top meets the rock.
local function shimmerIslands()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, island in map:GetChildren() do
		local isIsland = island.Name:match("^Island%d+$")
			or island.Name == "MarketIsland"
			or island.Name:match("^Pad%dRock$")
		if not (isIsland and island:IsA("Model")) then
			continue
		end
		local box, size = island:GetBoundingBox()
		local rim = Instance.new("Part")
		rim.Name = "Shimmer"
		rim.Anchored = true
		rim.CanCollide = false
		rim.CanQuery = false
		rim.CanTouch = false
		rim.Transparency = 1
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(2, math.max(size.X, size.Z), math.max(size.X, size.Z))
		rim.CFrame = CFrame.new((box * CFrame.new(0, size.Y / 2 - 3, 0)).Position) * CFrame.Angles(0, 0, math.rad(90))
		rim.Parent = world

		local glints = Instance.new("ParticleEmitter")
		glints.Shape = Enum.ParticleEmitterShape.Cylinder
		glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		glints.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
		glints.LightEmission = 1
		glints.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		glints.Lifetime = NumberRange.new(0.6, 1.2)
		glints.Rate = math.clamp(size.X * size.Z / 400, 6, 40)
		glints.Speed = NumberRange.new(0, 0.3)
		glints.Parent = rim
	end
end

function AtmosphereController.init() end

function AtmosphereController.start()
	world = Instance.new("Model")
	world.Name = "Atmosphere"
	world.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	world.Parent = Workspace

	buildSky()
	buildGalaxy()
	buildClouds()
	buildCloudsBelow()
	buildMotes()

	-- The baked models; without them (PlaceSky not run yet) the sky keeps
	-- its clouds and gradient.
	local templates = ReplicatedStorage:FindFirstChild(SKY_MODELS)
	if templates then
		buildPlanet(templates)
		buildCog(templates)
		buildMoons(templates)
		buildIslands(templates)
		buildWindmills(templates)
	else
		warn(`AtmosphereController: no ReplicatedStorage.{SKY_MODELS}; run tools/studio/PlaceSky.luau`)
	end

	-- After the camera moves, so the hosts sit where it is this frame.
	RunService:BindToRenderStep("Atmosphere", Enum.RenderPriority.Camera.Value + 2, animate)
	-- The map streams in after spawn.
	task.delay(5, shimmerIslands)
	task.spawn(function()
		while true do
			task.wait(math.random(GULL_EVERY.Min, GULL_EVERY.Max))
			flyGulls()
		end
	end)
end

return AtmosphereController
