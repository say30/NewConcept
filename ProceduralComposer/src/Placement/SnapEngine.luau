--[[
	SnapEngine
	Assemblage bord à bord sans trou ni chevauchement.

	Connecteurs d'un asset (dans le repère canonique mural, après lacet,
	échelle et étirement) :
	  - si l'asset possède les Attachments Snap_Left ET Snap_Right, ils sont
	    prioritaires : la largeur utile est la distance entre eux et le
	    connecteur de début d'un module coïncide EXACTEMENT avec le connecteur
	    de fin du précédent. Le nom gauche/droite n'a pas d'importance : le
	    connecteur d'abscisse la plus faible est le début (robuste quel que soit
	    le sens dans lequel l'asset a été modélisé) ;
	  - sinon, les faces de la boîte réelle sont utilisées.
	Même principe verticalement avec Snap_Bottom / Snap_Top (empilement).

	Les positions d'une rangée sont calculées par somme cumulée depuis
	l'origine du segment (pas de déplacement incrémental d'un CFrame à
	l'autre) : aucune erreur flottante ne s'accumule le long d'un mur.
]]

local PlacementMath = require(script.Parent.PlacementMath)

local SnapEngine = {}

local MIN_CONNECTOR_SPAN = 1e-3

local function canonicalPoint(localCFrame, scale, wallYaw, stretch)
	local p = localCFrame.Position * scale
	if stretch and stretch.Factor then
		if stretch.Axis == "Z" then
			p = Vector3.new(p.X, p.Y, p.Z * stretch.Factor)
		else
			p = Vector3.new(p.X * stretch.Factor, p.Y, p.Z)
		end
	end
	return CFrame.Angles(0, wallYaw, 0):VectorToWorldSpace(p)
end

--[[
	Connecteurs horizontaux.
	Renvoie { Start, End, Width, UsesAttachments, StartPoint, EndPoint, CanonMin, CanonMax }
]]
function SnapEngine.horizontalConnectors(asset, scale, wallYaw, stretch)
	wallYaw = if wallYaw ~= nil then wallYaw else asset.WallYaw or 0
	local cmin, cmax = PlacementMath.wallCanonBounds(asset, scale, wallYaw, stretch)
	local left = asset.Attachments.SnapLeft
	local right = asset.Attachments.SnapRight
	if left and right then
		local a = canonicalPoint(left, scale, wallYaw, stretch)
		local b = canonicalPoint(right, scale, wallYaw, stretch)
		if a.X > b.X then
			a, b = b, a
		end
		if b.X - a.X > MIN_CONNECTOR_SPAN then
			return {
				Start = a.X,
				End = b.X,
				Width = b.X - a.X,
				UsesAttachments = true,
				StartPoint = a,
				EndPoint = b,
				CanonMin = cmin,
				CanonMax = cmax,
			}
		end
	end
	return {
		Start = cmin.X,
		End = cmax.X,
		Width = cmax.X - cmin.X,
		UsesAttachments = false,
		StartPoint = Vector3.new(cmin.X, (cmin.Y + cmax.Y) * 0.5, cmax.Z),
		EndPoint = Vector3.new(cmax.X, (cmin.Y + cmax.Y) * 0.5, cmax.Z),
		CanonMin = cmin,
		CanonMax = cmax,
	}
end

-- Connecteurs verticaux : { Bottom, Top, Height, UsesAttachments, CanonMin, CanonMax }
function SnapEngine.verticalConnectors(asset, scale, wallYaw)
	wallYaw = if wallYaw ~= nil then wallYaw else asset.WallYaw or 0
	local cmin, cmax = PlacementMath.wallCanonBounds(asset, scale, wallYaw, nil)
	local bottom = asset.Attachments.SnapBottom
	local top = asset.Attachments.SnapTop
	if bottom and top then
		local a = canonicalPoint(bottom, scale, wallYaw, nil)
		local b = canonicalPoint(top, scale, wallYaw, nil)
		if a.Y > b.Y then
			a, b = b, a
		end
		if b.Y - a.Y > MIN_CONNECTOR_SPAN then
			return { Bottom = a.Y, Top = b.Y, Height = b.Y - a.Y, UsesAttachments = true, CanonMin = cmin, CanonMax = cmax }
		end
	end
	return { Bottom = cmin.Y, Top = cmax.Y, Height = cmax.Y - cmin.Y, UsesAttachments = false, CanonMin = cmin, CanonMax = cmax }
end

--[[
	Rangée : positions de départ (le long de U) de chaque élément.
	widths[i] = largeur utile, gaps[i] = espace après l'élément i (optionnel).
]]
function SnapEngine.layoutRow(startU, widths, gaps)
	local positions = table.create(#widths)
	local acc = 0
	for i, w in ipairs(widths) do
		positions[i] = startU + acc
		acc += w + ((gaps and gaps[i]) or 0)
	end
	return positions, startU + acc
end

--[[
	Empilement vertical : ordonnée (v) à donner à AnchorYValue = connecteur bas
	de chaque segment, pour que le segment i+1 repose exactement sur le segment i.
	baseV = hauteur du sol (bas de la boîte du premier segment).
]]
function SnapEngine.stackPositions(connectors, baseV, count)
	local positions = table.create(count)
	local first = baseV + (connectors.Bottom - connectors.CanonMin.Y)
	for i = 0, count - 1 do
		positions[i + 1] = first + i * connectors.Height
	end
	return positions
end

--[[
	Alignement 3D exact de deux attachments : renvoie le RefCFrame de l'asset B
	tel que son attachment `attachB` (CFrame local au repère de référence, échelle 1)
	coïncide avec le point monde `targetWorld`, pour une rotation monde donnée.
]]
function SnapEngine.alignToPoint(rotation, attachB, scale, targetWorld)
	local offset = rotation:VectorToWorldSpace(attachB.Position * scale)
	return CFrame.new(targetWorld - offset) * rotation
end

-- Point monde d'un attachment d'un asset posé.
function SnapEngine.worldAttachmentPoint(refCFrame, attach, scale)
	return refCFrame:PointToWorldSpace(attach.Position * scale)
end

-- Position monde d'un connecteur canonique pour une pose murale.
function SnapEngine.connectorWorld(surface, pose, canonicalPointValue)
	local rotWall = CFrame.fromMatrix(Vector3.new(), surface.U, surface.V, -surface.Normal)
	local refPos = pose.RefCFrame.Position
	return refPos + rotWall:VectorToWorldSpace(canonicalPointValue)
end


return SnapEngine
