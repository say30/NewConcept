-- ProportionGenerator : traits (issus d'une référence) + variation + graine
-- -> proportions ABSOLUES (en studs) et choix de style d'une NOUVELLE créature.
-- Faible : reste proche des proportions ; Moyenne : modifie davantage ;
-- Forte : la référence ne sert plus que de squelette structurel.

local Config = require(script.Parent.Parent.Config)

local ProportionGenerator = {}

local DEFAULT_LEG_LENGTH = { quadruped = 0.36, biped = 0.42, hexapod = 0.3, floating = 0, serpentine = 0.12 }

local HEAD_STYLE = {
	dragon = "snout", dino = "snout", beast = "snout", bird = "bird", insect = "flat",
	serpent = "flat", fish = "flat", blob = "round", golem = "boxy", humanoid = "round",
}
local MUZZLE_STYLE = {
	dragon = "snout", dino = "snout", beast = "snout", bird = "beak", insect = "flat",
	serpent = "flat", fish = "flat", blob = "none", golem = "none", humanoid = "flat",
}
local WING_STYLE = { dragon = "bat", bird = "feather", insect = "membrane", fish = "membrane" }

-- Stylisation « Roblox » : têtes un peu plus grosses, ailes plus lisibles.
local STYLE_HEAD = 1.25
local STYLE_WING = 1.3

local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end

function ProportionGenerator.fromTraits(traits, level: number, seed: number)
	local rng = Random.new(seed)
	local cfg = Config.VARIATION[level] or Config.VARIATION[2]
	local amt = cfg.amount

	local function vary(x, k)
		return x * (1 + rng:NextNumber(-amt, amt) * (k or 1))
	end
	local function chance(p)
		return rng:NextNumber() < p
	end
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local function keepOr(current, list)
		if current and chance(cfg.keepStyle) then
			return current
		end
		return pick(list)
	end
	-- Présence d'une caractéristique : conservée, sauf bascule selon la variation.
	local function flip(has, p)
		if chance(cfg.featureFlip * (p or 1)) then
			return not has
		end
		return has
	end

	local P = { seed = seed, level = level, archetype = traits.archetype }
	P.scale = vary(clamp(traits.scale or 8, 2, 80), 0.3)
	local s = P.scale
	P.locomotion = traits.locomotion or "quadruped"
	P.jitter = Config.LOWPOLY_JITTER * (0.8 + level * 0.3)

	-- Corps
	local b = traits.body
	local upright = P.locomotion == "biped"
	P.body = {
		length = vary(clamp(b.length, 0.25, 2.5)) * s,
		width = vary(clamp(b.width, 0.15, 1.4)) * s,
		height = vary(clamp(b.height, 0.18, 1.2)) * s,
		style = pick({ "barrel", "chest", "pear" }),
		sq = rng:NextNumber(0.05, 0.3),
	}
	if upright then
		-- Pour un bipède, « height » = hauteur du torse, « length » = profondeur.
		P.body.height = clamp(P.body.height, 0.22 * s, 0.55 * s)
		P.body.length = clamp(P.body.length, 0.15 * s, 0.45 * s)
		P.body.style = "chest"
	elseif P.locomotion == "serpentine" then
		P.body.length = clamp(P.body.length, 1.5 * s, 6 * s)
	end
	P.belly = chance(0.75)

	-- Pattes
	local pairs = traits.legPairs or 0
	local stance = if traits.sprawl then "sprawl" else "upright"
	if P.locomotion == "hexapod" then
		stance = if chance(0.7) then "insect" else "sprawl"
	end
	local legLen = traits.legLength or DEFAULT_LEG_LENGTH[P.locomotion] or 0.3
	P.legs = {
		pairs = pairs,
		length = vary(clamp(legLen, 0.12, 0.7)) * s,
		thickness = vary(clamp((traits.legThickness or 0.06) * 1.35, 0.045, 0.15), 1.2) * s,
		style = keepOr(traits.legStyle, { "paw", "paw", "hoof", "talon" }),
		stance = stance,
		toes = pick({ 3, 3, 4 }),
		claws = chance(0.6),
	}
	if traits.archetype == "bird" then
		P.legs.style = "talon"
	end
	if P.locomotion == "serpentine" and not chance(0.3 * level) then
		P.legs.pairs = 0
	end

	-- Bras (bipèdes)
	local armCount = traits.armCount or 0
	if P.locomotion == "biped" and armCount == 0 and chance(cfg.featureFlip) then
		armCount = 2
	end
	P.arms = {
		count = if armCount >= 2 then 2 else 0,
		length = vary(clamp(traits.armLength or 0.35, 0.2, 0.7)) * s,
		thickness = P.legs.thickness * 0.8,
	}

	-- Tête
	local h = traits.head
	local style = HEAD_STYLE[traits.archetype or ""] or "round"
	P.head = {
		length = clamp(vary(h.length) * STYLE_HEAD, 0.14, 0.8) * s,
		width = clamp(vary(h.width) * STYLE_HEAD, 0.12, 0.8) * s,
		height = clamp(vary(h.height) * STYLE_HEAD, 0.12, 0.8) * s,
		style = keepOr(style, { "round", "snout", "boxy", "flat" }),
		merged = P.locomotion == "floating" and (traits.headRatio or 0) > 0.9,
	}
	-- Une tête ne doit être ni minuscule ni plus grosse que 1,3 x le corps.
	local maxBody = math.max(P.body.width, P.body.height)
	local headMax = math.max(P.head.length, P.head.width, P.head.height)
	if headMax > maxBody * 1.3 then
		local k = maxBody * 1.3 / headMax
		P.head.length *= k
		P.head.width *= k
		P.head.height *= k
	elseif headMax < maxBody * 0.35 then
		local k = maxBody * 0.35 / headMax
		P.head.length *= k
		P.head.width *= k
		P.head.height *= k
	end
	local muzzleStyle = if traits.muzzle and traits.muzzle.beak then "beak" else MUZZLE_STYLE[traits.archetype or ""]
	muzzleStyle = keepOr(muzzleStyle or "snout", { "snout", "snout", "flat", "beak", "none" })
	P.head.muzzle = {
		style = muzzleStyle,
		length = clamp(vary((traits.muzzle and traits.muzzle.length) or 0.1), 0.05, 0.45) * s,
	}
	if muzzleStyle == "beak" then
		P.head.muzzle.length = math.max(P.head.muzzle.length, P.head.length * 0.45)
	else
		P.head.muzzle.length = clamp(P.head.muzzle.length, P.head.length * 0.25, P.head.length * 0.9)
	end
	P.head.jaw = (traits.hasJaw or chance(0.55)) and muzzleStyle ~= "beak" and muzzleStyle ~= "none"

	-- Cou
	local neckAngle = if upright then math.rad(80) elseif P.locomotion == "serpentine" then math.rad(55) else math.rad(35)
	if traits.head and traits.body and not upright then
		local dy = (traits.head.y - traits.body.y)
		local dz = math.max(traits.head.forward or 0.3, 0.05)
		neckAngle = clamp(math.atan2(dy, dz), math.rad(5), math.rad(70))
	end
	P.neck = {
		length = clamp(vary(traits.neckLength or 0.1), 0, 0.9) * s,
		thickness = P.head.width * rng:NextNumber(0.28, 0.4),
		angle = neckAngle + rng:NextNumber(-amt, amt) * 0.6,
	}
	if P.locomotion == "serpentine" then
		P.neck.length = math.max(P.neck.length, 0.35 * s)
	end

	-- Yeux
	local eyeCount = traits.eyes.count
	if eyeCount <= 0 then
		eyeCount = 2
	elseif eyeCount == 3 then
		eyeCount = 2
	elseif eyeCount > 4 then
		eyeCount = 4
	end
	if level == 3 and chance(0.12) then
		eyeCount = pick({ 1, 4 })
	end
	local eyeSize = if traits.eyes.size > 0 then traits.eyes.size else 0.08
	P.eyes = {
		count = eyeCount,
		radius = clamp(vary(eyeSize, 0.8) * 0.5 * 1.2 * s, 0.1 * P.head.height, 0.22 * P.head.height),
		pupil = pick({ "slit", "round" }),
	}

	-- Oreilles
	local hasEars = flip(traits.ears.count > 0)
	P.ears = {
		count = if hasEars then 2 else 0,
		size = clamp(vary(if traits.ears.size > 0 then traits.ears.size else 0.15), 0.06, 0.4) * s,
		style = pick({ "pointy", "round", "long" }),
	}

	-- Cornes
	local hornCount = traits.horns.count
	if flip(hornCount > 0) ~= (hornCount > 0) then
		hornCount = if hornCount > 0 then 0 else 2
	end
	if hornCount == 3 then
		hornCount = 2
	elseif hornCount > 4 then
		hornCount = 4
	end
	P.horns = {
		count = hornCount,
		length = clamp(vary(if traits.horns.length > 0 then traits.horns.length else 0.18), 0.06, 0.6) * s,
		style = pick({ "curved", "curved", "straight", "ram" }),
	}
	P.horns.radius = P.horns.length * rng:NextNumber(0.14, 0.22)

	-- Queue
	local t = traits.tail
	local hasTail = if t.has then (level < 3 or chance(0.9)) else flip(false, 0.7)
	P.tail = {
		has = hasTail,
		length = clamp(vary(t.length or 0.6), 0.2, 2.2) * s,
		segments = clamp(t.segments or 4, 3, 5),
		thickness = clamp(vary(t.thickness or 0.06), 0.03, 0.18) * s,
		tip = pick({ "none", "point", "spade", "club", "fin", "spikes" }),
		droop = rng:NextNumber(-0.45, -0.1),
		curl = rng:NextNumber(0, 0.9),
		sway = rng:NextNumber(-0.25, 0.25),
	}
	if traits.archetype == "dragon" and chance(0.5) then
		P.tail.tip = "spade"
	end
	P.tail.thickness = clamp(P.tail.thickness, P.body.height * 0.16, P.body.height * 0.3)

	-- Ailes
	local w = traits.wings
	local wingCount = w.count
	if level == 3 and chance(0.2) then
		wingCount = if wingCount > 0 then 0 else 2
	end
	P.wings = {
		count = wingCount,
		span = clamp(vary(w.span or 0.9) * STYLE_WING, 0.35, 2.5) * s,
		chord = clamp(vary(w.chord or 0.45), 0.2, 1.2) * s,
		style = keepOr(WING_STYLE[traits.archetype or ""] or "bat", { "bat", "bat", "feather", "membrane" }),
		dihedral = math.rad(rng:NextNumber(18, 38)),
	}

	-- Pics / plaques / cristaux dorsaux
	local spikeCount = traits.spikes.count + traits.crystals.count
	if flip(spikeCount > 0) ~= (spikeCount > 0) then
		spikeCount = if spikeCount > 0 then 0 else rng:NextInteger(3, 7)
	end
	P.spikes = {
		count = clamp(spikeCount, 0, 9),
		size = clamp(vary(if traits.spikes.size > 0 then traits.spikes.size else 0.1), 0.04, 0.3) * s,
		kind = if traits.crystals.count > traits.spikes.count
			then "crystal"
			else keepOr(traits.spikes.kind, { "spike", "plate", "crystal" }),
	}

	-- Tentacules
	local tentacles = traits.tentacles.count
	if P.locomotion == "floating" and tentacles == 0 and chance(0.5 + cfg.featureFlip) then
		tentacles = rng:NextInteger(3, 6)
	end
	P.tentacles = {
		count = tentacles,
		length = clamp(vary(if traits.tentacles.length > 0 then traits.tentacles.length else 0.5), 0.2, 1.2) * s,
		radius = P.body.width * rng:NextNumber(0.07, 0.11),
		curl = rng:NextNumber(0.3, 1),
	}

	P.fins = { side = traits.fins.count > 0 or (traits.archetype == "fish") }
	P.hover = if P.locomotion == "floating" then math.max(P.tentacles.length * 0.85, 0.25 * s) else 0

	return P
end

return ProportionGenerator
