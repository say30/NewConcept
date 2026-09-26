--[[
	ArchitectureEngine
	Construit une façade architecturale DEVANT un mur de référence, sans jamais
	modifier ce mur :

	  COVER   : façade modulaire complète (rangées de modules) devant le mur.
	  REBUILD : structure complète : soubassement, piliers, travées de modules,
	            arches, corniche, détails dans les travées (et, si autorisé,
	            masquage réversible du mur d'origine).

	Étapes pour chaque mur :
	  1. Plage utile U : découpée aux coins ; si le mur voisin possède déjà une
	     façade, on s'arrête devant elle (joint "bout à bout" : ni trou, ni
	     chevauchement dans l'angle).
	  2. Segmentation autour des zones d'exclusion (porte, passage...).
	  3. Architectural : travées égales entre piliers (espacement PillarSpacing),
	     les modules courent de centre de pilier à centre de pilier (les joints
	     sont cachés par les piliers). Modular : un seul remplissage par segment.
	  4. Rangées empilées pour couvrir la hauteur (murs très hauts), chaque
	     rangée remplie EXACTEMENT par ModularFitter.
	  5. Piliers empilés par Snap_Bottom/Snap_Top si plus courts que le mur.
	  6. Soubassement et corniche continus (modules étirables acceptés).
	  7. Détails centrés dans les travées (symétriques).
	Couches de profondeur : chaque couche est avancée de n × SURFACE_EPSILON.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local PlacementMath = require(script.Parent.PlacementMath)
local SnapEngine = require(script.Parent.SnapEngine)
local ModularFitter = require(script.Parent.ModularFitter)
local ExclusionZones = require(script.Parent.ExclusionZones)
local WallPlacementEngine = require(script.Parent.WallPlacementEngine)

local ArchitectureEngine = {}

local ARCH = Config.Architecture
local F = Config.Fitting
local A = Config.Assets
local TOL = Config.Precision.CONTACT_TOLERANCE

local function canonSize(asset, scale)
	local cmin, cmax = PlacementMath.wallCanonBounds(asset, scale, asset.WallYaw, nil)
	return cmax - cmin
end

local function moduleEntry(ctx, asset, dev)
	local S = ctx.Settings
	local conn = SnapEngine.horizontalConnectors(asset, 1, asset.WallYaw, nil)
	local allowScale = S.AllowModuleScaling and asset.Meta.AllowScale
	return {
		Key = asset.Key,
		Width = conn.Width,
		Weight = asset.Meta.Weight,
		Scalable = allowScale and dev > 0,
		MinFactor = asset.Meta.MinScale,
		MaxFactor = asset.Meta.MaxScale,
		Stretchable = asset.StretchPart ~= nil,
		MaxStretch = F.MAX_STRETCH,
		MinStretch = F.MIN_STRETCH,
		IsFiller = (asset.RoleScores.Filler or 0) >= A.ROLE_SCORE_THRESHOLD,
		Data = asset,
	}
end

-- Regroupe des assets par hauteur (rangées homogènes).
local function heightGroups(assets)
	local sorted = table.clone(assets)
	table.sort(sorted, function(a, b)
		local ha, hb = canonSize(a, 1).Y, canonSize(b, 1).Y
		if math.abs(ha - hb) > 1e-6 then
			return ha > hb
		end
		return a.Order < b.Order
	end)
	local groups = {}
	for _, a in ipairs(sorted) do
		local h = canonSize(a, 1).Y
		local g = groups[#groups]
		if g and h >= g.Height * (1 - F.HEIGHT_BUCKET_TOLERANCE) then
			table.insert(g.Assets, a)
		else
			table.insert(groups, { Height = h, Assets = { a } })
		end
	end
	return groups
end

-- Place les éléments d'un remplissage horizontal ; renvoie (hauteur de rangée, profondeur max, nb placés).
local function placeRow(ctx, wall, fit, segStart, vBottom, layer, meta)
	local eps = ctx.Epsilon
	local rowHeight, maxDepth, placed = 0, 0, 0
	for _, it in ipairs(fit.Items) do
		local asset = it.Module.Data
		local scale = it.Factor * (meta.BaseScale or 1)
		local stretch = nil
		if it.Stretch and math.abs(it.Stretch - 1) > 1e-9 then
			stretch = { Axis = PlacementMath.wallAlongAxis(asset.WallYaw), Factor = it.Stretch }
		end
		local conn = SnapEngine.horizontalConnectors(asset, scale, asset.WallYaw, stretch)
		local uStart = segStart + fit.StartOffset + it.Start
		local depth = (meta.DepthBase or 0) + layer * eps + asset.Meta.WallOffset
		local anchorY = meta.AnchorY or "Bottom"
		local pose = PlacementMath.wallPose(asset, scale, wall, uStart, vBottom, {
			AnchorXValue = conn.Start,
			AnchorY = anchorY,
			Depth = depth,
			Stretch = stretch,
		})
		local size = pose.CanonMax - pose.CanonMin
		local poly = PlacementMath.footprint(pose, wall)
		if ctx.Zones:blocks(wall, poly) then
			ctx.Diagnostics:reject("exclusion", pose.BoxCFrame.Position)
		else
			local item = ctx:tryCommit(pose, {
				Surface = wall,
				Role = "Architecture",
				Folder = "Architecture",
				PlacementType = meta.PlacementType,
				Group = "Architecture",
				AllowArchitectureOverlap = true,
				Layer = layer,
				IgnoreParts = meta.IgnoreParts,
				Pass = meta.Pass,
			})
			if item then
				placed += 1
				rowHeight = math.max(rowHeight, size.Y)
				maxDepth = math.max(maxDepth, depth + size.Z)
				ctx.Diagnostics:snap(SnapEngine.connectorWorld(wall, pose, conn.StartPoint))
				ctx.Diagnostics:snap(SnapEngine.connectorWorld(wall, pose, conn.EndPoint))
			end
		end
	end
	ctx.Diagnostics:add("ModulesFitted", placed)
	return rowHeight, maxDepth, placed
end

local function fitOptions(ctx, rng, endsFlush)
	local S = ctx.Settings
	return {
		AllowScale = S.AllowModuleScaling,
		MaxDeviation = S.MaxModuleScaleDeviation,
		AllowGaps = false,
		EndsFlush = endsFlush ~= false,
		Symmetric = S.Symmetry >= 0.5,
		Rng = rng,
		Variety = S.Variation,
		AllowFillers = true,
	}
end

-- Remplit un intervalle [u0, u1] par des rangées empilées de modules.
local function fillInterval(ctx, wall, u0, u1, groups, preferredFirst, rng, meta)
	local S = ctx.Settings
	local dev = if S.AllowModuleScaling then S.MaxModuleScaleDeviation else 0
	local length = u1 - u0
	local v = wall.VMin
	local remaining = wall.VMax - wall.VMin
	local maxDepth = 0
	local coveredHeight = 0
	local minGroupHeight = math.huge
	for _, g in ipairs(groups) do
		minGroupHeight = math.min(minGroupHeight, g.Height)
	end
	local rowIndex = 0
	local guard = 0
	while remaining > minGroupHeight * ARCH.MIN_ROW_FILL and guard < 64 do
		guard += 1
		rowIndex += 1
		local ordered = {}
		if rowIndex == 1 and preferredFirst then
			table.insert(ordered, preferredFirst)
		end
		for _, g in ipairs(groups) do
			if g ~= preferredFirst then
				table.insert(ordered, g)
			end
		end
		local done = false
		for _, g in ipairs(ordered) do
			if g.Height * (1 - dev) <= remaining + TOL then
				-- Le facteur d'échelle horizontal agrandit aussi la hauteur : il est
				-- borné pour que la rangée ne dépasse jamais le haut du mur.
				local modules = {}
				for _, a in ipairs(g.Assets) do
					if ctx:assetAvailable(a) then
						local entry = moduleEntry(ctx, a, dev)
						local h = canonSize(a, 1).Y
						local heightCap = (remaining + TOL * 0.5) / math.max(h, 1e-6)
						if heightCap >= 1 or (entry.Scalable and heightCap >= 1 - dev) then
							entry.MaxFactor = math.min(entry.MaxFactor or math.huge, heightCap)
							table.insert(modules, entry)
						end
					end
				end
				local fit = ModularFitter.fit(length, modules, fitOptions(ctx, rng:fork("row" .. rowIndex .. g.Height), true))
				if #fit.Items > 0 then
					-- Hauteur réelle de la rangée après mise à l'échelle.
					local rowH = 0
					for _, it in ipairs(fit.Items) do
						rowH = math.max(rowH, canonSize(it.Module.Data, it.Factor).Y)
					end
					if rowH <= remaining + TOL then
						local h, depth, placed = placeRow(ctx, wall, fit, u0, v, ARCH.LAYER_MODULE, meta)
						if placed > 0 then
							v += h
							remaining -= h
							coveredHeight += h
							maxDepth = math.max(maxDepth, depth)
							if fit.Method == "margin-large" then
								ctx.Diagnostics:warn(string.format("Wall %s: modules could not fill %.2f studs exactly (enable module scaling or add filler/stretchable modules).", wall.Id, fit.Residual))
							end
							done = true
							break
						end
					end
				end
			end
		end
		if not done then
			break
		end
		if not meta.MultiRow then
			break
		end
		ctx.Yield()
	end
	return coveredHeight, maxDepth
end

-- Pilier (éventuellement empilé) centré sur u.
local function placePillar(ctx, wall, pillar, u, targetHeight, moduleDepth, rng, ignore)
	local S = ctx.Settings
	local eps = ctx.Epsilon
	local dev = if S.AllowModuleScaling then S.MaxModuleScaleDeviation else 0
	local conn = SnapEngine.verticalConnectors(pillar, 1, pillar.WallYaw)
	local h = conn.Height
	if h <= 1e-3 then
		return 0
	end
	local count, scale
	if h >= targetHeight then
		scale = targetHeight / h
		count = 1
		local minScale = pillar.Meta.MinScale or (1 - dev * 2)
		if not pillar.Meta.AllowScale or scale < minScale then
			return 0
		end
	else
		count = math.max(1, math.floor(targetHeight / h + 0.5))
		scale = targetHeight / (count * h)
		if math.abs(scale - 1) > dev or not pillar.Meta.AllowScale then
			count = math.max(1, math.floor(targetHeight / h))
			scale = 1
		end
	end
	local size = canonSize(pillar, scale)
	local pillarDepth = size.Z
	local depth
	if pillarDepth > moduleDepth + ARCH.PILLAR_DEPTH_MARGIN then
		depth = ARCH.LAYER_PILLAR * eps
	else
		depth = moduleDepth + ARCH.LAYER_PILLAR * eps
	end
	depth += pillar.Meta.WallOffset
	local vconn = SnapEngine.verticalConnectors(pillar, scale, pillar.WallYaw)
	local positions = SnapEngine.stackPositions(vconn, wall.VMin, count)
	local placed = 0
	for i, vAnchor in ipairs(positions) do
		local pose = PlacementMath.wallPose(pillar, scale, wall, u, vAnchor, {
			AnchorX = "Center",
			AnchorYValue = vconn.Bottom,
			Depth = depth,
		})
		local poly = PlacementMath.footprint(pose, wall)
		if not ctx.Zones:blocks(wall, poly) then
			local item = ctx:tryCommit(pose, {
				Surface = wall,
				Role = "Architecture",
				Folder = "Architecture",
				PlacementType = "Pillar",
				Group = "Architecture",
				AllowArchitectureOverlap = true,
				Layer = ARCH.LAYER_PILLAR,
				IgnoreParts = ignore,
				Pass = "Pillar",
			})
			if item then
				placed += 1
				if i > 1 then
					ctx.Diagnostics:snap(pose.BoxCFrame.Position)
				end
			end
		end
	end
	return placed, depth + pillarDepth, size.X
end

-- Bordure continue (soubassement / corniche).
local function placeTrim(ctx, wall, u0, u1, assets, anchorY, depthBase, rng, ignore, placementType)
	local S = ctx.Settings
	local dev = if S.AllowModuleScaling then S.MaxModuleScaleDeviation else 0
	local height = wall.VMax - wall.VMin
	local modules = {}
	for _, a in ipairs(assets) do
		if canonSize(a, 1).Y <= height * 0.25 and ctx:assetAvailable(a) then
			table.insert(modules, moduleEntry(ctx, a, dev))
		end
	end
	if #modules == 0 then
		return 0
	end
	local fit = ModularFitter.fit(u1 - u0, modules, fitOptions(ctx, rng, true))
	if #fit.Items == 0 then
		return 0
	end
	local v = if anchorY == "Top" then wall.VMax else wall.VMin
	local _, depth = placeRow(ctx, wall, fit, u0, v, ARCH.LAYER_TRIM, {
		DepthBase = depthBase,
		AnchorY = anchorY,
		PlacementType = placementType,
		IgnoreParts = ignore,
		Pass = placementType,
	})
	return depth
end

--[[
	opts = { Treatment = "Cover" | "Rebuild", Mode = "Modular" | "Architectural" }
	Renvoie true si une façade a été construite.
]]
function ArchitectureEngine.run(ctx, wall, opts)
	local S = ctx.Settings
	local registry = ctx.Registry
	local rng = ctx.Rng:fork("arch:" .. wall.Id)
	local dev = if S.AllowModuleScaling then S.MaxModuleScaleDeviation else 0

	-- 1) Plage utile : arrêt devant la façade d'un mur voisin déjà construit.
	local u0, u1 = wall.UMin, wall.UMax
	for _, side in ipairs({ "Min", "Max" }) do
		local e = wall.Ends[side]
		if e.Type == "Corner" and ctx.Facades[e.Other] then
			local denom = wall.U:Dot(e.Other.Normal)
			if math.abs(denom) > 0.3 then
				local shift = ctx.Facades[e.Other].Depth / denom
				if side == "Min" then
					u0 = math.max(u0, wall.UMin + shift)
				else
					u1 = math.min(u1, wall.UMax + shift)
				end
			end
		end
	end
	local height = wall.VMax - wall.VMin
	if u1 - u0 < Config.Geometry.MIN_SURFACE_EXTENT or height < Config.Geometry.MIN_SURFACE_EXTENT then
		return false
	end

	local ignore = { [wall.Part] = true }
	if wall.SupportFloor then
		ignore[wall.SupportFloor.Part] = true
	end
	if wall.CeilingAbove then
		ignore[wall.CeilingAbove.Part] = true
	end

	-- 2) Assets disponibles.
	local function usable(role, maxHeightFactor)
		local list = {}
		for _, a in ipairs(registry:getByRole(role)) do
			local size = canonSize(a, 1)
			if size.Y <= height * (maxHeightFactor or (1 + dev)) and size.X > 1e-3 then
				table.insert(list, a)
			end
		end
		return list
	end
	local modulesAll = usable("WallModule")
	local arches = usable("Arch")
	local pillars = usable("Pillar", 1e9)
	local tops = usable("WallTop")
	local bases = usable("WallBase")
	local isArchitectural = opts.Mode == "Architectural"

	if #modulesAll == 0 and not (isArchitectural and #pillars > 0) and #tops == 0 and #bases == 0 then
		ctx.Diagnostics:warn(string.format("Wall %s: no WallModule / Pillar / WallTop / WallBase asset available for %s.", wall.Id, opts.Treatment))
		return false
	end
	-- Les arches ne servent pas de modules standards.
	local standard = {}
	for _, a in ipairs(modulesAll) do
		if not table.find(arches, a) or #modulesAll == #arches then
			table.insert(standard, a)
		end
	end
	local groups = heightGroups(standard)
	local archGroups = heightGroups(arches)

	-- 3) Segmentation autour des zones d'exclusion.
	local minWidth = math.huge
	for _, a in ipairs(standard) do
		minWidth = math.min(minWidth, SnapEngine.horizontalConnectors(a, 1, a.WallYaw).Width)
	end
	if minWidth == math.huge then
		minWidth = Config.Geometry.MIN_SURFACE_EXTENT
	end
	local blocked = ctx.Zones:blockedIntervalsU(wall, wall.VMin, wall.VMax)
	local segments = ExclusionZones.subtractIntervals(u0, u1, blocked, minWidth * (1 - dev))
	for _, seg in ipairs(segments) do
		ctx.Diagnostics:segment(wall.Frame:PointToWorldSpace(Vector3.new(seg[1], 0.05, wall.VMin)), wall.Frame:PointToWorldSpace(Vector3.new(seg[1], 0.05, wall.VMax)))
		ctx.Diagnostics:segment(wall.Frame:PointToWorldSpace(Vector3.new(seg[2], 0.05, wall.VMin)), wall.Frame:PointToWorldSpace(Vector3.new(seg[2], 0.05, wall.VMax)))
	end

	local moduleDepth = 0
	local facadeDepth = 0
	local coveredArea = 0
	local bays = {}
	local multiRow = true

	-- Largeur de pilier de référence (pour les travées).
	local pillarAsset = nil
	if isArchitectural and #pillars > 0 then
		pillarAsset = ctx.Selector:pick(pillars, { Role = "Pillar", Rng = rng, IgnoreFrequency = true })
	end

	for si, seg in ipairs(segments) do
		local segRng = rng:fork("seg" .. si)
		local s0, s1 = seg[1], seg[2]
		local segLength = s1 - s0
		if isArchitectural and pillarAsset then
			-- 4a) Travées égales entre piliers.
			local pw = canonSize(pillarAsset, 1).X
			if segLength < pw * 1.5 then
				continue
			end
			local n = math.max(1, math.floor((segLength - pw) / S.PillarSpacing + 0.5))
			local centers = {}
			local cStart = s0 + pw * 0.5
			local cEnd = s1 - pw * 0.5
			for i = 0, n do
				table.insert(centers, cStart + (cEnd - cStart) * (i / n))
			end
			-- Motif d'arches : travée centrale (symétrie) ou rythme régulier.
			local archBays = {}
			if #arches > 0 then
				if S.Symmetry >= 0.5 then
					if n % 2 == 1 then
						archBays[(n + 1) / 2] = true
					else
						archBays[n / 2] = true
						archBays[n / 2 + 1] = true
					end
				else
					local period = if S.VisualRhythm > 0.6 then 2 else 3
					local offset = segRng:int(0, period - 1)
					for b = 1, n do
						if (b + offset) % period == 0 and segRng:chance(math.max(ARCH.ARCH_BAY_RATIO, S.VisualRhythm)) then
							archBays[b] = true
						end
					end
				end
			end
			for b = 1, n do
				local bu0 = if b == 1 then s0 else centers[b]
				local bu1 = if b == n then s1 else centers[b + 1]
				-- Même graine pour des travées symétriques -> séquences identiques.
				local patternIndex = math.min(b, n + 1 - b)
				local bayRng = rng:fork("bay" .. patternIndex .. (if archBays[b] then "a" else "m") .. si)
				local preferred = nil
				local bayGroups = groups
				if archBays[b] and #archGroups > 0 then
					preferred = archGroups[1]
					bayGroups = table.clone(groups)
					table.insert(bayGroups, 1, archGroups[1])
				end
				if #bayGroups > 0 then
					local h, depth = fillInterval(ctx, wall, bu0, bu1, bayGroups, preferred, bayRng, {
						PlacementType = if archBays[b] then "Arch" else "WallModule",
						IgnoreParts = ignore,
						Pass = "Modules",
						MultiRow = multiRow,
					})
					moduleDepth = math.max(moduleDepth, depth)
					coveredArea += h * (bu1 - bu0)
				end
				table.insert(bays, { U0 = bu0, U1 = bu1, Center = (centers[b] + centers[b + 1]) * 0.5, Arch = archBays[b] == true, Index = b, Count = n })
			end
			-- Piliers (aux extrémités : sauf coin décoré par CornerEngine).
			for i, c in ipairs(centers) do
				local isEnd = i == 1 or i == #centers
				local skip = false
				if isEnd and S.CornerDecoration then
					local side = if i == 1 then "Min" else "Max"
					local atSegmentEnd = (i == 1 and math.abs(s0 - u0) < 1e-6) or (i == #centers and math.abs(s1 - u1) < 1e-6)
					if atSegmentEnd and wall.Ends[side].Type == "Corner" and #registry:getByRole("Corner") > 0 then
						skip = true
					end
				end
				if not skip then
					local p = pillarAsset
					if not ctx:assetAvailable(p) then
						p = ctx.Selector:pick(pillars, { Role = "Pillar", Rng = segRng, IgnoreFrequency = true })
					end
					if p then
						local _, depth = placePillar(ctx, wall, p, c, height, moduleDepth, segRng, ignore)
						if depth then
							facadeDepth = math.max(facadeDepth, depth)
						end
					end
				end
			end
		elseif #groups > 0 then
			-- 4b) Mur modulaire : remplissage continu du segment.
			local h, depth = fillInterval(ctx, wall, s0, s1, groups, nil, segRng, {
				PlacementType = "WallModule",
				IgnoreParts = ignore,
				Pass = "Modules",
				MultiRow = multiRow,
			})
			moduleDepth = math.max(moduleDepth, depth)
			coveredArea += h * segLength
			-- Travées virtuelles pour les détails : une par module de la première rangée.
			local count = math.max(1, math.floor(segLength / math.max(S.PillarSpacing, 1) + 0.5))
			for b = 1, count do
				local a = s0 + segLength * (b - 1) / count
				local z = s0 + segLength * b / count
				table.insert(bays, { U0 = a, U1 = z, Center = (a + z) * 0.5, Arch = false, Index = b, Count = count })
			end
		end
		ctx.Yield()
	end
	facadeDepth = math.max(facadeDepth, moduleDepth)

	-- 5) Soubassement et corniche (en avant des modules).
	for si, seg in ipairs(segments) do
		if S.BaseDecoration and #bases > 0 then
			local d = placeTrim(ctx, wall, seg[1], seg[2], bases, "Bottom", moduleDepth, rng:fork("base" .. si), ignore, "WallBase")
			facadeDepth = math.max(facadeDepth, d)
		end
		if S.TopDecoration and #tops > 0 then
			local d = placeTrim(ctx, wall, seg[1], seg[2], tops, "Top", moduleDepth, rng:fork("top" .. si), ignore, "WallTop")
			facadeDepth = math.max(facadeDepth, d)
		end
	end

	if facadeDepth <= 0 then
		return false
	end
	ctx.Facades[wall] = {
		Depth = facadeDepth,
		ModuleDepth = moduleDepth,
		U0 = u0,
		U1 = u1,
		Bays = bays,
	}

	-- 6) Détails dans les travées : rythme régulier (toutes les travées, une sur
	--    deux ou une sur trois selon WallDensity), motif symétrique, un ou deux
	--    assets cohérents pour toute la façade.
	local detailPalette = ctx.Selector:palette(wall, { "Relief", "Wall" }, rng:fork("details"))
	if #detailPalette > 0 and S.WallDensity > 0.05 and #bays > 0 then
		local detailRng = rng:fork("detailPick")
		local period = if S.WallDensity >= 0.66 then 1 elseif S.WallDensity >= 0.33 then 2 else 3
		local phase = if period > 1 then detailRng:int(0, period - 1) else 0
		local minBayWidth = math.huge
		for _, bay in ipairs(bays) do
			minBayWidth = math.min(minBayWidth, bay.U1 - bay.U0)
		end
		local function pickDetail(exclude)
			return ctx.Selector:pick(detailPalette, {
				Role = "Relief",
				Rng = detailRng,
				Surface = wall,
				Exclude = exclude,
				Filter = function(a)
					local size = canonSize(a, 1)
					return size.X <= minBayWidth * 0.7 and size.Y <= height * 0.6
				end,
			})
		end
		local primary = pickDetail(nil)
		local secondary = nil
		if primary and S.Variation >= 0.5 then
			secondary = pickDetail({ [primary] = true })
		end
		for _, bay in ipairs(bays) do
			if not bay.Arch and primary then
				local pattern = math.min(bay.Index, bay.Count + 1 - bay.Index)
				if (pattern - 1 + phase) % period == 0 then
					local asset = if secondary and pattern % 2 == 0 then secondary else primary
					if ctx:assetAvailable(asset) then
						local scale = PlacementMath.resolveScale(asset, S, rng:fork("detailScale" .. pattern))
						WallPlacementEngine.placeAt(ctx, wall, asset, scale, bay.Center, wall.VMin + height * ARCH.DETAIL_HEIGHT, "Center", {
							Layer = ARCH.LAYER_DETAIL,
							Folder = "Architecture",
							PlacementType = "Detail",
							Pass = "Details",
						})
					end
				end
			end
		end
	end

	-- 7) Masquage réversible du mur d'origine (Rebuild + option explicite).
	local wallArea = (wall.UMax - wall.UMin) * height
	if opts.Treatment == "Rebuild" and S.HideOriginalWalls and wallArea > 0 then
		if coveredArea / wallArea >= 0.85 then
			ctx.HiddenWalls = ctx.HiddenWalls or {}
			if not table.find(ctx.HiddenWalls, wall.Part) then
				table.insert(ctx.HiddenWalls, wall.Part)
			end
		else
			ctx.Diagnostics:warn(string.format("Wall %s kept visible: the generated facade covers only %d%% of it.", wall.Id, math.floor(coveredArea / wallArea * 100)))
		end
	end
	return true
end


return ArchitectureEngine
