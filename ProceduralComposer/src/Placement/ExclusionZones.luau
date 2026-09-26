--[[
	ExclusionZones
	Zones interdites projetées sur chaque surface :
	  - Parts sélectionnées comme zones d'exclusion ;
	  - Parts taguées "ProceduralPlacementExclude" (CollectionService) ;
	  - zone centrale protégée (Keep Center Clear) et chemin (Path Width) des sols.

	Une zone 3D est projetée sur le plan d'une surface si elle se trouve dans
	l'espace libre devant elle (profondeur de sonde configurable). On obtient un
	polygone convexe 2D : test de chevauchement par SAT, très rapide.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local MathUtil = require(Core.MathUtil)

local ExclusionZones = {}
ExclusionZones.__index = ExclusionZones

local G = Config.Geometry

function ExclusionZones.new(zoneParts)
	local self = setmetatable({}, ExclusionZones)
	self.Parts = zoneParts or {}
	self._perSurface = {}
	return self
end

-- Projette toutes les zones sur une surface (résultat mis en cache).
function ExclusionZones:forSurface(surface)
	local cached = self._perSurface[surface]
	if cached then
		return cached
	end
	local list = {}
	local frame = surface.Frame
	local depth = G.EXCLUSION_PROBE_DEPTH
	local back = G.EXCLUSION_PROBE_BACK
	local regionCf = frame * CFrame.new((surface.UMin + surface.UMax) * 0.5, (depth - back) * 0.5, (surface.VMin + surface.VMax) * 0.5)
	local regionSize = Vector3.new(surface.SizeU + 2 * back, depth + back, surface.SizeV + 2 * back)
	for _, part in ipairs(self.Parts) do
		if part.Parent ~= nil and MathUtil.obbIntersects(regionCf, regionSize, part.CFrame, part.Size, 0, 0) then
			local poly, hMin, hMax = MathUtil.projectOBBToSurface(frame, part.CFrame, part.Size)
			if #poly >= 3 then
				table.insert(list, { Polygon = poly, Part = part, HMin = hMin, HMax = hMax, Kind = "Exclusion" })
			end
		end
	end
	self._perSurface[surface] = list
	return list
end

-- Ajoute une zone 2D spécifique à une surface (zone centrale, chemin...).
function ExclusionZones:addSurfaceZone(surface, polygon, kind)
	local list = self:forSurface(surface)
	table.insert(list, { Polygon = polygon, Kind = kind or "Custom", HMin = -math.huge, HMax = math.huge })
end

-- L'empreinte chevauche-t-elle une zone ? (hauteur optionnelle pour les murs)
function ExclusionZones:blocks(surface, footprint, hMin, hMax)
	for _, zone in ipairs(self:forSurface(surface)) do
		local verticalOverlap = true
		if hMin and hMax and zone.HMin and zone.HMax then
			-- Une zone entièrement "derrière" la surface ne bloque rien.
			verticalOverlap = zone.HMax > 0 or zone.HMax == math.huge
		end
		if verticalOverlap and MathUtil.polygonsIntersect(footprint, zone.Polygon, Config.Precision.CONTACT_TOLERANCE) then
			return true, zone
		end
	end
	return false
end

--[[
	Intervalles U bloqués pour une bande verticale [v0, v1] d'un mur :
	utilisé pour segmenter les murs modulaires autour des zones d'exclusion.
]]
function ExclusionZones:blockedIntervalsU(surface, v0, v1)
	local intervals = {}
	for _, zone in ipairs(self:forSurface(surface)) do
		local minU, minV, maxU, maxV = MathUtil.polygonBounds(zone.Polygon)
		if maxV > v0 and minV < v1 then
			table.insert(intervals, { minU, maxU })
		end
	end
	table.sort(intervals, function(a, b)
		return a[1] < b[1]
	end)
	-- Fusion des intervalles qui se chevauchent.
	local merged = {}
	for _, iv in ipairs(intervals) do
		local last = merged[#merged]
		if last and iv[1] <= last[2] then
			last[2] = math.max(last[2], iv[2])
		else
			table.insert(merged, { iv[1], iv[2] })
		end
	end
	return merged
end

-- Soustrait des intervalles bloqués d'un intervalle [a, b] ; renvoie les segments libres.
function ExclusionZones.subtractIntervals(a, b, blocked, minLength)
	local segments = {}
	local cursor = a
	for _, iv in ipairs(blocked) do
		if iv[2] > cursor and iv[1] < b then
			if iv[1] - cursor >= (minLength or 0) then
				table.insert(segments, { cursor, math.min(iv[1], b) })
			end
			cursor = math.max(cursor, iv[2])
		end
	end
	if b - cursor >= (minLength or 0) then
		table.insert(segments, { cursor, b })
	end
	return segments
end

function ExclusionZones:all(surface)
	return self:forSurface(surface)
end

return ExclusionZones
