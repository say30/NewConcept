--[[
	CompositionPlanner
	Outils de composition visuelle partagés par les moteurs :

	  - beats() : séquence rythmique 1D (bords de sol, murs, plafonds) du type
	      [gros élément][2 petits proches][respiration][moyen][petit groupe][vide]
	    au lieu de "asset - asset - asset" à distance constante. Un gros
	    élément n'est jamais suivi d'un autre gros élément, un vide jamais
	    d'un autre vide. La séquence est ensuite redistribuée pour occuper
	    exactement la longueur disponible (pas de grand trou en fin de mur),
	    et peut être rendue symétrique (palindrome).
	  - rhythm() : champ rythmique le long de la grande dimension.
	  - floorBudget() : nombre de points focaux, de groupes et couverture
	    visée, calculés à partir de l'aire et de la taille réelle des assets.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local Utilities = require(Core.Utilities)

local CompositionPlanner = {}

local COMP = Config.Composition
local SC = Config.Scoring

--[[
	opts = {
	  BaseSpacing : espacement typique d'un beat (studs)
	  Density     : densité (0..1), défaut Settings.Density
	  Symmetric   : bool
	  Allowed     : { Large = bool, Medium = bool, SmallGroup = bool }
	  EndMargin   : marge aux extrémités
	}
]]
function CompositionPlanner.beats(length, rng, settings, opts)
	opts = opts or {}
	local beats = {}
	local endMargin = opts.EndMargin or 0
	local available = length - 2 * endMargin
	if available <= 0 then
		return beats
	end
	local density = opts.Density or settings.Density
	local spacing = math.max(0.5, (opts.BaseSpacing or 4) * settings.SpacingScale / Utilities.lerp(0.35, 1.6, density))
	local allowed = opts.Allowed or { Large = true, Medium = true, SmallGroup = true }
	local randomness = settings.Randomness
	local rhythmAmp = settings.VisualRhythm * 0.6
	local waves = Utilities.lerp(COMP.RHYTHM_MIN_WAVES, COMP.RHYTHM_MAX_WAVES, rng:next())
	local phase = rng:range(0, math.pi * 2)

	local symmetric = opts.Symmetric
	local runLength = if symmetric then available * 0.5 else available

	local t = 0
	local previous = "Gap"
	local sequence = {}
	local guard = 0
	while t < runLength and guard < COMP.BEAT_MAX do
		guard += 1
		local pLarge = if allowed.Large and previous ~= "Large" then settings.LargeAssetFrequency else 0
		local pMedium = if allowed.Medium then settings.MediumAssetFrequency else 0
		local pSmall = if allowed.SmallGroup then settings.SmallAssetFrequency else 0
		local pGap = if previous == "Gap" then 0 else settings.EmptySpaceRatio * 1.5
		if previous == "Large" then
			pGap *= 2
		end
		local weights = { pLarge, pMedium, pSmall, pGap }
		local index = rng:weightedIndex(weights)
		if not index then
			index = 4
			if previous == "Gap" then
				break
			end
		end
		local kind = ({ "Large", "Medium", "SmallGroup", "Gap" })[index]
		local width
		if kind == "Large" then
			width = spacing * 1.6
		elseif kind == "Medium" then
			width = spacing
		elseif kind == "SmallGroup" then
			width = spacing * 0.9
		else
			width = spacing * Utilities.lerp(0.6, 2.0, rng:next()) * (0.5 + settings.EmptySpaceRatio)
		end
		local rhythm = 1 + rhythmAmp * math.sin(phase + 2 * math.pi * waves * (t / math.max(runLength, 1e-3)))
		width *= rhythm * (1 + (rng:next() - 0.5) * 0.7 * randomness)
		width = math.max(width, 0.25)
		table.insert(sequence, { Kind = kind, Width = width })
		t += width
		previous = kind
	end
	if #sequence == 0 then
		return beats
	end
	-- Redistribution exacte sur la longueur disponible (ou la demi-longueur).
	local total = 0
	for _, b in ipairs(sequence) do
		total += b.Width
	end
	local k = runLength / total
	local cursor = endMargin
	for _, b in ipairs(sequence) do
		local w = b.Width * k
		table.insert(beats, { T = cursor + w * 0.5, Kind = b.Kind, Width = w })
		cursor += w
	end
	if symmetric then
		local mirrored = {}
		for i = #beats, 1, -1 do
			local b = beats[i]
			table.insert(mirrored, { T = length - b.T, Kind = b.Kind, Width = b.Width, Mirror = true })
		end
		for _, b in ipairs(mirrored) do
			table.insert(beats, b)
		end
	end
	return beats
end

-- Champ rythmique dans [0, 1] le long d'un axe.
function CompositionPlanner.rhythmField(rng)
	local waves = Utilities.lerp(COMP.RHYTHM_MIN_WAVES, COMP.RHYTHM_MAX_WAVES, rng:next())
	local phase = rng:range(0, math.pi * 2)
	return function(t, length)
		return 0.5 + 0.5 * math.sin(phase + 2 * math.pi * waves * (t / math.max(length, 1e-3)))
	end
end

-- Rayon d'empreinte typique (médiane) d'une liste d'assets filtrée par classes de taille.
function CompositionPlanner.typicalRadius(assets, sizeClasses)
	local radii = {}
	for _, a in ipairs(assets) do
		if not sizeClasses or sizeClasses[a.SizeClass] then
			table.insert(radii, a.FootprintRadius)
		end
	end
	if #radii == 0 then
		return nil
	end
	table.sort(radii)
	return radii[math.ceil(#radii / 2)]
end

--[[
	Budget d'un sol.
	Renvoie { Heroes, Clusters, CoverageTarget, TypicalRadius, HeroRadius, SmallRadius }
]]
function CompositionPlanner.floorBudget(settings, area, palette, algorithm)
	local typical = CompositionPlanner.typicalRadius(palette, nil) or 2
	local heroR = CompositionPlanner.typicalRadius(palette, { Hero = true, Large = true })
	local smallR = CompositionPlanner.typicalRadius(palette, { Small = true }) or typical * 0.5
	local mediumR = CompositionPlanner.typicalRadius(palette, { Medium = true }) or typical

	local heroZone = ((heroR or typical) * SC.HERO_SPACING_RADII) ^ 2
	local clusterZone = (mediumR * SC.CLUSTER_SPACING_RADII) ^ 2 * settings.SpacingScale

	local density = settings.Density
	local heroes = 0
	if heroR and settings.LargeAssetFrequency > 0.05 then
		heroes = math.floor(area / heroZone * settings.LargeAssetFrequency * (0.5 + density) + 0.5)
		if heroes == 0 and area >= (heroR * 3) ^ 2 and settings.LargeAssetFrequency >= 0.25 then
			heroes = 1
		end
	end
	local clusters = math.floor(area / clusterZone * density * (0.4 + 0.6 * settings.ClusterStrength) * (1 - 0.5 * settings.EmptySpaceRatio) + 0.5)
	if algorithm == "HeroComposition" then
		heroes = math.max(if heroR then 1 else 0, math.floor(area / heroZone * 1.2 + 0.5))
		clusters = 0
	elseif algorithm == "Scatter" or algorithm == "Grid" or algorithm == "Border" then
		clusters = 0
	end
	-- Remplissage : un petit élément par cellule de dispersion (budget en nombre,
	-- pas en surface : des centaines de cailloux ne remplacent pas une composition).
	local scatterRadius = if algorithm == "Scatter" then typical else smallR
	local cell = math.max(COMP.SCATTER_CELL_MIN, scatterRadius * COMP.SCATTER_CELL_RADII) * settings.SpacingScale
	local fillers = math.floor(area / (cell * cell) * density * (1 - settings.EmptySpaceRatio) * settings.SmallAssetFrequency * 1.4 + 0.5)
	if algorithm == "HeroComposition" or algorithm == "Grid" or algorithm == "Border" then
		fillers = 0
	end
	-- Éléments de classe "Hero" : au plus un par grande zone (au moins un si la place le permet).
	local heroClassR = CompositionPlanner.typicalRadius(palette, { Hero = true })
	local heroClassCap = 0
	if heroClassR then
		heroClassCap = math.max(1, math.floor(area / ((heroClassR * SC.HERO_CLASS_ZONE_RADII) ^ 2) + 0.5))
		if algorithm == "HeroComposition" then
			heroClassCap = math.max(heroClassCap, heroes)
		end
	end
	-- Plafond de sécurité de couverture.
	local coverage = COMP.MAX_FLOOR_COVERAGE * (0.5 + density) * (1 - 0.3 * settings.EmptySpaceRatio)
	return {
		Heroes = heroes,
		Clusters = clusters,
		Fillers = fillers,
		HeroClassCap = heroClassCap,
		CoverageTarget = coverage,
		TypicalRadius = typical,
		HeroRadius = heroR or typical,
		MediumRadius = mediumR,
		SmallRadius = smallR,
	}
end

-- Nombre de membres d'un groupe.
function CompositionPlanner.clusterSize(settings, rng)
	local s = settings.ClusterStrength * (0.5 + 0.5 * settings.Density)
	local base = Utilities.lerp(COMP.MIN_CLUSTER_MEMBERS, COMP.MAX_CLUSTER_MEMBERS, s)
	return math.max(COMP.MIN_CLUSTER_MEMBERS, math.floor(base + rng:range(-1, 1) * settings.Randomness + 0.5))
end

return CompositionPlanner
