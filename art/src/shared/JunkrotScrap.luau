-- Junkrot Scrap: the scrap-built body kit the remix junkrots share, on top
-- of JunkrotKit (which it brings in). A creature's body is a loft along x
-- (nose +x, z up, y to the sides) skinned in plates of mismatched metal;
-- its fins, wings and such are sheet metal in pieces; it may wear
-- sneakers and googly eyes. Include it first: `-- include: JunkrotScrap`.
--
-- Scrap.loft(spec) -> loft              a tube body lofted along x:
--   spec.stations  { {x, top, bottom, halfWidth}, ... } tail to nose, eased
--                  between, except from spec.straightFrom on (a snout)
--   spec.at        { x, y, z } where the body's axis origin goes (default 0)
--   spec.sides, spec.steps   ring vertices (24) and stations along (80)
--   spec.splits    { { nominal = 90, angle = fn(x) -> deg from top | nil,
--                      tag = "belly" }, ... }: the ring is warped so its
--                  vertex at the nominal angle sits exactly on angle(x),
--                  so a split along it is a true edge loop; faces below the
--                  nominal angle get the tag, where angle(x) is defined
--   loft.mesh      the EditMesh, tags on, in the model's frame
--   loft.skin(x, a)          point of the skin at x and nominal angle a
--                  (0 top, 180 bottom, minus for the -y side)
--   loft.normal(x, a) -> p, n  the point and the outward direction there
--   loft.on(x, a, lift)      the point lifted off the skin
--   loft.station(x) -> top, bottom, halfWidth (from the axis)
-- Scrap.skinPart(loft, { keep = tag } | { drop = { tags } }, thickness)
--                  a copy of the skin with only those faces, solidified
-- Scrap.fin(outline, thick, span)      a fin plate, x along, z out from the
--                  root, thick at the root thinning to tip and edges
-- Scrap.metalFin(outline, thick, span, cuts, place, first)
--                  the same fin as sheet metal in pieces cut at the span
--                  heights in cuts, each piece its own metal, rivets along
--                  the seams; place(m) positions a piece; returns the dark
--                  core to emit; pieces and rivets come out with the panel
--                  parts (Scrap.panelParts)
-- Scrap.panels(loft, spec) -> panels    plates tiling the skin:
--   spec.bands     { {a0, a1, {x cuts...}}, ... } nominal angle bands with
--                  their own cuts along x
--   spec.open(band, x0, x1, side) -> bool   leave this cell bare
--   spec.metal(band, seg, cell, side, x0, x1) -> {name, colour} or nil for
--                  the palette's pick; spec.paleFrom: bands from this angle
--                  take Scrap.BELLY_METALS, others Scrap.BACK_METALS
--   spec.splits    { [n] = share }: cells whose running count hits n are
--                  split round the section at that share
--   spec.gap (0.012), spec.nudge (1.5 deg), spec.lift (0.035)
-- Scrap.panelParts(loft, panels, spec)  declares the parts: Panels<Metal>
--                  (with any metal fin pieces), and the joins, by turns
--                  rivets, bolts, welds, tape, stitches and clips;
--                  spec.rivetsUpTo: no rivets or bolts beyond this x
-- Scrap.sneakers(collars, spec)        declares sneaker parts standing on
--                  the ground, toe +x, each collar's centre at {x, y}
--   Scrap.SHOE, Scrap.SOLE   the shoe's size and its sole's height
--   Scrap.collarCrossing(a, b, shoe)   where the line a->b crosses collar
--                  height: the collar centre for a fin running down a->b
-- Scrap.googlyEyes(eyes)   declares Eyes and Pupils: each { p, n }, a
--                  point and outward direction (from loft.normal)
-- Scrap.BACK_METALS, Scrap.BELLY_METALS   { {name, colour}, ... }
-- include: JunkrotKit
Scrap = {}

Scrap.BACK_METALS = {
	{ "BLUEGREY", { 0.4, 0.47, 0.52 } },
	{ "OLIVE", { 0.42, 0.45, 0.36 } },
	{ "RUST", { 0.55, 0.35, 0.16 } },
	{ "GUNMETAL", { 0.3, 0.33, 0.37 } },
	{ "PAINTED", { 0.36, 0.5, 0.62 } },
	{ "BRASS", { 0.7, 0.58, 0.3 } },
}
Scrap.BELLY_METALS = {
	{ "TIN", { 0.72, 0.7, 0.66 } },
	{ "GALVANISED", { 0.6, 0.63, 0.62 } },
	{ "ENAMEL", { 0.86, 0.86, 0.82 } },
	{ "ALUMINIUM", { 0.78, 0.8, 0.8 } },
	{ "TIN", { 0.72, 0.7, 0.66 } },
	{ "ENAMEL", { 0.86, 0.86, 0.82 } },
}
local DARK = { 0.18, 0.19, 0.21 }

local function smooth(t)
	return t * t * (3 - 2 * t)
end

-- Reads a list of { x, values... } at x, eased between entries.
local function tableAt(list, x, straightFrom)
	for k = 1, #list - 1 do
		local a, b = list[k], list[k + 1]
		if x <= b[1] then
			local t = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			if not straightFrom or a[1] < straightFrom then
				t = smooth(t)
			end
			local out = {}
			for i = 2, #a do
				out[i - 1] = a[i] + (b[i] - a[i]) * t
			end
			return table.unpack(out)
		end
	end
	local last = list[#list]
	return table.unpack(last, 2)
end
Scrap.tableAt = tableAt

function Scrap.loft(spec)
	local at = spec.at or { 0, 0, 0 }
	local sides, steps = spec.sides or 24, spec.steps or 80
	local splits = spec.splits or {}
	local x0, x1 = spec.stations[1][1], spec.stations[#spec.stations][1]
	local loft = {}

	function loft.station(x)
		return tableAt(spec.stations, x, spec.straightFrom)
	end
	-- The warp: nominal angle to actual, by the knots the splits set at x;
	-- a split with no angle at this x stays where the ring's even spacing
	-- would put it.
	local function actualAngle(x, n)
		local knots = { { 0, 0 } }
		for _, split in splits do
			table.insert(knots, { split.nominal, split.angle(x) })
		end
		table.insert(knots, { 180, 180 })
		table.sort(knots, function(a, b)
			return a[1] < b[1]
		end)
		for k = 2, #knots - 1 do
			if knots[k][2] == nil then
				local before, after = k - 1, k + 1
				while knots[after][2] == nil do
					after += 1
				end
				local t = (knots[k][1] - knots[before][1]) / (knots[after][1] - knots[before][1])
				knots[k][2] = knots[before][2] + (knots[after][2] - knots[before][2]) * t
			end
		end
		for k = 1, #knots - 1 do
			local a, b = knots[k], knots[k + 1]
			if n <= b[1] then
				local t = if b[1] > a[1] then (n - a[1]) / (b[1] - a[1]) else 0
				return a[2] + (b[2] - a[2]) * t
			end
		end
		return 180
	end
	function loft.skin(x, a)
		local top, bottom, w = loft.station(x)
		local side = if a < 0 then -1 else 1
		local r = math.rad(actualAngle(x, math.abs(a)))
		local c = math.cos(r)
		local mid = (top + bottom) / 2
		return { at[1] + x, at[2] + side * math.sin(r) * w, at[3] + mid + c * (if c > 0 then top - mid else mid - bottom) }
	end
	function loft.normal(x, a)
		local p = loft.skin(x, a)
		local px, pa = loft.skin(x + 0.01, a), loft.skin(x, a + 0.5)
		local u = { px[1] - p[1], px[2] - p[2], px[3] - p[3] }
		local v = { pa[1] - p[1], pa[2] - p[2], pa[3] - p[3] }
		local n = { u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1] }
		local len = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
		if len < 1e-9 then
			return p, { 0, 0, 1 }
		end
		n = { n[1] / len, n[2] / len, n[3] / len }
		local top, bottom = loft.station(x)
		local away = { 0, p[2] - at[2], p[3] - at[3] - (top + bottom) / 2 }
		if n[2] * away[2] + n[3] * away[3] < 0 then
			n = { -n[1], -n[2], -n[3] }
		end
		return p, n
	end
	function loft.on(x, a, lift)
		local p, n = loft.normal(x, a)
		return { p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift }
	end

	local ring, path = {}, {}
	for k = 0, sides - 1 do
		local r = math.rad(k * 360 / sides)
		table.insert(ring, { -math.sin(r), math.cos(r) })
	end
	for k = 0, steps do
		table.insert(path, { x0 + (x1 - x0) * k / steps, 0, 0 })
	end
	local m = EditMesh.sweep(ring, path)
	local half = (x1 - x0) / steps / 2
	for _, split in splits do
		if split.tag then
			m:tagging(split.tag, function()
				m:select("face", "where", function(p)
					local n = math.deg(math.atan2(math.abs(p[2]), p[3]))
					return n > split.nominal and p[1] > x0 + half / 2 and p[1] < x1 - half / 2 and split.angle(p[1]) ~= nil and split.angle(p[1] - half) ~= nil and split.angle(p[1] + half) ~= nil
				end):tag(split.tag)
			end)
		end
	end
	m:transform(function(p)
		return loft.skin(p[1], math.deg(math.atan2(p[2], p[3])))
	end)
	loft.mesh = m
	loft.x0, loft.x1, loft.at = x0, x1, at
	return loft
end

function Scrap.skinPart(loft, which, thickness)
	local m = loft.mesh:copy()
	local keep
	if which.keep then
		keep = m:select("face", "tag", which.keep)
	else
		keep = m:select("face", "all")
	end
	for _, tag in which.drop or {} do
		keep = keep:minus(m:select("face", "tag", tag))
	end
	for _, id in m:select("face", "all"):minus(keep):list() do
		m:removeFace(id)
	end
	m:solidify(thickness or 0.03)
	return m
end

function Scrap.fin(outline, thick, span)
	local m = Kit.plate(outline, thick)
	m:translate(0, -thick / 2, 0)
	m:transform(function(p)
		local out = math.clamp(p[3] / span, 0, 1)
		return { p[1], p[2] * math.max(0.12, 1 - 0.85 * out), p[3] }
	end)
	return m
end

-- Clips an x-z outline to lo <= z <= hi (Sutherland-Hodgman).
local function clipBand(outline, lo, hi)
	local function clip(poly, keep, cross)
		local out = {}
		for i, a in poly do
			local b = poly[i % #poly + 1]
			local ka, kb = keep(a), keep(b)
			if ka then
				table.insert(out, a)
			end
			if ka ~= kb then
				table.insert(out, cross(a, b))
			end
		end
		return out
	end
	local function at(a, b, z)
		local t = (z - a[2]) / (b[2] - a[2])
		return { a[1] + (b[1] - a[1]) * t, z }
	end
	local poly = clip(outline, function(q)
		return q[2] >= lo
	end, function(a, b)
		return at(a, b, lo)
	end)
	return clip(poly, function(q)
		return q[2] <= hi
	end, function(a, b)
		return at(a, b, hi)
	end)
end
Scrap.clipBand = clipBand

local finPieces, finRivets = {}, {}
function Scrap.metalFin(outline, thick, span, cuts, place, first)
	local edges = { -10 }
	for _, c in cuts do
		table.insert(edges, c)
	end
	table.insert(edges, 10)
	for k = 1, #edges - 1 do
		local lo = edges[k] + (if k > 1 then 0.012 else 0)
		local hi = edges[k + 1] - (if k < #edges - 1 then 0.012 else 0)
		local piece = clipBand(outline, lo, hi)
		if #piece >= 3 then
			local metal = Scrap.BACK_METALS[(first + k - 1) % #Scrap.BACK_METALS + 1]
			table.insert(finPieces, { metal = metal[1], mesh = place(Scrap.fin(piece, thick, span)) })
		end
	end
	for _, c in cuts do
		local band = clipBand(outline, c - 0.001, c + 0.001)
		local xs = {}
		for _, q in band do
			table.insert(xs, q[1])
		end
		table.sort(xs)
		if #xs >= 2 then
			local xa, xb = xs[1], xs[#xs]
			local out = math.clamp(c / span, 0, 1)
			local half = thick / 2 * math.max(0.12, 1 - 0.85 * out)
			for _, t in { 0.2, 0.5, 0.8 } do
				for _, side in { -1, 1 } do
					for _, dz in { -0.045, 0.045 } do
						local r = EditMesh.sphere(0.02, 6)
						r:translate(xa + (xb - xa) * t, side * (half + 0.004), c + dz)
						table.insert(finRivets, place(r))
					end
				end
			end
		end
	end
	return place(Scrap.fin(outline, thick * 0.8, span))
end

function Scrap.panels(loft, spec)
	local gap, nudgeStep = spec.gap or 0.012, spec.nudge or 1.5
	local panels = {}
	for b, band in spec.bands do
		for seg = 1, #band[3] - 1 do
			local x0, x1 = band[3][seg], band[3][seg + 1]
			for _, side in { -1, 1 } do
				if spec.open and spec.open(b, x0, x1, side) then
					continue
				end
				local pale = spec.paleFrom ~= nil and band[1] >= spec.paleFrom
				local palette = if pale then Scrap.BELLY_METALS else Scrap.BACK_METALS
				local count = #panels
				local nudge = ((count * 7) % 5 - 2) * nudgeStep
				local a0, a1 = band[1] + nudge, band[2] + nudge
				local cells = { { a0, a1 } }
				local split = spec.splits and spec.splits[count % 41 + 1]
				if split and not (spec.noSplitFrom and x0 >= spec.noSplitFrom) then
					local at = a0 + (a1 - a0) * split
					cells = { { a0, at }, { at, a1 } }
				end
				for c, cell in cells do
					local pick = spec.metal and spec.metal(b, seg, c, side, x0, x1, pale)
					pick = pick or palette[(b * 3 + seg * 5 + c * 2 + (if side < 0 then 2 else 0)) % #palette + 1]
					table.insert(panels, { x0 + gap, x1 - gap, side * (math.max(cell[1], 0.5) + 1.2), side * (math.min(cell[2], 179.5) - 1.2), pick[1], pick[2] })
				end
			end
		end
	end
	return panels
end

local function panelMesh(loft, q, lift)
	local m = EditMesh.new()
	local ALONG, ROUND = 8, 6
	local top, bottom = {}, {}
	for i = 0, ALONG do
		top[i], bottom[i] = {}, {}
		for j = 0, ROUND do
			local x, a = q[1] + (q[2] - q[1]) * i / ALONG, q[3] + (q[4] - q[3]) * j / ROUND
			local o, u = loft.on(x, a, lift), loft.on(x, a, -0.01)
			top[i][j] = m:addVertex(o[1], o[2], o[3])
			bottom[i][j] = m:addVertex(u[1], u[2], u[3])
		end
	end
	for i = 0, ALONG - 1 do
		for j = 0, ROUND - 1 do
			m:addFace({ top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1] })
			m:addFace({ bottom[i][j], bottom[i][j + 1], bottom[i + 1][j + 1], bottom[i + 1][j] })
		end
	end
	for k = 0, ALONG - 1 do
		m:addFace({ top[k][0], bottom[k][0], bottom[k + 1][0], top[k + 1][0] })
		m:addFace({ top[k + 1][ROUND], bottom[k + 1][ROUND], bottom[k][ROUND], top[k][ROUND] })
	end
	for k = 0, ROUND - 1 do
		m:addFace({ top[0][k + 1], bottom[0][k + 1], bottom[0][k], top[0][k] })
		m:addFace({ top[ALONG][k], bottom[ALONG][k], bottom[ALONG][k + 1], top[ALONG][k + 1] })
	end
	local mx, ma = (q[1] + q[2]) / 2, (q[3] + q[4]) / 2
	local o, c = loft.on(mx, ma, lift + 0.07), loft.on(mx, ma, lift)
	local n = m:faceNormal(m:select("face", "all"):list()[1])
	if n[1] * (o[1] - c[1]) + n[2] * (o[2] - c[2]) + n[3] * (o[3] - c[3]) < 0 then
		m:flip()
	end
	return m
end

local JOINS = { "rivets", "bolts", "weld", "tape", "stitches", "clips", "rivets", "weld", "bolts", "stitches", "tape", "clips" }

-- A small piece stood along a normal: turned from z up to n and set at p.
local function stood(piece, p, n, sink)
	local tilt = math.deg(math.acos(math.clamp(n[3], -1, 1)))
	local spin = math.deg(math.atan2(n[2], n[1]))
	Kit.turn(piece, "y", tilt)
	Kit.turn(piece, "z", spin)
	piece:translate(p[1] - n[1] * (sink or 0), p[2] - n[2] * (sink or 0), p[3] - n[3] * (sink or 0))
	return piece
end

function Scrap.panelParts(loft, panels, spec)
	spec = spec or {}
	local lift = spec.lift or 0.035
	local upTo = spec.rivetsUpTo or math.huge
	local metals = {}
	for _, q in panels do
		metals[q[5]] = q[6]
	end
	for _, list in { Scrap.BACK_METALS, Scrap.BELLY_METALS } do
		for _, m in list do
			metals[m[1]] = metals[m[1]] or m[2]
		end
	end
	local names = {}
	for metal in metals do
		table.insert(names, metal)
	end
	table.sort(names)
	for _, metal in names do
		local colour = metals[metal]
		part("Panels" .. metal, nil, colour, function(mesh)
			for _, q in panels do
				if q[5] == metal then
					panelMesh(loft, q, lift):emit(mesh)
				end
			end
			for _, piece in finPieces do
				if piece.metal == metal then
					piece.mesh:emit(mesh)
				end
			end
		end, 40, if metal == "RUST" then 0.7 elseif metal == "BRASS" or metal == "ENAMEL" then 0.3 else 0.5)
	end

	local function joinOf(index)
		return JOINS[(index * 5) % #JOINS + 1]
	end
	local function edgePoint(q, edge, t, off)
		if edge == "x0" or edge == "x1" then
			return loft.on(if edge == "x0" then q[1] else q[2], q[3] + (q[4] - q[3]) * t, off)
		end
		return loft.on(q[1] + (q[2] - q[1]) * t, if edge == "a0" then q[3] else q[4], off)
	end
	local function edgeNormal(q, edge, t)
		local _, n = loft.normal(if edge == "x0" then q[1] elseif edge == "x1" then q[2] else q[1] + (q[2] - q[1]) * t, if edge == "a0" then q[3] elseif edge == "a1" then q[4] else q[3] + (q[4] - q[3]) * t)
		return n
	end
	part("Rivets", nil, DARK_STEEL, function(mesh)
		for _, r in finRivets do
			r:emit(mesh)
		end
		for index, q in panels do
			local join = joinOf(index)
			if join == "rivets" or join == "bolts" then
				local dx, da = (q[2] - q[1]) * 0.1, (q[4] - q[3]) * 0.15
				for _, x in { q[1] + dx, q[2] - dx } do
					for _, a in { q[3] + da, q[4] - da } do
						if x <= upTo then
							local p, n = loft.normal(x, a)
							local o = { p[1] + n[1] * lift, p[2] + n[2] * lift, p[3] + n[3] * lift }
							if join == "rivets" then
								local rivet = EditMesh.sphere(0.026, 6)
								rivet:translate(o[1], o[2], o[3])
								rivet:emit(mesh)
							else
								local head = EditMesh.cylinder(0.022, 0.03, 6, 1)
								head:translate(0, 0, 0.012)
								stood(head, o, n, 0.012):emit(mesh)
								stood(EditMesh.cylinder(0.036, 0.01, 10, 1), o, n, 0.012):emit(mesh)
							end
						end
					end
				end
			end
		end
	end, true, 0.4)
	part("Welds", nil, { 0.32, 0.3, 0.28 }, function(mesh)
		local ring = {}
		for k = 0, 7 do
			local r = math.rad(k * 45)
			table.insert(ring, { math.cos(r) * 0.03, math.sin(r) * 0.022 })
		end
		for index, q in panels do
			if joinOf(index) == "weld" and q[1] < upTo then
				local path = {}
				for k = 0, 10 do
					table.insert(path, edgePoint(q, "x0", k / 10, lift - 0.005))
				end
				EditMesh.sweep(ring, path, { scale = function(t)
					return 0.8 + 0.35 * math.abs(math.sin(t * 31))
				end }):emit(mesh)
			end
		end
	end, true, 0.6)
	part("Tape", nil, { 0.58, 0.58, 0.56 }, function(mesh)
		for index, q in panels do
			if joinOf(index) == "tape" and q[2] < upTo then
				local path = {}
				for k = 0, 6 do
					table.insert(path, edgePoint(q, "x1", 0.3 + 0.4 * k / 6, lift + 0.003))
				end
				EditMesh.sweep({ { -0.045, -0.006 }, { 0.045, -0.006 }, { 0.045, 0.006 }, { -0.045, 0.006 } }, path):emit(mesh)
			end
		end
	end, 40, 0.3)
	part("Stitches", nil, { 0.55, 0.55, 0.52 }, function(mesh)
		for index, q in panels do
			if joinOf(index) == "stitches" and q[2] < upTo then
				for _, t in { 0.25, 0.5, 0.75 } do
					local o = edgePoint(q, "a0", t, lift + 0.001)
					local n = edgeNormal(q, "a0", t)
					local across, ref = edgePoint(q, "x0", 0.02, lift), edgePoint(q, "x0", 0.0, lift)
					local d = { across[1] - ref[1], across[2] - ref[2], across[3] - ref[3] }
					local len = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
					if len > 1e-6 then
						d = { d[1] / len, d[2] / len, d[3] / len }
						Kit.tube(Kit.curve({
							{ o[1] - d[1] * 0.05 - n[1] * 0.02, o[2] - d[2] * 0.05 - n[2] * 0.02, o[3] - d[3] * 0.05 - n[3] * 0.02 },
							{ o[1], o[2], o[3] },
							{ o[1] + d[1] * 0.05 - n[1] * 0.02, o[2] + d[2] * 0.05 - n[2] * 0.02, o[3] + d[3] * 0.05 - n[3] * 0.02 },
						}, 3), 0.009, 5):emit(mesh)
					end
				end
			end
		end
	end, true, 0.3)
	part("Clips", nil, { 0.5, 0.52, 0.5 }, function(mesh)
		for index, q in panels do
			if joinOf(index) == "clips" and q[2] < upTo then
				for _, t in { 0.3, 0.7 } do
					local o = edgePoint(q, "a1", t, lift + 0.005)
					stood(Kit.block(0.07, 0.09, 0.02, 0.005), o, edgeNormal(q, "a1", t)):emit(mesh)
				end
			end
		end
	end, 40, 0.4)
end

-- Sneakers.
Scrap.SHOE = { long = 1.05, wide = 0.56, high = 0.38 }
Scrap.SOLE = 0.14
local FOOTPRINT = { { 0, 0.1 }, { 0.06, 0.78 }, { 0.3, 0.8 }, { 0.62, 0.95 }, { 0.84, 0.86 }, { 0.96, 0.45 }, { 1, 0.08 } }
local UPPER = { { 0, 0.45 }, { 0.08, 1.0 }, { 0.28, 1.0 }, { 0.45, 0.82 }, { 0.7, 0.6 }, { 0.9, 0.4 }, { 0.97, 0.22 }, { 1, 0.08 } }
local function spring(t)
	return 0.05 * math.clamp((t - 0.6) / 0.4, 0, 1) ^ 2
end
function Scrap.collarCrossing(a, b, shoe)
	shoe = shoe or Scrap.SHOE
	local collarZ = Scrap.SOLE - 0.03 + shoe.high
	local t = (collarZ - a[3]) / (b[3] - a[3])
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t }
end
function Scrap.sneakers(collars, spec)
	spec = spec or {}
	local SHOE, SOLE = spec.shoe or Scrap.SHOE, Scrap.SOLE
	local blue = spec.colour or { 0.14, 0.46, 0.92 }
	local dark = spec.dark or { 0.1, 0.36, 0.78 }
	-- The shoe's middle from its collar centre.
	local function middle(c)
		return { c[1] + SHOE.long * 0.28, c[2] }
	end
	local function shoeLoft(stations, height, widen, z0, t0, t1)
		t0, t1 = t0 or 0, t1 or 1
		local ring, path = {}, {}
		for k = 0, 19 do
			local r = math.rad(k * 18)
			local c, sn = math.cos(r), math.sin(r)
			local push = 1 + 0.18 * (math.abs(c * sn) * 2)
			table.insert(ring, { -sn * push, c * push })
		end
		for k = 0, stations do
			table.insert(path, { -SHOE.long / 2 + SHOE.long * (t0 + (t1 - t0) * k / stations), 0, 0 })
		end
		local m = EditMesh.sweep(ring, path)
		m:transform(function(p)
			local t = (p[1] + SHOE.long / 2) / SHOE.long
			local w = tableAt(FOOTPRINT, t) * SHOE.wide / 2 + widen
			return { p[1], p[2] * w, z0 + spring(t) + (p[3] + 1) / 2 * height(t) }
		end)
		return m
	end
	local function instep(x)
		local t = (x + SHOE.long / 2) / SHOE.long
		return SOLE - 0.03 + spring(t) + tableAt(UPPER, t) * SHOE.high
	end
	part("Sneakers", nil, blue, function(mesh)
		for _, c in collars do
			local at = middle(c)
			local upper = shoeLoft(20, function(t)
				return tableAt(UPPER, t) * SHOE.high
			end, 0, SOLE - 0.03)
			local collar = upper:select("face", "facing", { 0, 0, 1 }, 35):filter(function(p)
				local t = (p[1] + SHOE.long / 2) / SHOE.long
				return t > 0.07 and t < 0.37 and math.abs(p[2]) < SHOE.wide * 0.3
			end)
			if collar:count() > 0 then
				upper:extrude(upper:inset(collar, 0.02, 0), -0.14)
			end
			upper:translate(at[1], at[2], 0)
			upper:emit(mesh)
			local tongue = Kit.block(0.16, 0.2, 0.22, 0.05)
			Kit.turn(tongue, "y", 30)
			tongue:translate(at[1] - 0.12, at[2], SOLE + SHOE.high * 0.92)
			tongue:emit(mesh)
		end
	end, true, RUBBER)
	part("HeelCounters", nil, dark, function(mesh)
		for _, c in collars do
			local at = middle(c)
			for _, band in { { 0, 0.24, 0.62 }, { 0.78, 1, 0.9 } } do
				local m = shoeLoft(8, function(t)
					return tableAt(UPPER, t) * SHOE.high * band[3]
				end, 0.012, SOLE - 0.02, band[1], band[2])
				m:translate(at[1], at[2], 0)
				m:emit(mesh)
			end
		end
	end, true, RUBBER)
	part("Soles", nil, { 0.95, 0.95, 0.93 }, function(mesh)
		for _, c in collars do
			local at = middle(c)
			local m = shoeLoft(20, function()
				return 0.1
			end, 0.03, 0.04)
			m:translate(at[1], at[2], 0)
			m:emit(mesh)
		end
	end, true, RUBBER)
	part("Outsoles", nil, { 0.2, 0.2, 0.22 }, function(mesh)
		for _, c in collars do
			local at = middle(c)
			local m = shoeLoft(20, function()
				return 0.045
			end, 0.02, 0)
			m:translate(at[1], at[2], 0)
			m:emit(mesh)
		end
	end, true, RUBBER)
	part("ShoeTrim", nil, { 0.96, 0.96, 0.94 }, function(mesh)
		for _, c in collars do
			local at = middle(c)
			local rows = { -0.12, 0.0, 0.12, 0.24 }
			for k = 1, #rows - 1 do
				for _, side in { -1, 1 } do
					Kit.tube({ { at[1] + rows[k], at[2] + side * 0.1, instep(rows[k]) + 0.01 }, { at[1] + rows[k + 1], at[2] - side * 0.1, instep(rows[k + 1]) + 0.01 } }, 0.016, 6):emit(mesh)
				end
			end
			for _, side in { -1, 1 } do
				Kit.tube(Kit.curve({ { at[1] - 0.4, at[2] + side * 0.23, 0.3 }, { at[1] - 0.1, at[2] + side * 0.26, 0.2 }, { at[1] + 0.22, at[2] + side * 0.26, 0.17 }, { at[1] + 0.4, at[2] + side * 0.2, 0.22 } }, 4), 0.02, 6):emit(mesh)
			end
			local rim = EditMesh.torus(0.12, 0.03, 16, 6)
			Kit.size(rim, { 1.5, 1, 1 })
			rim:translate(at[1] - SHOE.long * 0.28, at[2], SOLE - 0.03 + SHOE.high)
			rim:emit(mesh)
			Kit.tube(Kit.curve({ { at[1] - 0.49, at[2], SOLE + 0.18 }, { at[1] - 0.55, at[2], SOLE + 0.28 }, { at[1] - 0.47, at[2], SOLE + 0.36 } }, 3), 0.02, 6):emit(mesh)
		end
	end, 50, 0)
	part("Eyelets", nil, { 0.1, 0.1, 0.12 }, function(mesh)
		for _, c in collars do
			local at = middle(c)
			for _, x in { -0.12, 0.0, 0.12, 0.24 } do
				for _, side in { -1, 1 } do
					local eye = EditMesh.cylinder(0.024, 0.012, 8, 1)
					eye:translate(at[1] + x, at[2] + side * 0.1, instep(x) + 0.005)
					eye:emit(mesh)
				end
			end
		end
	end, 50, 0)
end

function Scrap.googlyEyes(eyes, size)
	size = size or 0.13
	part("Eyes", nil, { 0.96, 0.96, 0.94 }, function(mesh)
		for _, e in eyes do
			local p, n = e[1], e[2]
			local dome = EditMesh.sphere(size, 12)
			stood(dome, { p[1] + n[1] * 0.02, p[2] + n[2] * 0.02, p[3] + n[3] * 0.02 }, n)
			-- Flattened along its normal.
			local c = { p[1] + n[1] * 0.02, p[2] + n[2] * 0.02, p[3] + n[3] * 0.02 }
			dome:transform(function(q)
				local d = (q[1] - c[1]) * n[1] + (q[2] - c[2]) * n[2] + (q[3] - c[3]) * n[3]
				return { q[1] - n[1] * d * 0.5, q[2] - n[2] * d * 0.5, q[3] - n[3] * d * 0.5 }
			end)
			dome:emit(mesh)
		end
	end, true, 0)
	part("Pupils", nil, { 0.04, 0.04, 0.05 }, function(mesh)
		for _, e in eyes do
			local p, n = e[1], e[2]
			local out = size * 0.5 + 0.02 + 0.01
			-- Slid down and forward in the dome.
			local c = { p[1] + n[1] * out + 0.02 * size / 0.13, p[2] + n[2] * out, p[3] + n[3] * out - 0.035 * size / 0.13 }
			local pupil = EditMesh.sphere(size * 0.42, 8)
			pupil:transform(function(q)
				local d = q[1] * n[1] + q[2] * n[2] + q[3] * n[3]
				return { q[1] - n[1] * d * 0.6 + c[1], q[2] - n[2] * d * 0.6 + c[2], q[3] - n[3] * d * 0.6 + c[3] }
			end)
			pupil:emit(mesh)
		end
	end, true, 0)
end
