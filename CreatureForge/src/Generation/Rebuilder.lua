-- Rebuilder : « RECONSTRUIRE FIDÈLE ».
-- Chaque pièce visible de la référence est refaite avec une forme procédurale qui
-- remplit EXACTEMENT sa boîte (même taille, position, rotation, couleur, matière).
-- Le rig reprend la hiérarchie des Motor6D / welds d'origine.
-- Aucun sommet source n'est lu : seules les boîtes englobantes sont utilisées.

local Root = script.Parent.Parent
local PaletteAnalyzer = require(Root.Analysis.PaletteAnalyzer)
local MeshRegistry = require(Root.Geometry.MeshRegistry)

local Rebuilder = {}

local ELONGATED = { horn = true, claw = true, spike = true }

local function round(x)
	return math.floor(x * 100 + 0.5) / 100
end

-- Rotation qui aligne l'axe Y d'une forme sur l'axe `axis` (1 = X, 2 = Y, 3 = Z) de la pièce,
-- et tailles de forme correspondantes (sx, sy, sz).
local function alignY(axis: number, size: Vector3)
	if axis == 1 then
		return CFrame.Angles(0, 0, math.pi / 2), size.Y, size.X, size.Z
	elseif axis == 3 then
		return CFrame.Angles(math.pi / 2, 0, 0), size.X, size.Z, size.Y
	end
	return CFrame.new(), size.X, size.Y, size.Z
end

local function sortedAxes(size: Vector3)
	local dims = { { 1, size.X }, { 2, size.Y }, { 3, size.Z } }
	table.sort(dims, function(a, b)
		return a[2] > b[2]
	end)
	return dims
end

-- Choisit une forme qui remplit la boîte d'une pièce. Retourne shape, params, cframe local.
local function fitShape(p, localCF: CFrame, bodyCenter: Vector3)
	local size = p.size
	local dims = sortedAxes(size)
	local maxD, midD, minD = dims[1][2], dims[2][2], dims[3][2]
	local longAxis = dims[1][1]

	-- Cornes / griffes / pics allongés : cône orienté vers l'extérieur du corps.
	if ELONGATED[p.region] and maxD > midD * 1.6 then
		local rot = alignY(longAxis, size)
		local axisWorld = (localCF * rot).UpVector
		local outward = (localCF.Position - bodyCenter):Dot(axisWorld) >= 0
		local flip = if outward then CFrame.new() else CFrame.Angles(math.pi, 0, 0)
		return "horn",
			{ len = round(maxD), r = round(midD * 0.5), curve = 0, out = 0, segs = 3, sides = 6 },
			localCF * rot * flip * CFrame.new(0, -maxD * 0.5, 0)
	end

	-- Plaques fines (armures, ailes, nageoires, carapaces plates) : dalle arrondie.
	if minD < midD * 0.22 then
		return "roundedCube",
			{ sx = round(size.X), sy = round(size.Y), sz = round(size.Z), bevel = round(minD * 0.45) },
			localCF
	end

	-- Tout le reste : super-ellipsoïde orienté sur l'axe long (remplit ~90 % de la boîte).
	local rot, sx, sy, sz = alignY(longAxis, size)
	local sq = if p.region == "eye" then 0 else 0.45
	return "ellipsoid",
		{ sx = round(sx), sy = round(sy), sz = round(sz), sq = sq, sqY = sq, rings = 5, sides = 8 },
		localCF * rot
end

local function shortName(name: string)
	return (name:match("[^/\\]+$") or name):gsub("%.", "_")
end

function Rebuilder.plan(report)
	local frame = report.frame
	local slots = report.palette.slots
	local slotNames = { "Primary", "Secondary", "Accent", "Eyes", "Special" }

	local parts = {}
	for _, p in report.parts do
		if p.region ~= "ignore" and p.transparency < 0.95 then
			table.insert(parts, p)
		end
	end
	assert(#parts > 0, "Aucune pièce visible à reconstruire")

	-- Centre du corps (pour orienter les cornes vers l'extérieur).
	local bodyCenter, wsum = Vector3.zero, 0
	for _, p in parts do
		local w = p.volume
		bodyCenter += frame:PointToObjectSpace(p.cframe.Position) * w
		wsum += w
	end
	bodyCenter /= math.max(wsum, 1e-6)

	-- Noms uniques (le rig retrouve les parents par nom).
	local used = { Root = true, Palette = true }
	local nameOf, specs, byName = {}, {}, {}
	for _, p in parts do
		local base = shortName(p.name)
		local name, i = base, 2
		while used[name] do
			name = base .. "_" .. i
			i += 1
		end
		used[name] = true
		nameOf[p.inst] = name

		local localCF = frame:ToObjectSpace(p.cframe)
		local shape, params, cf = fitShape(p, localCF, bodyCenter)
		params.seed = 1
		params.jitter = 0.015

		-- Emplacement de palette le plus proche (pour NOUVELLES COULEURS / édition).
		local bestSlot, bestD = "Primary", math.huge
		for _, slot in slotNames do
			local d = PaletteAnalyzer.distance(p.color, slots[slot])
			if d < bestD then
				bestSlot, bestD = slot, d
			end
		end

		local spec = {
			name = name,
			shape = shape,
			params = params,
			cframe = cf,
			slot = bestSlot,
			region = p.region,
			color = p.color,
			sourceMaterial = p.material.Name,
			sourceVariant = p.materialVariant,
			parent = nil,
			joint = localCF.Position,
			jointKind = "Weld",
			mirror = false,
			volume = p.volume,
		}
		table.insert(specs, spec)
		byName[name] = spec
	end

	-- Rig : on reprend les articulations de la référence.
	local function createsCycle(child, parentName)
		local cur = parentName
		local guard = 0
		while cur and cur ~= "Root" and guard < 200 do
			if cur == child then
				return true
			end
			cur = byName[cur] and byName[cur].parent
			guard += 1
		end
		return false
	end
	for pass = 1, 2 do -- Motor6D d'abord, welds ensuite
		for _, j in report.rig.joints do
			local isMotor = j.kind == "Motor6D"
			if (pass == 1) == isMotor and j.part1 and nameOf[j.part1] then
				local childName = nameOf[j.part1]
				local spec = byName[childName]
				local parentName = if j.part0 and nameOf[j.part0] then nameOf[j.part0] else "Root"
				if spec.parent == nil and parentName ~= childName and not createsCycle(childName, parentName) then
					spec.parent = parentName
					spec.jointKind = if isMotor then "Motor6D" else "Weld"
					if isMotor and j.part0 and j.c0 then
						spec.joint = frame:PointToObjectSpace((j.part0.CFrame * j.c0).Position)
					end
				end
			end
		end
	end

	-- Pièces sans articulation : soudées à la plus grosse pièce (elle-même sur Root).
	table.sort(specs, function(a, b)
		return a.volume > b.volume
	end)
	local main = specs[1]
	if main.parent == nil then
		main.parent = "Root"
		main.jointKind = "Motor6D"
	end
	for _, spec in specs do
		if spec.parent == nil then
			spec.parent = main.name
			spec.jointKind = "Weld"
		end
	end

	-- Géométrie + mise au sol identique à la référence (repère d'analyse = sol).
	for _, spec in specs do
		local geo, key = MeshRegistry.geometry(spec.shape, spec.params, false)
		spec.geometry = geo
		spec.meshKey = key
	end

	local palette = table.clone(slots)
	return {
		parts = specs,
		byName = byName,
		groundOffset = 0,
		palette = palette,
		name = report.name .. "_Rebuild",
		proportions = { locomotion = report.traits.locomotion },
		faithful = true,
	}
end

return Rebuilder
