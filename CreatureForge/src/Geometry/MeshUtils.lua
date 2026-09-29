-- MeshUtils : primitives de construction (anneaux, loft, sweep, plaques extrudées).
-- Toutes les formes de ShapeLibrary sont bâties sur ces 3 briques.

local MeshBuilder = require(script.Parent.MeshBuilder)

local MeshUtils = {}

-- Profil d'anneau unitaire (superellipse). squareness 0 = cercle, 1 = carré arrondi.
function MeshUtils.ringProfile(sides: number, squareness: number?, phase: number?)
	local sq = squareness or 0
	local n = 2 + sq * 6
	local e = 2 / n
	local ph = phase or 0
	local pts = table.create(sides)
	for i = 0, sides - 1 do
		local a = ph + (i / sides) * math.pi * 2
		local c, s = math.cos(a), math.sin(a)
		local x = math.sign(c) * math.abs(c) ^ e
		local y = math.sign(s) * math.abs(s) ^ e
		pts[i + 1] = Vector2.new(x, y)
	end
	return pts
end

local function centroid(ring)
	local sum = Vector3.zero
	for _, p in ring do
		sum += p
	end
	return sum / #ring
end

-- Relie des anneaux (même nombre de points) et ferme les extrémités.
-- startTip / endTip : pointe optionnelle (sinon capuchon plat au centroïde).
function MeshUtils.loft(target, rings, startTip: Vector3?, endTip: Vector3?)
	local b = MeshBuilder.new()
	local count = #rings[1]
	local ids = {}
	for r, ring in rings do
		local row = table.create(count)
		for i, p in ring do
			row[i] = b:addVertex(p)
		end
		ids[r] = row
	end
	for r = 1, #rings - 1 do
		local a, c = ids[r], ids[r + 1]
		for i = 1, count do
			local j = i % count + 1
			b:addQuad(a[i], a[j], c[j], c[i])
		end
	end
	local first, last = ids[1], ids[#rings]
	local s = b:addVertex(startTip or centroid(rings[1]))
	for i = 1, count do
		local j = i % count + 1
		b:addTri(s, first[j], first[i])
	end
	local e = b:addVertex(endTip or centroid(rings[#rings]))
	for i = 1, count do
		local j = i % count + 1
		b:addTri(e, last[i], last[j])
	end
	b:fixWinding()
	target:merge(b)
	return target
end

-- Balayage d'un profil le long d'une colonne (spine) de points.
-- radii[k] = { rx, rz, ox?, oz? } (rayons + décalage du centre dans le repère local).
-- Un rayon nul au premier / dernier point crée une pointe.
-- opts : sides, squareness, phase, hint (Vector3 donnant l'axe « rx »).
function MeshUtils.sweep(target, spine, radii, opts)
	opts = opts or {}
	local sides = opts.sides or 8
	local profile = MeshUtils.ringProfile(sides, opts.squareness, opts.phase)
	local n = #spine

	local tangents = table.create(n)
	for k = 1, n do
		local a = spine[math.max(k - 1, 1)]
		local c = spine[math.min(k + 1, n)]
		local t = c - a
		if t.Magnitude < 1e-6 then
			t = Vector3.new(0, 1, 0)
		end
		tangents[k] = t.Unit
	end

	local hint = opts.hint or Vector3.new(1, 0, 0)
	local nrm = hint - tangents[1] * hint:Dot(tangents[1])
	if nrm.Magnitude < 1e-4 then
		local alt = Vector3.new(0, 0, 1)
		nrm = alt - tangents[1] * alt:Dot(tangents[1])
	end
	nrm = nrm.Unit

	local rings = {}
	local startTip, endTip = nil, nil
	for k = 1, n do
		local t = tangents[k]
		local projected = nrm - t * nrm:Dot(t)
		if projected.Magnitude > 1e-5 then
			nrm = projected.Unit
		end
		local bin = t:Cross(nrm)
		local r = radii[k]
		local rx, rz = r[1], r[2] or r[1]
		local ox, oz = r[3] or 0, r[4] or 0
		local center = spine[k] + nrm * ox + bin * oz
		if rx <= 1e-4 and rz <= 1e-4 and (k == 1 or k == n) then
			if k == 1 then
				startTip = center
			else
				endTip = center
			end
		else
			local ring = table.create(sides)
			for i, p in profile do
				ring[i] = center + nrm * (p.X * math.max(rx, 1e-3)) + bin * (p.Y * math.max(rz, 1e-3))
			end
			rings[#rings + 1] = ring
		end
	end
	if #rings == 0 then
		return target
	end
	return MeshUtils.loft(target, rings, startTip, endTip)
end

-- Plaque extrudée à partir d'un contour 2D « étoilé » autour de `center2`.
-- frame = { origin, u, v, n } : le contour vit dans le plan (u, v), épaisseur selon n.
-- L'épaisseur varie du centre (thickCenter) au bord (thickEdge) : look stylisé.
function MeshUtils.plate(target, outline, center2: Vector2, thickCenter: number, thickEdge: number, frame)
	local b = MeshBuilder.new()
	local o, u, v, n = frame.origin, frame.u, frame.v, frame.n
	local function at(p: Vector2, h: number)
		return o + u * p.X + v * p.Y + n * h
	end
	local ct = b:addVertex(at(center2, thickCenter * 0.5))
	local cb = b:addVertex(at(center2, -thickCenter * 0.5))
	local top, bot = {}, {}
	for i, p in outline do
		top[i] = b:addVertex(at(p, thickEdge * 0.5))
		bot[i] = b:addVertex(at(p, -thickEdge * 0.5))
	end
	local count = #outline
	for i = 1, count do
		local j = i % count + 1
		b:addTri(ct, top[i], top[j])
		b:addTri(cb, bot[j], bot[i])
		b:addQuad(top[i], bot[i], bot[j], top[j])
	end
	b:fixWinding()
	target:merge(b)
	return target
end

-- Courbe de Bézier quadratique échantillonnée (n+1 points).
function MeshUtils.bezier(p0: Vector3, p1: Vector3, p2: Vector3, n: number)
	local pts = table.create(n + 1)
	for i = 0, n do
		local t = i / n
		local a = p0:Lerp(p1, t)
		local c = p1:Lerp(p2, t)
		pts[i + 1] = a:Lerp(c, t)
	end
	return pts
end

-- Interpolation linéaire par morceaux d'un profil { {t, value}, ... }.
function MeshUtils.sampleProfile(profile, t: number)
	if t <= profile[1][1] then
		return profile[1][2]
	end
	for i = 1, #profile - 1 do
		local a, b = profile[i], profile[i + 1]
		if t <= b[1] then
			local k = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			return a[2] + (b[2] - a[2]) * k
		end
	end
	return profile[#profile][2]
end

return MeshUtils
