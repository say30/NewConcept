--[[
	WallPlacementEngine
	Décorations ponctuelles sur les murs (Wall Props) et reliefs (Wall Relief).

	  - Répartition horizontale par séquence rythmique (CompositionPlanner.beats),
	    symétrique autour du centre du mur si Symmetry est élevé.
	  - Hauteur : PreferredHeight (fraction si <= 1, sinon studs au-dessus du
	    pied du mur), sinon selon la forme : reliefs à mi-hauteur, props à
	    hauteur d'homme, éléments élancés suspendus depuis le haut. Les murs très
	    hauts reçoivent une rangée supérieure de reliefs.
	  - L'arrière de l'asset est posé contre le mur à SURFACE_EPSILON près. Si une
	    façade a été générée devant ce mur, sa profondeur réelle au point de pose
	    est mesurée par lancer de rayons sur la géométrie planifiée : le détail
	    se pose sur la façade, sans la traverser.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local PlacementMath = require(script.Parent.PlacementMath)
local CompositionPlanner = require(script.Parent.CompositionPlanner)

local WallPlacementEngine = {}

local COMP = Config.Composition
local ARCH = Config.Architecture
local TOL = Config.Precision.CONTACT_TOLERANCE

local LARGE_CLASSES = { Large = true, Hero = true }
local MEDIUM_CLASSES = { Medium = true }
local SMALL_CLASSES = { Small = true }

-- Profondeur de la façade générée devant le mur, mesurée sur l'empreinte arrière de l'asset.
function WallPlacementEngine.facadeDepthAt(ctx, wall, u0, u1, v0, v1)
	if not ctx.Facades[wall] then
		return 0
	end
	local start = ARCH.DETAIL_RAY_START
	local best = 0
	local samples = {
		{ (u0 + u1) * 0.5, (v0 + v1) * 0.5 },
		{ u0, v0 }, { u1, v0 }, { u0, v1 }, { u1, v1 },
		{ (u0 + u1) * 0.5, v0 }, { (u0 + u1) * 0.5, v1 },
	}
	for _, s in ipairs(samples) do
		local origin = wall.Frame:PointToWorldSpace(Vector3.new(s[1], start, s[2]))
		local dist = ctx.Collision:raycastPlanned(origin, -wall.Normal, start + 1, function(record)
			return record.Group == "Architecture" and record.Surface == wall
		end)
		if dist then
			best = math.max(best, start - dist)
		end
	end
	return best
end

-- Hauteur cible (coordonnée v) d'un asset sur un mur.
local function targetHeight(wall, asset, scale, rowFraction)
	local vMin, vMax = wall.VMin, wall.VMax
	local h = vMax - vMin
	local cmin, cmax = PlacementMath.wallCanonBounds(asset, scale, asset.WallYaw, nil)
	local assetH = cmax.Y - cmin.Y
	local pref = asset.Meta.PreferredHeight
	if pref then
		local v = if pref <= 1 then vMin + h * pref else vMin + pref
		return v, "Center"
	end
	if rowFraction then
		return vMin + h * rowFraction, "Center"
	end
	-- Élément élancé : suspendu depuis le haut du mur.
	if asset.Shape == "Relief" and assetH > (cmax.X - cmin.X) * 1.4 then
		return vMax - COMP.WALL_HANGING_TOP_MARGIN, "Top"
	end
	if asset.Shape == "Relief" or asset.Shape == "Panel" then
		return vMin + h * COMP.WALL_RELIEF_DEFAULT_HEIGHT, "Center"
	end
	-- Props : hauteur relative, plafonnée à une hauteur "humaine" sur les grands murs.
	local maxAbs = assetH * 2.5 + 4
	return vMin + math.min(h * COMP.WALL_PROP_DEFAULT_HEIGHT, maxAbs), "Center"
end

-- Tente de poser un asset au point (u, v) d'un mur ; renvoie l'item ou nil.
function WallPlacementEngine.placeAt(ctx, wall, asset, scale, u, v, anchorY, opts)
	opts = opts or {}
	local S = ctx.Settings
	local eps = ctx.Epsilon
	local cmin, cmax = PlacementMath.wallCanonBounds(asset, scale, asset.WallYaw, nil)
	local w = cmax.X - cmin.X
	local h = cmax.Y - cmin.Y
	-- Rectangle de l'asset dans le repère du mur.
	local vBottom
	if anchorY == "Top" then
		vBottom = v - h
	elseif anchorY == "Bottom" then
		vBottom = v
	else
		vBottom = v - h * 0.5
	end
	-- Recadrage vertical dans la plage utile.
	if vBottom < wall.VMin then
		vBottom = wall.VMin
	end
	if vBottom + h > wall.VMax then
		vBottom = wall.VMax - h
	end
	if vBottom < wall.VMin - TOL then
		ctx.Diagnostics:reject("bounds", nil)
		return nil
	end
	local u0, u1 = u - w * 0.5, u + w * 0.5
	local margin = COMP.WALL_EDGE_MARGIN
	if u0 < wall.UMin + margin - TOL or u1 > wall.UMax - margin + TOL then
		ctx.Diagnostics:reject("bounds", nil)
		return nil
	end
	local facade = WallPlacementEngine.facadeDepthAt(ctx, wall, u0, u1, vBottom, vBottom + h)
	local layer = opts.Layer or ARCH.LAYER_PROP
	local depth = facade + layer * eps + asset.Meta.WallOffset + S.SurfaceOffset
	local pose = PlacementMath.wallPose(asset, scale, wall, u, vBottom, {
		AnchorX = "Center",
		AnchorY = "Bottom",
		Depth = depth,
	})
	local poly = PlacementMath.footprint(pose, wall)
	if ctx.Zones:blocks(wall, poly) then
		ctx.Diagnostics:reject("exclusion", pose.BoxCFrame.Position)
		return nil
	end
	local item, reason = ctx:tryCommit(pose, {
		Surface = wall,
		Role = "Wall",
		Folder = opts.Folder or "Wall",
		PlacementType = opts.PlacementType or (if asset.Shape == "Relief" then "Relief" else "Wall"),
		Group = opts.Group or "Decor",
		Layer = layer,
		IgnoreParts = { [wall.Part] = true },
		Pos2D = Vector2.new(u, vBottom + h * 0.5),
		Radius = w * 0.5,
		Pass = opts.Pass or "WallProps",
	})
	if item then
		ctx.Diagnostics:candidate(pose.BoxCFrame.Position)
	end
	return item, reason
end

--[[
	mode : "Props" | "Relief" | "Hybrid"
	densityFactor : multiplicateur de WallDensity (façades déjà décorées...)
]]
function WallPlacementEngine.run(ctx, wall, mode, densityFactor)
	local S = ctx.Settings
	local rng = ctx.Rng:fork("wall:" .. wall.Id)
	local length = wall.UMax - wall.UMin
	local height = wall.VMax - wall.VMin
	if length < Config.Geometry.MIN_SURFACE_EXTENT or height < Config.Geometry.MIN_SURFACE_EXTENT then
		return
	end
	local roles
	if mode == "Relief" then
		roles = { "Relief" }
	elseif mode == "Props" then
		roles = { "Wall" }
	else
		roles = { "Wall", "Relief" }
	end
	local palette = ctx.Selector:palette(wall, roles, rng:fork("palette"))
	if #palette == 0 then
		ctx.Diagnostics:warn("No wall asset available (PlacementType = Wall / Relief, or flat assets for auto mode).")
		return
	end
	-- Filtre : l'asset doit tenir sur le mur.
	local fitting = {}
	for _, a in ipairs(palette) do
		local cmin, cmax = PlacementMath.wallCanonBounds(a, 1, a.WallYaw, nil)
		local minScale = if a.Meta.AllowScale then math.min(1, a.Meta.MinScale or 1) else 1
		if (cmax.X - cmin.X) * minScale <= length - 2 * COMP.WALL_EDGE_MARGIN and (cmax.Y - cmin.Y) * minScale <= height then
			table.insert(fitting, a)
		else
			ctx.Diagnostics:add("TooLarge")
		end
	end
	if #fitting == 0 then
		return
	end
	local widths = {}
	for _, a in ipairs(fitting) do
		local cmin, cmax = PlacementMath.wallCanonBounds(a, 1, a.WallYaw, nil)
		table.insert(widths, cmax.X - cmin.X)
	end
	table.sort(widths)
	local typicalWidth = widths[math.ceil(#widths / 2)]

	local density = math.clamp(S.WallDensity * (densityFactor or 1), 0, 1)
	if density <= 0.01 then
		return
	end
	-- Rangées : principale + rangée haute sur les murs très hauts.
	local rows = { { Fraction = nil, Name = "Main" } }
	local medianHeight = 0
	for _, a in ipairs(fitting) do
		medianHeight += a.Size.Y
	end
	medianHeight /= #fitting
	if height > medianHeight * 4 and density > 0.3 then
		table.insert(rows, { Fraction = 0.78, Name = "Upper", ReliefOnly = true })
	end

	for ri, row in ipairs(rows) do
		local rowRng = rng:fork("row" .. ri)
		local beats = CompositionPlanner.beats(length, rowRng, S, {
			BaseSpacing = typicalWidth * (if mode == "Relief" then 1.6 else 2.2),
			Density = density,
			Symmetric = S.Symmetry >= 0.5,
			EndMargin = COMP.WALL_EDGE_MARGIN + typicalWidth * 0.3,
		})
		-- Asset imposé par position miroir pour une vraie symétrie.
		local mirrorAssets = {}
		for bi, beat in ipairs(beats) do
			if ctx:remaining() <= 0 then
				return
			end
			if beat.Kind ~= "Gap" then
				local classes = if beat.Kind == "Large" then LARGE_CLASSES elseif beat.Kind == "Medium" then MEDIUM_CLASSES else SMALL_CLASSES
				local asset
				local key = string.format("%.3f", math.abs(beat.T - length * 0.5))
				if beat.Mirror and mirrorAssets[key] then
					asset = mirrorAssets[key]
					if not ctx:assetAvailable(asset) then
						asset = nil
					end
				end
				if not asset then
					asset = ctx.Selector:pick(fitting, {
						Role = if mode == "Relief" then "Relief" else "Wall",
						SizeClasses = classes,
						Surface = wall,
						Rng = rowRng,
						Filter = function(a)
							if row.ReliefOnly and a.Shape ~= "Relief" then
								return false
							end
							return true
						end,
					}) or ctx.Selector:pick(fitting, {
						Role = if mode == "Relief" then "Relief" else "Wall",
						Surface = wall,
						Rng = rowRng,
					})
				end
				if asset then
					if not beat.Mirror then
						mirrorAssets[key] = asset
					end
					local scale = PlacementMath.resolveScale(asset, S, rowRng)
					local count = if beat.Kind == "SmallGroup" then rowRng:int(1, 2) else 1
					for j = 1, count do
						local v, anchorY = targetHeight(wall, asset, scale, row.Fraction)
						local jitterU = if beat.Mirror then 0 else (rowRng:next() - 0.5) * beat.Width * 0.3 * S.Randomness
						local jitterV = if anchorY == "Top" then 0 else (rowRng:next() - 0.5) * height * 0.08 * S.Randomness
						local u = wall.UMin + beat.T + jitterU
						if j > 1 then
							u += (rowRng:next() - 0.5) * beat.Width
							v += (rowRng:next() - 0.5) * height * 0.12
						end
						local _, reason = WallPlacementEngine.placeAt(ctx, wall, asset, scale, u, v + jitterV, anchorY, {
							Pass = "Wall" .. row.Name,
						})
						if reason then
							-- Nouvelle tentative, plus centrée dans le beat, sans jitter.
							WallPlacementEngine.placeAt(ctx, wall, asset, scale, wall.UMin + beat.T, v, anchorY, {
								Pass = "Wall" .. row.Name,
							})
						end
					end
				end
			end
			if bi % 8 == 0 then
				ctx.Yield()
			end
		end
	end
end


return WallPlacementEngine
