-- Pipeline complet hors Studio : fausse créature -> analyse -> design x variations.
local CreatureAnalyzer = REQUIRE(ROOT_SCRIPT.Analysis.CreatureAnalyzer)
local CreatureGenerator = REQUIRE(ROOT_SCRIPT.Generation.CreatureGenerator)
local MeshRegistry = REQUIRE(ROOT_SCRIPT.Geometry.MeshRegistry)

local function vec(x, y, z)
	return Vector3.new(x, y, z)
end

-- Construit une créature de test. `facing` : rotation du pivot (teste l'auto-orientation).
local function makeCreature(kind, facing)
	local pivot = CFrame.new(10, 0, 5) * CFrame.Angles(0, facing or 0, 0)
	local model = MockInstance("Model", { Name = kind, _pivot = pivot })
	local colors = {
		body = Color3.fromRGB(240, 190, 40),
		belly = Color3.fromRGB(250, 235, 160),
		horn = Color3.fromRGB(120, 60, 20),
		eye = Color3.fromRGB(40, 200, 255),
		wing = Color3.fromRGB(230, 120, 30),
	}
	local count = 0
	local function part(name, pos, size, color, cls)
		count += 1
		local p = MockInstance(cls or "MeshPart", {
			Name = name,
			Size = size,
			CFrame = pivot * CFrame.new(pos),
			Color = color or colors.body,
			Material = Enum.Material.Plastic,
			MaterialVariant = "",
			Transparency = 0,
			MeshId = "rbxassetid://" .. (1000 + count),
			TextureID = "",
		}, model)
		return p
	end
	if kind == "Sunshine Dragon" then
		part("Body", vec(0, 3, 0), vec(2.6, 2.2, 4.2))
		part("Chest", vec(0, 3.3, -1.4), vec(2.4, 2.2, 1.8))
		part("Belly", vec(0, 2.3, 0), vec(2, 1.2, 3.4), colors.belly)
		part("Neck1", vec(0, 4.2, -2.4), vec(0.9, 1.2, 0.9))
		part("Neck2", vec(0, 5, -2.8), vec(0.8, 1.1, 0.8))
		part("Head", vec(0, 5.8, -3.4), vec(1.8, 1.6, 2))
		part("Snout", vec(0, 5.5, -4.6), vec(1.1, 0.8, 1.2))
		part("Jaw", vec(0, 5.1, -4.3), vec(1, 0.35, 1.4), colors.belly)
		for _, sx in { -1, 1 } do
			local s = if sx < 0 then "L" else "R"
			part("Eye" .. s, vec(0.6 * sx, 6.1, -4.2), vec(0.4, 0.4, 0.3), colors.eye)
			part("Pupil" .. s, vec(0.62 * sx, 6.1, -4.36), vec(0.15, 0.3, 0.1), Color3.new(0, 0, 0))
			part("Horn" .. s .. "1", vec(0.5 * sx, 6.8, -3.1), vec(0.3, 0.8, 0.3), colors.horn)
			part("Horn" .. s .. "2", vec(0.6 * sx, 7.4, -2.8), vec(0.2, 0.7, 0.4), colors.horn)
			part("Ear" .. s, vec(0.8 * sx, 6.5, -3.0), vec(0.2, 0.7, 0.4))
			part("Wing" .. s .. "Arm", vec(2.5 * sx, 4.8, -0.6), vec(3.4, 0.3, 0.3), colors.wing)
			part("Wing" .. s .. "Membrane", vec(2.8 * sx, 4.5, 0.4), vec(3.8, 0.2, 2.4), colors.wing)
			for _, z in { -1.3, 1.3 } do
				local fb = if z < 0 then "Front" else "Back"
				part(fb .. s .. "Thigh", vec(1.1 * sx, 2, z), vec(0.8, 1.6, 0.9))
				part(fb .. s .. "Shin", vec(1.15 * sx, 0.9, z), vec(0.6, 1.2, 0.6))
				part(fb .. s .. "Foot", vec(1.15 * sx, 0.2, z - 0.2), vec(0.8, 0.4, 1))
				part(fb .. s .. "Claw1", vec(1.0 * sx, 0.1, z - 0.8), vec(0.12, 0.15, 0.3), colors.horn)
				part(fb .. s .. "Claw2", vec(1.3 * sx, 0.1, z - 0.8), vec(0.12, 0.15, 0.3), colors.horn)
			end
		end
		for i = 1, 4 do
			part("Tail" .. i, vec(0, 3 - i * 0.35, 2.2 + i * 1.1), vec(0.9 - i * 0.15, 0.8 - i * 0.12, 1.3))
		end
		part("TailSpike", vec(0, 1.6, 7.2), vec(0.6, 0.1, 0.8), colors.horn)
		for i = 1, 3 do
			part("BackSpike" .. i, vec(0, 4.3, -1 + i * 0.8), vec(0.15, 0.6, 0.5), colors.horn)
		end
		local motor = MockInstance("Motor6D", { Name = "Neck", Part0 = model:FindFirstChild("Body"), Part1 = model:FindFirstChild("Head"), C0 = CFrame.new(), C1 = CFrame.new() }, model:FindFirstChild("Body"))
	elseif kind == "Stone Golem" then
		part("Pelvis", vec(0, 3.2, 0), vec(2.4, 1.2, 1.6))
		part("Torso", vec(0, 5, 0), vec(3.4, 2.6, 2))
		part("Head", vec(0, 7, -0.3), vec(1.4, 1.3, 1.4))
		for _, sx in { -1, 1 } do
			local s = if sx < 0 then "Left" else "Right"
			part(s .. "UpperLeg", vec(0.7 * sx, 2.1, 0), vec(0.9, 1.6, 0.9))
			part(s .. "LowerLeg", vec(0.7 * sx, 0.8, 0), vec(0.8, 1.4, 0.8))
			part(s .. "Foot", vec(0.7 * sx, 0.15, -0.2), vec(1, 0.3, 1.3))
			part(s .. "UpperArm", vec(2.1 * sx, 5.3, 0), vec(0.9, 1.8, 0.9))
			part(s .. "LowerArm", vec(2.2 * sx, 3.7, -0.2), vec(0.8, 1.6, 0.8))
			part(s .. "Hand", vec(2.2 * sx, 2.7, -0.3), vec(1, 0.8, 1))
			part(s .. "Eye", vec(0.35 * sx, 7.1, -1.0), vec(0.3, 0.25, 0.1), colors.eye)
		end
	elseif kind == "Ghost Jelly" then
		part("Bell", vec(0, 5, 0), vec(3, 2.4, 3))
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			part("Tentacle" .. i, vec(math.cos(a) * 0.9, 2.5, math.sin(a) * 0.9), vec(0.3, 3, 0.3))
		end
		part("EyeL", vec(-0.5, 5.3, -1.45), vec(0.4, 0.4, 0.2), colors.eye)
		part("EyeR", vec(0.5, 5.3, -1.45), vec(0.4, 0.4, 0.2), colors.eye)
	elseif kind == "Sand Serpent" then
		for i = 1, 8 do
			part("Segment" .. i, vec(math.sin(i) * 0.6, 0.6, -6 + i * 1.5), vec(1.2, 1.2, 1.6))
		end
		part("Head", vec(0, 1.4, -6.2), vec(1.4, 1.1, 1.8))
		part("EyeL", vec(-0.5, 1.7, -6.9), vec(0.25, 0.25, 0.2), colors.eye)
		part("EyeR", vec(0.5, 1.7, -6.9), vec(0.25, 0.25, 0.2), colors.eye)
	elseif kind == "Cave Spider" then
		part("Thorax", vec(0, 2, 0), vec(2, 1.4, 2))
		part("Abdomen", vec(0, 2.3, 2.2), vec(2.6, 2.2, 2.8))
		part("Head", vec(0, 2.1, -1.5), vec(1.2, 1, 1))
		for _, sx in { -1, 1 } do
			for i = 1, 4 do
				local z = -0.8 + (i - 1) * 0.55
				part("Leg" .. i .. (sx < 0 and "L" or "R") .. "Upper", vec(1.4 * sx, 2.4, z), vec(1.6, 0.25, 0.25))
				part("Leg" .. i .. (sx < 0 and "L" or "R") .. "Lower", vec(2.4 * sx, 1.2, z), vec(0.25, 2.4, 0.25))
			end
		end
	end
	return model, count
end

local OBJ = OBJ_DIR_MARK
local function dump(plan, label, offsetX)
	if not OBJ then
		return
	end
	for _, spec in plan.parts do
		local geo = spec.geometry
		local cf = CFrame.new(offsetX, plan.groundOffset, 0) * spec.cframe * CFrame.new(geo.center)
		local c = plan.palette[spec.slot] or plan.palette.Primary
		print(string.format("#OBJ %s_%s %.3f %.3f %.3f", label, spec.name, c.R, c.G, c.B))
		for _, v in geo.builder.verts do
			local w = cf * v
			print(string.format("v %.4f %.4f %.4f", w.X, w.Y, w.Z))
		end
		for _, t in geo.builder.tris do
			print(string.format("f %d %d %d", t[1], t[2], t[3]))
		end
		print("#END")
	end
end

local which = TEST_CREATURE or "Sunshine Dragon"
local model, count = makeCreature(which, math.pi / 2)
local report = CreatureAnalyzer.analyze(model)
local log = OBJ and function() end or print
log("Créature :", report.name)
log("Pièces :", report.counts.parts, "MeshParts :", report.counts.meshParts, "Couleurs :", report.counts.colors)
log("Motor6D :", report.counts.motor6D, "Bones :", report.counts.bones)
log("Morphologie :", report.morphology)
log(CreatureAnalyzer.details(report))

local levels = TEST_LEVELS or { 1, 2, 3 }
for i, level in levels do
	local seed = (TEST_SEED or 1234) + i
	local plan = CreatureGenerator.design(report.traits, level, seed)
	local names = {}
	local keys = {}
	local nkeys, tris = 0, 0
	for _, spec in plan.parts do
		table.insert(names, spec.name)
		if not keys[spec.meshKey] then
			keys[spec.meshKey] = true
			nkeys += 1
			tris += spec.geometry.tris
		end
		assert(spec.parent, "parent manquant : " .. spec.name)
		assert(spec.parent == "Root" or plan.byName[spec.parent], "parent inconnu : " .. spec.parent .. " pour " .. spec.name)
	end
	log(string.format("\n[variation %d] %s — %s : %d pièces, %d meshes uniques, %d triangles, sol %+.2f",
		level, plan.name, plan.proportions.locomotion, #plan.parts, nkeys, tris, plan.groundOffset))
	log("  " .. table.concat(names, ", "))
	dump(plan, "v" .. level, (i - 2) * plan.proportions.scale * 2.2)
end
log("PIPELINE OK")
