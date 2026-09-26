--[[
	CornerEngine
	Traitement des coins intérieurs détectés entre deux murs (GeometryAnalyzer).

	Un asset de coin (PlacementType = Corner, ou pilier / élément vertical en
	mode auto) est posé au sol dans l'angle et touche EXACTEMENT les deux murs :
	la position est obtenue en résolvant un système 2×2 sur les fonctions de
	support de sa boîte contre les deux plans (valable pour tout angle entre
	les murs, pas seulement 90°).

	Si les murs ont une façade générée, la pièce de coin appartient à
	l'architecture (elle recouvre le joint entre les deux façades) ; sinon elle
	est posée devant les murs comme une décoration.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local MathUtil = require(Core.MathUtil)
local PlacementMath = require(script.Parent.PlacementMath)
local SnapEngine = require(script.Parent.SnapEngine)

local CornerEngine = {}

local ARCH = Config.Architecture

-- Rotation d'un asset dont l'avant (-Z) regarde `front` (horizontal).
local function rotationFacing(front)
	local look = MathUtil.safeUnit(Vector3.new(front.X, 0, front.Z), Vector3.new(0, 0, -1))
	local right = look:Cross(MathUtil.UP)
	return CFrame.fromMatrix(Vector3.new(), right, MathUtil.UP, -look)
end

--[[
	Position (horizontale) du point d'ancrage pour que la boîte touche les deux plans.
	offsets[i] = distance souhaitée entre le plan du mur i et la boîte.
]]
local function solveCornerPosition(corner, rotation, bmin, bmax, anchorLocal, offsetA, offsetB)
	local nA = Vector3.new(corner.NormalA.X, 0, corner.NormalA.Z)
	local nB = Vector3.new(corner.NormalB.X, 0, corner.NormalB.Z)
	if nA.Magnitude < 0.5 or nB.Magnitude < 0.5 then
		return nil
	end
	nA, nB = nA.Unit, nB.Unit
	-- Support : min des projections des coins de la boîte (relatifs à l'ancre) sur chaque normale.
	local sA, sB = math.huge, math.huge
	for _, x in ipairs({ bmin.X, bmax.X }) do
		for _, y in ipairs({ bmin.Y, bmax.Y }) do
			for _, z in ipairs({ bmin.Z, bmax.Z }) do
				local w = rotation:VectorToWorldSpace(Vector3.new(x, y, z) - anchorLocal)
				sA = math.min(sA, w:Dot(nA))
				sB = math.min(sB, w:Dot(nB))
			end
		end
	end
	local aA = offsetA - sA
	local aB = offsetB - sB
	-- [nA.x nA.z; nB.x nB.z] * [px; pz] = [aA; aB]
	local det = nA.X * nB.Z - nA.Z * nB.X
	if math.abs(det) < 1e-4 then
		return nil
	end
	local px = (aA * nB.Z - nA.Z * aB) / det
	local pz = (nA.X * aB - aA * nB.X) / det
	return corner.Position + Vector3.new(px, 0, pz)
end

function CornerEngine.run(ctx, corners)
	local S = ctx.Settings
	if not S.CornerDecoration then
		return
	end
	local palette = ctx.Registry:getByRole("Corner")
	if #palette == 0 then
		return
	end
	local eps = ctx.Epsilon
	local dev = if S.AllowModuleScaling then S.MaxModuleScaleDeviation else 0
	for index, corner in ipairs(corners) do
		if ctx:remaining() <= 0 then
			return
		end
		ctx.Diagnostics:corner(corner)
		local rng = ctx.Rng:fork("corner:" .. corner.WallA.Id .. ":" .. corner.WallB.Id .. ":" .. index)
		local facadeA = ctx.Facades[corner.WallA]
		local facadeB = ctx.Facades[corner.WallB]
		local architectural = facadeA ~= nil or facadeB ~= nil
		local lenA = corner.WallA.UMax - corner.WallA.UMin
		local lenB = corner.WallB.UMax - corner.WallB.UMin
		local maxFootprint = math.min(lenA, lenB) * 0.45
		local tried = {}
		for _ = 1, Config.Scoring.MAX_ASSET_RETRIES do
			local asset = ctx.Selector:pick(palette, {
				Role = "Corner",
				Rng = rng,
				IgnoreFrequency = true,
				Exclude = tried,
				Filter = function(a)
					return math.max(a.Size.X, a.Size.Z) <= maxFootprint
				end,
			})
			if not asset then
				break
			end
			tried[asset] = true
			local scale = PlacementMath.resolveScale(asset, S, rng)
			local count = 1
			-- En architecture, un pilier de coin couvre la hauteur du mur (empilé si besoin).
			local isPillar = (asset.RoleScores.Pillar or 0) >= Config.Assets.ROLE_SCORE_THRESHOLD
			local vconn = SnapEngine.verticalConnectors(asset, 1, 0)
			if architectural and isPillar and vconn.Height > 1e-3 then
				if vconn.Height >= corner.Height then
					local s = corner.Height / vconn.Height
					if asset.Meta.AllowScale and s >= (asset.Meta.MinScale or 1 - 2 * dev) then
						scale = s
					end
				else
					count = math.max(1, math.floor(corner.Height / vconn.Height + 0.5))
					local s = corner.Height / (count * vconn.Height)
					if math.abs(s - 1) <= dev and asset.Meta.AllowScale then
						scale = s
					else
						count = math.max(1, math.floor(corner.Height / vconn.Height))
						scale = 1
					end
				end
			end
			if asset.Size.Y * scale * count > corner.Height + Config.Precision.CONTACT_TOLERANCE and isPillar and architectural then
				continue
			end
			-- Orientation : alignée sur le mur A pour les piliers, sinon face à la bissectrice.
			local front = if isPillar then corner.NormalA else corner.Bisector
			local rotation = rotationFacing(front)
			local bmin, bmax = PlacementMath.localBounds(asset, scale, nil)
			local anchorLocal = Vector3.new((bmin.X + bmax.X) * 0.5, bmin.Y, (bmin.Z + bmax.Z) * 0.5)
			local offsetA, offsetB
			if architectural then
				offsetA = ARCH.LAYER_PILLAR * eps
				offsetB = ARCH.LAYER_PILLAR * eps
			else
				offsetA = eps + (if facadeA then facadeA.Depth else 0)
				offsetB = eps + (if facadeB then facadeB.Depth else 0)
			end
			local target = solveCornerPosition(corner, rotation, bmin, bmax, anchorLocal, offsetA, offsetB)
			if target then
				local ignore = { [corner.WallA.Part] = true, [corner.WallB.Part] = true }
				if corner.WallA.SupportFloor then
					ignore[corner.WallA.SupportFloor.Part] = true
				end
				if corner.WallB.SupportFloor then
					ignore[corner.WallB.SupportFloor.Part] = true
				end
				local placedAny = false
				local vconnScaled = SnapEngine.verticalConnectors(asset, scale, 0)
				for i = 0, count - 1 do
					local lift = i * vconnScaled.Height
					local pose = PlacementMath.freePose(asset, scale, rotation, anchorLocal, target + MathUtil.UP * lift, nil)
					local item = ctx:tryCommit(pose, {
						Surface = nil,
						Role = "Corner",
						Folder = "Corner",
						PlacementType = "Corner",
						Group = if architectural then "Architecture" else "Decor",
						AllowArchitectureOverlap = architectural,
						Layer = ARCH.LAYER_PILLAR,
						IgnoreParts = ignore,
						Pass = "Corner",
					})
					if item then
						placedAny = true
						ctx.Diagnostics:snap(target + MathUtil.UP * lift)
					elseif i == 0 then
						break
					end
				end
				if placedAny then
					break
				end
			end
		end
		ctx.Yield()
	end
end

CornerEngine._solve = solveCornerPosition

return CornerEngine
