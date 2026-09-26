--[[
	PlacementMath
	Calcul exact de la pose d'un asset sur une surface, à partir de sa boîte
	réelle mesurée (jamais du pivot) :

	  - Sol   : la face la plus basse réelle de l'asset arrive exactement sur la
	            surface (les assets plats sont avancés de SURFACE_EPSILON pour
	            éviter le z-fighting). Sur une pente, un asset vertical est
	            légèrement enfoncé pour qu'aucun coin ne flotte.
	  - Mur   : la face arrière arrive contre le mur + profondeur contrôlée
	            (couche * SURFACE_EPSILON + WallOffset).
	  - Plafond : la face supérieure touche le plafond (direction de pose inversée).

	Repère canonique mural : x -> U (le long du mur), y -> V (haut), z -> -N
	(vers le mur). L'avant de l'asset (-Z) regarde donc l'espace libre.

	Une "pose" = { RefCFrame, BoxCFrame, BoxSize, Scale, Stretch, Rotation,
	               CanonMin, CanonMax }.
]]

local Core = script.Parent.Parent.Core
local MathUtil = require(Core.MathUtil)
local Utilities = require(Core.Utilities)

local PlacementMath = {}

local ZERO = Vector3.new(0, 0, 0)
local TILT_THRESHOLD_DEG = 0.5

-- Boîte locale (repère asset) après échelle uniforme et étirement éventuel.
-- stretch = { Axis = "X" | "Z", Factor = k } : étirement autour de l'origine du repère.
function PlacementMath.localBounds(asset, scale, stretch)
	local bmin = asset.BoundsMin * scale
	local bmax = asset.BoundsMax * scale
	if stretch and stretch.Factor and math.abs(stretch.Factor - 1) > 1e-9 then
		local k = stretch.Factor
		if stretch.Axis == "Z" then
			bmin = Vector3.new(bmin.X, bmin.Y, bmin.Z * k)
			bmax = Vector3.new(bmax.X, bmax.Y, bmax.Z * k)
		else
			bmin = Vector3.new(bmin.X * k, bmin.Y, bmin.Z)
			bmax = Vector3.new(bmax.X * k, bmax.Y, bmax.Z)
		end
	end
	return bmin, bmax
end

-- Axe local de l'asset qui suit le mur pour un lacet mural donné.
function PlacementMath.wallAlongAxis(wallYaw)
	local c = math.abs(math.cos(wallYaw))
	return if c >= 0.5 then "X" else "Z"
end

local function makePose(asset, scale, stretch, rotation, anchorLocalWorldOffset, target, bmin, bmax)
	local refCFrame = CFrame.new(target - anchorLocalWorldOffset) * rotation
	local center = (bmin + bmax) * 0.5
	return {
		Asset = asset,
		RefCFrame = refCFrame,
		BoxCFrame = refCFrame * CFrame.new(center),
		BoxSize = bmax - bmin,
		Scale = scale,
		Stretch = stretch,
		Rotation = rotation,
		LocalMin = bmin,
		LocalMax = bmax,
	}
end

local function translatePose(pose, delta)
	pose.RefCFrame = pose.RefCFrame + delta
	pose.BoxCFrame = pose.BoxCFrame + delta
end

--[[
	Pose au sol.
	opts = {
	  Yaw            : rotation autour du haut (radians)
	  AlignToSurface : incliner selon la surface (sinon vertical)
	  Offset         : décalage le long du haut (FloorOffset + SurfaceOffset)
	  Epsilon        : SURFACE_EPSILON (appliqué aux assets plats)
	  Stretch
	}
]]
function PlacementMath.floorPose(asset, scale, surface, u, v, opts)
	opts = opts or {}
	local bmin, bmax = PlacementMath.localBounds(asset, scale, opts.Stretch)
	local frame = surface.Frame
	local surfacePoint = frame:PointToWorldSpace(Vector3.new(u, 0, v))
	local tilted = surface.Tilt >= TILT_THRESHOLD_DEG
	local aligned = opts.AlignToSurface or not tilted
	local baseRot = if aligned then frame.Rotation else MathUtil.uprightRotation(surface.U)
	local rotation = baseRot * CFrame.Angles(0, opts.Yaw or 0, 0)

	local anchor
	local base = asset.Attachments.PlacementBase
	if base then
		local p = base.Position * scale
		anchor = Vector3.new(p.X, p.Y, p.Z)
	else
		anchor = Vector3.new((bmin.X + bmax.X) * 0.5, bmin.Y, (bmin.Z + bmax.Z) * 0.5)
	end
	local pose = makePose(asset, scale, opts.Stretch, rotation, rotation:VectorToWorldSpace(anchor), surfacePoint, bmin, bmax)

	-- Asset vertical sur une pente : on l'enfonce jusqu'à ce qu'aucun coin inférieur ne flotte.
	if not aligned then
		local n = surface.Normal
		local maxD = -math.huge
		for _, x in ipairs({ bmin.X, bmax.X }) do
			for _, z in ipairs({ bmin.Z, bmax.Z }) do
				local c = pose.RefCFrame:PointToWorldSpace(Vector3.new(x, bmin.Y, z))
				maxD = math.max(maxD, (c - surfacePoint):Dot(n))
			end
		end
		local upDotN = MathUtil.UP:Dot(n)
		if maxD > 0 and upDotN > 1e-3 then
			translatePose(pose, -MathUtil.UP * (maxD / upDotN))
		end
	end

	local offset = opts.Offset or 0
	if asset.IsFlat then
		offset += opts.Epsilon or 0
	end
	if math.abs(offset) > 0 then
		translatePose(pose, rotation.YVector * offset)
	end
	pose.SurfacePoint = surfacePoint
	return pose
end

--[[
	Pose murale.
	opts = {
	  AnchorX : "Center" | "Start" | "End"   (position u = centre / bord gauche / bord droit)
	  AnchorY : "Center" | "Bottom" | "Top"  (position v)
	  AnchorXValue : abscisse canonique explicite (snap par attachments)
	  AnchorYValue : ordonnée canonique explicite (empilement vertical)
	  Depth   : distance entre le plan du mur et l'arrière de l'asset
	  WallYaw : lacet mural (défaut : asset.WallYaw)
	  Stretch
	}
]]
function PlacementMath.wallPose(asset, scale, surface, u, v, opts)
	opts = opts or {}
	local wallYaw = if opts.WallYaw ~= nil then opts.WallYaw else asset.WallYaw or 0
	local n, uAxis, vAxis = surface.Normal, surface.U, surface.V
	local rotWall = CFrame.fromMatrix(ZERO, uAxis, vAxis, -n)
	local rotY = CFrame.Angles(0, wallYaw, 0)
	local rotation = rotWall * rotY
	local bmin, bmax = PlacementMath.localBounds(asset, scale, opts.Stretch)
	local cmin, cmax = MathUtil.rotatedBounds(bmin, bmax, rotY)

	local ax
	if opts.AnchorXValue ~= nil then
		ax = opts.AnchorXValue
	elseif opts.AnchorX == "Start" then
		ax = cmin.X
	elseif opts.AnchorX == "End" then
		ax = cmax.X
	else
		ax = (cmin.X + cmax.X) * 0.5
	end
	local ay
	if opts.AnchorYValue ~= nil then
		ay = opts.AnchorYValue
	elseif opts.AnchorY == "Bottom" then
		ay = cmin.Y
	elseif opts.AnchorY == "Top" then
		ay = cmax.Y
	else
		ay = (cmin.Y + cmax.Y) * 0.5
	end
	local az = cmax.Z
	local back = asset.Attachments.PlacementBack
	if back then
		az = rotY:VectorToWorldSpace(back.Position * scale).Z
	end
	local anchor = Vector3.new(ax, ay, az)
	local surfacePoint = surface.Frame:PointToWorldSpace(Vector3.new(u, 0, v))
	local target = surfacePoint + n * (opts.Depth or 0)
	local pose = makePose(asset, scale, opts.Stretch, rotation, rotWall:VectorToWorldSpace(anchor), target, bmin, bmax)
	pose.CanonMin = cmin
	pose.CanonMax = cmax
	pose.WallYaw = wallYaw
	pose.SurfacePoint = surfacePoint
	return pose
end

-- Bornes canoniques murales d'un asset (sans calculer de pose).
function PlacementMath.wallCanonBounds(asset, scale, wallYaw, stretch)
	local bmin, bmax = PlacementMath.localBounds(asset, scale, stretch)
	return MathUtil.rotatedBounds(bmin, bmax, CFrame.Angles(0, wallYaw or asset.WallYaw or 0, 0))
end

--[[
	Pose au plafond : l'asset reste "debout" (haut = haut du monde) et sa face
	supérieure touche le plafond. opts.Flip retourne l'asset (sa base contre le plafond).
]]
function PlacementMath.ceilingPose(asset, scale, surface, u, v, opts)
	opts = opts or {}
	local n = surface.Normal
	local up = -n
	local baseRot
	if opts.Flip then
		baseRot = CFrame.fromMatrix(ZERO, surface.U, n)
	else
		baseRot = CFrame.fromMatrix(ZERO, surface.U, up)
	end
	local rotation = baseRot * CFrame.Angles(0, opts.Yaw or 0, 0)
	local bmin, bmax = PlacementMath.localBounds(asset, scale, opts.Stretch)
	local anchorY = if opts.Flip then bmin.Y else bmax.Y
	local anchor = Vector3.new((bmin.X + bmax.X) * 0.5, anchorY, (bmin.Z + bmax.Z) * 0.5)
	local surfacePoint = surface.Frame:PointToWorldSpace(Vector3.new(u, 0, v))
	local target = surfacePoint + n * (opts.Depth or 0)
	local pose = makePose(asset, scale, opts.Stretch, rotation, rotation:VectorToWorldSpace(anchor), target, bmin, bmax)
	pose.SurfacePoint = surfacePoint
	return pose
end

-- Pose libre : l'asset est posé à partir d'une rotation monde et d'un point d'ancrage local.
function PlacementMath.freePose(asset, scale, rotation, anchorLocal, target, stretch)
	local bmin, bmax = PlacementMath.localBounds(asset, scale, stretch)
	return makePose(asset, scale, stretch, rotation, rotation:VectorToWorldSpace(anchorLocal), target, bmin, bmax)
end

PlacementMath.translatePose = translatePose

-- Pivot final à appliquer au clone (après ScaleTo).
function PlacementMath.pivotFor(asset, pose)
	return pose.RefCFrame * asset.PivotFromRef
end

-- Sous-boîtes de collision en coordonnées monde.
function PlacementMath.worldSubBoxes(pose)
	if pose.SubBoxes then
		return pose.SubBoxes
	end
	local asset = pose.Asset
	local list = {}
	if pose.Stretch and math.abs((pose.Stretch.Factor or 1) - 1) > 1e-9 then
		list[1] = { CFrame = pose.BoxCFrame, Size = pose.BoxSize }
	else
		local s = pose.Scale
		for _, b in ipairs(asset.SubBoxes) do
			local cf = b.CFrame
			list[#list + 1] = {
				CFrame = pose.RefCFrame * (CFrame.new(cf.Position * s) * cf.Rotation),
				Size = b.Size * s,
			}
		end
	end
	pose.SubBoxes = list
	return list
end

-- Empreinte 2D (polygone convexe) d'une pose dans le repère d'une surface.
function PlacementMath.footprint(pose, surface)
	local poly, hMin, hMax = MathUtil.projectOBBToSurface(surface.Frame, pose.BoxCFrame, pose.BoxSize)
	return poly, hMin, hMax
end

-- Échelle finale d'un asset selon les réglages et ses métadonnées.
function PlacementMath.resolveScale(asset, settings, rng)
	local meta = asset.Meta
	if not meta.AllowScale then
		return 1
	end
	local scale = 1
	local mode = settings.ScaleMode
	if mode == "Fixed" then
		scale = settings.FixedScale
	elseif mode == "RandomRange" then
		local lo = meta.MinScale or settings.MinScale
		local hi = meta.MaxScale or settings.MaxScale
		if hi < lo then
			lo, hi = hi, lo
		end
		scale = rng:range(lo, hi)
	end
	if meta.MinScale then
		scale = math.max(scale, meta.MinScale)
	end
	if meta.MaxScale then
		scale = math.min(scale, meta.MaxScale)
	end
	return Utilities.clamp(scale, 0.05, 20)
end

return PlacementMath
