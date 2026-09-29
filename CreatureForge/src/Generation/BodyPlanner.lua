-- BodyPlanner : proportions -> plan de construction (liste de pièces placées).
-- Repère créature : Y haut, -Z avant, +X = droite de la créature, sol à y = 0.
--
-- Chaque pièce :
--   name, shape, params (ShapeLibrary), cframe (placement de l'origine de la forme),
--   slot (couleur), region, parent (nom de la pièce parente dans le rig),
--   joint (Vector3, pivot d'articulation), jointKind ("Motor6D" | "Weld"), mirror.

local Util = require(script.Parent.Parent.Core.Util)

local BodyPlanner = {}

-- Formes non symétriques en X : leur version gauche utilise un mesh miroir.
local ASYMMETRIC = { wing = true, horn = true }

local function surfacePoint(center: Vector3, half: Vector3, dir: Vector3, depth: number)
	local d = dir.Unit
	local k = 1 / math.sqrt((d.X / half.X) ^ 2 + (d.Y / half.Y) ^ 2 + (d.Z / half.Z) ^ 2)
	local p = d * k * depth
	local normal = Vector3.new(p.X / half.X ^ 2, p.Y / half.Y ^ 2, p.Z / half.Z ^ 2).Unit
	return center + p, normal
end

local function newContext(P)
	local ctx = { P = P, parts = {}, byName = {} }

	function ctx.add(spec)
		spec.params.seed = spec.params.seed or P.seed % 100000
		spec.params.jitter = spec.params.jitter or P.jitter
		spec.jointKind = spec.jointKind or "Motor6D"
		spec.joint = spec.joint or spec.cframe.Position
		spec.mirror = spec.mirror or false
		table.insert(ctx.parts, spec)
		ctx.byName[spec.name] = spec
		return spec
	end

	-- Ajoute la version gauche d'une pièce droite.
	function ctx.mirror(spec, name: string, parent: string?)
		local m = table.clone(spec)
		m.params = table.clone(spec.params)
		m.name = name
		m.parent = parent or spec.parent
		m.cframe = Util.mirrorCFrameX(spec.cframe)
		m.joint = Vector3.new(-spec.joint.X, spec.joint.Y, spec.joint.Z)
		if ASYMMETRIC[spec.shape] and not (spec.shape == "horn" and (spec.params.out or 0) == 0) then
			m.mirror = not spec.mirror
		end
		local function mx(v: Vector3)
			return Vector3.new(-v.X, v.Y, v.Z)
		end
		if spec.snap then
			m.snap = { target = spec.snap.target, origin = mx(spec.snap.origin), dir = mx(spec.snap.dir), embed = spec.snap.embed }
		end
		if spec.follow then
			m.follow = { name = (spec.follow.name:gsub("_R$", "_L")), offset = spec.follow.offset }
		end
		return ctx.add(m)
	end

	function ctx.limb(name, from: Vector3, to: Vector3, r0, r1, parent, slot, region, extra)
		local spec = {
			name = name,
			shape = "limb",
			params = { len = (to - from).Magnitude, r0 = r0, r1 = r1, sides = 7 },
			cframe = Util.cframeAlongY(from, to),
			slot = slot or "Primary",
			region = region,
			parent = parent,
			joint = from,
		}
		if extra then
			for k, v in extra do
				spec.params[k] = v
			end
		end
		return ctx.add(spec)
	end

	return ctx
end

----------------------------------------------------------------------
-- Sous-ensembles réutilisables
----------------------------------------------------------------------

-- Tête complète (cou, crâne, museau, mâchoire, yeux, oreilles, cornes).
local function buildHead(ctx, neckBase: Vector3, parentName: string)
	local P = ctx.P
	local nk, hd = P.neck, P.head
	local d = Vector3.new(0, math.sin(nk.angle), -math.cos(nk.angle))
	local headParent, headJoint = parentName, neckBase
	if nk.length > 0.05 * P.scale then
		local neckEnd = neckBase + d * nk.length
		ctx.limb("Neck", neckBase, neckEnd, nk.thickness, nk.thickness * 0.85, parentName, "Primary", "neck")
		headParent, headJoint = "Neck", neckEnd
	end

	local hc = headJoint + Vector3.new(0, hd.height * 0.22, -hd.length * 0.3)
	ctx.add({
		name = "Head",
		shape = "head",
		params = { sx = hd.width, sy = hd.height, sz = hd.length, style = hd.style },
		cframe = CFrame.new(hc),
		slot = "Primary",
		region = "head",
		parent = headParent,
		joint = headJoint,
	})
	BodyPlanner.addFace(ctx, "Head", hc, Vector3.new(hd.width, hd.height, hd.length) * 0.5, true)
end

-- Museau, mâchoire, yeux, oreilles, cornes posés sur un volume (tête ou corps).
function BodyPlanner.addFace(ctx, parentName: string, c: Vector3, half: Vector3, withMouth: boolean)
	local P = ctx.P
	local hd = P.head

	if withMouth and hd.muzzle.style ~= "none" then
		local front = c + Vector3.new(0, -half.Y * 0.2, -half.Z * 0.82)
		ctx.add({
			name = "Muzzle",
			shape = "muzzle",
			params = { sx = half.X * 1.25, sy = half.Y * 1.0, sz = hd.muzzle.length, style = hd.muzzle.style },
			cframe = CFrame.new(front),
			slot = if hd.muzzle.style == "beak" then "Accent" else "Secondary",
			region = "muzzle",
			parent = parentName,
			jointKind = "Weld",
		})
		if hd.jaw then
			local hinge = c + Vector3.new(0, -half.Y * 0.55, -half.Z * 0.1)
			ctx.add({
				name = "Jaw",
				shape = "jaw",
				params = { sx = half.X * 1.1, sy = half.Y * 0.55, sz = half.Z * 0.8 + hd.muzzle.length * 0.85 },
				cframe = CFrame.new(hinge),
				slot = "Secondary",
				region = "jaw",
				parent = parentName,
				joint = hinge,
			})
		end
	end

	-- Yeux (+ pupilles)
	local eyes = P.eyes
	local eyeDirs = {}
	if eyes.count == 1 then
		eyeDirs = { Vector3.new(0, 0.35, -1) }
	else
		table.insert(eyeDirs, Vector3.new(0.55, 0.35, -0.75))
		if eyes.count >= 4 then
			table.insert(eyeDirs, Vector3.new(0.4, 0.62, -0.62))
		end
	end
	for i, dir in eyeDirs do
		local pos, normal = surfacePoint(c, half, dir, 0.9)
		local cf = CFrame.lookAt(pos, pos + normal)
		local suffix = if eyes.count == 1 then "" elseif i == 1 then "_R" else "2_R"
		local r = eyes.radius * (if i == 2 then 0.75 else 1)
		local eye = ctx.add({
			name = "Eye" .. suffix,
			shape = "eye",
			params = { r = r, jitter = 0 },
			cframe = cf,
			slot = "Eyes",
			region = "eye",
			parent = parentName,
			jointKind = "Weld",
			snap = { target = parentName, origin = c, dir = dir.Unit, embed = r * 0.4 },
		})
		local pupil = ctx.add({
			name = "Pupil" .. suffix,
			shape = "pupil",
			params = { r = r, style = eyes.pupil, jitter = 0 },
			cframe = cf * CFrame.new(0, 0, -r * 0.62),
			slot = "Pupil",
			region = "eye",
			parent = "Eye" .. suffix,
			jointKind = "Weld",
			follow = { name = "Eye" .. suffix, offset = CFrame.new(0, 0, -r * 0.62) },
		})
		if eyes.count ~= 1 then
			ctx.mirror(eye, (eye.name:gsub("_R$", "_L")))
			ctx.mirror(pupil, (pupil.name:gsub("_R$", "_L")), (eye.name:gsub("_R$", "_L")))
		end
	end

	-- Oreilles
	if P.ears.count > 0 then
		local earDir = Vector3.new(0.6, 0.75, 0.25)
		local pos = surfacePoint(c, half, earDir, 0.85)
		local len = P.ears.size
		local ear = ctx.add({
			name = "Ear_R",
			shape = "ear",
			params = { len = len, width = len * 0.55, thick = len * 0.14, style = P.ears.style },
			cframe = CFrame.new(pos) * CFrame.Angles(math.rad(15), 0, math.rad(-28)),
			slot = "Primary",
			region = "ear",
			parent = parentName,
			snap = { target = parentName, origin = c, dir = earDir.Unit, embed = len * 0.12 },
		})
		ctx.mirror(ear, "Ear_L")
	end

	-- Cornes
	local horns = P.horns
	if horns.count == 1 then
		local pos = surfacePoint(c, half, Vector3.new(0, 0.8, -0.55), 0.85)
		ctx.add({
			name = "Horn",
			shape = "horn",
			params = { len = horns.length, r = horns.radius, curve = 0.3, out = 0, style = "straight" },
			cframe = CFrame.new(pos) * CFrame.Angles(math.rad(-25), 0, 0),
			slot = "Accent",
			region = "horn",
			parent = parentName,
			jointKind = "Weld",
			snap = { target = parentName, origin = c, dir = Vector3.new(0, 0.8, -0.55).Unit, embed = horns.radius * 0.5 },
		})
	elseif horns.count >= 2 then
		local defs = { { dir = Vector3.new(0.45, 0.85, 0.1), scale = 1, name = "Horn_R" } }
		if horns.count >= 4 then
			table.insert(defs, { dir = Vector3.new(0.6, 0.55, 0.4), scale = 0.6, name = "Horn2_R" })
		end
		for _, def in defs do
			local pos = surfacePoint(c, half, def.dir, 0.82)
			local curve = if horns.style == "straight" then 0.15 else 0.6
			local horn = ctx.add({
				name = def.name,
				shape = "horn",
				params = {
					len = horns.length * def.scale,
					r = horns.radius * def.scale,
					curve = curve,
					out = 0.35,
					style = if horns.style == "ram" then "ram" else "curved",
				},
				cframe = CFrame.new(pos) * CFrame.Angles(math.rad(-10), 0, math.rad(-15)),
				slot = "Accent",
				region = "horn",
				parent = parentName,
				jointKind = "Weld",
				snap = { target = parentName, origin = c, dir = def.dir.Unit, embed = horns.radius * def.scale * 0.5 },
			})
			ctx.mirror(horn, (def.name:gsub("_R$", "_L")))
		end
	end
end

-- Pattes par paires. zs = positions avant -> arrière des hanches.
local function buildLegs(ctx, hipY: number, hipX: number, zs, parentName: string)
	local P = ctx.P
	local legs = P.legs
	local L, th = legs.length, legs.thickness
	local n = #zs
	local tags
	if n == 1 then
		tags = { "" }
	elseif n == 2 then
		tags = { "F", "B" }
	elseif n == 3 then
		tags = { "F", "M", "B" }
	else
		tags = { "F", "M1", "M2", "B" }
	end
	local footH = math.max(th * 1.1, L * 0.1)

	for i, z in zs do
		for _, side in { "R", "L" } do
			local sx = if side == "R" then 1 else -1
			local tag = tags[i] .. side
			local upperName = "Leg_" .. tag
			local lowerName = upperName .. "_Lower"
			local hip = Vector3.new(hipX * sx, hipY, z)
			local knee, ankle
			if legs.stance == "sprawl" then
				knee = Vector3.new((hipX + L * 0.38) * sx, hipY - L * 0.05, z)
				ankle = Vector3.new((hipX + L * 0.55) * sx, footH, z - L * 0.05)
			elseif legs.stance == "insect" then
				knee = Vector3.new((hipX + L * 0.5) * sx, hipY + L * 0.3, z * 1.05)
				ankle = Vector3.new((hipX + L * 0.95) * sx, footH * 0.4, z * 1.2)
			else
				local back = if n > 1 and i == n then 1 else -1
				knee = Vector3.new(hipX * 1.04 * sx, hipY - (hipY - footH) * 0.5, z + back * L * 0.06)
				ankle = Vector3.new(hipX * 1.06 * sx, footH, z - back * L * 0.02)
			end
			ctx.limb(upperName, hip, knee, th * 1.25, th * 0.85, parentName, "Primary", "leg")
			ctx.limb(lowerName, knee, ankle, th * 0.85, th * 0.65, upperName, "Primary", "leg")

			local footName = "Foot_" .. tag
			if legs.stance == "insect" then
				ctx.add({
					name = footName,
					shape = "claw",
					params = { len = L * 0.2, r = th * 0.55 },
					cframe = CFrame.new(ankle) * CFrame.Angles(math.pi, 0, 0),
					slot = "Accent",
					region = "leg",
					parent = lowerName,
					joint = ankle,
				})
			elseif legs.style == "hoof" then
				local sy = footH * 1.3
				ctx.add({
					name = footName,
					shape = "hoof",
					params = { sx = th * 1.7, sy = sy, sz = th * 1.8 },
					cframe = CFrame.new(ankle.X, sy * 0.5, ankle.Z),
					slot = "Accent",
					region = "leg",
					parent = lowerName,
					joint = ankle,
				})
			elseif legs.style == "talon" then
				local sz = th * 4
				ctx.add({
					name = footName,
					shape = "talon",
					params = { sx = th * 3, sy = footH, sz = sz },
					cframe = CFrame.new(ankle.X, footH * 0.5, ankle.Z - sz * 0.15),
					slot = "Secondary",
					region = "leg",
					parent = lowerName,
					joint = ankle,
				})
			else
				local sz = th * 3.2
				ctx.add({
					name = footName,
					shape = "paw",
					params = { sx = th * 2.5, sy = footH * 1.2, sz = sz, toes = legs.toes, claws = legs.claws },
					cframe = CFrame.new(ankle.X, footH * 0.35, ankle.Z - sz * 0.18),
					slot = "Secondary",
					region = "leg",
					parent = lowerName,
					joint = ankle,
				})
			end
		end
	end
end

local function buildTail(ctx, base: Vector3, parentName: string, baseDir: Vector3?)
	local T = ctx.P.tail
	if not T.has then
		return
	end
	local n = T.segments
	local segLen = T.length / n
	local pos, prev = base, parentName
	local lastDir = Vector3.new(0, 0, 1)
	local pitchOffset = 0
	if baseDir then
		pitchOffset = math.atan2(baseDir.Y, baseDir.Z)
	end
	for k = 1, n do
		local t = (k - 1) / math.max(n - 1, 1)
		local pitch = T.droop + pitchOffset * (1 - t) + T.curl * t * t
		local yaw = T.sway * math.sin(t * 2.5)
		local d = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
		local r0 = T.thickness * (1 - 0.72 * (k - 1) / n)
		local r1 = T.thickness * (1 - 0.72 * k / n)
		local nextPos = pos + d * segLen
		if nextPos.Y < r1 * 1.2 then
			nextPos = Vector3.new(nextPos.X, r1 * 1.2, nextPos.Z)
		end
		local name = string.format("Tail%02d", k)
		ctx.limb(name, pos, nextPos, r0, r1, prev, "Primary", "tail")
		lastDir = (nextPos - pos).Unit
		prev, pos = name, nextPos
	end
	if T.tip ~= "none" then
		local w = T.thickness * 3.2
		ctx.add({
			name = "TailTip",
			shape = "tailTip",
			params = { len = T.thickness * 3, width = w, style = T.tip },
			cframe = Util.cframeAlongY(pos - lastDir * T.thickness * 0.3, pos + lastDir),
			slot = if T.tip == "fin" or T.tip == "spade" then "Secondary" else "Accent",
			region = "tail",
			parent = prev,
			jointKind = "Weld",
		})
	end
end

local function buildWings(ctx, root: Vector3, parentName: string)
	local W = ctx.P.wings
	if W.count <= 0 then
		return
	end
	local pairsCount = if W.count >= 4 then 2 else 1
	for k = 1, pairsCount do
		local scale = if k == 1 then 1 else 0.65
		local name = if k == 1 then "Wing_R" else "Wing2_R"
		local r = root + Vector3.new(0, -(k - 1) * W.chord * 0.15, (k - 1) * W.chord * 0.6)
		local spec = ctx.add({
			name = name,
			shape = "wing",
			params = { span = W.span * scale, chord = W.chord * scale, style = W.style, fingers = 3 },
			cframe = CFrame.new(r) * CFrame.Angles(0, W.sweep or math.rad(-12), 0) * CFrame.Angles(0, 0, W.dihedral),
			slot = "Secondary",
			region = "wing",
			parent = parentName,
			joint = r,
		})
		ctx.mirror(spec, (name:gsub("_R$", "_L")))
	end
end

-- Pics / plaques / cristaux le long d'une ligne dorsale.
local function buildDorsal(ctx, pointAt, parentName: string)
	local S = ctx.P.spikes
	if S.count <= 0 then
		return
	end
	local levels = { 0.6, 0.8, 1 } -- tailles quantifiées : meshes partagés
	for i = 1, S.count do
		local t = (i - 0.5) / S.count
		local bell = math.sin(t * math.pi)
		local level = levels[math.clamp(math.floor(bell * 3) + 1, 1, 3)]
		local size = S.size * level
		local pos, origin, dir = pointAt(t)
		local spec
		if S.kind == "plate" then
			spec = {
				shape = "plate",
				params = { height = size * 1.1, width = size },
				cframe = CFrame.new(pos),
				slot = "Accent",
			}
		elseif S.kind == "crystal" then
			spec = {
				shape = "crystal",
				params = { len = size * 1.3, r = size * 0.24 },
				cframe = CFrame.new(pos) * CFrame.Angles(math.rad(15), 0, math.rad(((i % 3) - 1) * 14)),
				slot = "Special",
			}
		else
			spec = {
				shape = "spike",
				params = { len = size, r = size * 0.3, curve = 0.3 },
				cframe = CFrame.new(pos) * CFrame.Angles(math.rad(12), 0, 0),
				slot = "Accent",
			}
		end
		spec.name = string.format("Spike%02d", i)
		spec.region = "spike"
		spec.parent = parentName
		spec.jointKind = "Weld"
		if origin and dir then
			spec.snap = { target = parentName, origin = origin, dir = dir, embed = size * 0.12 }
		end
		ctx.add(spec)
	end
end

----------------------------------------------------------------------
-- Plans par type de locomotion
----------------------------------------------------------------------

local function planQuadruped(ctx)
	local P = ctx.P
	local BL, BW, BH = P.body.length, P.body.width, P.body.height
	local L = P.legs.length
	local bodyY = L + BH * 0.32
	local insect = P.archetype == "insect" or P.legs.stance == "insect"

	ctx.add({
		name = "Body",
		shape = "torso",
		params = { sx = BW, sy = BH, sz = BL, style = P.body.style, sq = P.body.sq },
		cframe = CFrame.new(0, bodyY, 0),
		slot = "Primary",
		region = "body",
		parent = "Root",
	})
	if P.belly then
		ctx.add({
			name = "Belly",
			shape = "belly",
			params = { sx = BW * 0.72, sy = BH * 0.55, sz = BL * 0.72, rings = 4 },
			cframe = CFrame.new(0, bodyY - BH * 0.2, -BL * 0.02),
			slot = "Secondary",
			region = "body",
			parent = "Body",
			jointKind = "Weld",
		})
	end

	local n = math.max(P.legs.pairs, 1)
	local zs = {}
	for i = 1, n do
		local t = if n == 1 then 0.5 else (i - 1) / (n - 1)
		table.insert(zs, -BL * 0.33 + t * BL * 0.64)
	end
	buildLegs(ctx, bodyY - BH * 0.15, BW * 0.34, zs, "Body")

	buildHead(ctx, Vector3.new(0, bodyY + BH * 0.18, -BL * 0.4), "Body")

	local tailParent, tailBase = "Body", Vector3.new(0, bodyY + BH * 0.08, BL * 0.44)
	if insect then
		local ac = Vector3.new(0, bodyY + BH * 0.12, BL * 0.5 + BL * 0.32)
		ctx.add({
			name = "Abdomen",
			shape = "ellipsoid",
			params = { sx = BW * 1.1, sy = BH * 1.05, sz = BL * 0.8, rings = 5 },
			cframe = CFrame.new(ac),
			slot = "Primary",
			region = "body",
			parent = "Body",
			joint = Vector3.new(0, ac.Y, BL * 0.45),
		})
		tailParent, tailBase = "Abdomen", ac + Vector3.new(0, 0, BL * 0.38)
	end
	buildTail(ctx, tailBase, tailParent)
	buildWings(ctx, Vector3.new(BW * 0.28, bodyY + BH * 0.36, -BL * 0.12), "Body")
	buildDorsal(ctx, function(t)
		local z = -BL * 0.36 + t * BL * 0.74
		local e = 1 - (2 * z / BL) ^ 2
		local pos = Vector3.new(0, bodyY + BH * 0.46 * math.sqrt(math.max(e, 0.05)) - BH * 0.06, z)
		return pos, Vector3.new(0, bodyY, z), Vector3.new(0, 1, 0)
	end, "Body")
end

local function planBiped(ctx)
	local P = ctx.P
	local BL, BW, BH = P.body.length, P.body.width, P.body.height
	local L = P.legs.length
	local pelvisH = BH * 0.34
	local hipY = L
	local pc = Vector3.new(0, hipY + pelvisH * 0.25, 0)

	ctx.add({
		name = "Pelvis",
		shape = "ellipsoid",
		params = { sx = BW * 0.92, sy = pelvisH, sz = BL * 0.85, rings = 4 },
		cframe = CFrame.new(pc),
		slot = "Primary",
		region = "body",
		parent = "Root",
	})

	local lean = math.rad(if P.tail.has then 25 else 8)
	local up = Vector3.new(0, math.cos(lean), -math.sin(lean))
	local waist = pc + Vector3.new(0, pelvisH * 0.2, 0)
	local torsoC = waist + up * BH * 0.5
	local top = waist + up * BH
	ctx.add({
		name = "Body",
		shape = "torso",
		params = { sx = BW, sy = BL, sz = BH, style = P.body.style, sq = P.body.sq },
		cframe = CFrame.new(torsoC) * CFrame.Angles(math.pi / 2 - lean, 0, 0),
		slot = "Primary",
		region = "body",
		parent = "Pelvis",
		joint = waist,
	})
	if P.belly then
		ctx.add({
			name = "Belly",
			shape = "belly",
			params = { sx = BW * 0.7, sy = BH * 0.7, sz = BL * 0.5, rings = 4 },
			cframe = CFrame.new(torsoC + Vector3.new(0, -BH * 0.05, -BL * 0.22)) * CFrame.Angles(-lean, 0, 0),
			slot = "Secondary",
			region = "body",
			parent = "Body",
			jointKind = "Weld",
		})
	end

	buildLegs(ctx, hipY, BW * 0.26, { BL * 0.02 }, "Pelvis")

	-- Bras
	if P.arms.count >= 2 then
		local A = P.arms
		local shoulder = top - up * BH * 0.16 + Vector3.new(BW * 0.5, 0, 0)
		local elbow = shoulder + Vector3.new(A.length * 0.12, -A.length * 0.48, -A.length * 0.06)
		local wrist = elbow + Vector3.new(0, -A.length * 0.36, -A.length * 0.2)
		for _, side in { "R", "L" } do
			local sx = if side == "R" then 1 else -1
			local function m(v: Vector3)
				return Vector3.new(v.X * sx, v.Y, v.Z)
			end
			ctx.limb("Arm_" .. side, m(shoulder), m(elbow), A.thickness * 1.15, A.thickness * 0.85, "Body", "Primary", "arm")
			ctx.limb("Arm_" .. side .. "_Lower", m(elbow), m(wrist), A.thickness * 0.85, A.thickness * 0.7, "Arm_" .. side, "Primary", "arm")
			local hs = A.thickness * 2.2
			local dir = (m(wrist) - m(elbow)).Unit
			local hc = m(wrist) + dir * hs * 0.45
			ctx.add({
				name = "Hand_" .. side,
				shape = "paw",
				params = { sx = hs, sy = hs * 0.55, sz = hs * 1.2, toes = 3, claws = P.legs.claws },
				cframe = CFrame.lookAt(hc, hc + dir),
				slot = "Secondary",
				region = "arm",
				parent = "Arm_" .. side .. "_Lower",
				joint = m(wrist),
			})
		end
	end

	buildHead(ctx, top - up * BH * 0.04, "Body")
	buildTail(ctx, pc + Vector3.new(0, pelvisH * 0.1, BL * 0.38), "Pelvis")
	buildWings(ctx, top - up * BH * 0.28 + Vector3.new(BW * 0.18, 0, BL * 0.32), "Body")
	buildDorsal(ctx, function(t)
		local axis = waist:Lerp(top, 0.95 - t * 0.85)
		return axis + Vector3.new(0, 0, BL * 0.42), axis, Vector3.new(0, 0, 1)
	end, "Body")
end

local function planFloating(ctx)
	local P = ctx.P
	local BL, BW, BH = P.body.length, P.body.width, P.body.height
	local bodyY = P.hover + BH * 0.5
	local bc = Vector3.new(0, bodyY, 0)
	local flat = P.body.flat
	local blob = (P.head.merged or P.archetype == "blob") and not flat
	local fullWidth = BW
	if flat then
		-- Raie / manta : la largeur de référence inclut les nageoires ; le corps en garde ~45 %.
		BW = fullWidth * 0.45
	end

	ctx.add({
		name = "Body",
		shape = if blob then "ellipsoid" else "torso",
		params = if blob
			then { sx = BW, sy = BH, sz = BL, rings = 6, sides = 10, flat = 0.25 }
			else { sx = BW, sy = BH, sz = BL, style = P.body.style, sq = P.body.sq },
		cframe = CFrame.new(bc),
		slot = "Primary",
		region = "body",
		parent = "Root",
	})
	if P.belly and not blob then
		ctx.add({
			name = "Belly",
			shape = "belly",
			params = { sx = BW * 0.72, sy = BH * 0.55, sz = BL * 0.72, rings = 4 },
			cframe = CFrame.new(bc + Vector3.new(0, -BH * 0.2, 0)),
			slot = "Secondary",
			region = "body",
			parent = "Body",
			jointKind = "Weld",
		})
	end

	if flat then
		BodyPlanner.addFace(ctx, "Body", bc + Vector3.new(0, BH * 0.05, -BL * 0.12), Vector3.new(BW, BH, BL) * 0.5, true)
	elseif blob then
		BodyPlanner.addFace(ctx, "Body", bc + Vector3.new(0, BH * 0.08, 0), Vector3.new(BW, BH, BL) * 0.5, false)
	else
		buildHead(ctx, bc + Vector3.new(0, BH * 0.1, -BL * 0.42), "Body")
	end

	-- Tentacules sous le corps
	local T = P.tentacles
	for i = 1, T.count do
		local a = (i - 0.5) / T.count * math.pi * 2
		local pos = Vector3.new(math.cos(a) * BW * 0.28, bodyY - BH * 0.32, math.sin(a) * BL * 0.28)
		local yaw = math.atan2(-math.cos(a), -math.sin(a))
		ctx.add({
			name = string.format("Tentacle%02d", i),
			shape = "tentacle",
			params = { len = T.length, r = T.radius, curl = T.curl },
			cframe = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.pi, 0, 0),
			slot = "Secondary",
			region = "tentacle",
			parent = "Body",
			joint = pos,
		})
	end

	-- Nageoires latérales (si pas d'ailes)
	if P.fins.side and P.wings.count == 0 then
		local fin = ctx.add({
			name = "Fin_R",
			shape = "wing",
			params = { span = BW * 0.8, chord = BL * 0.35, style = "membrane" },
			cframe = CFrame.new(BW * 0.4, bodyY, -BL * 0.05) * CFrame.Angles(0, math.rad(-25), math.rad(-15)),
			slot = "Secondary",
			region = "fin",
			parent = "Body",
		})
		ctx.mirror(fin, "Fin_L")
	end

	buildTail(ctx, bc + Vector3.new(0, 0, BL * 0.45), "Body", Vector3.new(0, if flat then 0 else 0.1, 1))
	if flat then
		-- Grandes nageoires-ailes qui prolongent le corps jusqu'à la largeur de référence.
		local W = P.wings
		W.span = math.max(W.span, (fullWidth * 0.5 - BW * 0.3) * 1.05)
		W.chord = math.max(W.chord, BL * 0.8)
		buildWings(ctx, bc + Vector3.new(BW * 0.3, 0, -BL * 0.12), "Body")
	else
		buildWings(ctx, bc + Vector3.new(BW * 0.3, BH * 0.3, -BL * 0.05), "Body")
	end
	buildDorsal(ctx, function(t)
		local z = -BL * 0.3 + t * BL * 0.6
		local pos = Vector3.new(0, bodyY + BH * 0.44 * math.sqrt(math.max(1 - (2 * z / BL) ^ 2, 0.05)) - BH * 0.05, z)
		return pos, Vector3.new(0, bodyY, z), Vector3.new(0, 1, 0)
	end, "Body")
end

local function planSerpentine(ctx)
	local P = ctx.P
	local BW, BH = P.body.width, P.body.height
	local r = math.max(BH, BW) * 0.5
	local total = P.body.length
	local m = math.clamp(math.floor(total / (r * 2.4) + 0.5), 5, 9)
	local amp = r * 1.2
	local pts = {}
	for k = 0, m do
		local z = -total * 0.5 + k * total / m
		table.insert(pts, Vector3.new(math.sin(k * 0.9) * amp, r, z))
	end
	local prev = "Root"
	for k = 1, m do
		local r0 = r * (1 - 0.55 * (k - 1) / m)
		local r1 = r * (1 - 0.55 * k / m)
		local name = if k == 1 then "Body" else string.format("Body%02d", k)
		ctx.limb(name, pts[k], pts[k + 1], r0, r1, prev, "Primary", "body", { sides = 8, bulge = 0.12 })
		prev = name
	end
	if P.belly then
		-- Bande ventrale = segments aplatis, légèrement sous le corps.
		for k = 1, m do
			local a, b = pts[k] - Vector3.new(0, r * 0.45, 0), pts[k + 1] - Vector3.new(0, r * 0.45, 0)
			local rr = r * (1 - 0.55 * (k - 0.5) / m) * 0.75
			local spec = ctx.limb(
				string.format("Belly%02d", k),
				a,
				b,
				rr,
				rr * 0.9,
				if k == 1 then "Body" else string.format("Body%02d", k),
				"Secondary",
				"body",
				{ sides = 6, bulge = 0 }
			)
			spec.jointKind = "Weld"
		end
	end

	if P.legs.pairs > 0 then
		local zs = {}
		for i = 1, P.legs.pairs do
			table.insert(zs, pts[1].Z + (i - 0.5) / P.legs.pairs * total * 0.6)
		end
		P.legs.stance = "sprawl"
		buildLegs(ctx, r * 0.9, r * 0.8, zs, "Body")
	end

	buildHead(ctx, pts[1] + Vector3.new(0, r * 0.3, 0), "Body")
	if P.tail.has then
		P.tail.thickness = math.min(P.tail.thickness, r * 0.45)
		buildTail(ctx, pts[m + 1], prev)
	end
	buildDorsal(ctx, function(t)
		local f = 1 + t * (m - 1)
		local k = math.clamp(math.floor(f), 1, m)
		local p = pts[k]:Lerp(pts[k + 1], f - k)
		return p + Vector3.new(0, r * (1 - 0.55 * t) * 0.85, 0)
	end, "Body")
end

----------------------------------------------------------------------

function BodyPlanner.plan(P)
	local ctx = newContext(P)
	local loco = P.locomotion
	if loco == "biped" then
		planBiped(ctx)
	elseif loco == "floating" then
		planFloating(ctx)
	elseif loco == "serpentine" then
		planSerpentine(ctx)
	else
		planQuadruped(ctx)
	end
	return { parts = ctx.parts, byName = ctx.byName, proportions = P }
end

return BodyPlanner
