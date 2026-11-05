--!strict
--[[
	AtmosphereController

	The world around the islands, built on this client only:

	- The sky: a saturated blue inverted sphere SKY_RADIUS studs out over a
	  plain skybox, with soft cumulus clouds drifting under it.
	- Distant bodies, all SpecialMesh parts (a Part can't be bigger than
	  2048 studs, and meshes keep rendering at that distance) in a
	  Persistent model so they never stream out: a pastel banded planet
	  with a sparkling ring system, a ringed moon orbiting behind it, a
	  huge rusted cog half hidden behind it, a red-orange moon and two pale
	  moons drifting, a spiral galaxy wisp, floating rocks, mossy floating
	  islands with trees, and slowly turning structures on the horizon.
	- Life on the islands: dust motes drifting around the camera, flecks of
	  gulls crossing the sky every few minutes, and a shimmer of glints
	  along each island's edge.

	Everything is flat colored for now; hand-drawn textures replace the
	colors as they're painted.

	Public API: none.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SKY_RADIUS = 20000
local SKY_COLOR = Color3.fromRGB(70, 150, 255)
-- The haze the islands sit in, thin enough for the distant bodies to show.
local ATMOSPHERE_DENSITY = 0.12

local PLANET_AT = Vector3.new(9000, 2600, -7000)
local PLANET_RADIUS = 2400
local PLANET_BANDS = {
	Color3.fromRGB(255, 205, 180),
	Color3.fromRGB(250, 230, 190),
	Color3.fromRGB(205, 190, 245),
	Color3.fromRGB(190, 225, 240),
	Color3.fromRGB(255, 190, 210),
}
local RING_COLORS = { Color3.fromRGB(255, 240, 200), Color3.fromRGB(230, 210, 255), Color3.fromRGB(200, 240, 255) }
local RING_SEGMENTS = 64
local RING_SPARKLE_SECONDS = 0.15

local GULL_EVERY = NumberRange.new(90, 200)
local GULL_HEIGHT = 140
local GULL_SECONDS = 30
local MOTE_BOX = Vector3.new(120, 40, 120)

local AtmosphereController = {}

local world: Model
local spinners: { { part: Model | BasePart, axis: Vector3, speed: number, base: CFrame } } = {}
local orbiters: { { model: Model, center: Vector3, radius: number, height: number, speed: number, phase: number } } = {}
local ringParts: { BasePart } = {}

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

local function sphere(radius: number, at: Vector3, color: Color3, parent: Instance, material: Enum.Material?): BasePart
	return meshPart(Enum.MeshType.Sphere, Vector3.one * radius * 2, CFrame.new(at), color, parent, material)
end

local function model(name: string): Model
	local group = Instance.new("Model")
	group.Name = name
	group.Parent = world
	return group
end

-- A ring of flat segments around `center`, tilted by `tilt`. Rings are
-- built from segments because a solid disc would show through the planet.
local function ring(
	center: CFrame,
	inner: number,
	outer: number,
	segments: number,
	colors: { Color3 },
	parent: Instance
)
	local radius = (inner + outer) / 2
	local width = outer - inner
	local length = 2 * math.pi * radius / segments * 1.08
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local cframe = center * CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0, 0)
		local part = meshPart(
			Enum.MeshType.Brick,
			Vector3.new(width, width * 0.02, length),
			cframe,
			colors[index % #colors + 1],
			parent,
			Enum.Material.Neon,
			0.25
		)
		table.insert(ringParts, part)
	end
end

local function buildSky()
	local sky = model("Sky")
	-- A negative scale turns the sphere inside out, so it's seen from within.
	meshPart(Enum.MeshType.Sphere, -Vector3.one * SKY_RADIUS * 2, CFrame.new(), SKY_COLOR, sky, Enum.Material.Neon)

	-- A plain skybox underneath: no sun, moon or stars to compete.
	local skybox = Lighting:FindFirstChildOfClass("Sky")
	if skybox then
		skybox.CelestialBodiesShown = false
		skybox.StarCount = 0
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = math.min(atmosphere.Density, ATMOSPHERE_DENSITY)
	end
end

local function buildPlanet()
	local planet = model("Planet")
	local tilt = CFrame.new(PLANET_AT) * CFrame.Angles(math.rad(18), 0, math.rad(-12))
	sphere(PLANET_RADIUS, PLANET_AT, PLANET_BANDS[1], planet).CFrame = tilt

	-- Bands: belts hugging the sphere at each latitude, alternating colors.
	local bands = 9
	for index = 1, bands do
		local latitude = (index / (bands + 1) - 0.5) * math.pi * 0.9
		local beltRadius = PLANET_RADIUS * math.cos(latitude) * 1.004
		local height = PLANET_RADIUS * 0.16
		meshPart(
			Enum.MeshType.Cylinder,
			Vector3.new(height, beltRadius * 2, beltRadius * 2),
			tilt * CFrame.new(0, PLANET_RADIUS * math.sin(latitude), 0) * CFrame.Angles(0, 0, math.rad(90)),
			PLANET_BANDS[index % #PLANET_BANDS + 1],
			planet
		)
	end

	ring(tilt, PLANET_RADIUS * 1.35, PLANET_RADIUS * 1.75, RING_SEGMENTS, RING_COLORS, planet)
	ring(tilt, PLANET_RADIUS * 1.8, PLANET_RADIUS * 2.15, RING_SEGMENTS, { RING_COLORS[2], RING_COLORS[1] }, planet)

	-- A ringed moon orbiting behind the planet, spinning slowly.
	local moon = model("RingedMoon")
	sphere(420, Vector3.zero, Color3.fromRGB(215, 225, 255), moon)
	ring(CFrame.Angles(math.rad(25), 0, 0), 560, 760, 24, { Color3.fromRGB(255, 220, 240) }, moon)
	table.insert(orbiters, {
		model = moon,
		center = PLANET_AT + (PLANET_AT.Unit * 3500),
		radius = PLANET_RADIUS * 3.2,
		height = 600,
		speed = 0.004,
		phase = 0,
	})
	table.insert(spinners, { part = moon, axis = Vector3.yAxis, speed = 0.05, base = CFrame.identity })
end

local function buildCog()
	local cog = model("Cog")
	local at = PLANET_AT * 1.45 + Vector3.new(-2500, -400, 0)
	local radius = 2600
	local rust = Color3.fromRGB(150, 80, 45)
	local center = CFrame.lookAt(at, Vector3.zero)
	meshPart(
		Enum.MeshType.Cylinder,
		Vector3.new(500, radius * 2, radius * 2),
		center * CFrame.Angles(0, math.rad(90), 0),
		rust,
		cog
	)
	meshPart(
		Enum.MeshType.Cylinder,
		Vector3.new(560, radius * 0.6, radius * 0.6),
		center * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(110, 60, 35),
		cog
	)
	local teeth = 24
	for index = 1, teeth do
		local angle = index / teeth * math.pi * 2
		meshPart(
			Enum.MeshType.Brick,
			Vector3.new(radius * 0.22, radius * 0.3, 500),
			center * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius + radius * 0.1, 0),
			rust,
			cog
		)
	end
	cog.WorldPivot = center
	table.insert(spinners, { part = cog, axis = Vector3.zAxis, speed = 0.01, base = center })
end

local function buildMoons()
	local moons = {
		{ radius = 600, at = Vector3.new(-6000, 3200, -9000), color = Color3.fromRGB(240, 110, 60), speed = 0.003 },
		{ radius = 350, at = Vector3.new(-11000, 4200, 2000), color = Color3.fromRGB(235, 235, 245), speed = 0.002 },
		{ radius = 220, at = Vector3.new(4000, 5200, 11000), color = Color3.fromRGB(225, 240, 250), speed = 0.004 },
	}
	for index, spec in moons do
		local moon = model(`Moon{index}`)
		sphere(spec.radius, Vector3.zero, spec.color, moon)
		local flat = Vector3.new(spec.at.X, 0, spec.at.Z)
		table.insert(orbiters, {
			model = moon,
			center = Vector3.zero,
			radius = flat.Magnitude,
			height = spec.at.Y,
			speed = spec.speed,
			phase = math.atan2(spec.at.Z, spec.at.X),
		})
	end
end

local function buildGalaxy()
	local galaxy = model("Galaxy")
	local center = CFrame.lookAt(Vector3.new(-9000, 9000, -11000), Vector3.zero) * CFrame.Angles(math.rad(70), 0, 0)
	meshPart(
		Enum.MeshType.Sphere,
		Vector3.new(1400, 200, 1400),
		center,
		Color3.fromRGB(255, 240, 255),
		galaxy,
		Enum.Material.Neon,
		0.6
	)
	-- Two arms of soft puffs spiralling out from the core.
	for arm = 0, 1 do
		for step = 1, 14 do
			local angle = arm * math.pi + step * 0.42
			local distance = 500 + step * 260
			meshPart(
				Enum.MeshType.Sphere,
				Vector3.new(900 - step * 30, 120, 500),
				center * CFrame.Angles(0, -angle, 0) * CFrame.new(distance, 0, 0),
				if step % 2 == 0 then Color3.fromRGB(210, 190, 255) else Color3.fromRGB(190, 220, 255),
				galaxy,
				Enum.Material.Neon,
				0.8 + step * 0.01
			)
		end
	end
end

local function buildRocks()
	local rocks = model("FloatingRocks")
	local random = Random.new(7)
	for _ = 1, 7 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(3000, 7000)
		local at = Vector3.new(math.cos(angle) * distance, random:NextNumber(-300, 1500), math.sin(angle) * distance)
		local size = random:NextNumber(80, 320)
		for _ = 1, random:NextInteger(2, 4) do
			meshPart(
				Enum.MeshType.Sphere,
				Vector3.new(size, size * 0.8, size) * random:NextNumber(0.6, 1.2),
				CFrame.new(at + random:NextUnitVector() * size * 0.6) * CFrame.Angles(0, random:NextNumber(0, 6), 0),
				Color3.fromRGB(125, 110, 100):Lerp(Color3.fromRGB(160, 140, 120), random:NextNumber()),
				rocks
			)
		end
	end
end

local function buildIslands()
	local islands = model("FloatingIslands")
	local random = Random.new(11)
	-- Three tiers: near, middle and far, each higher and bigger than the last.
	local tiers = { { 2500, 200, 1 }, { 5000, 900, 2 }, { 8500, 1800, 3.5 } }
	for _, tier in tiers do
		for _ = 1, 4 do
			local angle = random:NextNumber(0, math.pi * 2)
			local at = Vector3.new(
				math.cos(angle) * tier[1],
				tier[2] + random:NextNumber(-200, 200),
				math.sin(angle) * tier[1]
			)
			local scale = tier[3] * random:NextNumber(0.8, 1.3)
			local width = 160 * scale
			-- Rock tapering down underneath, moss on top, a few round trees.
			meshPart(
				Enum.MeshType.Sphere,
				Vector3.new(width, width * 1.1, width),
				CFrame.new(at - Vector3.new(0, width * 0.35, 0)),
				Color3.fromRGB(140, 115, 95),
				islands
			)
			meshPart(
				Enum.MeshType.Cylinder,
				Vector3.new(width * 0.12, width * 1.02, width * 1.02),
				CFrame.new(at + Vector3.new(0, width * 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(110, 190, 90),
				islands
			)
			for _ = 1, random:NextInteger(2, 4) do
				local spot = at
					+ Vector3.new(
						random:NextNumber(-0.3, 0.3) * width,
						width * 0.21,
						random:NextNumber(-0.3, 0.3) * width
					)
				local trunk = width * 0.18
				meshPart(
					Enum.MeshType.Cylinder,
					Vector3.new(trunk, trunk * 0.18, trunk * 0.18),
					CFrame.new(spot + Vector3.new(0, trunk / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Color3.fromRGB(120, 85, 60),
					islands
				)
				sphere(trunk * 0.55, spot + Vector3.new(0, trunk * 1.1, 0), Color3.fromRGB(90, 175, 80), islands)
			end
		end
	end
end

local function buildStructures()
	local structures = model("Structures")
	local random = Random.new(23)
	for _ = 1, 6 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(11000, 14000)
		local at = Vector3.new(math.cos(angle) * distance, random:NextNumber(-600, 400), math.sin(angle) * distance)
		local tower = Instance.new("Model")
		tower.Name = "Structure"
		tower.Parent = structures
		local height = random:NextNumber(1500, 3500)
		local color = Color3.fromRGB(150, 170, 210)
		local base =
			meshPart(Enum.MeshType.Brick, Vector3.new(300, height, 300), CFrame.new(at), color, tower, nil, 0.35)
		meshPart(
			Enum.MeshType.Brick,
			Vector3.new(900, 120, 120),
			CFrame.new(at + Vector3.new(0, height * 0.35, 0)),
			color,
			tower,
			nil,
			0.35
		)
		tower.PrimaryPart = base
		table.insert(spinners, {
			part = tower,
			axis = Vector3.yAxis,
			speed = random:NextNumber(0.01, 0.03),
			base = CFrame.new(at),
		})
	end
end

local function buildClouds()
	local clouds = model("Clouds")
	local random = Random.new(5)
	for _ = 1, 16 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(1200, 6000)
		local at = Vector3.new(math.cos(angle) * distance, random:NextNumber(250, 900), math.sin(angle) * distance)
		local size = random:NextNumber(120, 320)
		for puff = 1, random:NextInteger(4, 7) do
			local offset = Vector3.new(
				random:NextNumber(-1.2, 1.2) * size,
				random:NextNumber(0, 0.4) * size,
				random:NextNumber(-0.5, 0.5) * size
			)
			meshPart(
				Enum.MeshType.Sphere,
				Vector3.new(size, size * 0.7, size) * (if puff == 1 then 1.3 else random:NextNumber(0.6, 1)),
				CFrame.new(at + offset),
				Color3.new(1, 1, 1),
				clouds,
				nil,
				0.1
			)
		end
	end
	clouds.WorldPivot = CFrame.identity
	table.insert(spinners, { part = clouds, axis = Vector3.yAxis, speed = 0.004, base = CFrame.identity })
end

local function animate()
	local now = os.clock()
	for _, spinner in spinners do
		local cframe = spinner.base * CFrame.fromAxisAngle(spinner.axis, now * spinner.speed)
		if spinner.part:IsA("Model") then
			spinner.part:PivotTo(cframe)
		else
			spinner.part.CFrame = cframe
		end
	end
	for _, orbiter in orbiters do
		local angle = orbiter.phase + now * orbiter.speed
		local position = orbiter.center
			+ Vector3.new(math.cos(angle) * orbiter.radius, orbiter.height, math.sin(angle) * orbiter.radius)
		orbiter.model:PivotTo(CFrame.new(position) * orbiter.model:GetPivot().Rotation)
	end
end

-- Now and then a ring segment glints.
local function sparkleRings()
	while true do
		task.wait(RING_SPARKLE_SECONDS)
		local part = ringParts[math.random(#ringParts)]
		if part then
			part.Transparency = 0
			TweenService:Create(part, TweenInfo.new(0.8), { Transparency = 0.25 }):Play()
		end
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
	buildPlanet()
	buildCog()
	buildMoons()
	buildGalaxy()
	buildRocks()
	buildIslands()
	buildStructures()
	buildClouds()
	buildMotes()

	RunService.Heartbeat:Connect(animate)
	task.spawn(sparkleRings)
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
