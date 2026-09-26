--[[
	GeometryAnalyzer
	Analyse la géométrie cible à partir de l'orientation réelle des Parts
	(jamais de leur nom) et produit des "surfaces" exploitables :

	  Surface = {
	    Id, Index, Role ("Floor" | "Wall" | "Ceiling" | "Slope"),
	    Part, PartName, FaceName,
	    Frame   : CFrame (X = U, Y = N normale sortante, Z = V),
	    Normal, U, V,
	    SizeU, SizeV,                  -- dimensions de la face
	    UMin, UMax, VMin, VMax,        -- plage utilisable (après découpes)
	    Thickness, Tilt, IsAnalytic,
	    Walls      : (sols) murs adjacents en coordonnées 2D du sol
	    Obstacles  : polygones 2D des autres géométries cibles/protégées
	    Ends       : (murs) extrémités { Min = {Type = "Free"|"Corner"}, Max = ... }
	    SupportFloor, CeilingAbove : relations
	  }

	Tout est calculé dans les repères locaux des faces : une zone tournée de
	37° dans le Workspace donne exactement la même composition relative.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local MathUtil = require(Core.MathUtil)
local Utilities = require(Core.Utilities)

local GeometryAnalyzer = {}

local G = Config.Geometry
local UP = MathUtil.UP
local EPS = Config.Precision.NUMERIC_EPSILON

GeometryAnalyzer.Roles = { "Auto", "Floor", "Wall", "Ceiling", "Ignore" }

local ROLE_ORDER = { Floor = 1, Slope = 2, Wall = 3, Ceiling = 4 }
local FACE_NAMES = {
	{ [1] = "Right", [-1] = "Left" },
	{ [1] = "Top", [-1] = "Bottom" },
	{ [1] = "Back", [-1] = "Front" },
}

local COS_FLOOR = math.cos(math.rad(G.FLOOR_MAX_ANGLE_DEG))
local SIN_WALL = math.sin(math.rad(G.WALL_MAX_TILT_DEG))

-- Normalise un rôle saisi (UI / attribut) : "FLOOR", "floor" -> "Floor".
function GeometryAnalyzer.normalizeRole(value)
	if type(value) ~= "string" then
		return "Auto"
	end
	local lower = string.lower(value)
	for _, role in ipairs(GeometryAnalyzer.Roles) do
		if string.lower(role) == lower then
			return role
		end
	end
	return "Auto"
end

-- Classe une normale selon son orientation.
function GeometryAnalyzer.classifyNormal(n)
	local d = n:Dot(UP)
	if d >= COS_FLOOR then
		return "Floor"
	elseif d <= -COS_FLOOR then
		return "Ceiling"
	elseif math.abs(d) <= SIN_WALL then
		return "Wall"
	end
	return if d > 0 then "Slope" else "Ceiling"
end

-- Informations d'une Part ---------------------------------------------------------

local function isAnalyticBox(part)
	return part.ClassName == "Part" and (part :: any).Shape == Enum.PartType.Block
end

function GeometryAnalyzer.partInfo(part)
	local cf = part.CFrame
	local size = part.Size
	local info = {
		Part = part,
		CFrame = cf,
		Size = size,
		Axes = { cf.XVector, cf.YVector, cf.ZVector },
		Dims = { size.X, size.Y, size.Z },
		IsWedge = part:IsA("WedgePart"),
		IsAnalytic = isAnalyticBox(part) or part:IsA("WedgePart"),
	}
	local order = { 1, 2, 3 }
	table.sort(order, function(a, b)
		if math.abs(info.Dims[a] - info.Dims[b]) > EPS then
			return info.Dims[a] < info.Dims[b]
		end
		return a < b
	end)
	info.ThinIndex = order[1]
	info.MidIndex = order[2]
	info.LongIndex = order[3]
	info.ThinRatio = info.Dims[order[1]] / math.max(info.Dims[order[2]], EPS)
	info.IsSlab = info.ThinRatio <= G.SLAB_THIN_RATIO
	return info
end

local function makeFace(info, axisIndex, sign)
	local n = info.Axes[axisIndex] * sign
	local tangents = {}
	for i = 1, 3 do
		if i ~= axisIndex then
			table.insert(tangents, { Axis = info.Axes[i], Half = info.Dims[i] * 0.5 })
		end
	end
	return {
		Normal = n,
		Center = info.CFrame.Position + n * (info.Dims[axisIndex] * 0.5),
		T1 = tangents[1],
		T2 = tangents[2],
		Thickness = info.Dims[axisIndex],
		Name = FACE_NAMES[axisIndex][sign],
		AxisIndex = axisIndex,
		Sign = sign,
		Analytic = info.IsAnalytic,
	}
end

-- Face inclinée d'un WedgePart (la pente descend de l'arrière-haut vers l'avant-bas).
local function wedgeSlopeFace(info)
	local h = info.Dims[2] * 0.5
	local d = info.Dims[3] * 0.5
	local cf = info.CFrame
	local nLocal = MathUtil.safeUnit(Vector3.new(0, d, -h), Vector3.new(0, 1, 0))
	local tLocal = MathUtil.safeUnit(Vector3.new(0, h, d), Vector3.new(0, 0, 1))
	return {
		Normal = cf:VectorToWorldSpace(nLocal),
		Center = cf.Position,
		T1 = { Axis = info.Axes[1], Half = info.Dims[1] * 0.5 },
		T2 = { Axis = cf:VectorToWorldSpace(tLocal), Half = math.sqrt(h * h + d * d) },
		Thickness = math.min(info.Dims[2], info.Dims[3]),
		Name = "Slope",
		Analytic = true,
	}
end

local function allFaces(info)
	local faces = {}
	for axis = 1, 3 do
		for _, sign in ipairs({ 1, -1 }) do
			local skip = info.IsWedge and ((axis == 2 and sign == 1) or (axis == 3 and sign == -1))
			if not skip then
				table.insert(faces, makeFace(info, axis, sign))
			end
		end
	end
	if info.IsWedge then
		table.insert(faces, wedgeSlopeFace(info))
	end
	return faces
end

local function faceArea(face)
	return face.T1.Half * face.T2.Half * 4
end

local function mostUpFace(faces)
	local best, bestDot = nil, -math.huge
	for _, f in ipairs(faces) do
		local d = f.Normal:Dot(UP)
		if d > bestDot + EPS or (math.abs(d - bestDot) <= EPS and best and faceArea(f) > faceArea(best)) then
			best, bestDot = f, d
		end
	end
	return best
end

local function mostDownFace(faces)
	local best, bestDot = nil, math.huge
	for _, f in ipairs(faces) do
		local d = f.Normal:Dot(UP)
		if d < bestDot - EPS or (math.abs(d - bestDot) <= EPS and best and faceArea(f) > faceArea(best)) then
			best, bestDot = f, d
		end
	end
	return best
end

-- Les deux faces verticales les plus larges (même axe local).
local function broadVerticalFaces(info)
	local bestAxis, bestScore = nil, -math.huge
	for axis = 1, 3 do
		local verticality = 1 - math.abs(info.Axes[axis]:Dot(UP))
		if verticality > 0.5 then
			local area = 1
			for i = 1, 3 do
				if i ~= axis then
					area *= info.Dims[i]
				end
			end
			local score = area * verticality
			if score > bestScore then
				bestAxis, bestScore = axis, score
			end
		end
	end
	if not bestAxis then
		return {}
	end
	return { makeFace(info, bestAxis, 1), makeFace(info, bestAxis, -1) }
end

-- Construction d'une surface ------------------------------------------------------

local function buildSurface(face, role, info)
	local n = face.Normal
	local u
	if role == "Wall" then
		u = MathUtil.safeUnit(n:Cross(UP), nil)
		if u.Magnitude < 0.5 then
			u = MathUtil.safeUnit(MathUtil.projectOnPlane(face.T1.Axis, n), Vector3.new(1, 0, 0))
		end
	else
		local long = if face.T1.Half >= face.T2.Half then face.T1 else face.T2
		u = MathUtil.safeUnit(MathUtil.projectOnPlane(long.Axis, n), MathUtil.anyPerpendicular(n))
	end
	local v = u:Cross(n)
	local frame = CFrame.fromMatrix(face.Center, u, n)
	local halfU = math.abs(face.T1.Axis:Dot(u)) * face.T1.Half + math.abs(face.T2.Axis:Dot(u)) * face.T2.Half
	local halfV = math.abs(face.T1.Axis:Dot(v)) * face.T1.Half + math.abs(face.T2.Axis:Dot(v)) * face.T2.Half
	return {
		Role = role,
		Part = info.Part,
		PartName = Utilities.fullName(info.Part),
		FaceName = face.Name,
		Frame = frame,
		Normal = n,
		U = u,
		V = v,
		SizeU = halfU * 2,
		SizeV = halfV * 2,
		UMin = -halfU,
		UMax = halfU,
		VMin = -halfV,
		VMax = halfV,
		Thickness = face.Thickness,
		Tilt = math.deg(math.acos(math.clamp(math.abs(n:Dot(UP)), -1, 1))),
		IsAnalytic = face.Analytic,
		Walls = {},
		Obstacles = {},
		Ends = { Min = { Type = "Free" }, Max = { Type = "Free" } },
		Corners = {},
		Info = info,
	}
end

function GeometryAnalyzer.usableArea(surface)
	return math.max(0, surface.UMax - surface.UMin) * math.max(0, surface.VMax - surface.VMin)
end

function GeometryAnalyzer.surfaceHeightWorld(surface, u, v)
	return surface.Frame:PointToWorldSpace(Vector3.new(u, 0, v)).Y
end

-- Choix des faces par rôle -------------------------------------------------------------

-- Rôle automatique d'une Part : ("Floor" | "Wall" | "Slope" | "Ceiling" | nil, faces)
local function autoRole(info)
	local faces = allFaces(info)
	if info.IsWedge then
		local slope = faces[#faces]
		local cls = GeometryAnalyzer.classifyNormal(slope.Normal)
		if cls == "Floor" or cls == "Slope" then
			return cls, { slope }
		end
		local top = mostUpFace(faces)
		if top and GeometryAnalyzer.classifyNormal(top.Normal) == "Floor" then
			return "Floor", { top }
		end
		return nil, {}
	end
	if info.IsSlab then
		local a = info.Axes[info.ThinIndex]
		local upDot = math.abs(a:Dot(UP))
		if upDot >= COS_FLOOR then
			local sign = if a:Dot(UP) >= 0 then 1 else -1
			return "Floor", { makeFace(info, info.ThinIndex, sign) }
		elseif upDot <= SIN_WALL then
			return "Wall", { makeFace(info, info.ThinIndex, 1), makeFace(info, info.ThinIndex, -1) }
		else
			local sign = if a:Dot(UP) >= 0 then 1 else -1
			return "Slope", { makeFace(info, info.ThinIndex, sign) }
		end
	end
	local top = mostUpFace(faces)
	if top then
		local cls = GeometryAnalyzer.classifyNormal(top.Normal)
		if cls == "Floor" or cls == "Slope" then
			return cls, { top }
		end
	end
	return nil, {}
end

local function forcedFaces(info, role)
	local faces = allFaces(info)
	if role == "Floor" then
		local f = mostUpFace(faces)
		return if f then { f } else {}
	elseif role == "Ceiling" then
		local f = mostDownFace(faces)
		return if f then { f } else {}
	elseif role == "Wall" then
		return broadVerticalFaces(info)
	end
	return {}
end

-- Relations ---------------------------------------------------------------------------

local function projectToSurface2D(surface, worldPoint)
	local l = surface.Frame:PointToObjectSpace(worldPoint)
	return Vector2.new(l.X, l.Z), l.Y
end

local function pointNearRect(surface, p2, tolerance)
	return p2.X >= surface.UMin - tolerance and p2.X <= surface.UMax + tolerance
		and p2.Y >= surface.VMin - tolerance and p2.Y <= surface.VMax + tolerance
end

-- Hauteur (en coordonnée V du mur) où le plan d'une surface horizontale coupe le mur.
local function wallVAtPlane(wall, plane, uSample)
	local base = wall.Frame:PointToWorldSpace(Vector3.new(uSample, 0, 0))
	-- Intersection de la droite base + V*t avec le plan de `plane`.
	local denom = wall.V:Dot(plane.Normal)
	if math.abs(denom) < 0.2 then
		return nil
	end
	local t = (plane.Frame.Position - base):Dot(plane.Normal) / denom
	return t
end

-- Le pied du mur est-il au-dessus de la surface horizontale `plane` (plan) ?
local function wallOverlapsPlan(wall, plane)
	local samples = 7
	for i = 0, samples - 1 do
		local u = wall.UMin + (wall.UMax - wall.UMin) * (i / (samples - 1))
		local vAt = wallVAtPlane(wall, plane, u)
		local vRef = if vAt then vAt else wall.VMin
		local p = wall.Frame:PointToWorldSpace(Vector3.new(u, 0, vRef))
		-- On recule légèrement dans le mur (épaisseur) pour tester le recouvrement en plan.
		local inside = p - wall.Normal * (wall.Thickness * 0.5)
		local p2 = projectToSurface2D(plane, inside)
		if pointNearRect(plane, p2, G.WALL_FLOOR_PLAN_TOLERANCE + wall.Thickness) then
			return true
		end
	end
	return false
end

local function clipWallVertically(wall, floors, ceilings)
	local uMid = (wall.UMin + wall.UMax) * 0.5
	for _, f in ipairs(floors) do
		if f.Part ~= wall.Part and wallOverlapsPlan(wall, f) then
			local vF = wallVAtPlane(wall, f, uMid)
			if vF and vF > wall.VMin - G.WALL_FLOOR_CONTACT_TOLERANCE and vF < wall.VMax - G.MIN_SURFACE_EXTENT then
				if vF > wall.VMin then
					wall.VMin = vF
				end
				if not wall.SupportFloor or vF >= (wall.SupportFloorV or -math.huge) then
					wall.SupportFloor = f
					wall.SupportFloorV = vF
				end
			end
		end
	end
	for _, c in ipairs(ceilings) do
		if c.Part ~= wall.Part and wallOverlapsPlan(wall, c) then
			local vC = wallVAtPlane(wall, c, uMid)
			if vC and vC < wall.VMax + G.WALL_FLOOR_CONTACT_TOLERANCE and vC > wall.VMin + G.MIN_SURFACE_EXTENT then
				if vC < wall.VMax then
					wall.VMax = vC
				end
				wall.CeilingAbove = c
			end
		end
	end
end

-- Détection d'un coin intérieur entre deux murs et découpe de leurs plages U.
local function detectCorner(a, b)
	local dotN = a.Normal:Dot(b.Normal)
	if math.abs(dotN) > G.CORNER_MAX_ABS_DOT then
		return nil
	end
	local denomA = a.U:Dot(b.Normal)
	local denomB = b.U:Dot(a.Normal)
	if math.abs(denomA) < 0.3 or math.abs(denomB) < 0.3 then
		return nil
	end
	local cA, cB = a.Frame.Position, b.Frame.Position
	-- Coin intérieur : chaque mur est devant l'autre.
	if (cB - cA):Dot(a.Normal) <= 0 or (cA - cB):Dot(b.Normal) <= 0 then
		return nil
	end
	local uA = (cB - cA):Dot(b.Normal) / denomA
	local uB = (cA - cB):Dot(a.Normal) / denomB
	local tolA = G.CORNER_TOLERANCE + b.Thickness
	local tolB = G.CORNER_TOLERANCE + a.Thickness
	if uA < a.UMin - tolA or uA > a.UMax + tolA then
		return nil
	end
	if uB < b.UMin - tolB or uB > b.UMax + tolB then
		return nil
	end
	-- Plage verticale commune (monde).
	local aBottom = a.Frame:PointToWorldSpace(Vector3.new(uA, 0, a.VMin)).Y
	local aTop = a.Frame:PointToWorldSpace(Vector3.new(uA, 0, a.VMax)).Y
	local bBottom = b.Frame:PointToWorldSpace(Vector3.new(uB, 0, b.VMin)).Y
	local bTop = b.Frame:PointToWorldSpace(Vector3.new(uB, 0, b.VMax)).Y
	local bottom = math.max(aBottom, bBottom)
	local top = math.min(aTop, bTop)
	if top - bottom < G.MIN_SURFACE_EXTENT then
		return nil
	end

	-- Découpe : la partie de A située derrière la face de B est inutilisable (et réciproquement).
	local aSide, bSide
	if denomA > 0 then
		if uA > a.UMin then
			a.UMin = math.min(uA, a.UMax)
		end
		aSide = "Min"
	else
		if uA < a.UMax then
			a.UMax = math.max(uA, a.UMin)
		end
		aSide = "Max"
	end
	if denomB > 0 then
		if uB > b.UMin then
			b.UMin = math.min(uB, b.UMax)
		end
		bSide = "Min"
	else
		if uB < b.UMax then
			b.UMax = math.max(uB, b.UMin)
		end
		bSide = "Max"
	end

	local cornerPoint = a.Frame:PointToWorldSpace(Vector3.new(uA, 0, 0))
	local position = Vector3.new(cornerPoint.X, bottom, cornerPoint.Z)
	-- Pour des murs non parfaitement verticaux, on projette le point à la hauteur `bottom` le long de V.
	if math.abs(a.V.Y) > 0.5 then
		local t = (bottom - cornerPoint.Y) / a.V.Y
		position = cornerPoint + a.V * t
	end
	local corner = {
		WallA = a,
		WallB = b,
		SideA = aSide,
		SideB = bSide,
		Position = position,
		Height = top - bottom,
		NormalA = a.Normal,
		NormalB = b.Normal,
		Bisector = MathUtil.safeUnit(a.Normal + b.Normal, a.Normal),
		AngleDeg = math.deg(math.acos(math.clamp(-dotN, -1, 1))),
	}
	a.Ends[aSide] = { Type = "Corner", Corner = corner, Other = b }
	b.Ends[bSide] = { Type = "Corner", Corner = corner, Other = a }
	table.insert(a.Corners, corner)
	table.insert(b.Corners, corner)
	return corner
end

-- Obstacles 2D : autres géométries qui empiètent dans l'espace libre devant la surface.
local function computeObstacles(surface, parts, probeDepth)
	local frame = surface.Frame
	local regionCf = frame * CFrame.new((surface.UMin + surface.UMax) * 0.5, probeDepth * 0.5, (surface.VMin + surface.VMax) * 0.5)
	local regionSize = Vector3.new(surface.UMax - surface.UMin, probeDepth, surface.VMax - surface.VMin)
	for _, part in ipairs(parts) do
		if part ~= surface.Part then
			local ok = MathUtil.obbIntersects(regionCf, regionSize, part.CFrame, part.Size, Config.Precision.CONTACT_TOLERANCE, 0)
			if ok then
				local poly, hMin, hMax = MathUtil.projectOBBToSurface(frame, part.CFrame, part.Size)
				if hMax > Config.Precision.CONTACT_TOLERANCE and #poly >= 3 then
					table.insert(surface.Obstacles, { Polygon = poly, Part = part, HMin = hMin, HMax = hMax })
				end
			end
		end
	end
end

-- Murs adjacents à un sol, exprimés en 2D dans le repère du sol.
local function computeFloorWalls(floor, walls)
	for _, w in ipairs(walls) do
		if w.Part ~= floor.Part and w.UMax - w.UMin > G.MIN_SURFACE_EXTENT then
			local p0w = w.Frame:PointToWorldSpace(Vector3.new(w.UMin, 0, w.VMin))
			local p1w = w.Frame:PointToWorldSpace(Vector3.new(w.UMax, 0, w.VMin))
			local p0, h0 = projectToSurface2D(floor, p0w)
			local p1, h1 = projectToSurface2D(floor, p1w)
			local heightOk = math.abs(h0) <= G.WALL_FLOOR_CONTACT_TOLERANCE + 0.05 or math.abs(h1) <= G.WALL_FLOOR_CONTACT_TOLERANCE + 0.05
			local nearOk = false
			local tol = G.WALL_FLOOR_PLAN_TOLERANCE
			for i = 0, 4 do
				local p = p0:Lerp(p1, i / 4)
				if pointNearRect(floor, p, tol) then
					nearOk = true
					break
				end
			end
			local n2 = Vector2.new(w.Normal:Dot(floor.U), w.Normal:Dot(floor.V))
			if heightOk and nearOk and n2.Magnitude > 0.5 then
				table.insert(floor.Walls, {
					Surface = w,
					P0 = p0,
					P1 = p1,
					Normal = n2.Unit,
					Length = (p1 - p0).Magnitude,
				})
			end
		end
	end
end

-- Recouvrement en plan (approximatif : AABB dans le repère du sol) entre deux surfaces horizontales.
local function planOverlapFraction(lower, upper)
	local corners = {
		upper.Frame:PointToWorldSpace(Vector3.new(upper.UMin, 0, upper.VMin)),
		upper.Frame:PointToWorldSpace(Vector3.new(upper.UMax, 0, upper.VMin)),
		upper.Frame:PointToWorldSpace(Vector3.new(upper.UMax, 0, upper.VMax)),
		upper.Frame:PointToWorldSpace(Vector3.new(upper.UMin, 0, upper.VMax)),
	}
	local minU, minV, maxU, maxV = math.huge, math.huge, -math.huge, -math.huge
	for _, c in ipairs(corners) do
		local p = projectToSurface2D(lower, c)
		minU = math.min(minU, p.X)
		minV = math.min(minV, p.Y)
		maxU = math.max(maxU, p.X)
		maxV = math.max(maxV, p.Y)
	end
	local ou = math.max(0, math.min(maxU, lower.UMax) - math.max(minU, lower.UMin))
	local ov = math.max(0, math.min(maxV, lower.VMax) - math.max(minV, lower.VMin))
	local overlap = ou * ov
	local ref = math.min(GeometryAnalyzer.usableArea(lower), (maxU - minU) * (maxV - minV))
	if ref <= EPS then
		return 0
	end
	return overlap / ref
end

-- Distance d'un point intérieur au bord d'un rectangle de surface le long d'une direction 2D.
local function rayRectDistance(surface, p2, dir2)
	local t = math.huge
	if dir2.X > 1e-6 then
		t = math.min(t, (surface.UMax - p2.X) / dir2.X)
	elseif dir2.X < -1e-6 then
		t = math.min(t, (surface.UMin - p2.X) / dir2.X)
	end
	if dir2.Y > 1e-6 then
		t = math.min(t, (surface.VMax - p2.Y) / dir2.Y)
	elseif dir2.Y < -1e-6 then
		t = math.min(t, (surface.VMin - p2.Y) / dir2.Y)
	end
	return math.max(0, t)
end

--[[
	Choix de la (des) face(s) utile(s) d'un mur :
	  - sol le plus proche : face tournée vers la plus grande partie du sol ;
	    si le mur coupe le sol en deux parties significatives, c'est un
	    séparateur et les deux faces sont décorées ;
	  - pas de sol : face tournée vers la caméra ;
	  - sinon : les deux faces.
]]
local function chooseWallFaces(wallInfo, faces, floors, camera)
	local center = wallInfo.CFrame.Position
	local bestFloor, bestDist = nil, math.huge
	for _, f in ipairs(floors) do
		if f.Part ~= wallInfo.Part then
			local p2 = projectToSurface2D(f, center)
			local du = math.max(0, math.max(f.UMin - p2.X, p2.X - f.UMax))
			local dv = math.max(0, math.max(f.VMin - p2.Y, p2.Y - f.VMax))
			local dist = math.sqrt(du * du + dv * dv)
			if dist < bestDist then
				bestFloor, bestDist = f, dist
			end
		end
	end
	if bestFloor then
		local f = bestFloor
		local p2 = projectToSurface2D(f, center)
		local inside = p2.X > f.UMin and p2.X < f.UMax and p2.Y > f.VMin and p2.Y < f.VMax
		local scored = {}
		for _, face in ipairs(faces) do
			local n2 = Vector2.new(face.Normal:Dot(f.U), face.Normal:Dot(f.V))
			local score
			if n2.Magnitude < 0.3 then
				score = -math.huge
			elseif inside then
				score = rayRectDistance(f, p2, n2.Unit)
			else
				local toCenter = Vector2.new((f.UMin + f.UMax) * 0.5, (f.VMin + f.VMax) * 0.5) - p2
				score = n2.Unit:Dot(toCenter)
			end
			table.insert(scored, { Face = face, Score = score })
		end
		table.sort(scored, function(a, b)
			return a.Score > b.Score
		end)
		if inside and #scored == 2 and scored[2].Score > -math.huge then
			local d1, d2 = scored[1].Score, scored[2].Score
			if d2 >= math.max(G.DIVIDER_MIN_SIDE_DISTANCE, G.DIVIDER_MIN_SIDE_FRACTION * (d1 + d2)) then
				return faces
			end
		end
		return { scored[1].Face }
	end
	if camera then
		local camPos = camera.CFrame.Position
		local best, bestD = faces[1], -math.huge
		for _, face in ipairs(faces) do
			local d = (camPos - face.Center):Dot(face.Normal)
			if d > bestD then
				best, bestD = face, d
			end
		end
		return { best }
	end
	return faces
end

-- Tri stable et invariant par rotation : dans le repère de la plus grande surface.
local function sortSurfaces(surfaces)
	local ref = nil
	local refArea = -1
	for _, s in ipairs(surfaces) do
		local area = s.SizeU * s.SizeV
		if area > refArea + EPS then
			ref, refArea = s, area
		end
	end
	local refFrame = if ref then ref.Frame else CFrame.new()
	local function key(s)
		local l = refFrame:PointToObjectSpace(s.Frame.Position)
		return l
	end
	table.sort(surfaces, function(a, b)
		local ra, rb = ROLE_ORDER[a.Role] or 9, ROLE_ORDER[b.Role] or 9
		if ra ~= rb then
			return ra < rb
		end
		local ka, kb = key(a), key(b)
		local q = 0.01
		for _, axis in ipairs({ "Y", "X", "Z" }) do
			local va = Utilities.round(ka[axis], q)
			local vb = Utilities.round(kb[axis], q)
			if math.abs(va - vb) > q * 0.5 then
				return va < vb
			end
		end
		if math.abs(a.SizeU - b.SizeU) > 0.01 then
			return a.SizeU < b.SizeU
		end
		return a.SizeV < b.SizeV
	end)
	return refFrame
end

--[[
	Analyse principale.
	targets    : BaseParts cibles
	options    : { Overrides = {[Part] = role}, WallSides = "Auto"|"Both",
	               ObstacleParts = {BasePart}, Camera = Camera? }
]]
function GeometryAnalyzer.analyze(targets, options)
	options = options or {}
	local overrides = options.Overrides or {}
	local warnings = {}
	local infos = {}

	-- 1) Rôles automatiques / forcés.
	local pending = {}
	for _, part in ipairs(targets) do
		local info = GeometryAnalyzer.partInfo(part)
		table.insert(infos, info)
		local forced = overrides[part]
		if forced == nil or forced == "Auto" then
			local attrRole = Utilities.getAttribute(part, Config.Attr.SurfaceRole, "string", nil)
			if attrRole then
				forced = GeometryAnalyzer.normalizeRole(attrRole)
			end
		end
		forced = GeometryAnalyzer.normalizeRole(forced)
		local role, faces
		if forced == "Ignore" then
			role, faces = nil, {}
		elseif forced ~= "Auto" then
			role, faces = forced, forcedFaces(info, forced)
		else
			role, faces = autoRole(info)
		end
		info.AutoRole = role
		info.Forced = forced ~= "Auto"
		if role then
			table.insert(pending, { Info = info, Role = role, Faces = faces, Forced = forced ~= "Auto" })
		end
	end

	-- 2) Sols / pentes / plafonds forcés d'abord (les murs en ont besoin pour choisir leur face).
	local floors, ceilings, slopes = {}, {}, {}
	for _, p in ipairs(pending) do
		if p.Role == "Floor" or p.Role == "Slope" or p.Role == "Ceiling" then
			for _, face in ipairs(p.Faces) do
				local s = buildSurface(face, p.Role, p.Info)
				s.Forced = p.Forced
				if p.Role == "Floor" then
					table.insert(floors, s)
				elseif p.Role == "Slope" then
					table.insert(slopes, s)
				else
					table.insert(ceilings, s)
				end
			end
		end
	end

	-- 3) Murs : choix de la face utile.
	local walls = {}
	for _, p in ipairs(pending) do
		if p.Role == "Wall" then
			local chosen = p.Faces
			if options.WallSides ~= "Both" and #p.Faces == 2 then
				chosen = chooseWallFaces(p.Info, p.Faces, floors, options.Camera)
			end
			for _, face in ipairs(chosen) do
				local s = buildSurface(face, "Wall", p.Info)
				s.Forced = p.Forced
				table.insert(walls, s)
			end
		end
	end

	-- 4) Promotion en plafond : dalle horizontale au-dessus d'un sol, reliée par des murs.
	local promoted = {}
	for _, s in ipairs(floors) do
		local slabInfo = s.Info
		if not s.Forced and slabInfo.IsSlab and not slabInfo.IsWedge
			and math.abs(slabInfo.Axes[slabInfo.ThinIndex]:Dot(UP)) >= COS_FLOOR then
			local info = slabInfo
			local bottomFace = makeFace(info, info.ThinIndex, if info.Axes[info.ThinIndex]:Dot(UP) >= 0 then -1 else 1)
			local bottomY = bottomFace.Center.Y
			for _, f in ipairs(floors) do
				if f ~= s and f.Part ~= s.Part and f.Frame.Position.Y < bottomY - G.MIN_ROOM_HEIGHT then
					if planOverlapFraction(f, s) >= G.CEILING_MIN_OVERLAP then
						local connected = false
						for _, w in ipairs(walls) do
							local wBottom = w.Frame:PointToWorldSpace(Vector3.new(0, 0, w.VMin)).Y
							local wTop = w.Frame:PointToWorldSpace(Vector3.new(0, 0, w.VMax)).Y
							if wBottom <= f.Frame.Position.Y + G.WALL_FLOOR_CONTACT_TOLERANCE
								and wTop >= bottomY - G.WALL_FLOOR_CONTACT_TOLERANCE
								and wallOverlapsPlan(w, f) then
								connected = true
								break
							end
						end
						if connected then
							promoted[s] = bottomFace
							break
						end
					end
				end
			end
		end
	end
	if next(promoted) then
		local keptFloors = {}
		for _, s in ipairs(floors) do
			local bottomFace = promoted[s]
			if bottomFace then
				local c = buildSurface(bottomFace, "Ceiling", s.Info)
				table.insert(ceilings, c)
				-- Le dessus reste un sol seulement si des murs d'un étage supérieur y reposent.
				local topY = s.Frame.Position.Y
				local upperWalls = false
				for _, w in ipairs(walls) do
					local wBottom = w.Frame:PointToWorldSpace(Vector3.new(0, 0, w.VMin)).Y
					if math.abs(wBottom - topY) <= G.WALL_FLOOR_CONTACT_TOLERANCE and wallOverlapsPlan(w, s) then
						upperWalls = true
						break
					end
				end
				if upperWalls then
					table.insert(keptFloors, s)
				end
			else
				table.insert(keptFloors, s)
			end
		end
		floors = keptFloors
	end

	-- 5) Découpes verticales des murs (sol / plafond), puis coins.
	local horizontalSupports = {}
	Utilities.appendAll(horizontalSupports, floors)
	Utilities.appendAll(horizontalSupports, slopes)
	for _, w in ipairs(walls) do
		clipWallVertically(w, horizontalSupports, ceilings)
	end
	local corners = {}
	for i = 1, #walls do
		for j = i + 1, #walls do
			if walls[i].Part ~= walls[j].Part then
				local c = detectCorner(walls[i], walls[j])
				if c then
					table.insert(corners, c)
				end
			end
		end
	end

	-- 6) Paires de murs parallèles (face à face).
	local wallPairs = {}
	for i = 1, #walls do
		for j = i + 1, #walls do
			local a, b = walls[i], walls[j]
			if a.Normal:Dot(b.Normal) <= -G.PARALLEL_DOT then
				local distance = (b.Frame.Position - a.Frame.Position):Dot(a.Normal)
				if distance > 0 then
					table.insert(wallPairs, { A = a, B = b, Distance = distance })
				end
			end
		end
	end

	-- 7) Assemblage, filtrage des surfaces trop petites.
	local all = {}
	for _, list in ipairs({ floors, slopes, walls, ceilings }) do
		for _, s in ipairs(list) do
			if s.UMax - s.UMin >= G.MIN_SURFACE_EXTENT and s.VMax - s.VMin >= G.MIN_SURFACE_EXTENT then
				table.insert(all, s)
			else
				table.insert(warnings, string.format("Surface on '%s' (%s) is too small to decorate and was skipped.", s.PartName, s.FaceName))
			end
		end
	end
	local refFrame = sortSurfaces(all)

	-- 8) Obstacles et adjacences.
	local obstacleParts = table.clone(targets)
	for _, p in ipairs(options.ObstacleParts or {}) do
		if not table.find(obstacleParts, p) then
			table.insert(obstacleParts, p)
		end
	end
	local result = {
		Surfaces = all,
		Floors = {},
		Walls = {},
		Ceilings = {},
		Slopes = {},
		Corners = corners,
		WallPairs = wallPairs,
		PartInfos = infos,
		Parts = targets,
		RefFrame = refFrame,
		Warnings = warnings,
	}
	for index, s in ipairs(all) do
		s.Index = index
		s.Id = string.format("S%02d", index)
		if s.Role == "Floor" then
			table.insert(result.Floors, s)
		elseif s.Role == "Wall" then
			table.insert(result.Walls, s)
		elseif s.Role == "Ceiling" then
			table.insert(result.Ceilings, s)
		elseif s.Role == "Slope" then
			table.insert(result.Slopes, s)
		end
		local depth = if s.Role == "Wall" then G.EXCLUSION_PROBE_DEPTH * 0.25 else G.OBSTACLE_PROBE_HEIGHT
		computeObstacles(s, obstacleParts, depth)
	end
	for _, f in ipairs(result.Floors) do
		computeFloorWalls(f, result.Walls)
	end
	for _, f in ipairs(result.Slopes) do
		computeFloorWalls(f, result.Walls)
	end

	if #all == 0 and #targets > 0 then
		table.insert(warnings, "No usable surface found. Use the Target Surfaces list to force a role (FLOOR / WALL / CEILING).")
	end
	return result
end

return GeometryAnalyzer
