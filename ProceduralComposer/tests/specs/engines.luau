-- Tests complémentaires : architecture, plafonds, algorithmes de sol, rotations,
-- pentes, attachments de snap, tags, géométrie protégée, métadonnées, flux complet.

local UP2 = Vector3.new(0, 1, 0)

local function archLibrary(withArch)
	local lib = folder("ArchLib", workspace)
	assetModule("Section", 8, 10, 1, lib)
	assetModule("SectionNarrow", 4, 10, 1, lib)
	local pillar = assetPillar("Column", 2, 5, lib)
	-- Snap vertical pour l'empilement.
	local top = Instance.new("Attachment")
	top.Name = "Snap_Top"
	top.CFrame = CFrame.new(0, 2.5, 0)
	top.Parent = pillar
	local bottom = Instance.new("Attachment")
	bottom.Name = "Snap_Bottom"
	bottom.CFrame = CFrame.new(0, -2.5, 0)
	bottom.Parent = pillar
	assetTrim("Cornice", 5, lib, "WallTop")
	assetTrim("Baseboard", 4, lib, "WallBase")
	if withArch then
		local arch = model("ArchWay", lib, {
			part({ Name = "L", Size = Vector3.new(1, 10, 1), CFrame = CFrame.new(5000 - 3.5, 5, 5000) }),
			part({ Name = "R", Size = Vector3.new(1, 10, 1), CFrame = CFrame.new(5000 + 3.5, 5, 5000) }),
			part({ Name = "T", Size = Vector3.new(8, 1, 1), CFrame = CFrame.new(5000, 9.5, 5000) }),
		}, 3)
		arch:SetAttribute("PlacementType", "Arch, WallModule")
	end
	assetRelief("Emblem", 2, 2, 0.3, lib)
	return lib
end

test("ARCH - rebuild: pillars, arches, trims, corners, hidden walls, exact rows", function()
	local lib = archLibrary(true)
	local floor = part({ Name = "Floor", Size = Vector3.new(100, 2, 60), Parent = workspace })
	local back = part({ Name = "Back", Size = Vector3.new(100, 10, 2), CFrame = CFrame.new(0, 6, -29), Parent = workspace })
	local side = part({ Name = "Side", Size = Vector3.new(2, 10, 60), CFrame = CFrame.new(-49, 6, 0), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor, back, side }, { lib }, {
		PlacementMode = "Architecture", WallTreatment = "Rebuild", WallMode = "Architectural",
		HideOriginalWalls = true, Symmetry = 0.8, PillarSpacing = 12, WallDensity = 0.8,
	})
	local kinds = {}
	for _, item in ipairs(plan.Items) do
		kinds[item.PlacementType] = (kinds[item.PlacementType] or 0) + 1
	end
	check((kinds.WallModule or 0) > 0, "modules expected")
	check((kinds.Pillar or 0) > 0, "pillars expected")
	check((kinds.Arch or 0) > 0, "arches expected")
	check((kinds.WallTop or 0) > 0 and (kinds.WallBase or 0) > 0, "cornice and base expected")
	check((kinds.Corner or 0) >= 1, "corner piece expected")
	check(#plan.HiddenWalls == 2, "both walls fully covered must be hidden, got " .. #plan.HiddenWalls)
	check(plan.Facades[analysis.Walls[1]] ~= nil and plan.Facades[analysis.Walls[2]] ~= nil, "facades recorded")
	-- Piliers empilés par attachments (5 studs -> 2 segments pour 10 studs).
	local pillarSegments = kinds.Pillar or 0
	check(pillarSegments % 2 == 0, "pillars must be stacked in pairs (Snap_Bottom/Snap_Top)")
	validatePlan(plan, analysis, settings)
	-- Les deux façades ne se chevauchent pas dans l'angle (joint bout à bout).
	local wA, wB = analysis.Walls[1], analysis.Walls[2]
	for _, a in ipairs(plan.Items) do
		if a.Surface == wA and a.PlacementType == "WallModule" then
			for _, b in ipairs(plan.Items) do
				if b.Surface == wB and b.PlacementType == "WallModule" then
					check(not itemsIntersect(a, b), "facade modules of the two walls overlap in the corner")
				end
			end
		end
	end
	-- Instanciation : murs masqués puis restaurés par Cancel.
	local preview = M.PreviewManager.new()
	check(preview:showPlan(plan, { Seed = 1, AnchorClones = true }), "preview")
	check(back.Transparency == 1 and side.Transparency == 1, "walls hidden in preview")
	preview:cancel()
	check(back.Transparency == 0 and side.Transparency == 0, "walls restored after cancel")
end)

test("ARCH - modules with Snap_Left / Snap_Right attachments align exactly", function()
	local lib = folder("SnapLib", workspace)
	-- Module de 6 studs dont les connecteurs sont à ±2.75 (0.25 de recouvrement voulu de chaque côté).
	local m = assetModule("Overlapping", 6, 8, 1, lib)
	local l = Instance.new("Attachment")
	l.Name = "Snap_Left"
	l.CFrame = CFrame.new(-2.75, 0, 0)
	l.Parent = m
	local r = Instance.new("Attachment")
	r.Name = "Snap_Right"
	r.CFrame = CFrame.new(2.75, 0, 0)
	r.Parent = m
	local floor = part({ Name = "Floor", Size = Vector3.new(60, 2, 20), Parent = workspace })
	local wall = part({ Name = "Wall", Size = Vector3.new(55, 12, 2), CFrame = CFrame.new(0, 7, -8), Parent = workspace })
	local plan, analysis = runPlan({ floor, wall }, { lib }, {
		PlacementMode = "Wall", WallTreatment = "Cover", WallMode = "Modular", WallDensity = 0, CornerDecoration = false,
	})
	local w = analysis.Walls[1]
	local centers = {}
	for _, item in ipairs(plan.Items) do
		if item.Role == "Architecture" then
			table.insert(centers, w.Frame:PointToObjectSpace(item.BoxCFrame.Position).X)
		end
	end
	table.sort(centers)
	check(#centers == 10, "10 modules of 5.5 useful studs expected for 55 studs, got " .. #centers)
	for i = 2, #centers do
		check(approx(centers[i] - centers[i - 1], 5.5, 1e-6), "connector pitch must be exactly 5.5 studs")
	end
	check(approx(centers[1] - 2.75, w.UMin, 1e-6), "first connector at wall start")
end)

test("CEILING - hanging assets touch the ceiling and respect room height", function()
	local lib = folder("Lib", workspace)
	assetLamp("Lamp", lib)
	assetRock("FloorRock", Vector3.new(2, 1, 2), lib)
	local floor = part({ Name = "Floor", Size = Vector3.new(40, 2, 40), Parent = workspace })
	local roof = part({ Name = "Roof", Size = Vector3.new(40, 2, 40), CFrame = CFrame.new(0, 17, 0), Parent = workspace })
	local w1 = part({ Name = "W1", Size = Vector3.new(2, 14, 40), CFrame = CFrame.new(-19, 9, 0), Parent = workspace })
	local w2 = part({ Name = "W2", Size = Vector3.new(2, 14, 40), CFrame = CFrame.new(19, 9, 0), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor, roof, w1, w2 }, { lib }, { CeilingDensity = 0.8 })
	check(#analysis.Ceilings == 1, "roof bottom must be detected as ceiling")
	check(#analysis.Floors == 1, "roof top must not be decorated as a floor")
	local lamps = 0
	for _, item in ipairs(plan.Items) do
		if item.Role == "Ceiling" then
			lamps += 1
			local top = -math.huge
			for _, c in ipairs(M.MathUtil.obbCorners(item.BoxCFrame, item.BoxSize)) do
				top = math.max(top, c.Y)
			end
			check(approx(top, 16 - settings.SurfaceEpsilon, 1e-6), "lamp top must touch the ceiling: " .. top)
		end
	end
	check(lamps > 0, "lamps expected")
	validatePlan(plan, analysis, settings)
end)

test("FLOOR - every algorithm and rotation mode produces valid results", function()
	local lib = buildLibrary()
	local floor = part({ Name = "Floor", Size = Vector3.new(120, 4, 90), CFrame = CFrame.Angles(0, math.rad(-23), 0), Parent = workspace })
	local wall = part({ Name = "Wall", Size = Vector3.new(120, 14, 3), CFrame = CFrame.Angles(0, math.rad(-23), 0) * CFrame.new(0, 9, -43), Parent = workspace })
	local algorithms = { "Hybrid", "EdgeDecoration", "Scatter", "Cluster", "Grid", "Border", "HeroComposition" }
	local rotations = { "Fixed", "Random90", "Random180", "Random360", "AlignToSurface", "AlignToWall", "FaceCenter", "FaceAway", "FollowPath" }
	for i, algo in ipairs(algorithms) do
		local rot = rotations[(i - 1) % #rotations + 1]
		local plan, analysis, _, settings = runPlan({ floor, wall }, { lib }, {
			PlacementMode = "Floor", FloorAlgorithm = algo, RotationMode = rot, Seed = 100 + i,
			ScaleMode = "RandomRange", MinScale = 0.8, MaxScale = 1.2, Symmetry = if i % 2 == 0 then 0.7 else 0,
		})
		check(#plan.Items > 0, algo .. " placed nothing")
		validatePlan(plan, analysis, settings)
	end
	for _, rot in ipairs({ "AlignToWall", "FaceCenter", "FaceAway", "FollowPath" }) do
		local plan, analysis, _, settings = runPlan({ floor, wall }, { lib }, { PlacementMode = "Floor", RotationMode = rot, Seed = 3 })
		validatePlan(plan, analysis, settings)
	end
end)

test("FLOOR - composition quality: hierarchy, breathing space, no giant clumps", function()
	local lib = buildLibrary()
	local floor = part({ Name = "Floor", Size = Vector3.new(160, 4, 160), Parent = workspace })
	local plan = runPlan({ floor }, { lib }, { Density = 0.5, Seed = 2024 })
	local large = {}
	local counts = { Small = 0, Medium = 0, Large = 0, Hero = 0 }
	for _, item in ipairs(plan.Items) do
		counts[item.SizeClass] += 1
		if item.SizeClass == "Large" or item.SizeClass == "Hero" then
			table.insert(large, item)
		end
	end
	check(counts.Small + counts.Medium > #large, "fillers must outnumber focal elements")
	-- Deux grands éléments ne sont jamais collés.
	for i = 1, #large do
		for j = i + 1, #large do
			local d = (large[i].BoxCFrame.Position - large[j].BoxCFrame.Position).Magnitude
			local r = (large[i].Asset.FootprintRadius * large[i].Scale + large[j].Asset.FootprintRadius * large[j].Scale)
			check(d > r * 1.05, "large elements glued together")
		end
	end
	-- Couverture raisonnable : il reste du vide.
	local area = 0
	for _, item in ipairs(plan.Items) do
		area += item.BoxSize.X * item.BoxSize.Z
	end
	check(area / (160 * 160) < 0.5, "floor must keep breathing space")
end)

test("SLOPE - wedge ramp: assets are upright and never float", function()
	local lib = folder("Lib", workspace)
	assetRock("Stone", Vector3.new(1.5, 1, 1.5), lib)
	assetRock("Bush", Vector3.new(2, 2, 2), lib)
	local ramp = part({ Class = "WedgePart", Name = "Ramp", Size = Vector3.new(30, 8, 40), CFrame = CFrame.new(0, 4, 0), Parent = workspace })
	local plan, analysis = runPlan({ ramp }, { lib }, { Density = 0.8 })
	check(#analysis.Slopes == 1 or #analysis.Floors == 1, "ramp surface expected")
	local s = analysis.Slopes[1] or analysis.Floors[1]
	check(#plan.Items > 0, "items on the ramp expected")
	for _, item in ipairs(plan.Items) do
		check(item.BoxCFrame.YVector:Dot(UP2) > 0.9999, "assets stay upright on slopes")
		-- Aucun coin inférieur au-dessus du plan de la pente.
		local maxBottom = -math.huge
		local bmin = item.Pose.LocalMin
		for _, x in ipairs({ bmin.X, item.Pose.LocalMax.X }) do
			for _, z in ipairs({ bmin.Z, item.Pose.LocalMax.Z }) do
				local c = item.RefCFrame:PointToWorldSpace(Vector3.new(x, bmin.Y, z))
				maxBottom = math.max(maxBottom, s.Frame:PointToObjectSpace(c).Y)
			end
		end
		check(maxBottom <= 1e-6, "an asset corner floats above the slope: " .. maxBottom)
	end
end)

test("ZONES - tagged exclusion, protected parts and existing scene geometry", function()
	local lib = buildLibrary()
	local floor = part({ Name = "Floor", Size = Vector3.new(80, 2, 80), Parent = workspace })
	local spawnZone = part({ Name = "Spawn", Size = Vector3.new(30, 1, 30), CFrame = CFrame.new(0, 1.5, 0), Parent = workspace })
	__mock.services.CollectionService:AddTag(spawnZone, M.Config.Tags.EXCLUDE)
	local chest = part({ Name = "Chest", Size = Vector3.new(6, 4, 4), CFrame = CFrame.new(25, 3, 25), Parent = workspace })
	local npc = part({ Name = "NPC", Size = Vector3.new(4, 6, 4), CFrame = CFrame.new(-25, 4, 25), Parent = workspace })
	local SelectionAnalyzer = require(ROOT.Analysis.SelectionAnalyzer)
	local tagged = SelectionAnalyzer.getTaggedParts(M.Config.Tags.EXCLUDE)
	check(#tagged == 1, "tagged exclusion zone found")
	local plan, analysis, _, settings = runPlan({ floor }, { lib }, { Density = 1, EmptySpaceRatio = 0, Seed = 8 }, { Zones = tagged, Protected = { chest } })
	for _, item in ipairs(plan.Items) do
		local l = analysis.Floors[1].Frame:PointToObjectSpace(item.BoxCFrame.Position)
		local poly = M.MathUtil.projectOBBToSurface(analysis.Floors[1].Frame, item.BoxCFrame, item.BoxSize)
		local u0, v0, u1, v1 = M.MathUtil.polygonBounds(poly)
		local tol = M.Config.Precision.CONTACT_TOLERANCE + 1e-6
		check(u1 <= -15 + tol or u0 >= 15 - tol or v1 <= -15 + tol or v0 >= 15 - tol, "item inside the spawn zone at " .. tostring(l))
		local fakeChest = { BoxCFrame = chest.CFrame, BoxSize = chest.Size, Pose = { SubBoxes = { { CFrame = chest.CFrame, Size = chest.Size } } } }
		local fakeNpc = { BoxCFrame = npc.CFrame, BoxSize = npc.Size, Pose = { SubBoxes = { { CFrame = npc.CFrame, Size = npc.Size } } } }
		check(not itemsIntersect(item, fakeChest), "item overlaps protected chest")
		check(not itemsIntersect(item, fakeNpc), "item overlaps existing scene geometry (NPC)")
	end
	check(#plan.Items > 5, "items expected around the zones")
	validatePlan(plan, analysis, settings)
end)

test("META - UniqueAsset, RepeatLimit, Weight 0, CanOverlapDecoration, FloorOffset", function()
	local lib = folder("Lib", workspace)
	local unique = assetRock("Unique", Vector3.new(3, 3, 3), lib)
	unique:SetAttribute("UniqueAsset", true)
	local limited = assetRock("Limited", Vector3.new(2, 2, 2), lib)
	limited:SetAttribute("RepeatLimit", 2)
	local never = assetRock("Never", Vector3.new(2, 2, 2), lib)
	never:SetAttribute("Weight", 0)
	local grass = assetRock("Grass", Vector3.new(1, 0.5, 1), lib)
	grass:SetAttribute("CanOverlapDecoration", true)
	local sunk = assetRock("Roots", Vector3.new(2, 1, 2), lib)
	sunk:SetAttribute("FloorOffset", -0.3)
	local floor = part({ Name = "Floor", Size = Vector3.new(80, 2, 80), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor }, { lib }, { Density = 1, EmptySpaceRatio = 0, MaxAssets = 300 })
	local counts = {}
	for _, item in ipairs(plan.Items) do
		counts[item.Asset.Name] = (counts[item.Asset.Name] or 0) + 1
	end
	check((counts.Unique or 0) <= 1, "UniqueAsset violated")
	check((counts.Limited or 0) <= 2, "RepeatLimit violated")
	check((counts.Never or 0) == 0, "Weight 0 asset used")
	validatePlan(plan, analysis, settings)
end)

test("SETTINGS - validation, clamping, presets are reproducible", function()
	local s = M.Settings.new(nil)
	s:set("Density", 5)
	check(s:get("Density") == 1, "clamped to max")
	s:set("RotationMode", "NotAMode")
	check(s:get("RotationMode") == "Random360", "invalid enum falls back to default")
	s:set("Seed", 12.7)
	check(s:get("Seed") == 13, "int rounding")
	s:applyPreset("Architectural")
	check(s:get("WallTreatment") == "Rebuild" and s:get("Preset") == "Architectural", "preset applied")
	s:applyPreset("Balanced")
	check(s:get("WallTreatment") == "Keep" and s:get("Density") == 0.5, "presets restart from defaults")
	local snap = s:snapshot()
	snap.Density = 0.1
	check(s:get("Density") == 0.5, "snapshot is a copy")
end)

test("RNG - deterministic streams and forks", function()
	local a = M.RandomGenerator.new(42)
	local b = M.RandomGenerator.new(42)
	for _ = 1, 100 do
		check(a:nextUInt32() == b:nextUInt32(), "same seed, same sequence")
	end
	local f1 = M.RandomGenerator.new(42):fork("floor:S01")
	local f2 = M.RandomGenerator.new(42):fork("floor:S01")
	local f3 = M.RandomGenerator.new(42):fork("wall:S02")
	check(f1:next() == f2:next(), "fork determinism")
	check(f1:next() ~= f3:next(), "different forks differ")
	local n = M.RandomGenerator.noise2D(7, 3.25, -1.5)
	check(n >= 0 and n <= 1, "noise range")
end)

test("APP - full flow through AppController (selection, preview, accept, clear)", function()
	local AppController = require(ROOT.Generation.AppController)
	local lib = buildLibrary({ Architecture = true })
	local parts, zone = roomScene()
	local settings = M.Settings.new(nil)
	settings:set("Seed", 99)
	local app = AppController.new(nil, settings)
	local sel = __mock.services.Selection
	sel:Set({})
	check(app:useSelectionAsTargets() == false, "empty selection handled")
	sel:Set({ zone })
	check(app:useSelectionAsTargets(), "zone as target")
	check(app.Analysis and #app.Analysis.Surfaces == 3, "analysis done")
	sel:Set({ lib })
	check(app:useSelectionAsLibrary(), "library scanned")
	app:setOverride(parts[2], "Ignore")
	check(#app.Analysis.Walls == 1, "role override applied")
	app:setOverride(parts[2], "Auto")
	app:generatePreview()
	check(app:hasPreview(), "preview created: " .. tostring(app.Status.Text))
	check(app.LastPlan and #app.LastPlan.Items > 0, "plan kept for diagnostics")
	app:regenerate()
	check(settings:get("Seed") ~= 99, "regenerate picks a new seed")
	app:accept()
	check(not app:hasPreview() and app:generationCount() == 1, "accepted")
	app:generatePreview()
	app:accept()
	check(app:generationCount() == 2, "second generation")
	local names = {}
	for _, g in ipairs(app.Preview:getGenerations()) do
		table.insert(names, g.Name)
	end
	table.sort(names)
	check(names[1] == "Generation_001" and names[2] == "Generation_002", "generation numbering")
	app:clearGenerated()
	check(app:generationCount() == 0 and not app:hasPreview(), "cleared")
	app:destroy()
end)

test("ROBUSTNESS - empty library, scripts, huge part counts, attachments", function()
	local empty = folder("Empty", workspace)
	local registry = M.AssetRegistry.new()
	local summary = registry:scan({ empty }, true)
	check(summary.Count == 0 and #summary.Warnings > 0, "empty library reported")
	local lib = folder("Lib", workspace)
	local scripted = assetTree("ScriptedTree", 10, 6, lib)
	Instance.new("Script", scripted)
	local many = Instance.new("Model")
	many.Name = "ManyParts"
	for i = 1, 300 do
		part({ Name = "P" .. i, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(5000 + (i % 10), 0.25 + math.floor(i / 100), 5000 + math.floor(i / 10) % 10), Parent = many })
	end
	many.Parent = lib
	local data = M.AssetAnalyzer.analyze(many, { LibraryRoot = lib })
	check(data and #data.SubBoxes <= 64 and #data.SubBoxes > 0, "occupancy grid used for 300 parts")
	summary = registry:scan({ lib }, true)
	check(summary.Count == 2, "assets scanned")
	local floor = part({ Name = "Floor", Size = Vector3.new(60, 2, 60), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor }, { lib }, { StripScripts = true })
	validatePlan(plan, analysis, settings)
	local out = folder("Out", workspace)
	local created = M.OutputBuilder.instantiate(plan.Items, { Floor = out }, { Seed = 1, GenerationId = "x", StripScripts = true, AnchorClones = true })
	check(created == #plan.Items, "all instantiated")
	for _, d in ipairs(out:GetDescendants()) do
		check(not d:IsA("LuaSourceContainer"), "scripts stripped from clones")
	end
	check(#scripted:GetDescendants() == 3, "source asset keeps its script")
end)

test("OUTPUT - clones land exactly where planned (scale, pivot, rotated zone)", function()
	local lib = buildLibrary()
	local R = CFrame.new(-40, 12, 18) * CFrame.Angles(0, math.rad(37), 0)
	local floor = part({ Name = "Floor", Size = Vector3.new(90, 4, 70), CFrame = R, Parent = workspace })
	local plan, analysis = runPlan({ floor }, { lib }, { ScaleMode = "RandomRange", MinScale = 0.7, MaxScale = 1.4, Seed = 31 })
	local out = folder("Out", workspace)
	local subs = { Floor = out, Wall = out, Architecture = out, Ceiling = out, Corner = out }
	local created = M.OutputBuilder.instantiate(plan.Items, subs, { Seed = 31, GenerationId = "g", AnchorClones = true })
	check(created == #plan.Items and created > 0, "clones created")
	local s = analysis.Floors[1]
	local children = out:GetChildren()
	for i, clone in ipairs(children) do
		local lo = math.huge
		local parts = if clone:IsA("BasePart") then { clone } else {}
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				table.insert(parts, d)
			end
		end
		for _, p in ipairs(parts) do
			for _, c in ipairs(M.MathUtil.obbCorners(p.CFrame, p.Size)) do
				lo = math.min(lo, s.Frame:PointToObjectSpace(c).Y)
			end
		end
		local item = plan.Items[i]
		local expected = item.Asset.Meta.FloorOffset + (if item.Asset.IsFlat then 0.02 else 0)
		check(approx(lo, expected, 1e-5), string.format("clone %s bottom %.6f (expected %.6f)", clone.Name, lo, expected))
	end
end)

test("ZONES - 'Create Center Exclusion Zone' keeps the middle of the floor empty", function()
	local AppController = require(ROOT.Generation.AppController)
	local lib = buildLibrary()
	local parts, zone = roomScene()
	local settings = M.Settings.new(nil)
	settings:applyPreset("EdgesOnly")
	settings:set("KeepCenterClear", false) -- seule la Part de zone protège le centre
	local app = AppController.new(nil, settings)
	__mock.services.Selection:Set({ zone })
	app:useSelectionAsTargets()
	__mock.services.Selection:Set({ lib })
	app:useSelectionAsLibrary()
	local zones = app:createCenterExclusionZone()
	check(#zones == 1, "one zone per floor")
	local z = zones[1]
	check(approx(z.Size.X, 112 * 0.6, 1e-6) and approx(z.Size.Z, 80, 1e-6), "zone spans 20%..80% between the walls: " .. tostring(z.Size))
	check(app:taggedExclusionCount() == 1, "zone is tagged ProceduralPlacementExclude")
	-- La zone ne devient jamais une cible, même sélectionnée avec le sol.
	app:analyse()
	check(#app.Analysis.Parts == 3, "zone part excluded from targets")
	settings:set("Density", 0.9)
	app:generatePreview()
	check(app:hasPreview() and #app.LastPlan.Items > 0, "preview: " .. app.Status.Text)
	local s = app.Analysis.Floors[1]
	local floorItems = 0
	for _, item in ipairs(app.LastPlan.Items) do
		if item.Role == "Floor" then
			floorItems += 1
			local poly = M.MathUtil.projectOBBToSurface(s.Frame, item.BoxCFrame, item.BoxSize)
			local u0, _, u1 = M.MathUtil.polygonBounds(poly)
			local tol = M.Config.Precision.CONTACT_TOLERANCE + 1e-6
			check(u1 <= -33.6 + tol or u0 >= 33.6 - tol, string.format("floor item in the center: [%.2f, %.2f]", u0, u1))
		end
	end
	check(floorItems > 0, "the sides are decorated")
	app:clearGenerated()
	check(z.Parent ~= nil, "Clear Generated never deletes user zones")
	app:destroy()
end)
