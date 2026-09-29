-- CreatureGenerator : traits de référence -> NOUVELLE créature (Model complet).
-- Toute la géométrie est générée (EditableMesh) : aucun MeshId source n'est lu
-- ni réutilisé. Le modèle source n'est jamais touché.

local Generation = script.Parent
local Root = Generation.Parent
local Config = require(Root.Config)
local MeshRegistry = require(Root.Geometry.MeshRegistry)
local EditableMeshFactory = require(Root.Geometry.EditableMeshFactory)
local ProportionGenerator = require(Generation.ProportionGenerator)
local BodyPlanner = require(Generation.BodyPlanner)
local PaletteGenerator = require(Generation.PaletteGenerator)

local CreatureGenerator = {}
local A = Config.ATTR

local SYLLABLES = {
	"kar", "vo", "rath", "zel", "mor", "thi", "gra", "lum", "sy", "dra", "khan", "or", "bel",
	"nix", "ta", "ruk", "xe", "fal", "gor", "ae", "quo", "ly", "mir", "tak", "ven", "zu",
}

function CreatureGenerator.makeName(seed: number)
	local rng = Random.new(seed + 911)
	local n = rng:NextInteger(2, 3)
	local s = ""
	for _ = 1, n do
		s ..= SYLLABLES[rng:NextInteger(1, #SYLLABLES)]
	end
	return s:sub(1, 1):upper() .. s:sub(2)
end

-- Rayon / triangle (Möller–Trumbore). Retourne la distance ou nil.
local function rayTriangle(o: Vector3, d: Vector3, a: Vector3, b: Vector3, c: Vector3)
	local e1, e2 = b - a, c - a
	local p = d:Cross(e2)
	local det = e1:Dot(p)
	if math.abs(det) < 1e-9 then
		return nil
	end
	local inv = 1 / det
	local s = o - a
	local u = s:Dot(p) * inv
	if u < 0 or u > 1 then
		return nil
	end
	local q = s:Cross(e1)
	local v = d:Dot(q) * inv
	if v < 0 or u + v > 1 then
		return nil
	end
	local t = e2:Dot(q) * inv
	return if t > 0 then t else nil
end

-- Colle yeux, oreilles, cornes et pics sur la VRAIE surface du mesh parent
-- (lancer de rayon depuis l'intérieur), puis replace les pupilles.
function CreatureGenerator.snapFeatures(plan)
	local cache = {}
	local function worldMesh(name)
		if cache[name] then
			return cache[name]
		end
		local spec = plan.byName[name]
		if not spec then
			return nil
		end
		local cf = spec.cframe * CFrame.new(spec.geometry.center)
		local verts = {}
		for i, v in spec.geometry.builder.verts do
			verts[i] = cf * v
		end
		cache[name] = { verts = verts, tris = spec.geometry.builder.tris }
		return cache[name]
	end
	for _, spec in plan.parts do
		local snap = spec.snap
		if snap then
			local mesh = worldMesh(snap.target)
			if mesh then
				local best = nil
				for _, t in mesh.tris do
					local hit = rayTriangle(snap.origin, snap.dir, mesh.verts[t[1]], mesh.verts[t[2]], mesh.verts[t[3]])
					if hit and (best == nil or hit < best) then
						best = hit
					end
				end
				if best then
					local pos = snap.origin + snap.dir * math.max(best - snap.embed, 0)
					spec.cframe = spec.cframe.Rotation + pos
					spec.joint = pos
				end
			end
		end
		if spec.follow then
			local leader = plan.byName[spec.follow.name]
			if leader then
				spec.cframe = leader.cframe * spec.follow.offset
				spec.joint = spec.cframe.Position
			end
		end
	end
end

-- Étape 1 (pure, sans Instance) : proportions + plan + géométrie + palette.
function CreatureGenerator.design(traits, level: number, seed: number, biome: string?)
	local P = ProportionGenerator.fromTraits(traits, level, seed)
	local plan = BodyPlanner.plan(P)
	for _, spec in plan.parts do
		local geo, key = MeshRegistry.geometry(spec.shape, spec.params, spec.mirror)
		spec.geometry = geo
		spec.meshKey = key
	end
	CreatureGenerator.snapFeatures(plan)
	local minY = math.huge
	for _, spec in plan.parts do
		local geo = spec.geometry
		local h = geo.size * 0.5
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local p = spec.cframe:PointToWorldSpace(geo.center + Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
					minY = math.min(minY, p.Y)
				end
			end
		end
	end
	-- Pose la créature au sol (point le plus bas à y = 0).
	plan.groundOffset = if minY < math.huge then -minY else 0
	if P.locomotion == "floating" then
		-- Une créature flottante garde sa hauteur de vol (on la relève seulement si elle traverse le sol).
		plan.groundOffset = math.max(plan.groundOffset, 0)
	end
	plan.palette = PaletteGenerator.generate({ base = traits.palette, level = level, seed = seed, biome = biome })
	plan.name = CreatureGenerator.makeName(seed)
	return plan
end

-- Étape 2 : instancie le Model (EditableMesh + MeshParts).
-- opts : { traits, level, seed, biome?, parent, placeCFrame, referenceName, onProgress? }
function CreatureGenerator.build(opts)
	local plan = CreatureGenerator.design(opts.traits, opts.level, opts.seed, opts.biome)
	local palette = plan.palette
	local place = opts.placeCFrame * CFrame.new(0, plan.groundOffset, 0)

	local model = Instance.new("Model")
	model.Name = plan.name
	model:SetAttribute(A .. "Generated", true)
	model:SetAttribute(A .. "Version", Config.VERSION)
	model:SetAttribute(A .. "Seed", opts.seed)
	model:SetAttribute(A .. "Variation", opts.level)
	model:SetAttribute(A .. "Reference", opts.referenceName or "")
	model:SetAttribute(A .. "Locomotion", plan.proportions.locomotion)
	model:SetAttribute(A .. "Biome", opts.biome or "")
	model:SetAttribute(A .. "RefMaterial", opts.traits.material or "Plastic")
	model:SetAttribute(A .. "RefVariant", opts.traits.materialVariant or "")
	model:SetAttribute(A .. "Published", false)

	local uniqueKeys, meshCount, tris = {}, 0, 0
	local total = #plan.parts
	for i, spec in plan.parts do
		local entry = MeshRegistry.ensureMesh(spec.shape, spec.params, spec.mirror)
		if not uniqueKeys[spec.meshKey] then
			uniqueKeys[spec.meshKey] = true
			meshCount += 1
			tris += entry.tris
		end
		local part = EditableMeshFactory.createMeshPart(entry.editableMesh, entry.size)
		part.Name = spec.name
		part.CFrame = place * spec.cframe * CFrame.new(entry.center)
		part.Color = palette[spec.slot] or palette.Primary
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		part:SetAttribute(A .. "Slot", spec.slot)
		part:SetAttribute(A .. "Region", spec.region or "")
		part:SetAttribute(A .. "MeshKey", spec.meshKey)
		part:SetAttribute(A .. "ShapeSpec", MeshRegistry.specJson(spec.shape, spec.params, spec.mirror))
		part:SetAttribute(A .. "RigParent", spec.parent or "Root")
		part:SetAttribute(A .. "JointPos", spec.joint + Vector3.new(0, plan.groundOffset, 0))
		part:SetAttribute(A .. "JointKind", spec.jointKind)
		part.Parent = model
		if opts.onProgress then
			opts.onProgress(i, total)
		end
		if i % Config.MESH.YieldEvery == 0 then
			task.wait()
		end
	end

	model.WorldPivot = opts.placeCFrame
	model:SetAttribute(A .. "MeshCount", meshCount)
	PaletteGenerator.apply(model, palette)
	model.Parent = opts.parent

	return model,
		{
			parts = total,
			meshes = meshCount,
			triangles = tris,
			locomotion = plan.proportions.locomotion,
			name = plan.name,
		}
end

return CreatureGenerator
