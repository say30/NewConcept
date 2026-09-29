-- ShapeLibrary : bibliothèque de formes stylisées low-poly, 100 % procédurales.
-- Chaque forme = fonction(params, rng) -> MeshBuilder, dans son repère local :
--   * formes « membres » (limb, horn, claw, spike, crystal, tentacle, ear, tail...) :
--     base à l'origine, croissance selon +Y ;
--   * formes « volumes » (ellipsoid, head, torso, paw, eye...) : centrées ;
--     head / muzzle / jaw / torso sont orientés avec l'avant vers -Z ;
--   * wing : racine à l'origine, envergure +X, arrière +Z, épaisseur Y ;
--   * fin / plate : base à l'origine, hauteur +Y, longueur +Z, épaisseur X.

local MeshBuilder = require(script.Parent.MeshBuilder)
local MeshUtils = require(script.Parent.MeshUtils)

local X = Vector3.new(1, 0, 0)
local Y = Vector3.new(0, 1, 0)
local Z = Vector3.new(0, 0, 1)

local Shapes = {}

local function alongY(from: Vector3, to: Vector3)
	local dir = to - from
	local up = dir.Unit
	local h = if math.abs(up:Dot(X)) > 0.95 then Z else X
	local right = (h - up * h:Dot(up)).Unit
	return CFrame.fromMatrix(from, right, up)
end

-- Profil longitudinal { {t, largeur, hauteur, décalageVertical}, ... } balayé selon -Z.
local function sweepProfileZ(b, sx, sy, sz, profile, zStart, opts)
	local spine, radii = {}, {}
	for _, e in profile do
		local t, w, h, oy = e[1], e[2], e[3], e[4] or 0
		spine[#spine + 1] = Vector3.new(0, oy * sy * 0.5, zStart - t * sz)
		radii[#radii + 1] = { w * sx * 0.5, h * sy * 0.5 }
	end
	MeshUtils.sweep(b, spine, radii, { sides = opts.sides or 8, squareness = opts.sq, hint = X })
	return b
end

----------------------------------------------------------------------
-- Volumes de base
----------------------------------------------------------------------

function Shapes.ellipsoid(p)
	local b = MeshBuilder.new()
	local rings = p.rings or 5
	local flat = p.flat or 0
	local spine, radii = {}, {}
	-- sqY > 0 : profil vertical « super-ellipse » (extrémités plus pleines, remplit la boîte).
	local e = 2 / (2 + (p.sqY or 0) * 6)
	for k = 0, rings + 1 do
		local phi = -math.pi / 2 + math.pi * k / (rings + 1)
		local sn = math.sin(phi)
		local y = math.sign(sn) * math.abs(sn) ^ e * p.sy * 0.5
		if y < 0 then
			y *= (1 - flat)
		end
		local c = math.abs(math.cos(phi)) ^ e
		if k == 0 or k == rings + 1 then
			c = 0
		end
		spine[#spine + 1] = Vector3.new(0, y, 0)
		radii[#radii + 1] = { c * p.sx * 0.5, c * p.sz * 0.5 }
	end
	return MeshUtils.sweep(b, spine, radii, { sides = p.sides or 8, squareness = p.sq, hint = X })
end
Shapes.sphere = Shapes.ellipsoid
Shapes.pelvis = Shapes.ellipsoid
Shapes.belly = Shapes.ellipsoid

function Shapes.roundedCube(p)
	local b = MeshBuilder.new()
	local bv = p.bevel or math.min(p.sx, p.sy, p.sz) * 0.18
	local hx, hy, hz = p.sx * 0.5, p.sy * 0.5, p.sz * 0.5
	local spine = {
		Vector3.new(0, -hy, 0),
		Vector3.new(0, -hy + bv, 0),
		Vector3.new(0, hy - bv, 0),
		Vector3.new(0, hy, 0),
	}
	local radii = { { hx - bv, hz - bv }, { hx, hz }, { hx, hz }, { hx - bv, hz - bv } }
	return MeshUtils.sweep(b, spine, radii, { sides = 8, squareness = 0.8, hint = X })
end

----------------------------------------------------------------------
-- Membres et cylindres
----------------------------------------------------------------------

-- Segment de membre aux extrémités arrondies (déborde légèrement des articulations).
function Shapes.limb(p)
	local b = MeshBuilder.new()
	local L, r0, r1 = p.len, p.r0, p.r1 or p.r0
	local bulge = p.bulge or 0.08
	local curve = p.curve or 0
	local spine = {
		Vector3.new(0, -r0 * 0.5, 0),
		Vector3.new(0, 0, 0),
		Vector3.new(0, L * 0.5, curve * L),
		Vector3.new(0, L, 0),
		Vector3.new(0, L + r1 * 0.5, 0),
	}
	local rm = (r0 + r1) * 0.5 * (1 + bulge)
	local radii = { { r0 * 0.6 }, { r0 }, { rm }, { r1 }, { r1 * 0.6 } }
	return MeshUtils.sweep(b, spine, radii, { sides = p.sides or 7, squareness = p.sq, hint = X })
end
Shapes.capsule = Shapes.limb
Shapes.tail = Shapes.limb
Shapes.neck = Shapes.limb

function Shapes.taperedCylinder(p)
	local b = MeshBuilder.new()
	return MeshUtils.sweep(
		b,
		{ Vector3.zero, Vector3.new(0, p.len, 0) },
		{ { p.r0 }, { p.r1 or p.r0 } },
		{ sides = p.sides or 8, squareness = p.sq, hint = X }
	)
end

function Shapes.cone(p)
	local b = MeshBuilder.new()
	return MeshUtils.sweep(
		b,
		{ Vector3.zero, Vector3.new(0, p.len, 0) },
		{ { p.r }, { 0 } },
		{ sides = p.sides or 7, hint = X }
	)
end

-- Corne : courbe vers l'arrière (+Z) et l'extérieur (+X). style "ram" = spirale.
function Shapes.horn(p)
	local b = MeshBuilder.new()
	local L, r = p.len, p.r
	local segs = p.segs or 6
	local out = p.out or 0.2
	local curve = p.curve or 0.5
	local spine
	if p.style == "ram" then
		spine = {}
		for i = 0, segs + 2 do
			local t = i / (segs + 2)
			local ang = t * math.pi * 1.35
			local R = L * 0.42 * (1 - 0.35 * t)
			spine[#spine + 1] = Vector3.new(out * L * 0.6 * t, math.sin(ang) * R, (1 - math.cos(ang)) * R)
		end
	else
		spine = MeshUtils.bezier(
			Vector3.zero,
			Vector3.new(0, L * 0.55, 0),
			Vector3.new(out * L * 0.5, L * (1 - math.abs(curve) * 0.35), curve * L * 0.6),
			segs
		)
	end
	local radii = {}
	for i = 1, #spine do
		local t = (i - 1) / (#spine - 1)
		radii[i] = { r * (1 - t) ^ 0.9 }
	end
	radii[#radii] = { 0 }
	return MeshUtils.sweep(b, spine, radii, { sides = p.sides or 6, hint = X })
end

-- Griffe : corne courbée vers l'avant (-Z).
function Shapes.claw(p)
	return Shapes.horn({ len = p.len, r = p.r, curve = -(p.curve or 0.7), out = 0, segs = 3, sides = 5 })
end

function Shapes.spike(p)
	return Shapes.horn({ len = p.len, r = p.r, curve = p.curve or 0.25, out = 0, segs = 2, sides = p.sides or 4 })
end

function Shapes.crystal(p, rng)
	local b = MeshBuilder.new()
	local L, r = p.len, p.r
	local spine = {
		Vector3.new(0, -L * 0.12, 0),
		Vector3.new(0, L * 0.08, 0),
		Vector3.new(0, L * 0.68, 0),
		Vector3.new(0, L, 0),
	}
	local radii = { { 0 }, { r }, { r * 0.9 }, { 0 } }
	return MeshUtils.sweep(b, spine, radii, { sides = p.sides or 6, phase = rng:NextNumber(0, 1), hint = X })
end

-- Tentacule : s'enroule progressivement vers +Z.
function Shapes.tentacle(p)
	local b = MeshBuilder.new()
	local L, r = p.len, p.r
	local segs = p.segs or 8
	local curl = p.curl or 0.8
	local spine, radii = {}, {}
	local pos = Vector3.zero
	local step = L / segs
	for i = 0, segs do
		local t = i / segs
		spine[#spine + 1] = pos
		radii[#radii + 1] = { if i == segs then 0 else r * (1 - t * 0.85) }
		local ang = curl * t * t * math.pi
		pos += Vector3.new(0, math.cos(ang), math.sin(ang)) * step
	end
	return MeshUtils.sweep(b, spine, radii, { sides = p.sides or 6, hint = X })
end

----------------------------------------------------------------------
-- Tête
----------------------------------------------------------------------

local HEAD_PROFILES = {
	round = {
		{ 0, 0, 0, 0.05 },
		{ 0.08, 0.55, 0.6, 0.03 },
		{ 0.3, 0.95, 0.95, 0 },
		{ 0.55, 1, 0.93, 0 },
		{ 0.8, 0.85, 0.78, -0.05 },
		{ 1, 0.55, 0.5, -0.12 },
	},
	snout = {
		{ 0, 0, 0, 0.1 },
		{ 0.1, 0.6, 0.65, 0.05 },
		{ 0.35, 1, 1, 0 },
		{ 0.6, 0.9, 0.85, -0.05 },
		{ 0.85, 0.7, 0.62, -0.15 },
		{ 1, 0.5, 0.42, -0.2 },
	},
	flat = {
		{ 0, 0, 0, 0 },
		{ 0.1, 0.65, 0.5, 0 },
		{ 0.35, 1, 0.72, 0 },
		{ 0.7, 0.95, 0.66, -0.05 },
		{ 1, 0.7, 0.45, -0.1 },
	},
}
HEAD_PROFILES.boxy = HEAD_PROFILES.round
HEAD_PROFILES.bird = HEAD_PROFILES.round

function Shapes.head(p)
	local b = MeshBuilder.new()
	local profile = HEAD_PROFILES[p.style or "round"] or HEAD_PROFILES.round
	local sq = p.sq or (if p.style == "boxy" then 0.6 else 0.1)
	return sweepProfileZ(b, p.sx, p.sy, p.sz, profile, p.sz * 0.5, { sq = sq, sides = 8 })
end

local MUZZLE_PROFILES = {
	snout = { { 0, 1, 1, 0 }, { 0.45, 0.95, 0.9, -0.03 }, { 0.8, 0.8, 0.72, -0.06 }, { 1, 0.55, 0.5, -0.08 } },
	beak = { { 0, 1, 1, 0 }, { 0.4, 0.75, 0.8, -0.05 }, { 0.75, 0.4, 0.5, -0.2 }, { 1, 0, 0, -0.45 } },
	flat = { { 0, 1, 1, 0 }, { 0.5, 1.05, 0.8, -0.05 }, { 1, 0.85, 0.55, -0.1 } },
}

-- Museau : base en z = 0 (collée à la tête), pointe vers -Z.
function Shapes.muzzle(p)
	local b = MeshBuilder.new()
	local style = p.style or "snout"
	local profile = MUZZLE_PROFILES[style] or MUZZLE_PROFILES.snout
	return sweepProfileZ(b, p.sx, p.sy, p.sz, profile, 0, {
		sq = if style == "beak" then 0.1 else 0.35,
		sides = if style == "beak" then 6 else 8,
	})
end

-- Mâchoire : charnière en z = 0, s'étend vers -Z.
function Shapes.jaw(p)
	local b = MeshBuilder.new()
	local profile = { { 0, 0.9, 0.8, 0 }, { 0.5, 0.85, 0.7, -0.1 }, { 0.85, 0.7, 0.5, -0.15 }, { 1, 0.5, 0.35, -0.15 } }
	return sweepProfileZ(b, p.sx, p.sy, p.sz, profile, 0, { sq = 0.5, sides = 8 })
end

----------------------------------------------------------------------
-- Corps
----------------------------------------------------------------------

local TORSO_PROFILES = {
	barrel = {
		{ 0, 0.35, 0.4, 0 },
		{ 0.12, 0.8, 0.82, 0 },
		{ 0.45, 1, 1, 0 },
		{ 0.8, 0.95, 0.97, 0.03 },
		{ 1, 0.55, 0.6, 0.05 },
	},
	chest = {
		{ 0, 0.3, 0.35, -0.02 },
		{ 0.15, 0.7, 0.72, 0 },
		{ 0.45, 0.88, 0.9, 0 },
		{ 0.72, 1, 1, 0.04 },
		{ 0.9, 0.9, 0.92, 0.06 },
		{ 1, 0.5, 0.55, 0.08 },
	},
	pear = {
		{ 0, 0.45, 0.5, 0 },
		{ 0.15, 0.92, 0.95, -0.02 },
		{ 0.4, 1, 1, 0 },
		{ 0.75, 0.82, 0.85, 0.03 },
		{ 1, 0.45, 0.5, 0.05 },
	},
}
TORSO_PROFILES.slim = TORSO_PROFILES.barrel

-- Torse : axe long selon Z (avant = -Z), centré.
function Shapes.torso(p)
	local b = MeshBuilder.new()
	local profile = TORSO_PROFILES[p.style or "barrel"] or TORSO_PROFILES.barrel
	return sweepProfileZ(b, p.sx, p.sy, p.sz, profile, p.sz * 0.5, { sq = p.sq or 0.15, sides = p.sides or 10 })
end

----------------------------------------------------------------------
-- Yeux / oreilles
----------------------------------------------------------------------

function Shapes.eye(p)
	return Shapes.ellipsoid({ sx = 2 * p.r, sy = 2 * p.r * 1.05, sz = 2 * p.r * 0.75, rings = 4, sides = 8 })
end

function Shapes.pupil(p)
	if p.style == "slit" then
		return Shapes.ellipsoid({ sx = p.r * 0.35, sy = p.r * 1.3, sz = p.r * 0.25, rings = 3, sides = 6 })
	end
	return Shapes.ellipsoid({ sx = p.r * 0.9, sy = p.r * 0.9, sz = p.r * 0.25, rings = 3, sides = 6 })
end

local EAR_PROFILES = {
	pointy = { { 0, 0.75 }, { 0.3, 1 }, { 0.65, 0.65 }, { 1, 0 } },
	round = { { 0, 0.7 }, { 0.35, 1 }, { 0.75, 0.85 }, { 1, 0 } },
	long = { { 0, 0.6 }, { 0.2, 0.9 }, { 0.6, 0.8 }, { 1, 0 } },
}

-- Oreille : feuille aplatie selon Z, croissance +Y, légère courbure arrière.
function Shapes.ear(p)
	local b = MeshBuilder.new()
	local profile = EAR_PROFILES[p.style or "pointy"] or EAR_PROFILES.pointy
	local spine, radii = {}, {}
	for _, e in profile do
		local t, w = e[1], e[2]
		spine[#spine + 1] = Vector3.new(0, t * p.len, t * t * p.len * 0.18)
		radii[#radii + 1] = { w * p.width * 0.5, w * p.thick * 0.5 }
	end
	return MeshUtils.sweep(b, spine, radii, { sides = 6, hint = X })
end

----------------------------------------------------------------------
-- Pieds
----------------------------------------------------------------------

-- Patte : coussinet aplati + orteils + griffes optionnelles. Centrée.
function Shapes.paw(p)
	local b = MeshBuilder.new()
	b:merge(Shapes.ellipsoid({ sx = p.sx, sy = p.sy, sz = p.sz, flat = 0.7, rings = 4, sides = 8 }))
	local toes = p.toes or 3
	local toeW = p.sx / toes * 1.05
	for i = 1, toes do
		local x = (i - (toes + 1) / 2) * toeW * 0.85
		local toePos = Vector3.new(x, -p.sy * 0.18, -p.sz * 0.38)
		b:merge(
			Shapes.ellipsoid({ sx = toeW, sy = p.sy * 0.55, sz = p.sz * 0.38, flat = 0.6, rings = 3, sides = 6 }),
			CFrame.new(toePos)
		)
		if p.claws then
			local claw = Shapes.claw({ len = p.sz * 0.32, r = toeW * 0.22 })
			b:merge(claw, CFrame.new(toePos + Vector3.new(0, 0, -p.sz * 0.12)) * CFrame.Angles(-math.pi / 2, 0, 0))
		end
	end
	return b
end

-- Sabot : cylindre évasé à section carrée arrondie. Centré.
function Shapes.hoof(p)
	local b = MeshBuilder.new()
	return MeshUtils.sweep(b, {
		Vector3.new(0, -p.sy * 0.5, -p.sz * 0.05),
		Vector3.new(0, 0, 0),
		Vector3.new(0, p.sy * 0.5, p.sz * 0.05),
	}, {
		{ p.sx * 0.5, p.sz * 0.5 },
		{ p.sx * 0.44, p.sz * 0.44 },
		{ p.sx * 0.36, p.sz * 0.36 },
	}, { sides = 8, squareness = 0.35, hint = X })
end

-- Pied d'oiseau / reptile : trois longs doigts vers l'avant + un ergot. Centré.
function Shapes.talon(p)
	local b = MeshBuilder.new()
	b:merge(Shapes.ellipsoid({ sx = p.sx * 0.45, sy = p.sy, sz = p.sz * 0.35, flat = 0.5, rings = 3, sides = 6 }))
	local toeR = p.sx * 0.1
	local angles = { -0.45, 0, 0.45 }
	for _, a in angles do
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		local from = Vector3.new(0, -p.sy * 0.25, 0)
		local to = from + dir * p.sz * 0.5
		b:merge(Shapes.limb({ len = (to - from).Magnitude, r0 = toeR, r1 = toeR * 0.8, sides = 5 }), alongY(from, to))
		b:merge(Shapes.claw({ len = p.sz * 0.2, r = toeR * 0.8 }), alongY(to, to + dir))
	end
	local back = Vector3.new(0, -p.sy * 0.25, 0)
	b:merge(Shapes.claw({ len = p.sz * 0.22, r = toeR * 0.8 }), alongY(back, back + Vector3.new(0, 0, 1)))
	return b
end

----------------------------------------------------------------------
-- Ailes, nageoires, plaques
----------------------------------------------------------------------

function Shapes.wing(p)
	local b = MeshBuilder.new()
	local S, C = p.span, p.chord
	local style = p.style or "bat"
	local P = Vector2.new(0.4 * S, 0.3 * C)
	local outline = {}
	local function add(v: Vector2)
		outline[#outline + 1] = v
	end
	local function scallop(a: Vector2, c: Vector2, depth: number)
		return ((a + c) * 0.5):Lerp(P, depth)
	end

	local O = Vector2.new(0, 0)
	local W = Vector2.new(0.45 * S, -0.12 * C)
	local T = Vector2.new(S, 0.02 * C)
	local body = Vector2.new(0.02 * S, 0.55 * C)
	local boneR = math.max(C * 0.045, 0.06)

	if style == "bat" then
		local tips = if (p.fingers or 3) >= 3
			then { Vector2.new(0.85 * S, 0.6 * C), Vector2.new(0.58 * S, 0.92 * C), Vector2.new(0.3 * S, 0.85 * C) }
			else { Vector2.new(0.8 * S, 0.65 * C), Vector2.new(0.4 * S, 0.9 * C) }
		add(O)
		add(W)
		add(T)
		local prev = T
		for _, tip in tips do
			add(scallop(prev, tip, 0.3))
			add(tip)
			prev = tip
		end
		add(scallop(prev, body, 0.25))
		add(body)
		-- Os : bras + doigts (même MeshPart, même couleur).
		local function bone(a: Vector2, c: Vector2, r: number)
			local from, to = Vector3.new(a.X, 0, a.Y), Vector3.new(c.X, 0, c.Y)
			b:merge(Shapes.limb({ len = (to - from).Magnitude, r0 = r, r1 = r * 0.7, sides = 5, bulge = 0 }), alongY(from, to))
		end
		bone(O, W, boneR)
		bone(W, T, boneR * 0.8)
		for _, tip in tips do
			bone(W, tip, boneR * 0.45)
		end
	elseif style == "feather" then
		add(O)
		add(Vector2.new(0.5 * S, -0.1 * C))
		add(Vector2.new(S, 0.1 * C))
		local feathers = 6
		local a0, a1 = Vector2.new(0.97 * S, 0.45 * C), Vector2.new(0.08 * S, 0.8 * C)
		for i = 0, feathers - 1 do
			local t0 = i / feathers
			local t1 = (i + 1) / feathers
			local tip = a0:Lerp(a1, t0) + Vector2.new(0, 0.12 * C * (1 - t0))
			add(tip)
			add(a0:Lerp(a1, (t0 + t1) * 0.5):Lerp(P, 0.12))
		end
		add(Vector2.new(0.02 * S, 0.6 * C))
	elseif style == "ray" then
		-- Nageoire de raie / manta : triangle aux bords courbes, pointe vers l'extérieur.
		P = Vector2.new(0.3 * S, 0.1 * C)
		add(Vector2.new(0, -0.4 * C))
		add(Vector2.new(0.35 * S, -0.3 * C))
		add(Vector2.new(0.75 * S, -0.1 * C))
		add(Vector2.new(S, 0.05 * C))
		add(Vector2.new(0.7 * S, 0.2 * C))
		add(Vector2.new(0.35 * S, 0.45 * C))
		add(Vector2.new(0, 0.6 * C))
	else -- "membrane" : contour elliptique lisse (insecte / nageoire)
		local n = 14
		for i = 0, n - 1 do
			local a = -math.pi + (i / n) * math.pi * 2
			add(P + Vector2.new(math.cos(a) * 0.6 * S, math.sin(a) * 0.45 * C))
		end
	end

	local thick = math.max(C * 0.06, 0.08)
	MeshUtils.plate(b, outline, P, thick, thick * 0.4, { origin = Vector3.zero, u = X, v = Z, n = Y })
	return b
end

-- Nageoire (dorsale par défaut) : base le long de +Z, hauteur +Y, épaisseur X.
function Shapes.fin(p)
	local b = MeshBuilder.new()
	local H, L = p.height, p.len
	local outline = {
		Vector2.new(0, 0),
		Vector2.new(0.2 * L, 0.5 * H),
		Vector2.new(0.45 * L, H),
		Vector2.new(0.62 * L, 0.62 * H),
		Vector2.new(0.9 * L, 0.3 * H),
		Vector2.new(L, 0),
	}
	local thick = math.max(math.min(H, L) * 0.1, 0.06)
	return MeshUtils.plate(
		b,
		outline,
		Vector2.new(0.45 * L, 0.3 * H),
		thick,
		thick * 0.4,
		{ origin = Vector3.zero, u = Z, v = Y, n = X }
	)
end

-- Plaque dorsale (type stégosaure), centrée en Z, base à y = 0.
function Shapes.plate(p)
	local b = MeshBuilder.new()
	local H, W = p.height, p.width
	local outline = {
		Vector2.new(-0.5 * W, 0),
		Vector2.new(-0.42 * W, 0.5 * H),
		Vector2.new(-0.1 * W, H),
		Vector2.new(0.2 * W, 0.85 * H),
		Vector2.new(0.45 * W, 0.45 * H),
		Vector2.new(0.5 * W, 0),
	}
	local thick = math.max(W * 0.12, 0.06)
	return MeshUtils.plate(
		b,
		outline,
		Vector2.new(0, 0.35 * H),
		thick,
		thick * 0.35,
		{ origin = Vector3.zero, u = Z, v = Y, n = X }
	)
end

----------------------------------------------------------------------
-- Bout de queue (repère : +Y = direction de la queue, X = latéral)
----------------------------------------------------------------------

function Shapes.tailTip(p)
	local b = MeshBuilder.new()
	local L, W = p.len, p.width
	local style = p.style or "point"
	if style == "spade" then
		local outline = {
			Vector2.new(0, 0),
			Vector2.new(0.5 * W, 0.35 * L),
			Vector2.new(0.3 * W, 0.75 * L),
			Vector2.new(0, L),
			Vector2.new(-0.3 * W, 0.75 * L),
			Vector2.new(-0.5 * W, 0.35 * L),
		}
		local thick = math.max(W * 0.12, 0.06)
		MeshUtils.plate(b, outline, Vector2.new(0, 0.4 * L), thick, thick * 0.4, {
			origin = Vector3.zero,
			u = X,
			v = Y,
			n = Z,
		})
	elseif style == "fin" then
		b:merge(Shapes.fin({ height = W, len = L }), CFrame.Angles(-math.pi / 2, 0, 0))
	elseif style == "club" then
		b:merge(Shapes.ellipsoid({ sx = W, sy = L, sz = W, rings = 4, sides = 7 }), CFrame.new(0, L * 0.5, 0))
		for i = 0, 3 do
			local a = i * math.pi / 2
			local dir = Vector3.new(math.cos(a), 0.2, math.sin(a)).Unit
			local base = Vector3.new(0, L * 0.5, 0) + dir * W * 0.4
			b:merge(Shapes.spike({ len = W * 0.45, r = W * 0.13, curve = 0 }), alongY(base, base + dir))
		end
	elseif style == "spikes" then
		for i = -1, 1 do
			local dir = Vector3.new(i * 0.45, 1, 0).Unit
			b:merge(Shapes.spike({ len = L * (if i == 0 then 1 else 0.7), r = W * 0.18, curve = 0.1 }), alongY(Vector3.zero, dir))
		end
	else -- point
		b:merge(Shapes.cone({ len = L, r = W * 0.3, sides = 6 }))
	end
	return b
end

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------

local ShapeLibrary = {}
ShapeLibrary.Shapes = Shapes

function ShapeLibrary.has(shape: string)
	return Shapes[shape] ~= nil
end

function ShapeLibrary.list()
	local names = {}
	for name in Shapes do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- params.seed : graine du jitter ; params.jitter : amplitude relative (0 = aucune).
function ShapeLibrary.build(shape: string, params)
	local fn = Shapes[shape]
	if not fn then
		error("Forme inconnue : " .. tostring(shape))
	end
	local rng = Random.new(params.seed or 1)
	local b = fn(params, rng)
	local amount = params.jitter or 0
	if amount > 0 then
		local minV, maxV = b:bounds()
		local size = maxV - minV
		local smallest = math.min(size.X, size.Y, size.Z)
		b:jitter(rng, smallest * amount)
	end
	return b
end

return ShapeLibrary
