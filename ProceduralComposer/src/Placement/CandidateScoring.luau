--[[
	CandidateScoring
	Plutôt que de choisir une position au hasard, chaque placement génère
	plusieurs candidats valides puis leur attribue un score composite :

	  + cohésion de groupe (distance idéale aux membres du même groupe)
	  - encombrement (trop proche d'éléments non groupés)
	  - deux grands éléments trop proches (hiérarchie visuelle)
	  - répétition du même asset à proximité
	  ± affinité aux bords / aux murs (selon la passe et l'algorithme)
	  - proximité de l'axe central (préservation du centre, couloirs)
	  + équilibre gauche/droite de la masse visuelle (modulé par Symmetry)
	  + rythme visuel le long de la grande dimension
	  - zones "respirantes" du champ de bruit (EmptySpaceRatio)
	  + points de composition (tiers) pour les éléments héros
	  + bruit (Randomness)

	Le moteur choisit ensuite parmi les meilleurs candidats (pas toujours le
	premier, pour éviter un résultat mécanique).
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local RandomGenerator = require(Core.RandomGenerator)

local CandidateScoring = {}

local SC = Config.Scoring
local W = SC.Weights
local COMP = Config.Composition

local LARGE = { Large = true, Hero = true }

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

--[[
	env = {
	  State, Domain, Asset, Radius, Profile, ClusterId, Rng, Settings, NoiseSeed
	}
	Profile = {
	  EdgeAffinity (-1..1), WallAffinity (0..1), Thirds (0..1),
	  ClusterCenter (Vector2?), ClusterRadius, CenterAvoid (0..1),
	  RhythmWeight (0..1), EmptyWeight (0..1), BalanceWeight (0..1),
	  AvoidClusters (bool)
	}
	Renvoie le score (plus grand = meilleur).
]]
function CandidateScoring.floor(env, pos)
	local settings = env.Settings
	local profile = env.Profile
	local domain = env.Domain
	local asset = env.Asset
	local r = env.Radius
	local score = 0

	-- Voisinage.
	local searchRadius = r * SC.NEIGHBOR_RADIUS_FACTOR + 2 * settings.SpacingScale
	local neighbors = env.State.Index:query(pos, searchRadius)
	local isLarge = LARGE[asset.SizeClass] == true
	local crowd, cohesion, largePenalty, repeatPenalty = 0, 0, 0, 0
	local cohesionCount = 0
	for _, n in ipairs(neighbors) do
		local d = (n.Pos - pos).Magnitude - n.Radius - r
		if env.ClusterId and n.ClusterId == env.ClusterId then
			local ideal = r * SC.CLUSTER_GAP_FACTOR * (1.5 - settings.ClusterStrength) + settings.MinimumSpacing
			local dev = math.abs(d - ideal) / math.max(r * 2, 0.5)
			cohesion += math.exp(-dev * dev * 2)
			cohesionCount += 1
		else
			local desired = (r + n.Radius) * SC.DESIRED_GAP_FACTOR * settings.SpacingScale + settings.MinimumSpacing
			if d < desired then
				crowd += (1 - clamp01(d / desired)) ^ 2
			end
		end
		if isLarge and LARGE[n.SizeClass] then
			local need = (r + n.Radius) * SC.LARGE_SEPARATION_FACTOR * settings.SpacingScale
			if d < need then
				largePenalty += 1 - clamp01(d / need)
			end
		end
		if n.Asset == asset then
			local repeatRadius = r * SC.REPEAT_RADIUS_FACTOR
			if d < repeatRadius then
				repeatPenalty += 1 - clamp01(d / repeatRadius)
			end
		end
	end
	score -= W.Crowding * math.min(crowd, 3)
	if cohesionCount > 0 then
		score += W.ClusterCohesion * (cohesion / cohesionCount)
	end
	score -= W.LargeSeparation * math.min(largePenalty, 2)
	score -= W.Repetition * math.min(repeatPenalty, 2) * (1.2 - settings.Variation)

	-- Distance au centre du groupe visé.
	if profile.ClusterCenter and profile.ClusterRadius then
		local d = (pos - profile.ClusterCenter).Magnitude
		score -= W.ClusterCohesion * clamp01(d / math.max(profile.ClusterRadius * 2, 1)) * 0.5
	end

	-- Bords et murs.
	if profile.EdgeAffinity and profile.EdgeAffinity ~= 0 and domain.edgeDistance then
		local dEdge = domain:edgeDistance(pos)
		local closeness = 1 - clamp01(dEdge / math.max(domain.EdgeDepth, 0.5))
		score += W.Edge * profile.EdgeAffinity * (closeness * 2 - 1)
	end
	if profile.WallAffinity and profile.WallAffinity > 0 and domain.wallDistance then
		local dWall = domain:wallDistance(pos)
		if dWall < math.huge then
			score += W.Wall * profile.WallAffinity * (1 - clamp01(dWall / math.max(domain.EdgeDepth * 2, 1)))
		end
	end

	-- Préservation douce du centre.
	if profile.CenterAvoid and profile.CenterAvoid > 0 and domain.crossNormalized then
		local c = math.abs(domain:crossNormalized(pos))
		score -= W.Center * profile.CenterAvoid * (1 - c) ^ 2
	end

	-- Équilibre gauche/droite.
	if profile.BalanceWeight and profile.BalanceWeight > 0 and domain.crossNormalized then
		local side = domain:crossNormalized(pos)
		local mp, mn = env.State.MassPositive, env.State.MassNegative
		local total = mp + mn
		if total > 0 then
			local imbalance = (mp - mn) / total
			-- Côté le plus léger favorisé.
			local prefer = if side >= 0 then -imbalance else imbalance
			score += W.Balance * profile.BalanceWeight * prefer
		end
	end

	-- Rythme le long de la grande dimension.
	if profile.RhythmWeight and profile.RhythmWeight > 0 and domain.rhythm then
		score += W.Rhythm * profile.RhythmWeight * settings.VisualRhythm * (domain:rhythm(pos) * 2 - 1)
	end

	-- Champ de densité : zones respirantes cohérentes.
	if profile.EmptyWeight and profile.EmptyWeight > 0 and settings.EmptySpaceRatio > 0 then
		local scale = math.max(COMP.NOISE_SCALE * settings.SpacingScale, domain.NoiseScale or 0)
		local n = RandomGenerator.fractalNoise2D(env.NoiseSeed, pos.X / scale, pos.Y / scale)
		local threshold = settings.EmptySpaceRatio
		if n < threshold then
			score -= W.Empty * profile.EmptyWeight * (1 - n / math.max(threshold, 1e-3))
		else
			score += W.Empty * profile.EmptyWeight * 0.25 * ((n - threshold) / math.max(1 - threshold, 1e-3))
		end
	end

	-- Points de composition (règle des tiers).
	if profile.Thirds and profile.Thirds > 0 and domain.Thirds then
		local best = math.huge
		for _, p in ipairs(domain.Thirds) do
			best = math.min(best, (p - pos).Magnitude)
		end
		local ref = math.max(domain.MinExtent * 0.25, 1)
		score += W.Thirds * profile.Thirds * (1 - clamp01(best / ref))
	end

	-- Éloignement des autres groupes (centres de groupes).
	if profile.AvoidClusters then
		local minD = math.huge
		for _, c in ipairs(env.State.Clusters) do
			minD = math.min(minD, (c.Center - pos).Magnitude - c.Radius)
		end
		if minD < math.huge then
			local breathing = (profile.ClusterRadius or r * 3) * COMP.CLUSTER_BREATHING * (0.6 + settings.EmptySpaceRatio)
			score -= W.ClusterSeparation * (1 - clamp01(minD / math.max(breathing, 1)))
		end
	end

	-- Bruit.
	score += W.Noise * settings.Randomness * (env.Rng:next() - 0.5) * 2

	return score
end

--[[
	Choisit l'ordre de test des candidats triés par score :
	le premier est tiré parmi les N meilleurs (N dépend de Randomness),
	les suivants restent dans l'ordre du score.
]]
function CandidateScoring.orderCandidates(scored, settings, rng)
	table.sort(scored, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.Index < b.Index
	end)
	local topN = math.clamp(math.floor(COMP.MIN_TOP_CHOICES + (COMP.MAX_TOP_CHOICES - COMP.MIN_TOP_CHOICES) * settings.Randomness + 0.5), 1, math.max(1, #scored))
	if topN > 1 then
		local weights = {}
		for i = 1, topN do
			weights[i] = 1 / i
		end
		local pick = rng:weightedIndex(weights) or 1
		if pick ~= 1 then
			local chosen = table.remove(scored, pick)
			table.insert(scored, 1, chosen)
		end
	end
	return scored
end

return CandidateScoring
