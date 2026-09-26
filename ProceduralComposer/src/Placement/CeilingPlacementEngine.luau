--[[
	CeilingPlacementEngine
	Éléments suspendus : lampes, câbles, chaînes, stalactites, tuyaux...

	La normale d'un plafond pointe vers le bas : la direction de pose est
	inversée automatiquement. L'asset reste "debout" (son haut vers le
	plafond) et sa face supérieure touche le plafond à SURFACE_EPSILON près ;
	CeilingFlip = true retourne l'asset (sa base contre le plafond).

	Répartition : rangées parallèles à la grande dimension, séquences
	rythmiques le long de chaque rangée, symétrie optionnelle. La hauteur de
	chute est limitée par la hauteur de la pièce.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local MathUtil = require(Core.MathUtil)
local PlacementMath = require(script.Parent.PlacementMath)
local CompositionPlanner = require(script.Parent.CompositionPlanner)

local CeilingPlacementEngine = {}

local COMP = Config.Composition
local ARCH = Config.Architecture
local TOL = Config.Precision.CONTACT_TOLERANCE

-- Hauteur libre sous le plafond (distance au sol le plus haut situé dessous).
local function roomHeight(ctx, ceiling)
	local best = math.huge
	local c = ceiling.Frame.Position
	for _, f in ipairs(ctx.Analysis.Floors) do
		local l = f.Frame:PointToObjectSpace(c)
		if l.X >= f.UMin and l.X <= f.UMax and l.Z >= f.VMin and l.Z <= f.VMax and l.Y > 0 then
			best = math.min(best, l.Y)
		end
	end
	return best
end

function CeilingPlacementEngine.run(ctx, ceiling)
	local S = ctx.Settings
	if not S.CeilingDecoration or S.CeilingDensity <= 0.01 then
		return
	end
	local rng = ctx.Rng:fork("ceiling:" .. ceiling.Id)
	local palette = ctx.Selector:palette(ceiling, { "Ceiling" }, rng:fork("palette"))
	if #palette == 0 then
		return
	end
	local eps = ctx.Epsilon
	local room = roomHeight(ctx, ceiling)
	local maxDrop = if room < math.huge then room * COMP.CEILING_MAX_DROP_RATIO else math.huge
	local margin = S.EdgeMargin
	local u0, u1 = ceiling.UMin + margin, ceiling.UMax - margin
	local v0, v1 = ceiling.VMin + margin, ceiling.VMax - margin
	if u1 - u0 < 1 or v1 - v0 < 1 then
		return
	end
	local fitting = {}
	for _, a in ipairs(palette) do
		if a.Size.Y <= maxDrop and a.Size.X <= u1 - u0 and a.Size.Z <= v1 - v0 then
			table.insert(fitting, a)
		else
			ctx.Diagnostics:add("TooLarge")
		end
	end
	if #fitting == 0 then
		return
	end
	local radii = {}
	for _, a in ipairs(fitting) do
		table.insert(radii, a.FootprintRadius)
	end
	table.sort(radii)
	local typical = radii[math.ceil(#radii / 2)]
	local spacing = typical * 2 * S.SpacingScale / math.max(S.CeilingDensity, 0.1)
	local rowCount = math.max(1, math.floor((v1 - v0) / math.max(spacing, 1) + 0.5))
	local rowCount2 = math.min(rowCount, 8)
	for r = 1, rowCount2 do
		local v = v0 + (v1 - v0) * (r - 0.5) / rowCount2
		local rowRng = rng:fork("row" .. math.min(r, rowCount2 + 1 - r))
		local beats = CompositionPlanner.beats(u1 - u0, rowRng, S, {
			BaseSpacing = typical * 2,
			Density = S.CeilingDensity,
			Symmetric = S.Symmetry >= 0.5,
			EndMargin = typical,
		})
		for _, beat in ipairs(beats) do
			if ctx:remaining() <= 0 then
				return
			end
			if beat.Kind ~= "Gap" then
				local asset = ctx.Selector:pick(fitting, { Role = "Ceiling", Rng = rowRng, Surface = ceiling })
				if asset then
					local scale = PlacementMath.resolveScale(asset, S, rowRng)
					local yaw = 0
					if asset.Meta.AllowRotation then
						if S.RotationMode == "Random360" then
							yaw = rowRng:range(0, math.pi * 2)
						elseif S.RotationMode == "Random90" then
							yaw = rowRng:int(0, 3) * math.pi * 0.5
						elseif S.RotationMode == "Random180" then
							yaw = rowRng:int(0, 1) * math.pi
						end
					end
					local u = u0 + beat.T
					local pose = PlacementMath.ceilingPose(asset, scale, ceiling, u, v, {
						Yaw = yaw,
						Flip = asset.Meta.CeilingFlip,
						Depth = ARCH.LAYER_MODULE * eps + S.SurfaceOffset,
					})
					local poly, _, hMax = PlacementMath.footprint(pose, ceiling)
					local inside = MathUtil.polygonInsideRect(poly, u0, v0, u1, v1, TOL)
					if not inside or hMax > maxDrop then
						ctx.Diagnostics:reject("bounds", pose.BoxCFrame.Position)
					elseif ctx.Zones:blocks(ceiling, poly) then
						ctx.Diagnostics:reject("exclusion", pose.BoxCFrame.Position)
					else
						ctx:tryCommit(pose, {
							Surface = ceiling,
							Role = "Ceiling",
							Folder = "Ceiling",
							PlacementType = "Ceiling",
							Group = "Decor",
							Layer = ARCH.LAYER_MODULE,
							IgnoreParts = { [ceiling.Part] = true },
							Pos2D = Vector2.new(u, v),
							Radius = asset.FootprintRadius * scale,
							Pass = "Ceiling",
						})
					end
				end
			end
		end
		ctx.Yield()
	end
end

return CeilingPlacementEngine
