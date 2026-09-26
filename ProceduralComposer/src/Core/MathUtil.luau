--[[
	MathUtil
	Géométrie : boîtes orientées (OBB), test SAT 3D, polygones convexes 2D,
	projections sur les repères de surface, intersections rayon/boîte.

	Convention des repères de surface (voir GeometryAnalyzer) :
	  Frame.XVector = U (axe principal / longueur)
	  Frame.YVector = N (normale sortante, côté espace libre)
	  Frame.ZVector = V (axe secondaire ; "hauteur" pour un mur)
	Un point 2D (u, v) de la surface vaut Frame * Vector3.new(u, 0, v).
]]

local Config = require(script.Parent.Config)

local MathUtil = {}

local EPS = Config.Precision.NUMERIC_EPSILON
local MIN_LEN = Config.Precision.MIN_VECTOR_LENGTH

MathUtil.UP = Vector3.new(0, 1, 0)

-- Vecteurs ---------------------------------------------------------------------

function MathUtil.safeUnit(v, fallback)
	local m = v.Magnitude
	if m < MIN_LEN or m ~= m then
		return fallback or Vector3.new(0, 0, 0)
	end
	return v / m
end

function MathUtil.projectOnPlane(v, normal)
	return v - normal * v:Dot(normal)
end

function MathUtil.anyPerpendicular(n)
	local ref = if math.abs(n.Y) < 0.9 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	return MathUtil.safeUnit(ref:Cross(n), Vector3.new(1, 0, 0))
end

function MathUtil.absVector(v)
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

function MathUtil.componentMin(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end

function MathUtil.componentMax(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end

function MathUtil.v2(u, v)
	return Vector2.new(u, v)
end

function MathUtil.cross2(a, b)
	return a.X * b.Y - a.Y * b.X
end

-- Rotation autour de Y (convention CFrame.Angles(0, yaw, 0)).
function MathUtil.rotY(yaw)
	return CFrame.Angles(0, yaw, 0)
end

-- Angle de lacet pour que l'avant canonique (-Z) pointe vers la direction 2D (du, dv)
-- exprimée dans le repère (X, Z) courant.
function MathUtil.yawFacing(du, dv)
	if math.abs(du) < EPS and math.abs(dv) < EPS then
		return 0
	end
	return math.atan2(-du, -dv)
end

-- Repère "debout" : Y = haut monde, X = projection horizontale de `forwardHint`.
function MathUtil.uprightRotation(xHint)
	local up = MathUtil.UP
	local x = MathUtil.safeUnit(MathUtil.projectOnPlane(xHint, up), nil)
	if x.Magnitude < 0.5 then
		x = Vector3.new(1, 0, 0)
	end
	return CFrame.fromMatrix(Vector3.new(0, 0, 0), x, up)
end

-- Rotation "lacet seul" d'un CFrame (Y monde conservé) ; sert au repère de référence des assets.
function MathUtil.yawOnly(cf)
	local look = MathUtil.projectOnPlane(cf.LookVector, MathUtil.UP)
	if look.Magnitude < 0.2 then
		-- Pivot fortement basculé : on se rabat sur RightVector puis UpVector.
		local right = MathUtil.projectOnPlane(cf.RightVector, MathUtil.UP)
		if right.Magnitude >= 0.2 then
			right = right.Unit
			return CFrame.fromMatrix(Vector3.new(0, 0, 0), right, MathUtil.UP)
		end
		look = MathUtil.projectOnPlane(cf.UpVector, MathUtil.UP)
		if look.Magnitude < 0.2 then
			return CFrame.new()
		end
	end
	look = look.Unit
	local right = look:Cross(MathUtil.UP)
	return CFrame.fromMatrix(Vector3.new(0, 0, 0), right, MathUtil.UP)
end

-- Boîtes orientées ------------------------------------------------------------------

function MathUtil.obbCorners(cf, size)
	local h = size * 0.5
	local corners = table.create(8)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(corners, cf:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
			end
		end
	end
	return corners
end

-- Boîte englobante alignée monde (min, max) d'une OBB, calcul analytique.
function MathUtil.obbAABB(cf, size)
	local h = size * 0.5
	local rx, ry, rz = cf.XVector, cf.YVector, cf.ZVector
	local ex = math.abs(rx.X) * h.X + math.abs(ry.X) * h.Y + math.abs(rz.X) * h.Z
	local ey = math.abs(rx.Y) * h.X + math.abs(ry.Y) * h.Y + math.abs(rz.Y) * h.Z
	local ez = math.abs(rx.Z) * h.X + math.abs(ry.Z) * h.Y + math.abs(rz.Z) * h.Z
	local e = Vector3.new(ex, ey, ez)
	local p = cf.Position
	return p - e, p + e
end

-- Boîte englobante (dans un repère local `frame`) d'une OBB monde.
function MathUtil.obbBoundsInFrame(frame, cf, size)
	local rel = frame:ToObjectSpace(cf)
	return MathUtil.obbAABB(rel, size)
end

-- Rayon de projection d'une OBB sur un axe.
local function projectRadius(axis, x, y, z, h)
	return math.abs(axis:Dot(x)) * h.X + math.abs(axis:Dot(y)) * h.Y + math.abs(axis:Dot(z)) * h.Z
end

--[[
	Test SAT 3D entre deux OBB.
	`tolerance` > 0 : les boîtes doivent s'interpénétrer de plus de `tolerance`
	pour être en collision (contact exact autorisé).
	`inflate` : distance minimale exigée entre les boîtes (espacement).
]]
function MathUtil.obbIntersects(cfA, sizeA, cfB, sizeB, tolerance, inflate)
	tolerance = tolerance or 0
	inflate = inflate or 0
	local hA = sizeA * 0.5
	local hB = sizeB * 0.5
	local ax, ay, az = cfA.XVector, cfA.YVector, cfA.ZVector
	local bx, by, bz = cfB.XVector, cfB.YVector, cfB.ZVector
	local d = cfB.Position - cfA.Position
	local margin = inflate - tolerance

	local axesA = { ax, ay, az }
	local axesB = { bx, by, bz }

	local function separated(axis)
		local len = axis.Magnitude
		if len < MIN_LEN then
			return false
		end
		local n = axis / len
		local ra = projectRadius(n, ax, ay, az, hA)
		local rb = projectRadius(n, bx, by, bz, hB)
		return math.abs(d:Dot(n)) >= ra + rb + margin
	end

	for i = 1, 3 do
		if separated(axesA[i]) then
			return false
		end
		if separated(axesB[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(axesA[i]:Cross(axesB[j])) then
				return false
			end
		end
	end
	return true
end

-- Intersection rayon / OBB. Renvoie la distance d'entrée (>= 0) ou nil.
function MathUtil.rayOBB(origin, direction, cf, size, maxDistance)
	local h = size * 0.5
	local localOrigin = cf:PointToObjectSpace(origin)
	local localDir = cf:VectorToObjectSpace(direction)
	local tMin = 0
	local tMax = maxDistance or math.huge
	local o = { localOrigin.X, localOrigin.Y, localOrigin.Z }
	local dir = { localDir.X, localDir.Y, localDir.Z }
	local ext = { h.X, h.Y, h.Z }
	for i = 1, 3 do
		if math.abs(dir[i]) < EPS then
			if o[i] < -ext[i] or o[i] > ext[i] then
				return nil
			end
		else
			local t1 = (-ext[i] - o[i]) / dir[i]
			local t2 = (ext[i] - o[i]) / dir[i]
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end
	return tMin
end

-- Transforme les 8 coins de la boîte [bmin, bmax] par la rotation `rot` et renvoie l'AABB.
function MathUtil.rotatedBounds(bmin, bmax, rot)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, x in ipairs({ bmin.X, bmax.X }) do
		for _, y in ipairs({ bmin.Y, bmax.Y }) do
			for _, z in ipairs({ bmin.Z, bmax.Z }) do
				local p = rot:VectorToWorldSpace(Vector3.new(x, y, z))
				lo = MathUtil.componentMin(lo, p)
				hi = MathUtil.componentMax(hi, p)
			end
		end
	end
	return lo, hi
end

-- Polygones 2D (convexes) -------------------------------------------------------------

-- Enveloppe convexe (monotone chain), sens antihoraire.
function MathUtil.convexHull(points)
	local pts = table.clone(points)
	if #pts < 3 then
		return pts
	end
	table.sort(pts, function(a, b)
		if math.abs(a.X - b.X) > EPS then
			return a.X < b.X
		end
		return a.Y < b.Y
	end)
	local function cross(o, a, b)
		return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)
	end
	local lower = {}
	for _, p in ipairs(pts) do
		while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= EPS do
			table.remove(lower)
		end
		table.insert(lower, p)
	end
	local upper = {}
	for i = #pts, 1, -1 do
		local p = pts[i]
		while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= EPS do
			table.remove(upper)
		end
		table.insert(upper, p)
	end
	table.remove(lower)
	table.remove(upper)
	for _, p in ipairs(upper) do
		table.insert(lower, p)
	end
	return lower
end

function MathUtil.rectPolygon(u0, v0, u1, v1)
	return {
		Vector2.new(u0, v0),
		Vector2.new(u1, v0),
		Vector2.new(u1, v1),
		Vector2.new(u0, v1),
	}
end

function MathUtil.polygonBounds(poly)
	local minU, minV = math.huge, math.huge
	local maxU, maxV = -math.huge, -math.huge
	for _, p in ipairs(poly) do
		minU = math.min(minU, p.X)
		minV = math.min(minV, p.Y)
		maxU = math.max(maxU, p.X)
		maxV = math.max(maxV, p.Y)
	end
	return minU, minV, maxU, maxV
end

function MathUtil.polygonArea(poly)
	local a = 0
	for i = 1, #poly do
		local p = poly[i]
		local q = poly[(i % #poly) + 1]
		a += p.X * q.Y - q.X * p.Y
	end
	return math.abs(a) * 0.5
end

function MathUtil.polygonCentroid(poly)
	local sum = Vector2.new(0, 0)
	for _, p in ipairs(poly) do
		sum += p
	end
	return sum / math.max(1, #poly)
end

local function projectPolygon(poly, axis)
	local lo, hi = math.huge, -math.huge
	for _, p in ipairs(poly) do
		local d = p:Dot(axis)
		if d < lo then
			lo = d
		end
		if d > hi then
			hi = d
		end
	end
	return lo, hi
end

-- SAT 2D entre polygones convexes. `tolerance` > 0 autorise le contact.
function MathUtil.polygonsIntersect(a, b, tolerance)
	tolerance = tolerance or 0
	if #a == 0 or #b == 0 then
		return false
	end
	for _, poly in ipairs({ a, b }) do
		local n = #poly
		for i = 1, n do
			local p = poly[i]
			local q = poly[(i % n) + 1]
			local edge = q - p
			local len = edge.Magnitude
			if len > EPS then
				local axis = Vector2.new(-edge.Y, edge.X) / len
				local aLo, aHi = projectPolygon(a, axis)
				local bLo, bHi = projectPolygon(b, axis)
				if aHi - tolerance <= bLo or bHi - tolerance <= aLo then
					return false
				end
			end
		end
	end
	return true
end

-- Tous les sommets de `inner` sont-ils dans le rectangle [u0,u1]×[v0,v1] ?
function MathUtil.polygonInsideRect(poly, u0, v0, u1, v1, tolerance)
	tolerance = tolerance or 0
	for _, p in ipairs(poly) do
		if p.X < u0 - tolerance or p.X > u1 + tolerance or p.Y < v0 - tolerance or p.Y > v1 + tolerance then
			return false
		end
	end
	return true
end

function MathUtil.pointInConvexPolygon(point, poly)
	local n = #poly
	if n < 3 then
		return false
	end
	local sign = 0
	for i = 1, n do
		local p = poly[i]
		local q = poly[(i % n) + 1]
		local c = MathUtil.cross2(q - p, point - p)
		if math.abs(c) > EPS then
			local s = if c > 0 then 1 else -1
			if sign == 0 then
				sign = s
			elseif s ~= sign then
				return false
			end
		end
	end
	return true
end

-- Distance d'un point à un segment 2D ; renvoie aussi le paramètre t du projeté.
function MathUtil.pointSegmentDistance(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < EPS then
		return (p - a).Magnitude, 0
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude, t
end

-- Projection sur une surface ---------------------------------------------------------

-- Coordonnées locales (u, h, v) d'un point monde dans le repère d'une surface.
function MathUtil.toSurfaceLocal(frame, worldPoint)
	return frame:PointToObjectSpace(worldPoint)
end

-- Point monde depuis (u, v) et hauteur h le long de la normale.
function MathUtil.fromSurface(frame, u, v, h)
	return frame:PointToWorldSpace(Vector3.new(u, h or 0, v))
end

-- Projette une OBB sur le plan d'une surface : enveloppe convexe 2D (u, v) + étendue en h.
function MathUtil.projectOBBToSurface(frame, cf, size)
	local pts = {}
	local hMin, hMax = math.huge, -math.huge
	for _, corner in ipairs(MathUtil.obbCorners(cf, size)) do
		local l = frame:PointToObjectSpace(corner)
		table.insert(pts, Vector2.new(l.X, l.Z))
		hMin = math.min(hMin, l.Y)
		hMax = math.max(hMax, l.Y)
	end
	return MathUtil.convexHull(pts), hMin, hMax
end

return MathUtil
