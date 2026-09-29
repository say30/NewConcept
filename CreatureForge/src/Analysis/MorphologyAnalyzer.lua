-- MorphologyAnalyzer : transforme une liste de pièces en « traits » généraux
-- (proportions, nombre de membres, ailes, queue, cornes...). Aucun sommet n'est lu :
-- uniquement noms, tailles, positions et orientations des BaseParts.
--
-- Repère d'analyse : Y = haut, -Z = avant de la créature, origine = centre au sol.
-- Toutes les longueurs des traits sont relatives à la hauteur H (sauf `scale`).

local Util = require(script.Parent.Parent.Core.Util)

local M = {}

local KEYWORDS = {
	-- yeux
	eye = "eye", eyes = "eye", eyeball = "eye", pupil = "eye", iris = "eye", eyelid = "eye",
	sclera = "eye", oeil = "eye", yeux = "eye", retina = "eye",
	-- cornes
	horn = "horn", antler = "horn", tusk = "horn", corne = "horn",
	-- oreilles
	ear = "ear", oreille = "ear",
	-- bouche
	jaw = "jaw", mouth = "jaw", teeth = "jaw", tooth = "jaw", tongue = "jaw", mandible = "jaw",
	fang = "jaw", lip = "jaw", bouche = "jaw", machoire = "jaw", dent = "jaw",
	-- museau
	beak = "muzzle", bill = "muzzle", snout = "muzzle", muzzle = "muzzle", nose = "muzzle",
	nostril = "muzzle", bec = "muzzle", museau = "muzzle",
	-- tête
	head = "head", skull = "head", face = "head", cranium = "head", brow = "head",
	forehead = "head", cheek = "head", tete = "head", chin = "head",
	neck = "neck", cou = "neck",
	-- appendices
	wing = "wing", membrane = "wing", feather = "wing", aile = "wing",
	tail = "tail", queue = "tail",
	tentacle = "tentacle", tendril = "tentacle", tentacule = "tentacle",
	fin = "fin", flipper = "fin", nageoire = "fin",
	arm = "arm", forearm = "arm", hand = "arm", finger = "arm", thumb = "arm", elbow = "arm",
	wrist = "arm", bras = "arm", palm = "arm",
	leg = "leg", thigh = "leg", shin = "leg", calf = "leg", knee = "leg", foot = "leg", feet = "leg",
	paw = "leg", toe = "leg", hoof = "leg", ankle = "leg", heel = "leg", jambe = "leg", pied = "leg",
	patte = "leg", cuisse = "leg", sabot = "leg",
	claw = "claw", talon = "claw", nail = "claw", griffe = "claw",
	spike = "spike", spikes = "spike", spines = "spike", plate = "spike", crest = "spike",
	frill = "spike", thorn = "spike", epine = "spike",
	crystal = "crystal", gem = "crystal", jewel = "crystal", orb = "crystal", cristal = "crystal",
	-- corps
	torso = "body", body = "body", chest = "body", belly = "body", stomach = "body", pelvis = "body",
	hip = "body", waist = "body", abdomen = "body", thorax = "body", back = "body", spine = "body",
	shoulder = "body", corps = "body", ventre = "body", rump = "body", root = "body",
	hair = "mane", mane = "mane", fur = "mane", tuft = "mane", beard = "mane",
}

local PRIORITY = {
	"eye", "claw", "horn", "ear", "jaw", "muzzle", "tentacle", "fin", "spike", "crystal",
	"wing", "tail", "arm", "leg", "mane", "neck", "head", "body",
}
local RANK = {}
for i, r in PRIORITY do
	RANK[r] = i
end

local IGNORE = { hitbox = true, collider = true, collision = true, bounds = true, point = true, attachment = true }
-- Noms complets de pièces techniques (rig / accessoires), jamais de la morphologie.
local HELPER_NAMES = {
	humanoidrootpart = true, rootpart = true, root = true, hatpoint = true, torso = true,
	hitbox = true, collider = true, primarypart = true,
}

local ARCHETYPES = {
	dragon = "dragon", wyvern = "dragon", drake = "dragon", dino = "dino", rex = "dino", raptor = "dino",
	wolf = "beast", dog = "beast", cat = "beast", fox = "beast", bear = "beast", lion = "beast", tiger = "beast",
	bird = "bird", eagle = "bird", owl = "bird", phoenix = "bird", griffin = "bird", gryphon = "bird", chicken = "bird",
	spider = "insect", ant = "insect", beetle = "insect", scorpion = "insect", bug = "insect", insect = "insect",
	snake = "serpent", serpent = "serpent", worm = "serpent", naga = "serpent", eel = "serpent",
	fish = "fish", shark = "fish", whale = "fish", sea = "fish", ray = "fish",
	slime = "blob", blob = "blob", ghost = "blob", spirit = "blob", jelly = "blob", jellyfish = "blob",
	golem = "golem", demon = "humanoid", goblin = "humanoid", troll = "humanoid", ogre = "humanoid",
}

function M.classifyName(name: string)
	local best = nil
	for _, tok in Util.tokenize(name) do
		if IGNORE[tok] then
			return "ignore"
		end
		local singular = tok:gsub("s$", "")
		local r = KEYWORDS[tok] or KEYWORDS[singular]
		if r and (best == nil or RANK[r] < RANK[best]) then
			best = r
		end
	end
	return best
end

function M.archetypeOf(name: string)
	for _, tok in Util.tokenize(name) do
		local singular = tok:gsub("s$", "")
		local a = ARCHETYPES[tok] or ARCHETYPES[singular]
		if a then
			return a
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Boîtes englobantes
----------------------------------------------------------------------

local function newBox()
	return { min = Vector3.new(math.huge, math.huge, math.huge), max = Vector3.new(-math.huge, -math.huge, -math.huge), n = 0 }
end

local function addBox(box, bmin, bmax)
	box.min = box.min:Min(bmin)
	box.max = box.max:Max(bmax)
	box.n += 1
end

local function boxSize(box)
	if box.n == 0 then
		return Vector3.zero
	end
	return box.max - box.min
end

local function boxCenter(box)
	return (box.min + box.max) * 0.5
end

local function touches(a, b, eps)
	return a.bmin.X - eps <= b.bmax.X and b.bmin.X - eps <= a.bmax.X
		and a.bmin.Y - eps <= b.bmax.Y and b.bmin.Y - eps <= a.bmax.Y
		and a.bmin.Z - eps <= b.bmax.Z and b.bmin.Z - eps <= a.bmax.Z
end

-- Regroupe les pièces qui se touchent (union-find) -> une grappe = un membre / une corne...
local function clusters(list, eps)
	local parent = {}
	for i = 1, #list do
		parent[i] = i
	end
	local function find(i)
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	for i = 1, #list do
		for j = i + 1, #list do
			if touches(list[i], list[j], eps) then
				parent[find(i)] = find(j)
			end
		end
	end
	local groups, byRoot = {}, {}
	for i, p in list do
		local r = find(i)
		if not byRoot[r] then
			byRoot[r] = { parts = {}, box = newBox(), volume = 0 }
			table.insert(groups, byRoot[r])
		end
		local g = byRoot[r]
		table.insert(g.parts, p)
		addBox(g.box, p.bmin, p.bmax)
		g.volume += p.volume
	end
	return groups
end

local function computeBoxes(parts, frame)
	for _, p in parts do
		local h = p.size * 0.5
		local bmin = Vector3.new(math.huge, math.huge, math.huge)
		local bmax = -bmin
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local world = p.cframe:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
					local l = frame:PointToObjectSpace(world)
					bmin = bmin:Min(l)
					bmax = bmax:Max(l)
				end
			end
		end
		p.bmin, p.bmax = bmin, bmax
		p.center = (bmin + bmax) * 0.5
	end
end

----------------------------------------------------------------------
-- Analyse principale
----------------------------------------------------------------------

-- parts : { { inst?, name, cframe, size, volume, jointName? } }
-- Retourne traits, frame (CFrame du repère d'analyse, origine au sol).
function M.analyze(parts, pivot: CFrame, modelName: string)
	local look = pivot.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local frame = CFrame.lookAt(pivot.Position, pivot.Position + flat.Unit)

	local used = {}
	local hints = {} -- noms de pièces invisibles (ex. RightWing sans géométrie)
	for _, p in parts do
		p.region = M.classifyName(p.name)
		local lower = p.name:lower()
		local isPlainPart = p.className == "Part"
		if (p.transparency or 0) >= 0.95 or (HELPER_NAMES[lower] and isPlainPart) then
			if p.region and p.region ~= "ignore" and p.region ~= "body" then
				p.hintRegion = p.region
				table.insert(hints, p)
			end
			p.region = "ignore"
		end
		if (p.region == nil or p.region == "body") and p.jointName then
			local jr = M.classifyName(p.jointName)
			if jr and jr ~= "ignore" and jr ~= "body" then
				p.region = jr
			end
		end
		if p.region ~= "ignore" then
			table.insert(used, p)
		end
	end
	if #used == 0 then
		used = parts
		for _, p in used do
			p.region = M.classifyName(p.name)
		end
	end

	computeBoxes(used, frame)
	computeBoxes(hints, frame)

	-- Orientation : la tête (ou l'opposé de la queue) définit l'avant (-Z).
	local all = newBox()
	for _, p in used do
		addBox(all, p.bmin, p.bmax)
	end
	local function regionCentroid(regions)
		local sum, w = Vector3.zero, 0
		for _, p in used do
			if table.find(regions, p.region) then
				sum += p.center * p.volume
				w += p.volume
			end
		end
		return if w > 0 then sum / w else nil
	end
	local c = boxCenter(all)
	local headC = regionCentroid({ "head", "muzzle", "jaw", "eye" })
	local tailC = regionCentroid({ "tail" })
	local dir = if headC then headC - c elseif tailC then c - tailC else nil
	if dir then
		local extent = math.max(boxSize(all).X, boxSize(all).Z)
		if math.max(math.abs(dir.X), math.abs(dir.Z)) > 0.12 * extent then
			local angle = 0
			if math.abs(dir.X) > math.abs(dir.Z) then
				angle = if dir.X > 0 then -math.pi / 2 else math.pi / 2
			elseif dir.Z > 0 then
				angle = math.pi
			end
			if angle ~= 0 then
				frame = frame * CFrame.Angles(0, angle, 0)
				computeBoxes(used, frame)
				computeBoxes(hints, frame)
			end
		end
	end

	-- Origine : centre de l'emprise, au niveau du sol.
	all = newBox()
	for _, p in used do
		addBox(all, p.bmin, p.bmax)
	end
	local ground = all.min.Y
	local center = boxCenter(all)
	local shift = Vector3.new(center.X, ground, center.Z)
	frame = frame * CFrame.new(shift)
	for _, list in { used, hints } do
		for _, p in list do
			p.bmin -= shift
			p.bmax -= shift
			p.center -= shift
		end
	end
	local size = boxSize(all)
	local H = math.max(size.Y, 0.1)
	local Lz = math.max(size.Z, 0.1)
	local Wx = math.max(size.X, 0.1)
	-- Unité des traits : la plus grande dimension (robuste pour les créatures plates ou longues).
	local U = math.max(H, Lz, Wx)

	-- Classification géométrique des pièces sans nom parlant.
	local totalVol = 0
	for _, p in used do
		totalVol += p.volume
	end
	local core = Vector3.zero
	for _, p in used do
		core += p.center * (p.volume / math.max(totalVol, 1e-6))
	end
	for _, p in used do
		if p.region == nil then
			local s = p.bmax - p.bmin
			local maxD, minD = math.max(s.X, s.Y, s.Z), math.min(s.X, s.Y, s.Z)
			if p.volume < totalVol * 0.002 and maxD < 0.08 * H then
				p.region = "detail"
			elseif p.center.Y < 0.3 * H and math.max(s.X, s.Z) < 0.35 * math.min(Wx, Lz) then
				p.region = "leg"
			elseif p.center.Z > core.Z + 0.3 * Lz and p.center.Y > 0.1 * H then
				p.region = "tail"
			elseif math.abs(p.center.X) > 0.3 * Wx and minD < 0.3 * maxD and p.center.Y > core.Y then
				p.region = "wing"
			elseif p.center.Z < core.Z - 0.25 * Lz and p.center.Y > core.Y then
				p.region = "head"
			else
				p.region = "body"
			end
		end
	end

	-- Regroupements par région.
	local byRegion = {}
	for _, p in used do
		byRegion[p.region] = byRegion[p.region] or {}
		table.insert(byRegion[p.region], p)
	end
	local function regionBox(regions)
		local box = newBox()
		for _, r in regions do
			for _, p in byRegion[r] or {} do
				addBox(box, p.bmin, p.bmax)
			end
		end
		return box
	end
	local eps = 0.04 * H
	local function groupsOf(region, minExtent)
		local list = byRegion[region] or {}
		local gs = clusters(list, eps)
		local out = {}
		for _, g in gs do
			local s = boxSize(g.box)
			if math.max(s.X, s.Y, s.Z) >= (minExtent or 0) then
				table.insert(out, g)
			end
		end
		return out
	end

	local traits = { name = modelName, scale = U, found = {} }
	traits.archetype = M.archetypeOf(modelName)
	traits.heightRatio = H / U
	traits.lengthRatio = Lz / U
	traits.widthRatio = Wx / U
	traits.aspect = Lz / H

	-- Corps
	local bodyBox = regionBox({ "body" })
	if bodyBox.n == 0 then
		bodyBox = regionBox({ "body", "detail", "mane" })
	end
	traits.found.body = bodyBox.n > 0
	local bs = if bodyBox.n > 0 then boxSize(bodyBox) else Vector3.new(0.5 * Wx, 0.4 * H, 0.6 * Lz)
	local bc = if bodyBox.n > 0 then boxCenter(bodyBox) else Vector3.new(0, 0.55 * H, 0)
	traits.body = {
		length = bs.Z / U,
		width = bs.X / U,
		height = bs.Y / U,
		y = bc.Y / U,
		bottom = (bc.Y - bs.Y * 0.5) / H,
		upright = bs.Y > bs.Z * 1.15,
		-- Corps plat et large (raie, manta, poisson plat, soucoupe...).
		flat = bs.Y < 0.35 * math.max(bs.X, bs.Z) and bs.X > 0.8 * bs.Z,
	}

	-- Tête (+ museau + mâchoire)
	local headBox = regionBox({ "head", "muzzle", "jaw" })
	traits.found.head = headBox.n > 0
	local hs = if headBox.n > 0 then boxSize(headBox) else Vector3.new(bs.X * 0.6, bs.Y * 0.6, bs.Y * 0.7)
	local hc = if headBox.n > 0 then boxCenter(headBox) else bc + Vector3.new(0, bs.Y * 0.4, -bs.Z * 0.6)
	traits.head = {
		length = hs.Z / U,
		width = hs.X / U,
		height = hs.Y / U,
		y = hc.Y / U,
		forward = (bc.Z - hc.Z) / U,
	}
	local headVol = hs.X * hs.Y * hs.Z
	local bodyVol = bs.X * bs.Y * bs.Z
	traits.headRatio = (headVol / math.max(bodyVol, 1e-6)) ^ (1 / 3)

	local muzzleBox = regionBox({ "muzzle" })
	traits.muzzle = {
		length = if muzzleBox.n > 0 then boxSize(muzzleBox).Z / U else hs.Z / U * 0.3,
		beak = false,
	}
	for _, p in byRegion.muzzle or {} do
		for _, tok in Util.tokenize(p.name) do
			if tok == "beak" or tok == "bec" or tok == "bill" then
				traits.muzzle.beak = true
			end
		end
	end
	traits.hasJaw = (byRegion.jaw ~= nil)

	-- Cou
	local neckBox = regionBox({ "neck" })
	if neckBox.n > 0 then
		local s = boxSize(neckBox)
		traits.neckLength = math.max(s.Y, s.Z) / U
	elseif traits.body.upright then
		local gap = (hc.Y - hs.Y * 0.5) - (bc.Y + bs.Y * 0.5)
		traits.neckLength = math.max(gap, 0) / U
	else
		local gap = (Vector3.new(0, hc.Y, hc.Z) - Vector3.new(0, bc.Y, bc.Z - bs.Z * 0.5)).Magnitude - hs.Z * 0.5
		traits.neckLength = math.max(gap, 0) / U
	end

	-- Membres
	local legGroups = groupsOf("leg", 0.08 * H)
	local armGroups = groupsOf("arm", 0.06 * H)
	local legs = {}
	for _, g in legGroups do
		if g.box.min.Y > 0.2 * H and #legGroups > 2 then
			table.insert(armGroups, g) -- membre qui ne touche pas le sol : bras
		else
			table.insert(legs, g)
		end
	end
	traits.legCount = #legs
	traits.armCount = math.min(#armGroups, 4)
	local legTop, legThick, footSpread = 0, 0, 0
	for _, g in legs do
		legTop += math.min(g.box.max.Y, bc.Y - bs.Y * 0.25)
		footSpread += math.abs(boxCenter(g.box).X)
		local t = 0
		for _, p in g.parts do
			local s = p.bmax - p.bmin
			t += math.min(s.X, s.Z) * 0.5
		end
		legThick += t / #g.parts
	end
	if #legs > 0 then
		traits.legLength = (legTop / #legs) / U
		traits.legThickness = (legThick / #legs) / U
		traits.sprawl = (footSpread / #legs) > bs.X * 0.7
	end
	if #armGroups > 0 then
		local len = 0
		for _, g in armGroups do
			local s = boxSize(g.box)
			len += math.max(s.X, s.Y, s.Z)
		end
		traits.armLength = len / #armGroups / U
	end
	traits.legStyle = "paw"
	for _, p in byRegion.leg or {} do
		for _, tok in Util.tokenize(p.name) do
			if tok == "hoof" or tok == "sabot" then
				traits.legStyle = "hoof"
			elseif tok == "talon" then
				traits.legStyle = "talon"
			end
		end
	end

	-- Queue
	local tailBox = regionBox({ "tail" })
	traits.tail = { has = tailBox.n > 0 }
	if tailBox.n > 0 then
		local s = boxSize(tailBox)
		local t = 0
		for _, p in byRegion.tail do
			local ps = p.bmax - p.bmin
			t += math.min(ps.X, ps.Y, ps.Z) * 0.5
		end
		traits.tail.length = s.Magnitude * 0.9 / U
		traits.tail.segments = math.clamp(#byRegion.tail, 2, 6)
		traits.tail.thickness = t / #byRegion.tail / U
	end

	-- Ailes
	local wingGroups = groupsOf("wing", 0.1 * H)
	traits.wings = { count = math.min(#wingGroups, 4) }
	if #wingGroups > 0 then
		local span, chord = 0, 0
		for _, g in wingGroups do
			local s = boxSize(g.box)
			span += math.max(s.X, s.Y)
			chord += s.Z
		end
		traits.wings.span = span / #wingGroups / U
		traits.wings.chord = chord / #wingGroups / U
		if traits.wings.count == 1 then
			traits.wings.count = 2
		end
	end

	-- Ailes « fantômes » : pièces invisibles nommées Wing aux extrémités (rigs de pets).
	if traits.wings.count == 0 then
		local tip = 0
		for _, p in hints do
			if p.hintRegion == "wing" or p.hintRegion == "fin" then
				tip = math.max(tip, math.abs(p.center.X))
			end
		end
		if tip > bs.X * 0.25 then
			traits.wings.count = 2
			traits.wings.span = math.max(tip - bs.X * 0.2, tip * 0.5) / U
			traits.wings.chord = bs.Z * 0.7 / U
			traits.wings.fromHints = true
		end
	end

	-- Détails appariés
	local function countAndSize(region, minExtent)
		local gs = groupsOf(region, minExtent or 0)
		local size = 0
		for _, g in gs do
			local s = boxSize(g.box)
			size += math.max(s.X, s.Y, s.Z)
		end
		return #gs, if #gs > 0 then size / #gs / U else 0
	end
	local n, s
	n, s = countAndSize("horn")
	traits.horns = { count = math.min(n, 6), length = s }
	n, s = countAndSize("ear")
	traits.ears = { count = math.min(n, 4), size = s }
	n, s = countAndSize("eye")
	traits.eyes = { count = math.min(n, 8), size = s }
	n, s = countAndSize("spike")
	traits.spikes = { count = math.max(n, #(byRegion.spike or {})), size = s, kind = "spike" }
	for _, p in byRegion.spike or {} do
		for _, tok in Util.tokenize(p.name) do
			if tok == "plate" then
				traits.spikes.kind = "plate"
			end
		end
	end
	n, s = countAndSize("crystal")
	traits.crystals = { count = n, size = s }
	n, s = countAndSize("tentacle", 0.1 * H)
	traits.tentacles = { count = math.min(n, 8), length = s }
	n, s = countAndSize("fin")
	traits.fins = { count = n, size = s }

	-- Locomotion
	local legCount = traits.legCount
	if legCount >= 5 then
		traits.locomotion = "hexapod"
		traits.legPairs = math.clamp(math.floor(legCount / 2 + 0.5), 3, 4)
	elseif legCount >= 3 then
		traits.locomotion = if traits.armCount >= 2 and legCount == 3 then "biped" else "quadruped"
		traits.legPairs = 2
	elseif legCount >= 1 then
		traits.locomotion = "biped"
		traits.legPairs = 1
	else
		traits.legPairs = 0
		local lifted = traits.body.bottom > 0.15
		if lifted or traits.body.flat or traits.tentacles.count > 0 or traits.wings.count > 0 then
			traits.locomotion = "floating"
		elseif traits.aspect > 2.2 and bs.X < 0.5 * bs.Z then
			traits.locomotion = "serpentine"
		else
			traits.locomotion = "floating"
		end
	end
	if traits.archetype == "insect" and traits.legPairs >= 2 then
		traits.locomotion = "hexapod"
		traits.legPairs = math.max(traits.legPairs, 3)
	end

	traits.regionCounts = {}
	for r, list in byRegion do
		traits.regionCounts[r] = #list
	end

	return traits, frame
end

-- Résumé morphologique en une ligne.
function M.describe(traits)
	local names = {
		quadruped = "Quadrupède",
		biped = "Bipède",
		hexapod = "Hexapode",
		floating = "Flottante",
		serpentine = "Rampante",
	}
	local bits = { names[traits.locomotion] or "Créature" }
	if traits.legPairs and traits.legPairs > 0 then
		table.insert(bits, (traits.legPairs * 2) .. " pattes")
	end
	if traits.armCount and traits.armCount > 0 then
		table.insert(bits, traits.armCount .. " bras")
	end
	if traits.wings.count > 0 then
		table.insert(bits, traits.wings.count .. " ailes")
	end
	if traits.tail.has then
		table.insert(bits, "queue")
	end
	if traits.horns.count > 0 then
		table.insert(bits, traits.horns.count .. " cornes")
	end
	if traits.tentacles.count > 0 then
		table.insert(bits, traits.tentacles.count .. " tentacules")
	end
	return table.concat(bits, " · ")
end

return M
