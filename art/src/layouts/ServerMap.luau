-- uses: HubSectionA HubSectionB HubSectionEnd YardIsland YardFence YardFenceHalf YardFooting YardGate PlotMarker PadKitchen PadGarage PadGadget BuildBay ScrapCrate RebirthPress JunkMound CapsuleScrap CapsuleSalvaged CapsuleRefurbished CapsuleFactory CapsulePrecision CapsulePrototype CapsuleSecret JunkrotCanettoRustini JunkrotSpoonzoBentolo JunkrotKettlinaDentata JunkrotTyroFlattino JunkrotBoltoloLonelo JunkrotHubcappaWobbla JunkrotRemotinoMuto JunkrotCabloTanglino JunkrotBulboFulminato JunkrotCrumboPoppalot JunkrotPannettoPatchato JunkrotBlendroCigolante JunkrotJackoloCrickato JunkrotOilcannaGluglu JunkrotMuffleroTossetto JunkrotRadioloFruscio JunkrotFanettoWobblino JunkrotClockoTictacco
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
-- The capsule belt loops round the bed down the Line's middle, through the
-- sorter at its west end. One of each model the game places itself (the
-- kit) is built here too, out of sight, so it uploads with the map.
-- Labels: HubSection1-HubSection5, Line, Belt, Sorter, Spawn, Island1-Island8,
-- Plot1-Plot8 (1-4 along the north row from the west, 5-8 along the south),
-- Approach1-Approach8, Spoke1-Spoke8, Bridge1-Bridge8 and
-- Yard1_<piece>-Yard8_<piece>, where the
-- pieces are Gate, PlotMarker, and Fence and Footing pieces; and Kit_<model>
-- for each kit model (see KIT at the end).

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

-- The capsule belt: a rubber tread 5 studs wide between two low steel rails,
-- looping round the bed as a stadium (the game's Config/Belt gives the same
-- path: straights BELT_HALF_LENGTH either side of the middle at y = +-BELT_TURN,
-- joined by half circles). Its top is 0.6 over the deck, low enough to step
-- over anywhere; the rails stand 0.35 above it to keep the capsules on.
local BELT_HALF_LENGTH, BELT_TURN = 200, 16
local BELT_HALF_WIDTH = 2.5
local BELT_TOP = DECK + 0.6
local BELT_STEP = 4
local BELT_RUBBER = { 0.16, 0.16, 0.17 }

-- The belt's middle line as points { x, y, headingX, headingY }, BELT_STEP
-- apart at most, running east along the north straight first, as the
-- capsules do.
local function beltPath(): { { number } }
	local straight, turn = 2 * BELT_HALF_LENGTH, math.pi * BELT_TURN
	local length = 2 * straight + 2 * turn
	local count = math.ceil(length / BELT_STEP)
	local points = {}
	for i = 0, count do
		local along = i / count * length
		if along < straight then
			table.insert(points, { -BELT_HALF_LENGTH + along, BELT_TURN, 1, 0 })
		elseif along < straight + turn then
			local a = (along - straight) / BELT_TURN
			table.insert(points, { BELT_HALF_LENGTH + math.sin(a) * BELT_TURN, math.cos(a) * BELT_TURN, math.cos(a), -math.sin(a) })
		elseif along < 2 * straight + turn then
			table.insert(points, { BELT_HALF_LENGTH - (along - straight - turn), -BELT_TURN, -1, 0 })
		else
			local a = (along - 2 * straight - turn) / BELT_TURN
			table.insert(points, { -BELT_HALF_LENGTH - math.sin(a) * BELT_TURN, -math.cos(a) * BELT_TURN, -math.cos(a), math.sin(a) })
		end
	end
	return points
end

-- A strip along the belt between `from` and `to` studs left of its middle
-- line (negative is right), from `bottom` up to `top`: its top and both
-- sides. It lies on the bed, so it has no underside.
local function beltStrip(mesh, path: { { number } }, from: number, to: number, bottom: number, top: number)
	local rows = {}
	for i, point in path do
		local leftX, leftY = -point[4], point[3]
		local function at(offset: number, z: number)
			return mesh:vertex(point[1] + leftX * offset, point[2] + leftY * offset, z)
		end
		rows[i] = { lowR = at(from, bottom), highR = at(from, top), lowL = at(to, bottom), highL = at(to, top) }
	end
	for i = 1, #rows - 1 do
		local a, b = rows[i], rows[i + 1]
		mesh:face({ a.highR, b.highR, b.highL, a.highL })
		mesh:face({ a.lowR, b.lowR, b.highR, a.highR })
		mesh:face({ b.lowL, a.lowL, a.highL, b.highL })
	end
end

-- Ribbed rubber: a darker cleat across the tread every 2 studs along it,
-- under scuffs and dust.
local function beltTread(x: number, y: number): (number, number, number)
	local along = x
	if math.abs(x) > BELT_HALF_LENGTH then
		local side = if x > 0 then 1 else -1
		along = math.atan2(y, (x - side * BELT_HALF_LENGTH) * side) * BELT_TURN
	end
	local k = 1 + fbm(x / 3, y / 3, 61) * 0.25
	if along % 2 < 0.3 then
		k -= 0.35
	end
	k += math.max(0, warpedFbm(x / 6, y / 6, 62) - 0.2) * 1.2
	return BELT_RUBBER[1] * k, BELT_RUBBER[2] * k, BELT_RUBBER[3] * k
end

slab("Belt", function()
	local path = beltPath()
	chunkedPart("Tread", nil, BELT_RUBBER, function(mesh)
		beltStrip(mesh, path, -BELT_HALF_WIDTH, BELT_HALF_WIDTH, DECK, BELT_TOP)
	end, nil, function(px, py)
		return beltTread(px, py)
	end, true)
	chunkedPart("Rails", nil, STEEL, function(mesh)
		beltStrip(mesh, path, -BELT_HALF_WIDTH - 0.6, -BELT_HALF_WIDTH, DECK, BELT_TOP + 0.35)
		beltStrip(mesh, path, BELT_HALF_WIDTH, BELT_HALF_WIDTH + 0.6, DECK, BELT_TOP + 0.35)
	end, nil, 0.55, true)
end, 0, 0)

-- The sorter: the shed the belt runs through where its lap ends and
-- begins. Capsules nobody bought go in the west mouth to be crushed, and
-- new ones come out of the east mouth, dropped in through the hopper on
-- the roof by the magnet crane. Its legs stand clear of the belt, which is
-- still curving as it comes in; strip curtains hang over both mouths. A
-- capsule is 3.4 studs tall at most and rides 0.6 up: the roof clears it by
-- 3 studs, and a player (5.5 tall) walks under too.
local SORTER_X, SORTER_Y = -202, BELT_TURN
local SORTER_HALF_LENGTH, SORTER_HALF_WIDTH = 7, 8
local SORTER_ROOF = DECK + 7
local SORTER_PAINT = { 0.26, 0.4, 0.46 }
slab("Sorter", function()
	part("Legs", nil, SORTER_PAINT, function(mesh)
		for _, x in { -SORTER_HALF_LENGTH, SORTER_HALF_LENGTH } do
			for _, y in { -SORTER_HALF_WIDTH, SORTER_HALF_WIDTH } do
				box(mesh, x, y, DECK, 1, 1, SORTER_ROOF - DECK)
				box(mesh, x, y, DECK, 1.8, 1.8, 0.3)
			end
		end
	end, nil, 0.5)
	part("Roof", nil, SORTER_PAINT, function(mesh)
		box(mesh, 0, 0, SORTER_ROOF, 2 * SORTER_HALF_LENGTH + 1.6, 2 * SORTER_HALF_WIDTH + 1.6, 0.8)
	end, nil, 0.5)
	part("Fascia", nil, MARK, function(mesh)
		for _, y in { -SORTER_HALF_WIDTH, SORTER_HALF_WIDTH } do
			box(mesh, 0, y, SORTER_ROOF - 2.4, 2 * SORTER_HALF_LENGTH - 1, 0.3, 2.4)
		end
	end, nil, 0.4)
	part("FasciaStripes", nil, { 0.1, 0.1, 0.11 }, function(mesh)
		for _, y in { -SORTER_HALF_WIDTH - 0.17, SORTER_HALF_WIDTH + 0.17 } do
			for k = -3, 3 do
				box(mesh, k * 1.8, y, SORTER_ROOF - 2.2, 0.7, 0.05, 2.0)
			end
		end
	end, nil, 0.3)
	part("Curtains", nil, RUBBER_BLACK, function(mesh)
		-- Strips over each mouth, from the roof down to just over the rails.
		for _, x in { -SORTER_HALF_LENGTH, SORTER_HALF_LENGTH } do
			for k = -6, 6 do
				box(mesh, x, k * 1.05, BELT_TOP + 0.6, 0.12, 0.85, SORTER_ROOF - BELT_TOP - 0.6)
			end
		end
	end, nil, RUBBER)
	part("Hopper", nil, DARK_STEEL, function(mesh)
		box(mesh, 1, 0, SORTER_ROOF + 0.8, 5, 5, 1.2)
		box(mesh, 1, 0, SORTER_ROOF + 2.0, 6.4, 6.4, 0.5)
	end, nil, 0.6)
	part("Crane", nil, MARK, function(mesh)
		box(mesh, -5, 4, SORTER_ROOF + 0.8, 1, 1, 7)
		strut(mesh, -5, 4, SORTER_ROOF + 7.4, 3, 0, SORTER_ROOF + 8.6, 0.7)
		strut(mesh, -5, 4, SORTER_ROOF + 4.5, -1, 2, SORTER_ROOF + 8.0, 0.4)
	end, nil, 0.5)
	part("Magnet", nil, DARK_STEEL, function(mesh)
		tube(mesh, { { 2.6, 0.2, SORTER_ROOF + 8.5 }, { 2.4, 0.1, SORTER_ROOF + 5.6 } }, 0.08, 6)
		cylinder(mesh, 2.4, 0.1, SORTER_ROOF + 5.3, 1.3, 0.6, "z", 16)
		cylinder(mesh, 2.4, 0.1, SORTER_ROOF + 5.75, 0.5, 0.4, "z", 10)
	end, nil, 0.55)
	part("Beacons", nil, { 1.0, 0.6, 0.15 }, function(mesh)
		for _, x in { -SORTER_HALF_LENGTH, SORTER_HALF_LENGTH } do
			for _, y in { -SORTER_HALF_WIDTH, SORTER_HALF_WIDTH } do
				sphere(mesh, x, y, SORTER_ROOF + 1.1, 0.4, 0.4, 0.4, 6, 10)
			end
		end
	end, true, 0, nil, 1.5)
end, SORTER_X, SORTER_Y)

-- The kit: one of each model the game places itself (yard things, capsules
-- and junkrots), built here so they upload with the map. They stand in a
-- row far under the hub; tools/studio/PlaceMap.luau takes them out of the
-- map and files them where the game clones them from. Yard things are
-- built to their plot footprint (pads and the mound are modelled 6 studs
-- across and stand 10), and everything at KIT_DENSITY, finer than the
-- map's, as players stand right next to them.
local KIT_DENSITY = 40
local KIT_Z = -150
local KIT_SPACING = 24
local KIT = {
	{ "PadKitchen", buildPadKitchen, 10 / 6 },
	{ "PadGarage", buildPadGarage, 10 / 6 },
	{ "PadGadget", buildPadGadget, 10 / 6 },
	{ "Bay", buildBuildBay, 1 },
	{ "Crate", buildScrapCrate, 1 },
	{ "Press", buildRebirthPress, 1 },
	{ "Mound", buildJunkMound, 10 / 6 },
	{ "CapsuleScrap", buildCapsuleScrap, 1 },
	{ "CapsuleSalvaged", buildCapsuleSalvaged, 1 },
	{ "CapsuleRefurbished", buildCapsuleRefurbished, 1 },
	{ "CapsuleFactory", buildCapsuleFactory, 1 },
	{ "CapsulePrecision", buildCapsulePrecision, 1 },
	{ "CapsulePrototype", buildCapsulePrototype, 1 },
	{ "CapsuleSecret", buildCapsuleSecret, 1 },
	{ "JunkrotCanettoRustini", buildJunkrotCanettoRustini, 1 },
	{ "JunkrotSpoonzoBentolo", buildJunkrotSpoonzoBentolo, 1 },
	{ "JunkrotKettlinaDentata", buildJunkrotKettlinaDentata, 1 },
	{ "JunkrotTyroFlattino", buildJunkrotTyroFlattino, 1 },
	{ "JunkrotBoltoloLonelo", buildJunkrotBoltoloLonelo, 1 },
	{ "JunkrotHubcappaWobbla", buildJunkrotHubcappaWobbla, 1 },
	{ "JunkrotRemotinoMuto", buildJunkrotRemotinoMuto, 1 },
	{ "JunkrotCabloTanglino", buildJunkrotCabloTanglino, 1 },
	{ "JunkrotBulboFulminato", buildJunkrotBulboFulminato, 1 },
	{ "JunkrotCrumboPoppalot", buildJunkrotCrumboPoppalot, 1 },
	{ "JunkrotPannettoPatchato", buildJunkrotPannettoPatchato, 1 },
	{ "JunkrotBlendroCigolante", buildJunkrotBlendroCigolante, 1 },
	{ "JunkrotJackoloCrickato", buildJunkrotJackoloCrickato, 1 },
	{ "JunkrotOilcannaGluglu", buildJunkrotOilcannaGluglu, 1 },
	{ "JunkrotMuffleroTossetto", buildJunkrotMuffleroTossetto, 1 },
	{ "JunkrotRadioloFruscio", buildJunkrotRadioloFruscio, 1 },
	{ "JunkrotFanettoWobblino", buildJunkrotFanettoWobblino, 1 },
	{ "JunkrotClockoTictacco", buildJunkrotClockoTictacco, 1 },
}
useTexelDensity(KIT_DENSITY)
for index, entry in KIT do
	place(`Kit_{entry[1]}`, entry[2], (index - #KIT / 2) * KIT_SPACING, 0, KIT_Z, 0, nil, nil, entry[3])
	useTexelDensity(KIT_DENSITY)
end
useTexelDensity(MAP_DENSITY)
