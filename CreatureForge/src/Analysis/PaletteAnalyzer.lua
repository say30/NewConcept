-- PaletteAnalyzer : couleurs, matériaux et MaterialVariants d'une créature,
-- pondérés par surface, puis répartis en 5 emplacements (Primary...Special).

local PaletteAnalyzer = {}

local function colorKey(c: Color3)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function distance(a: Color3, b: Color3)
	local dr, dg, db = a.R - b.R, a.G - b.G, a.B - b.B
	return math.sqrt(dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11)
end
PaletteAnalyzer.distance = distance

local function area(size: Vector3)
	return 2 * (size.X * size.Y + size.Y * size.Z + size.Z * size.X)
end

-- parts : { { color, material, materialVariant, size, region } }
function PaletteAnalyzer.analyze(parts)
	local byColor, order = {}, {}
	local byRegion = {}
	local materials, variants = {}, {}
	local total = 0

	for _, p in parts do
		local w = area(p.size)
		total += w
		local key = colorKey(p.color)
		if not byColor[key] then
			byColor[key] = { color = p.color, weight = 0 }
			table.insert(order, byColor[key])
		end
		byColor[key].weight += w

		local region = p.region or "body"
		byRegion[region] = byRegion[region] or {}
		byRegion[region][key] = (byRegion[region][key] or 0) + w

		local m = p.material and p.material.Name or "Plastic"
		materials[m] = (materials[m] or 0) + w
		if p.materialVariant and p.materialVariant ~= "" then
			variants[p.materialVariant] = (variants[p.materialVariant] or 0) + w
		end
	end

	table.sort(order, function(a, b)
		return a.weight > b.weight
	end)

	local function topOf(regions, exclude)
		local best, bestW = nil, 0
		for _, r in regions do
			for key, w in byRegion[r] or {} do
				local c = byColor[key].color
				local ok = true
				for _, e in exclude do
					if distance(c, e) < 0.08 then
						ok = false
					end
				end
				if ok and w > bestW then
					best, bestW = c, w
				end
			end
		end
		return best
	end

	local slots = {}
	slots.Primary = topOf({ "body", "head", "neck", "leg", "tail", "arm" }, {}) or (order[1] and order[1].color)
		or Color3.fromRGB(200, 120, 60)
	slots.Secondary = topOf({ "body", "head", "leg", "tail", "wing", "muzzle", "jaw", "arm", "ear", "fin" }, { slots.Primary })
	if not slots.Secondary then
		for _, e in order do
			if distance(e.color, slots.Primary) > 0.08 then
				slots.Secondary = e.color
				break
			end
		end
	end
	slots.Secondary = slots.Secondary or slots.Primary:Lerp(Color3.new(1, 1, 1), 0.35)
	slots.Accent = topOf({ "horn", "claw", "spike", "crystal", "mane" }, { slots.Primary, slots.Secondary })
		or slots.Primary:Lerp(Color3.new(0, 0, 0), 0.4)
	slots.Eyes = topOf({ "eye" }, {}) or Color3.fromRGB(255, 220, 90)

	-- Special : la couleur la plus saturée restante.
	local bestS, special = -1, nil
	for _, e in order do
		local _, s, v = e.color:ToHSV()
		local score = s * v
		local used = false
		for _, u in { slots.Primary, slots.Secondary, slots.Accent, slots.Eyes } do
			if distance(u, e.color) < 0.08 then
				used = true
			end
		end
		if not used and score > bestS then
			bestS, special = score, e.color
		end
	end
	slots.Special = special or slots.Accent:Lerp(Color3.new(1, 1, 1), 0.3)

	local dominantMaterial, dmW = "Plastic", -1
	for m, w in materials do
		if w > dmW then
			dominantMaterial, dmW = m, w
		end
	end
	local dominantVariant, dvW = nil, 0
	for v, w in variants do
		if w > dvW and w > total * 0.3 then
			dominantVariant, dvW = v, w
		end
	end

	return {
		colors = order,
		uniqueCount = #order,
		slots = slots,
		materials = materials,
		dominantMaterial = dominantMaterial,
		dominantVariant = dominantVariant,
	}
end

return PaletteAnalyzer
