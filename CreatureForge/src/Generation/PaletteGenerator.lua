-- PaletteGenerator : palettes cohérentes (harmonies HSV) à 5 emplacements
-- Primary / Secondary / Accent / Eyes / Special (+ Pupil dérivée, non exposée).
-- Un biome facultatif oriente les teintes sans imposer de morphologie.

local Config = require(script.Parent.Parent.Config)

local PaletteGenerator = {}

-- Plages de teinte (0..1) + saturation / valeur typiques par mot-clé de biome.
local BIOMES = {
	{ keys = { "toxic", "swamp", "poison", "marais", "toxique", "bog" }, hues = { 0.22, 0.3, 0.78 }, s = { 0.5, 0.85 }, v = { 0.4, 0.75 } },
	{ keys = { "crystal", "cave", "gem", "cristal", "grotte" }, hues = { 0.5, 0.58, 0.78, 0.85 }, s = { 0.4, 0.8 }, v = { 0.55, 0.9 } },
	{ keys = { "frozen", "ice", "snow", "frost", "glace", "neige", "gel", "tomb" }, hues = { 0.52, 0.58, 0.62 }, s = { 0.15, 0.5 }, v = { 0.7, 0.98 } },
	{ keys = { "infernal", "fire", "lava", "forge", "hell", "volcan", "feu", "magma", "ember" }, hues = { 0.0, 0.03, 0.07, 0.1 }, s = { 0.65, 0.95 }, v = { 0.35, 0.9 } },
	{ keys = { "forest", "jungle", "foret", "wood", "grove" }, hues = { 0.25, 0.3, 0.08 }, s = { 0.4, 0.75 }, v = { 0.35, 0.7 } },
	{ keys = { "desert", "sand", "dune", "sable" }, hues = { 0.08, 0.11, 0.13 }, s = { 0.35, 0.65 }, v = { 0.6, 0.9 } },
	{ keys = { "ocean", "sea", "reef", "water", "mer", "abyss", "deep" }, hues = { 0.47, 0.53, 0.6 }, s = { 0.45, 0.85 }, v = { 0.4, 0.85 } },
	{ keys = { "shadow", "void", "dark", "ombre", "necro", "cursed" }, hues = { 0.72, 0.78, 0.83 }, s = { 0.3, 0.65 }, v = { 0.18, 0.45 } },
	{ keys = { "sky", "cloud", "storm", "ciel", "celestial" }, hues = { 0.55, 0.6, 0.15 }, s = { 0.2, 0.55 }, v = { 0.75, 1 } },
}

local EYE_HUES = { 0.14, 0.5, 0.0, 0.33, 0.85, 0.08 }

local function findBiome(biome: string?)
	if not biome or biome == "" then
		return nil
	end
	local lower = biome:lower()
	for _, b in BIOMES do
		for _, k in b.keys do
			if lower:find(k, 1, true) then
				return b
			end
		end
	end
	return nil
end

local function hueDistance(a, b)
	local d = math.abs(a - b) % 1
	return math.min(d, 1 - d)
end

-- opts : { base = slots de référence?, level = 1..3, seed, biome? }
function PaletteGenerator.generate(opts)
	local rng = Random.new(opts.seed or os.clock() * 1000)
	local level = opts.level or 2
	local biome = findBiome(opts.biome)

	local h, s, v
	if biome then
		h = biome.hues[rng:NextInteger(1, #biome.hues)] + rng:NextNumber(-0.03, 0.03)
		s = rng:NextNumber(biome.s[1], biome.s[2])
		v = rng:NextNumber(biome.v[1], biome.v[2])
	elseif opts.base and opts.base.Primary and level < 3 then
		local bh, bs, bv = opts.base.Primary:ToHSV()
		local shift = if level == 1 then 0.06 else 0.22
		h = bh + rng:NextNumber(-shift, shift)
		s = math.clamp(bs + rng:NextNumber(-0.15, 0.15), 0.25, 0.85)
		v = math.clamp(bv + rng:NextNumber(-0.15, 0.15), 0.35, 0.9)
	else
		h = rng:NextNumber()
		s = rng:NextNumber(0.4, 0.75)
		v = rng:NextNumber(0.5, 0.85)
	end
	h %= 1

	local schemes = { "analogous", "complementary", "split", "triad" }
	local scheme = schemes[rng:NextInteger(1, #schemes)]
	local accentH = ({
		analogous = h + 0.1,
		complementary = h + 0.5,
		split = h + 0.42,
		triad = h + 0.33,
	})[scheme] % 1

	local palette = {}
	palette.Primary = Color3.fromHSV(h, s, v)
	-- Secondaire : plus clair, moins saturé (ventre, museau, pieds).
	palette.Secondary = Color3.fromHSV((h + rng:NextNumber(-0.04, 0.06)) % 1, s * rng:NextNumber(0.35, 0.65), math.min(v + rng:NextNumber(0.15, 0.3), 1))
	if rng:NextNumber() < 0.3 then
		-- Cornes / griffes « os » ivoire ou sombres.
		palette.Accent = if rng:NextNumber() < 0.5
			then Color3.fromHSV(0.11, rng:NextNumber(0.1, 0.25), rng:NextNumber(0.82, 0.95))
			else Color3.fromHSV(h, s * 0.5, v * 0.35)
	else
		palette.Accent = Color3.fromHSV(accentH, math.clamp(s + 0.15, 0.5, 0.9), math.clamp(v + 0.1, 0.55, 0.95))
	end

	local eyeH = EYE_HUES[rng:NextInteger(1, #EYE_HUES)]
	for _ = 1, 6 do
		if hueDistance(eyeH, h) > 0.15 then
			break
		end
		eyeH = EYE_HUES[rng:NextInteger(1, #EYE_HUES)]
	end
	palette.Eyes = Color3.fromHSV(eyeH, rng:NextNumber(0.65, 0.95), 1)
	palette.Special = Color3.fromHSV((accentH + rng:NextNumber(-0.08, 0.08)) % 1, rng:NextNumber(0.75, 1), rng:NextNumber(0.85, 1))
	palette.Pupil = PaletteGenerator.pupilOf(palette.Eyes)
	return palette
end

function PaletteGenerator.pupilOf(eyes: Color3)
	return eyes:Lerp(Color3.new(0.03, 0.03, 0.05), 0.9)
end

-- Applique une palette à une créature générée (pièces marquées CF_Slot).
function PaletteGenerator.apply(model: Instance, palette)
	local A = Config.ATTR
	palette.Pupil = palette.Pupil or PaletteGenerator.pupilOf(palette.Eyes)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local slot = d:GetAttribute(A .. "Slot")
			if slot and palette[slot] then
				d.Color = palette[slot]
			end
		end
	end
	local folder = model:FindFirstChild("Palette")
	if not folder then
		folder = Instance.new("Configuration")
		folder.Name = "Palette"
		folder.Parent = model
	end
	for _, slot in Config.PALETTE_SLOTS do
		local value = folder:FindFirstChild(slot)
		if not value then
			value = Instance.new("Color3Value")
			value.Name = slot
			value.Parent = folder
		end
		value.Value = palette[slot]
	end
end

-- Lit la palette actuelle d'une créature (dossier Palette).
function PaletteGenerator.read(model: Instance)
	local folder = model:FindFirstChild("Palette")
	if not folder then
		return nil
	end
	local palette = {}
	for _, slot in Config.PALETTE_SLOTS do
		local value = folder:FindFirstChild(slot)
		if value and value:IsA("Color3Value") then
			palette[slot] = value.Value
		end
	end
	return palette
end

return PaletteGenerator
