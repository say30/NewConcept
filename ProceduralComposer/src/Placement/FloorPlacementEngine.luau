--[[
	FloorPlacementEngine
	Décoration des sols (et pentes) par composition :

	  Hero Composition : quelques gros éléments sur les points de composition ;
	  Cluster          : groupes (leader moyen/grand + satellites) séparés par
	                     des zones respirantes ;
	  Edge Decoration  : séquences rythmiques le long des murs / bords, les
	                     assets sont "snappés" dos au mur (contact exact) ;
	  Border           : suite continue d'assets bord à bord le long des bords ;
	  Grid             : placement régulier (trous cohérents via champ de bruit) ;
	  Scatter          : dispersion pondérée par le score ;
	  Hybrid           : choix automatique selon la forme de la zone.

	Toutes les coordonnées sont celles du repère local de la surface.
]]

local Workspace = game:GetService("Workspace")

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local MathUtil = require(Core.MathUtil)
local Utilities = require(Core.Utilities)
local PlacementMath = require(script.Parent.PlacementMath)
local CandidateScoring = require(script.Parent.CandidateScoring)
local CompositionPlanner = require(script.Parent.CompositionPlanner)
local ModularFitter = require(script.Parent.ModularFitter)
local RandomGenerator = require(Core.RandomGenerator)

local FloorPlacementEngine = {}

local COMP = Config.Composition
local SC = Config.Scoring
local G = Config.Geometry
local TOL = Config.Precision.CONTACT_TOLERANCE

local LARGE_CLASSES = { Large = true, Hero = true }
local MEDIUM_CLASSES = { Medium = true }
local SMALL_CLASSES = { Small = true }

-- Domaine ----------------------------------------------------------------------------

local Domain = {}
Domain.__index = Domain

local function segmentDistance(p, line)
	local d = MathUtil.pointSegmentDistance(p, line.P0, line.P1)
	return d
end

function Domain:edgeDistance(p)
	local best = math.min(p.X - self.U0, self.U1 - p.X, p.Y - self.V0, self.V1 - p.Y)
	best = math.max(best, 0)
	for _, line in ipairs(self.WallLines) do
		best = math.min(best, segmentDistance(p, line))
	end
	return best
end

function Domain:wallDistance(p)
	local best = math.huge
	for _, line in ipairs(self.WallLines) do
		best = math.min(best, segmentDistance(p, line))
	end
	return best
end

function Domain:nearestEdge(p)
	local best, bestLine = math.huge, nil
	for _, line in ipairs(self.EdgeLines) do
		local d = segmentDistance(p, line)
		if d < best then
			best, bestLine = d, line
		end
	end
	return bestLine, best
end

function Domain:crossCoord(p)
	return if self.CrossAxis == "U" then p.X else p.Y
end

function Domain:alongCoord(p)
	return if self.CrossAxis == "U" then p.Y else p.X
end

function Domain:crossNormalized(p)
	local half = (self.CrossMax - self.CrossMin) * 0.5
	if half <= 1e-6 then
		return 0
	end
	return math.clamp((self:crossCoord(p) - (self.CrossMin + self.CrossMax) * 0.5) / half, -1, 1)
end

function Domain:rhythm(p)
	local a0 = if self.CrossAxis == "U" then self.V0 else self.U0
	local length = if self.CrossAxis == "U" then self.V1 - self.V0 else self.U1 - self.U0
	return self.RhythmFn(self:alongCoord(p) - a0, length)
end

function Domain:randomPoint(rng)
	return Vector2.new(rng:range(self.U0, self.U1), rng:range(self.V0, self.V1))
end

-- Construit le domaine de placement d'une surface de sol.
local function buildDomain(ctx, surface, rng)
	local S = ctx.Settings
	local margin = S.EdgeMargin
	local d = setmetatable({}, Domain)
	d.Surface = surface
	d.U0, d.U1 = surface.UMin + margin, surface.UMax - margin
	d.V0, d.V1 = surface.VMin + margin, surface.VMax - margin
	if d.U1 - d.U0 < G.MIN_SURFACE_EXTENT or d.V1 - d.V0 < G.MIN_SURFACE_EXTENT then
		return nil
	end
	d.SizeU = d.U1 - d.U0
	d.SizeV = d.V1 - d.V0
	d.Center = Vector2.new((d.U0 + d.U1) * 0.5, (d.V0 + d.V1) * 0.5)
	d.MinExtent = math.min(d.SizeU, d.SizeV)
	d.MaxExtent = math.max(d.SizeU, d.SizeV)
	d.LengthAxis = if d.SizeU >= d.SizeV then "U" else "V"
	d.EdgeDepth = math.clamp(math.max(S.EdgeDepth, COMP.MIN_EDGE_DEPTH), 0.5, math.max(0.5, d.MinExtent * 0.5))
	d.Obstacles = surface.Obstacles

	-- Lignes de murs (décalées de la profondeur de façade si une architecture a été générée).
	d.WallLines = {}
	for _, w in ipairs(surface.Walls) do
		local offset = ctx:facadeDepth(w.Surface)
		table.insert(d.WallLines, {
			P0 = w.P0 + w.Normal * offset,
			P1 = w.P1 + w.Normal * offset,
			Normal = w.Normal,
			Length = w.Length,
			Kind = "Wall",
			Wall = w.Surface,
		})
	end
	table.sort(d.WallLines, function(a, b)
		return a.Wall.Index < b.Wall.Index
	end)

	-- Bords du rectangle non couverts par un mur.
	local rectEdges = {
		{ P0 = Vector2.new(d.U0, d.V0), P1 = Vector2.new(d.U1, d.V0), Normal = Vector2.new(0, 1) },
		{ P0 = Vector2.new(d.U1, d.V1), P1 = Vector2.new(d.U0, d.V1), Normal = Vector2.new(0, -1) },
		{ P0 = Vector2.new(d.U0, d.V1), P1 = Vector2.new(d.U0, d.V0), Normal = Vector2.new(1, 0) },
		{ P0 = Vector2.new(d.U1, d.V0), P1 = Vector2.new(d.U1, d.V1), Normal = Vector2.new(-1, 0) },
	}
	d.EdgeLines = table.clone(d.WallLines)
	for _, e in ipairs(rectEdges) do
		e.Length = (e.P1 - e.P0).Magnitude
		e.Kind = "Edge"
		local covered = false
		for _, w in ipairs(d.WallLines) do
			if w.Normal:Dot(e.Normal) > 0.9 then
				local mid = (e.P0 + e.P1) * 0.5
				local dist = MathUtil.pointSegmentDistance(mid, w.P0, w.P1)
				if dist <= math.max(d.EdgeDepth * 0.5, G.WALL_FLOOR_PLAN_TOLERANCE + 1) + ctx:facadeDepth(w.Wall) then
					covered = true
					break
				end
			end
		end
		e.Covered = covered
		if not covered then
			table.insert(d.EdgeLines, e)
		end
	end

	-- Axe transversal (pour Keep Center Clear, l'équilibre et le rythme).
	local mode = S.CenterClearAxis
	local shortAxis = if d.LengthAxis == "U" then "V" else "U"
	local cross = shortAxis
	if mode == "Length" then
		cross = d.LengthAxis
	elseif mode == "Auto" and #d.WallLines > 0 then
		local su, sv = 0, 0
		for _, w in ipairs(d.WallLines) do
			su += math.abs(w.Normal.X) * w.Length
			sv += math.abs(w.Normal.Y) * w.Length
		end
		cross = if su >= sv then "U" else "V"
	end
	d.CrossAxis = cross
	local cmin = if cross == "U" then d.U0 else d.V0
	local cmax = if cross == "U" then d.U1 else d.V1
	for _, w in ipairs(d.WallLines) do
		local nc = if cross == "U" then w.Normal.X else w.Normal.Y
		if math.abs(nc) > 0.9 then
			local c = if cross == "U" then (w.P0.X + w.P1.X) * 0.5 else (w.P0.Y + w.P1.Y) * 0.5
			if nc > 0 and c > cmin and c < cmax then
				cmin = c
			elseif nc < 0 and c < cmax and c > cmin then
				cmax = c
			end
		end
	end
	d.CrossMin, d.CrossMax = cmin, cmax

	-- Points de composition (tiers) dans la zone décorable.
	d.Thirds = {}
	for _, fu in ipairs({ 1 / 3, 2 / 3 }) do
		for _, fv in ipairs({ 1 / 3, 2 / 3 }) do
			table.insert(d.Thirds, Vector2.new(d.U0 + d.SizeU * fu, d.V0 + d.SizeV * fv))
		end
	end
	d.RhythmFn = CompositionPlanner.rhythmField(rng)
	d.NoiseScale = d.MinExtent * 0.35
	return d
end

-- Polygones (repère de la surface) de la zone centrale protégée et du chemin.
-- force = true : calcule la zone centrale même si KeepCenterClear est désactivé.
local function computeClearZones(domain, S, force)
	local zones = {}
	local function band(c0, c1)
		if c1 - c0 <= 1e-3 then
			return
		end
		if domain.CrossAxis == "U" then
			table.insert(zones, MathUtil.rectPolygon(c0, domain.V0 - 1, c1, domain.V1 + 1))
		else
			table.insert(zones, MathUtil.rectPolygon(domain.U0 - 1, c0, domain.U1 + 1, c1))
		end
	end
	local span = domain.CrossMax - domain.CrossMin
	if (S.KeepCenterClear or force) and span > 0 then
		local c0 = domain.CrossMin + span * S.CenterClearStart
		local c1 = domain.CrossMin + span * S.CenterClearEnd
		if S.CenterClearAxis == "Both" then
			local a0 = if domain.CrossAxis == "U" then domain.V0 else domain.U0
			local a1 = if domain.CrossAxis == "U" then domain.V1 else domain.U1
			local la = a1 - a0
			local l0 = a0 + la * S.CenterClearStart
			local l1 = a0 + la * S.CenterClearEnd
			if domain.CrossAxis == "U" then
				table.insert(zones, MathUtil.rectPolygon(c0, l0, c1, l1))
			else
				table.insert(zones, MathUtil.rectPolygon(l0, c0, l1, c1))
			end
		else
			band(c0, c1)
		end
	end
	if S.PathWidth > 0 and span > 0 and not force then
		local mid = (domain.CrossMin + domain.CrossMax) * 0.5
		band(mid - S.PathWidth * 0.5, mid + S.PathWidth * 0.5)
	end
	return zones
end

-- Zones "Keep Center Clear" et "Path Width" enregistrées comme zones interdites.
local function registerClearZones(ctx, domain)
	local zones = computeClearZones(domain, ctx.Settings, false)
	for _, poly in ipairs(zones) do
		ctx.Zones:addSurfaceZone(domain.Surface, poly, "CenterClear")
		ctx.Diagnostics:zone(domain.Surface, poly, "CenterClear")
	end
	domain.ClearZones = zones
	return #zones > 0
end

-- Outils de pose ----------------------------------------------------------------------

local function surfaceVector(surface, v2)
	return surface.U * v2.X + surface.V * v2.Y
end

local function footprintCenter(surface, pose)
	local l = surface.Frame:PointToObjectSpace(pose.BoxCFrame.Position)
	return Vector2.new(l.X, l.Z)
end

-- Colle l'empreinte contre une ligne (mur ou bord) à la distance `gap`.
local function snapToLine(surface, pose, line, gap)
	local poly = PlacementMath.footprint(pose, surface)
	local dmin = math.huge
	for _, v in ipairs(poly) do
		dmin = math.min(dmin, (v - line.P0):Dot(line.Normal))
	end
	if dmin == math.huge then
		return
	end
	local shift = (gap or 0) - dmin
	if math.abs(shift) > 1e-9 then
		PlacementMath.translatePose(pose, surfaceVector(surface, line.Normal * shift))
		pose.SubBoxes = nil
	end
end

-- Hôte non analytique (MeshPart, Union...) : sonde la surface réelle par raycast.
local function probeMeshGround(surface, pose, poly)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { surface.Part }
	local n = surface.Normal
	local probe = G.RAYCAST_PROBE_HEIGHT
	local heights = {}
	local points = table.clone(poly)
	table.insert(points, MathUtil.polygonCentroid(poly))
	for _, p in ipairs(points) do
		local origin = surface.Frame:PointToWorldSpace(Vector3.new(p.X, probe, p.Y))
		local result = Workspace:Raycast(origin, -n * (probe + surface.Thickness + G.RAYCAST_MAX_SINK), params)
		if not result then
			return false
		end
		table.insert(heights, probe - (origin - result.Position).Magnitude)
	end
	local lo, hi = math.huge, -math.huge
	for _, h in ipairs(heights) do
		lo = math.min(lo, h)
		hi = math.max(hi, h)
	end
	if hi - lo > G.RAYCAST_MAX_SINK then
		return false
	end
	if math.abs(lo) > 1e-6 then
		PlacementMath.translatePose(pose, n * lo)
		pose.SubBoxes = nil
	end
	return true
end

local function checkFootprint(ctx, domain, pose, asset)
	local surface = domain.Surface
	local poly, hMin, hMax = PlacementMath.footprint(pose, surface)
	if not MathUtil.polygonInsideRect(poly, domain.U0, domain.V0, domain.U1, domain.V1, TOL) then
		return false, "bounds"
	end
	local S = ctx.Settings
	local wallTol = if S.AllowWallContact and asset.Meta.CanTouchWall then TOL else -(S.MinimumSpacing + TOL)
	for _, ob in ipairs(domain.Obstacles) do
		if ob.HMin < hMax - TOL and ob.HMax > math.max(hMin, 0) + TOL then
			if MathUtil.polygonsIntersect(poly, ob.Polygon, wallTol) then
				return false, "bounds"
			end
		end
	end
	if ctx.Zones:blocks(surface, poly) then
		return false, "exclusion"
	end
	if not surface.IsAnalytic then
		if not probeMeshGround(surface, pose, poly) then
			return false, "bounds"
		end
	end
	return true, nil, poly
end

-- Orientation selon le mode de rotation.
local function computeYaw(ctx, domain, p, asset, rng, hintNormal, modeOverride)
	if not asset.Meta.AllowRotation then
		return 0
	end
	local S = ctx.Settings
	local mode = modeOverride or S.RotationMode
	local jitter = math.rad(COMP.MAX_ROTATION_JITTER_DEG) * S.Randomness * rng:gaussian() * 0.5
	if mode == "Fixed" or mode == "AlignToSurface" then
		return 0
	elseif mode == "Random90" then
		return rng:int(0, 3) * math.pi * 0.5
	elseif mode == "Random180" then
		return rng:int(0, 1) * math.pi
	elseif mode == "Random360" then
		return rng:range(0, math.pi * 2)
	elseif mode == "AlignToWall" then
		local n = hintNormal
		if not n then
			local line = domain:nearestEdge(p)
			n = if line then line.Normal else Vector2.new(0, 1)
		end
		return MathUtil.yawFacing(n.X, n.Y) + jitter
	elseif mode == "FaceCenter" or mode == "FaceAway" then
		local target
		if domain.MaxExtent / math.max(domain.MinExtent, 1e-3) > 1.8 then
			-- Zone allongée : on regarde la ligne centrale.
			local mid = (domain.CrossMin + domain.CrossMax) * 0.5
			target = if domain.CrossAxis == "U" then Vector2.new(mid, p.Y) else Vector2.new(p.X, mid)
		else
			target = domain.Center
		end
		local dir = target - p
		if mode == "FaceAway" then
			dir = -dir
		end
		return MathUtil.yawFacing(dir.X, dir.Y) + jitter
	elseif mode == "FollowPath" then
		local dir = if domain.LengthAxis == "U" then Vector2.new(1, 0) else Vector2.new(0, 1)
		if asset.Meta.AllowMirror and rng:chance(0.5) then
			dir = -dir
		end
		return MathUtil.yawFacing(dir.X, dir.Y) + jitter * 0.5
	end
	return 0
end

local function mirrorPoint(domain, p)
	local mid = (domain.CrossMin + domain.CrossMax) * 0.5
	if domain.CrossAxis == "U" then
		return Vector2.new(2 * mid - p.X, p.Y)
	end
	return Vector2.new(p.X, 2 * mid - p.Y)
end

local function mirrorYaw(domain, yaw)
	local fu, fv = -math.sin(yaw), -math.cos(yaw)
	if domain.CrossAxis == "U" then
		fu = -fu
	else
		fv = -fv
	end
	return MathUtil.yawFacing(fu, fv)
end

-- Placement unitaire ----------------------------------------------------------------------

local function commit(ctx, domain, pose, asset, request, pos2D, polyArea)
	local surface = domain.Surface
	local item = ctx:tryCommit(pose, {
		Surface = surface,
		Role = "Floor",
		Folder = "Floor",
		PlacementType = if LARGE_CLASSES[asset.SizeClass] then "LargeStructure" else "Floor",
		Group = "Decor",
		Layer = 0,
		IgnoreParts = domain.IgnoreParts,
		Pos2D = pos2D,
		Radius = asset.FootprintRadius * pose.Scale,
		ClusterId = request.ClusterId,
		CrossCoord = domain:crossNormalized(pos2D),
		Pass = request.Pass,
	})
	if item then
		domain.Coverage += polyArea or (pose.BoxSize.X * pose.BoxSize.Z)
		if asset.SizeClass == "Hero" then
			domain.HeroCount += 1
		end
	end
	return item
end

local function tryMirror(ctx, domain, item, request, yaw, rng)
	local S = ctx.Settings
	if request.NoMirror or S.Symmetry <= 0 then
		return
	end
	if not request.ForceMirror and not rng:chance(S.Symmetry) then
		return
	end
	local surface = domain.Surface
	local asset = item.Asset
	local p = footprintCenter(surface, item.Pose)
	local mp = mirrorPoint(domain, p)
	if (mp - p).Magnitude < asset.FootprintRadius * item.Scale * 2 then
		return
	end
	local myaw = mirrorYaw(domain, yaw)
	-- On repositionne l'ancre pour que le centre de l'empreinte tombe sur le point miroir.
	local pose = PlacementMath.floorPose(asset, item.Scale, surface, mp.X, mp.Y, {
		Yaw = myaw,
		AlignToSurface = domain.AlignToSurface,
		Offset = asset.Meta.FloorOffset + S.SurfaceOffset,
		Epsilon = ctx.Epsilon,
	})
	local center = footprintCenter(surface, pose)
	local delta = mp - center
	if delta.Magnitude > 1e-6 then
		PlacementMath.translatePose(pose, surfaceVector(surface, delta))
		pose.SubBoxes = nil
	end
	local ok, _, poly = checkFootprint(ctx, domain, pose, asset)
	if ok and ctx:assetAvailable(asset) then
		commit(ctx, domain, pose, asset, { Pass = "Mirror", ClusterId = item.ClusterId }, mp, MathUtil.polygonArea(poly))
	end
end

--[[
	request = {
	  Palette, Asset?, SizeClasses?, Sampler(rng, asset, radius) -> (Vector2?, hintNormal?, snapLine?, gap?),
	  Profile, ClusterId?, Pass, Candidates?, RotationMode?, NoMirror?, Scale?
	}
]]
local function placeOne(ctx, domain, request, rng)
	local S = ctx.Settings
	local surface = domain.Surface
	local selector = ctx.Selector
	local tried = {}
	for _ = 1, SC.MAX_ASSET_RETRIES do
		if ctx:remaining() <= 0 then
			return nil
		end
		local classes = request.SizeClasses
		if domain.HeroCount >= domain.HeroCap then
			-- Hiérarchie : les éléments "Hero" restent rares sur une même surface.
			local filtered = {}
			for k, v in pairs(classes or { Small = true, Medium = true, Large = true, Hero = true }) do
				if k ~= "Hero" then
					filtered[k] = v
				end
			end
			classes = filtered
		end
		local asset = request.Asset or selector:pick(request.Palette, {
			Role = "Floor",
			SizeClasses = classes,
			Surface = surface,
			Rng = rng,
			MaxWidth = domain.MinExtent,
			Exclude = tried,
			IgnoreFrequency = request.IgnoreFrequency,
		})
		if not asset then
			return nil
		end
		local scale = request.Scale or PlacementMath.resolveScale(asset, S, rng)
		local footprintW = math.min(asset.Size.X, asset.Size.Z) * scale
		if footprintW > domain.MinExtent or math.max(asset.Size.X, asset.Size.Z) * scale > domain.MaxExtent then
			ctx.Diagnostics:add("TooLarge")
			tried[asset] = true
			if request.Asset then
				return nil
			end
		else
			local radius = asset.FootprintRadius * scale
			local env = {
				State = ctx:surfaceState(surface),
				Domain = domain,
				Asset = asset,
				Radius = radius,
				Profile = request.Profile or {},
				ClusterId = request.ClusterId,
				Rng = rng,
				Settings = S,
				NoiseSeed = domain.NoiseSeed,
			}
			local scored = {}
			local count = request.Candidates or S.CandidatesPerPlacement
			for k = 1, count do
				local p, hint, line, gap = request.Sampler(rng, asset, radius)
				if p then
					local yaw = computeYaw(ctx, domain, p, asset, rng, hint, request.RotationMode)
					local pose = PlacementMath.floorPose(asset, scale, surface, p.X, p.Y, {
						Yaw = yaw,
						AlignToSurface = domain.AlignToSurface,
						Offset = asset.Meta.FloorOffset + S.SurfaceOffset,
						Epsilon = ctx.Epsilon,
					})
					if line then
						snapToLine(surface, pose, line, gap or 0)
					end
					local ok, reason, poly = checkFootprint(ctx, domain, pose, asset)
					local center = footprintCenter(surface, pose)
					if ok then
						local score = CandidateScoring.floor(env, center)
						table.insert(scored, { Pose = pose, Pos = center, Score = score, Index = k, Yaw = yaw, Area = MathUtil.polygonArea(poly) })
						ctx.Diagnostics:candidate(pose.BoxCFrame.Position)
					else
						ctx.Diagnostics:reject(reason, pose.BoxCFrame.Position)
					end
				end
			end
			if #scored > 0 then
				CandidateScoring.orderCandidates(scored, S, rng)
				for i = 1, math.min(#scored, SC.MAX_COLLISION_TESTS) do
					local c = scored[i]
					local item = commit(ctx, domain, c.Pose, asset, request, c.Pos, c.Area)
					if item then
						tryMirror(ctx, domain, item, request, c.Yaw, rng)
						return item
					end
				end
			end
			tried[asset] = true
			if request.Asset then
				return nil
			end
		end
	end
	return nil
end

-- Échantillonneurs -------------------------------------------------------------------------

local function uniformSampler(domain)
	return function(rng)
		return domain:randomPoint(rng)
	end
end

local function thirdsSampler(domain)
	return function(rng)
		if rng:chance(0.6) then
			local p = domain.Thirds[rng:int(1, #domain.Thirds)]
			local j = domain.MinExtent * 0.12
			return p + Vector2.new(rng:gaussian() * j, rng:gaussian() * j)
		end
		return domain:randomPoint(rng)
	end
end

local function ringSampler(center, rMin, rMax)
	return function(rng)
		local a = rng:range(0, math.pi * 2)
		local r = rng:range(rMin, rMax)
		return center + Vector2.new(math.cos(a) * r, math.sin(a) * r)
	end
end

local function pickLine(lines, rng)
	local weights = {}
	for i, l in ipairs(lines) do
		weights[i] = l.Length
	end
	local i = rng:weightedIndex(weights)
	return if i then lines[i] else nil
end

local function edgeBandSampler(domain, lines)
	return function(rng, _, radius)
		local line = pickLine(lines, rng)
		if not line then
			return domain:randomPoint(rng)
		end
		local t = rng:next()
		local depth = (rng:next() ^ 1.5) * domain.EdgeDepth
		local p = line.P0:Lerp(line.P1, t) + line.Normal * (depth + radius)
		if depth < domain.EdgeDepth * 0.15 then
			return p, line.Normal, line, 0
		end
		return p, line.Normal
	end
end

-- Passes ------------------------------------------------------------------------------------

local function nextClusterId(domain)
	domain.ClusterCount += 1
	return domain.Surface.Id .. ":C" .. tostring(domain.ClusterCount)
end

local function addCluster(ctx, domain, center, radius, id)
	local state = ctx:surfaceState(domain.Surface)
	table.insert(state.Clusters, { Center = center, Radius = radius, Id = id })
	return id
end

local function satellites(ctx, domain, leader, clusterId, count, palette, rng, pass)
	if count <= 0 then
		return
	end
	-- Sous-palette cohérente : 1 à 2 petits assets + éventuellement un moyen.
	local smalls, mediums = {}, {}
	for _, a in ipairs(palette) do
		if a.SizeClass == "Small" then
			table.insert(smalls, a)
		elseif a.SizeClass == "Medium" then
			table.insert(mediums, a)
		end
	end
	local sub = {}
	rng:shuffle(smalls)
	for i = 1, math.min(#smalls, if ctx.Settings.Variation > 0.6 then 3 else 2) do
		table.insert(sub, smalls[i])
	end
	if #mediums > 0 and (#sub == 0 or rng:chance(ctx.Settings.MediumAssetFrequency * 0.6)) then
		table.insert(sub, mediums[rng:int(1, #mediums)])
	end
	if #sub == 0 then
		return
	end
	local surface = domain.Surface
	local leaderPos = footprintCenter(surface, leader.Pose)
	local leaderR = leader.Asset.FootprintRadius * leader.Scale
	local S = ctx.Settings
	for _ = 1, count do
		if domain.Coverage >= domain.CoverageLimit or ctx:remaining() <= 0 then
			return
		end
		local spread = Utilities.lerp(5, 1.2, S.ClusterStrength)
		placeOne(ctx, domain, {
			Palette = sub,
			IgnoreFrequency = true,
			Sampler = function(r, _, radius)
				local rMin = leaderR + radius + S.MinimumSpacing
				return ringSampler(leaderPos, rMin, rMin + radius * spread)(r)
			end,
			Profile = {
				ClusterCenter = leaderPos,
				ClusterRadius = leaderR * 2,
				EmptyWeight = 0.15,
				EdgeAffinity = 0,
				CenterAvoid = domain.CenterAvoid,
			},
			ClusterId = clusterId,
			Pass = pass or "Cluster",
			NoMirror = true,
		}, rng)
	end
end

local function heroPass(ctx, domain, budget, palette, rng, edgeAffinity)
	local S = ctx.Settings
	for _ = 1, budget.Heroes do
		if ctx:remaining() <= 0 then
			return
		end
		local clusterId = nextClusterId(domain)
		local item = placeOne(ctx, domain, {
			Palette = palette,
			SizeClasses = LARGE_CLASSES,
			IgnoreFrequency = true,
			Sampler = thirdsSampler(domain),
			Profile = {
				Thirds = 0.9,
				EdgeAffinity = edgeAffinity,
				BalanceWeight = 0.8,
				EmptyWeight = 0.4,
				AvoidClusters = true,
				ClusterRadius = budget.HeroRadius * 3,
				CenterAvoid = domain.CenterAvoid,
			},
			ClusterId = clusterId,
			Pass = "Hero",
		}, rng)
		if item then
			local pos = footprintCenter(domain.Surface, item.Pose)
			local r = item.Asset.FootprintRadius * item.Scale
			local id = addCluster(ctx, domain, pos, r * 2.5, clusterId)
			if S.ClusterStrength >= 0.25 then
				satellites(ctx, domain, item, id, CompositionPlanner.clusterSize(S, rng) - 1, palette, rng, "HeroCluster")
			end
		end
	end
end

local function clusterPass(ctx, domain, budget, palette, rng, edgeAffinity, centerSampler)
	local S = ctx.Settings
	local state = ctx:surfaceState(domain.Surface)
	for _ = 1, budget.Clusters do
		if domain.Coverage >= domain.CoverageLimit or ctx:remaining() <= 0 then
			return
		end
		-- Centre du groupe : meilleur point parmi plusieurs, loin des autres groupes.
		local probeAsset = { SizeClass = "Medium", Meta = {}, Importance = 1 }
		local env = {
			State = state,
			Domain = domain,
			Asset = probeAsset,
			Radius = budget.MediumRadius,
			Profile = {
				AvoidClusters = true,
				ClusterRadius = budget.MediumRadius * 3,
				EmptyWeight = 1,
				EdgeAffinity = edgeAffinity,
				BalanceWeight = 0.6,
				RhythmWeight = 0.5,
				CenterAvoid = domain.CenterAvoid,
			},
			Rng = rng,
			Settings = S,
			NoiseSeed = domain.NoiseSeed,
		}
		local bestP, bestScore = nil, -math.huge
		for _ = 1, S.CandidatesPerPlacement do
			local p = centerSampler(rng, probeAsset, budget.MediumRadius)
			if p then
				local s = CandidateScoring.floor(env, p)
				if s > bestScore then
					bestP, bestScore = p, s
				end
			end
		end
		if bestP then
			local classes = { Medium = true }
			if S.LargeAssetFrequency >= 0.4 and rng:chance(S.LargeAssetFrequency * 0.5) then
				classes.Large = true
			end
			local center = bestP
			local clusterId = nextClusterId(domain)
			local leader = placeOne(ctx, domain, {
				Palette = palette,
				SizeClasses = classes,
				IgnoreFrequency = true,
				Sampler = function(r)
					local j = budget.MediumRadius * 0.6
					return center + Vector2.new(r:gaussian() * j, r:gaussian() * j)
				end,
				Profile = { EmptyWeight = 0.2, AvoidClusters = true, ClusterRadius = budget.MediumRadius * 2, CenterAvoid = domain.CenterAvoid },
				ClusterId = clusterId,
				Pass = "Cluster",
			}, rng)
			if leader then
				local pos = footprintCenter(domain.Surface, leader.Pose)
				local id = addCluster(ctx, domain, pos, leader.Asset.FootprintRadius * leader.Scale * 2.5, clusterId)
				satellites(ctx, domain, leader, id, CompositionPlanner.clusterSize(S, rng), palette, rng, "Cluster")
			end
		end
		ctx.Yield()
	end
end

-- Ligne opposée et parallèle (murs face à face) : décorée en miroir si Symmetry est élevé.
local function findOppositeLines(domain, lines)
	local mirrored = {}
	for i, a in ipairs(lines) do
		if not mirrored[a] then
			for j = i + 1, #lines do
				local b = lines[j]
				local crossComponent = if domain.CrossAxis == "U" then math.abs(a.Normal.X) else math.abs(a.Normal.Y)
				if not mirrored[b] and a.Normal:Dot(b.Normal) < -0.9 and crossComponent > 0.9 then
					mirrored[b] = a
					break
				end
			end
		end
	end
	return mirrored
end

local function edgePass(ctx, domain, budget, palette, rng, lines, coverageShare)
	local S = ctx.Settings
	local limit = domain.CoverageLimit * coverageShare
	local symmetric = S.Symmetry >= 0.5
	local mirrored = if symmetric then findOppositeLines(domain, lines) else {}
	local hasOpposite = {}
	for b, a in pairs(mirrored) do
		hasOpposite[a] = true
		hasOpposite[b] = true
	end
	local spacing = math.max(budget.MediumRadius * 2.4, COMP.EDGE_BEAT_MIN_SPACING)
	for li, line in ipairs(lines) do
		if domain.Coverage >= limit or ctx:remaining() <= 0 then
			return
		end
		-- La ligne opposée reçoit les copies miroir de celle-ci.
		if not mirrored[line] then
			local dir = (line.P1 - line.P0).Unit
			local lineRng = rng:fork("edge" .. tostring(li))
			local beats = CompositionPlanner.beats(line.Length, lineRng, S, {
				BaseSpacing = spacing,
				Symmetric = S.Symmetry >= 0.6,
				EndMargin = math.min(budget.TypicalRadius * 0.5, line.Length * 0.1),
			})
			for bi, beat in ipairs(beats) do
				if domain.Coverage >= limit or ctx:remaining() <= 0 then
					break
				end
				if beat.Kind ~= "Gap" then
					local classes = if beat.Kind == "Large" then LARGE_CLASSES elseif beat.Kind == "Medium" then MEDIUM_CLASSES else SMALL_CLASSES
					local count = if beat.Kind == "SmallGroup" then lineRng:int(2, 3) else 1
					local clusterId = if count > 1 then (domain.Surface.Id .. ":E" .. li .. ":" .. bi) else nil
					for j = 1, count do
						local contact = beat.Kind == "Large" or j == 1
						placeOne(ctx, domain, {
							Palette = palette,
							SizeClasses = classes,
							Sampler = function(r, _, radius)
								local t = math.clamp(beat.T + (r:next() - 0.5) * beat.Width * 0.8, 0, line.Length)
								local depth = if contact then 0 else (r:next() ^ 2) * domain.EdgeDepth * 0.6
								local p = line.P0 + dir * t + line.Normal * (depth + radius)
								if contact or depth < 0.05 then
									return p, line.Normal, line, S.MinimumSpacing * 0.25
								end
								return p, line.Normal
							end,
							Profile = {
								EdgeAffinity = 0.6,
								RhythmWeight = 0.3,
								EmptyWeight = 0.3,
								CenterAvoid = domain.CenterAvoid,
							},
							ClusterId = clusterId,
							Pass = "Edge",
							NoMirror = not hasOpposite[line],
							ForceMirror = hasOpposite[line],
						}, lineRng)
					end
				end
			end
			ctx.Yield()
		end
	end
end

local function borderPass(ctx, domain, palette, rng, lines)
	local S = ctx.Settings
	local surface = domain.Surface
	for li, line in ipairs(lines) do
		if ctx:remaining() <= 0 then
			return
		end
		local lineRng = rng:fork("border" .. tostring(li))
		local candidates = {}
		for _, a in ipairs(palette) do
			if a.SizeClass ~= "Hero" and math.max(a.Size.X, a.Size.Z) <= line.Length and a.Size.Z <= domain.EdgeDepth * 2 then
				table.insert(candidates, a)
			end
		end
		table.sort(candidates, function(a, b)
			local ta = if a.Shape == "Trim" then 0 else 1
			local tb = if b.Shape == "Trim" then 0 else 1
			if ta ~= tb then
				return ta < tb
			end
			return a.Order < b.Order
		end)
		local modules = {}
		for i = 1, math.min(#candidates, 6) do
			local a = candidates[i]
			table.insert(modules, {
				Key = a.Key,
				Width = a.Size.X,
				Weight = a.Meta.Weight,
				Scalable = a.Meta.AllowScale,
				MinFactor = a.Meta.MinScale,
				MaxFactor = a.Meta.MaxScale,
				Data = a,
			})
		end
		local endMargin = 0
		local fit = ModularFitter.fit(line.Length - 2 * endMargin, modules, {
			AllowScale = true,
			MaxDeviation = 0.1,
			AllowGaps = S.EmptySpaceRatio > 0.05,
			MaxGapFraction = S.EmptySpaceRatio * 1.5 + 0.05,
			EndsFlush = false,
			Symmetric = S.Symmetry >= 0.5,
			Rng = lineRng,
			Variety = S.Variation,
		})
		local dir = (line.P1 - line.P0).Unit
		local yaw = MathUtil.yawFacing(line.Normal.X, line.Normal.Y)
		for _, it in ipairs(fit.Items) do
			local a = it.Module.Data
			if ctx:assetAvailable(a) and ctx:remaining() > 0 then
				local t = endMargin + fit.StartOffset + it.Start + it.Width * 0.5
				local p = line.P0 + dir * t + line.Normal * (a.Size.Z * it.Factor * 0.5)
				local pose = PlacementMath.floorPose(a, it.Factor, surface, p.X, p.Y, {
					Yaw = yaw,
					AlignToSurface = domain.AlignToSurface,
					Offset = a.Meta.FloorOffset + S.SurfaceOffset,
					Epsilon = ctx.Epsilon,
				})
				snapToLine(surface, pose, line, 0)
				-- Recentrage exact le long de la ligne (l'ancre de pose peut être un attachment).
				local center = footprintCenter(surface, pose)
				local along = (center - line.P0):Dot(dir)
				local fix = t - along
				if math.abs(fix) > 1e-9 then
					PlacementMath.translatePose(pose, surfaceVector(surface, dir * fix))
					pose.SubBoxes = nil
				end
				local ok, reason, poly = checkFootprint(ctx, domain, pose, a)
				if ok then
					commit(ctx, domain, pose, a, { Pass = "Border" }, footprintCenter(surface, pose), MathUtil.polygonArea(poly))
					ctx.Diagnostics:snap(pose.BoxCFrame.Position)
				else
					ctx.Diagnostics:reject(reason, pose.BoxCFrame.Position)
				end
			end
		end
		ctx.Diagnostics:add("ModulesFitted", #fit.Items)
		ctx.Yield()
	end
end

local function gridPass(ctx, domain, budget, palette, rng)
	local S = ctx.Settings
	local cell = math.max(budget.TypicalRadius * 2 * S.SpacingScale * (1 + S.EmptySpaceRatio), 1)
	local nu = math.max(1, math.floor(domain.SizeU / cell))
	local nv = math.max(1, math.floor(domain.SizeV / cell))
	local cu = domain.SizeU / nu
	local cv = domain.SizeV / nv
	for i = 1, nu do
		for j = 1, nv do
			if ctx:remaining() <= 0 then
				return
			end
			local center = Vector2.new(domain.U0 + (i - 0.5) * cu, domain.V0 + (j - 0.5) * cv)
			local n = RandomGenerator.noise2D(domain.NoiseSeed, center.X / (cell * 3), center.Y / (cell * 3))
			local keep = n >= S.EmptySpaceRatio * 0.9 and rng:next() < 0.35 + 0.65 * S.Density
			if keep then
				placeOne(ctx, domain, {
					Palette = palette,
					Candidates = 3,
					Sampler = function(r)
						local jit = S.Randomness * 0.3
						return center + Vector2.new((r:next() - 0.5) * cu * jit, (r:next() - 0.5) * cv * jit)
					end,
					Profile = {},
					Pass = "Grid",
					NoMirror = true,
				}, rng)
			end
		end
		ctx.Yield()
	end
end

local function scatterPass(ctx, domain, budget, palette, rng, sizeClasses, sampler, edgeAffinity, countFactor)
	local S = ctx.Settings
	local state = ctx:surfaceState(domain.Surface)
	local failures = 0
	local guard = 0
	local placed = 0
	local target = math.floor(budget.Fillers * (countFactor or 1) + 0.5)
	while placed < target and domain.Coverage < domain.CoverageLimit and failures < COMP.MAX_CONSECUTIVE_FAILURES and ctx:remaining() > 0 do
		guard += 1
		if guard > Config.Performance.HARD_MAX_ASSETS then
			break
		end
		local useCluster = #state.Clusters > 0 and rng:chance(S.ClusterStrength * 0.75)
		local s = sampler
		local clusterId = nil
		if useCluster then
			local c = state.Clusters[rng:int(1, #state.Clusters)]
			clusterId = c.Id
			s = function(r, _, radius)
				return ringSampler(c.Center, c.Radius * 0.6 + radius, c.Radius * 1.8 + radius * 2)(r)
			end
		end
		local item = placeOne(ctx, domain, {
			Palette = palette,
			SizeClasses = sizeClasses,
			Sampler = s,
			Profile = {
				EmptyWeight = 1,
				RhythmWeight = 0.6,
				BalanceWeight = 0.4,
				EdgeAffinity = edgeAffinity,
				CenterAvoid = domain.CenterAvoid,
			},
			ClusterId = clusterId,
			Pass = "Scatter",
		}, rng)
		if item then
			failures = 0
			placed += 1
		else
			failures += 1
		end
		ctx.Yield()
	end
end

-- Point focal unique pour une surface minuscule.
local function focalPass(ctx, domain, palette, rng)
	local center = domain.Center
	placeOne(ctx, domain, {
		Palette = palette,
		IgnoreFrequency = true,
		Sampler = function(r)
			local j = domain.MinExtent * 0.1
			return center + Vector2.new((r:next() - 0.5) * j, (r:next() - 0.5) * j)
		end,
		Profile = {},
		Pass = "Focal",
		NoMirror = true,
	}, rng)
end

-- Point d'entrée ----------------------------------------------------------------------------

function FloorPlacementEngine.run(ctx, surface, algorithmOverride)
	local S = ctx.Settings
	local rng = ctx.Rng:fork("floor:" .. surface.Id)
	local domain = buildDomain(ctx, surface, rng)
	if not domain then
		ctx.Diagnostics:warn(string.format("Floor %s is too small after margins.", surface.Id))
		return
	end
	domain.IgnoreParts = { [surface.Part] = true }
	domain.AlignToSurface = S.AlignToSlopes
	domain.NoiseSeed = rng:nextUInt32()
	domain.ClusterCount = 0
	domain.Coverage = 0

	local palette = ctx.Selector:palette(surface, { "Floor", "LargeStructure" }, rng:fork("palette"))
	if #palette == 0 then
		ctx.Diagnostics:warn("No floor asset available in the library (check PlacementType attributes).")
		return
	end
	-- Assets trop grands pour cette surface : signalés (jamais posés).
	local oversize = 0
	for _, a in ipairs(palette) do
		local minScale = if a.Meta.AllowScale then math.min(1, a.Meta.MinScale or 1) else 1
		if math.min(a.Size.X, a.Size.Z) * minScale > domain.MinExtent then
			oversize += 1
		end
	end
	if oversize > 0 then
		ctx.Diagnostics:add("TooLarge", oversize)
		ctx.Diagnostics:warn(string.format("%d asset(s) are larger than floor %s and were skipped.", oversize, surface.Id))
	end
	local hasClear = registerClearZones(ctx, domain)
	local area = domain.SizeU * domain.SizeV
	if hasClear then
		for _, poly in ipairs(domain.ClearZones) do
			area -= MathUtil.polygonArea(poly)
		end
		area = math.max(area, 0)
	end
	local algorithm = algorithmOverride or S.FloorAlgorithm
	if surface.Role == "Slope" then
		algorithm = "Scatter"
	end
	local budget = CompositionPlanner.floorBudget(S, area, palette, algorithm)
	domain.CoverageLimit = area * budget.CoverageTarget
	domain.HeroCount = 0
	domain.HeroCap = budget.HeroClassCap
	local aspect = domain.MaxExtent / math.max(domain.MinExtent, 1e-3)
	local corridor = aspect >= COMP.CORRIDOR_ASPECT
	domain.CenterAvoid = if corridor then 0.6 elseif S.KeepCenterClear then 0.3 else 0
	local hasWalls = #domain.WallLines > 0
	local typicalArea = (budget.TypicalRadius * 2) ^ 2

	if area < math.max(COMP.TINY_AREA, typicalArea * 3) then
		focalPass(ctx, domain, palette, rng)
		return
	end

	local wallLines = if #domain.WallLines > 0 then domain.WallLines else domain.EdgeLines
	if algorithm == "HeroComposition" then
		heroPass(ctx, domain, budget, palette, rng, if hasWalls then 0.2 else 0)
	elseif algorithm == "Cluster" then
		heroPass(ctx, domain, budget, palette, rng, 0)
		clusterPass(ctx, domain, budget, palette, rng, 0, uniformSampler(domain))
		scatterPass(ctx, domain, budget, palette, rng, SMALL_CLASSES, uniformSampler(domain), 0)
	elseif algorithm == "EdgeDecoration" then
		edgePass(ctx, domain, budget, palette, rng, domain.EdgeLines, 0.8)
		scatterPass(ctx, domain, budget, palette, rng, nil, edgeBandSampler(domain, domain.EdgeLines), 0.8, 0.6)
	elseif algorithm == "Scatter" then
		scatterPass(ctx, domain, budget, palette, rng, nil, uniformSampler(domain), 0)
	elseif algorithm == "Grid" then
		gridPass(ctx, domain, budget, palette, rng)
	elseif algorithm == "Border" then
		borderPass(ctx, domain, palette, rng, domain.EdgeLines)
	else
		-- Hybrid : décision automatique selon la forme de la zone.
		if corridor then
			edgePass(ctx, domain, budget, palette, rng, wallLines, 0.75)
			scatterPass(ctx, domain, budget, palette, rng, SMALL_CLASSES, edgeBandSampler(domain, wallLines), 0.5, 0.6)
		elseif hasWalls then
			heroPass(ctx, domain, budget, palette, rng, 0.35)
			edgePass(ctx, domain, budget, palette, rng, domain.WallLines, 0.55)
			clusterPass(ctx, domain, budget, palette, rng, 0.2, uniformSampler(domain))
			scatterPass(ctx, domain, budget, palette, rng, SMALL_CLASSES, uniformSampler(domain), 0.25, 0.8)
		else
			heroPass(ctx, domain, budget, palette, rng, 0)
			clusterPass(ctx, domain, budget, palette, rng, 0, uniformSampler(domain))
			scatterPass(ctx, domain, budget, palette, rng, SMALL_CLASSES, uniformSampler(domain), 0)
		end
	end
end

FloorPlacementEngine._buildDomain = buildDomain

--[[
	Rectangles de zone centrale d'un sol (repère de la surface), hors génération :
	utilisé par "Create Center Exclusion Zone" pour matérialiser la zone en Part.
	Renvoie une liste de { U0, V0, U1, V1 } bornés à la surface.
]]
function FloorPlacementEngine.centerZoneRects(surface, settings)
	local fakeCtx = {
		Settings = settings,
		facadeDepth = function()
			return 0
		end,
	}
	local domain = buildDomain(fakeCtx, surface, RandomGenerator.new(0))
	if not domain then
		return {}
	end
	local rects = {}
	for _, poly in ipairs(computeClearZones(domain, settings, true)) do
		local u0, v0, u1, v1 = MathUtil.polygonBounds(poly)
		u0, u1 = math.max(u0, surface.UMin), math.min(u1, surface.UMax)
		v0, v1 = math.max(v0, surface.VMin), math.min(v1, surface.VMax)
		if u1 - u0 > 0.1 and v1 - v0 > 0.1 then
			table.insert(rects, { U0 = u0, V0 = v0, U1 = u1, V1 = v1 })
		end
	end
	return rects
end

return FloorPlacementEngine
