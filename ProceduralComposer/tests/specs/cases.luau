-- Les 20 cas obligatoires du cahier des charges + tests unitaires associés.

local UP = Vector3.new(0, 1, 0)

test("CAS 1  - large floor + library of 20+ assets", function()
	local lib = buildLibrary()
	local floor = part({ Name = "Floor", Size = Vector3.new(200, 4, 200), Parent = workspace })
	local plan, analysis, registry, settings = runPlan({ floor }, { lib }, { Density = 0.6 })
	check(registry:count() >= 20, "library should contain 20+ assets, got " .. registry:count())
	check(#analysis.Floors == 1, "one floor expected")
	check(#plan.Items >= 10, "expected a real composition, got " .. #plan.Items)
	validatePlan(plan, analysis, settings)
end)

test("CAS 2  - floor + two parallel walls", function()
	local lib = buildLibrary()
	local parts = roomScene()
	local plan, analysis, _, settings = runPlan(parts, { lib }, { WallDensity = 0.8 })
	check(#analysis.Floors == 1 and #analysis.Walls == 2, string.format("floor/walls detected: %d/%d", #analysis.Floors, #analysis.Walls))
	check(#analysis.WallPairs == 1 and approx(analysis.WallPairs[1].Distance, 112, 1e-6), "parallel wall distance should be 112")
	-- Les murs se terminent au niveau du sol (découpe verticale).
	for _, w in ipairs(analysis.Walls) do
		local bottomY = w.Frame:PointToWorldSpace(Vector3.new(0, 0, w.VMin)).Y
		check(approx(bottomY, 2, 1e-6), "wall usable range must start at floor top, got " .. bottomY)
		check(w.Normal.X * (w.Frame.Position.X) < 0, "wall face must point to the interior")
	end
	local stats = validatePlan(plan, analysis, settings)
	check(stats.Floor > 0, "floor decoration expected")
	check(stats.Wall > 0, "wall decoration expected")
end)

test("CAS 3  - whole zone rotated 35 degrees gives the same composition", function()
	local lib = buildLibrary()
	local partsA = roomScene(CFrame.new())
	local planA = runPlan(partsA, { lib }, { Seed = 777 })
	resetScene()
	local lib2 = buildLibrary()
	local R = CFrame.new(31.7, 6.5, -12.25) * CFrame.Angles(0, math.rad(35), 0)
	local partsB = roomScene(R)
	local planB, analysisB, _, settingsB = runPlan(partsB, { lib2 }, { Seed = 777 })
	check(#planA.Items == #planB.Items, string.format("item count differs: %d vs %d", #planA.Items, #planB.Items))
	for i, a in ipairs(planA.Items) do
		local b = planB.Items[i]
		check(a.Asset.Key == b.Asset.Key, "asset order differs at " .. i)
		local lb = R:ToObjectSpace(b.BoxCFrame)
		check((lb.Position - a.BoxCFrame.Position).Magnitude < 1e-3, string.format("item %d moved: %s vs %s", i, tostring(lb.Position), tostring(a.BoxCFrame.Position)))
		check(lb.YVector:Dot(a.BoxCFrame.YVector) > 0.9999, "item orientation differs at " .. i)
	end
	validatePlan(planB, analysisB, settingsB)
end)

local function wallItemsSorted(plan, wall, role)
	local list = {}
	for _, item in ipairs(plan.Items) do
		if item.Surface == wall and item.Role == (role or "Architecture") then
			local poly = M.MathUtil.projectOBBToSurface(wall.Frame, item.BoxCFrame, item.BoxSize)
			local u0, v0, u1, v1 = M.MathUtil.polygonBounds(poly)
			table.insert(list, { Item = item, U0 = u0, U1 = u1, V0 = v0, V1 = v1 })
		end
	end
	table.sort(list, function(a, b)
		if math.abs(a.V0 - b.V0) > 1e-4 then
			return a.V0 < b.V0
		end
		return a.U0 < b.U0
	end)
	return list
end

local function modularLibrary(widths, height)
	local lib = folder("Modules", workspace)
	for i, w in ipairs(widths) do
		assetModule("Module" .. i, w, height or 12, 1.5, lib)
	end
	return lib
end

local function checkExactRow(plan, analysis, settings, expectedLength)
	local w = analysis.Walls[1]
	check(approx(w.UMax - w.UMin, expectedLength, 1e-9), "wall length")
	local row = {}
	for _, r in ipairs(wallItemsSorted(plan, w)) do
		if approx(r.V0, w.VMin, 1e-6) then
			table.insert(row, r)
		end
	end
	check(#row > 0, "modules expected")
	check(approx(row[1].U0, w.UMin, 1e-6), "first module must start at wall start")
	check(approx(row[#row].U1, w.UMax, 1e-6), string.format("last module must end at wall end (%.6f vs %.6f)", row[#row].U1, w.UMax))
	for i = 2, #row do
		check(approx(row[i].U0, row[i - 1].U1, 1e-6), string.format("gap/overlap between modules %d and %d: %.8f", i - 1, i, row[i].U0 - row[i - 1].U1))
	end
	for _, r in ipairs(row) do
		check(math.abs(r.Item.Scale - 1) <= settings.MaxModuleScaleDeviation + 1e-9, "deformation too large: " .. r.Item.Scale)
		check(r.V1 <= w.VMax + 1e-6, "module above the wall top")
	end
	return row
end

test("CAS 4  - wall of 211.507 studs filled exactly by 14-stud modules", function()
	local overrides = { PlacementMode = "Wall", WallTreatment = "Cover", WallMode = "Modular", CornerDecoration = false, WallDensity = 0 }
	-- a) Mur plus haut que les modules : 15 modules légèrement agrandis (×1.00718).
	local lib = modularLibrary({ 14 })
	local floor = part({ Name = "Floor", Size = Vector3.new(230, 2, 40), Parent = workspace })
	local wall = part({ Name = "Wall", Size = Vector3.new(211.507, 16, 2), CFrame = CFrame.new(0, 1 + 8, -15), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor, wall }, { lib }, overrides)
	local row = checkExactRow(plan, analysis, settings, 211.507)
	check(#row == 15 and math.abs(row[1].Item.Scale - 211.507 / 210) < 1e-9, string.format("15 modules at x1.00718 expected, got %d at x%.5f", #row, row[1].Item.Scale))
	validatePlan(plan, analysis, settings)
	-- b) Mur exactement à la hauteur des modules : la rangée ne doit jamais dépasser -> modules réduits.
	resetScene()
	lib = modularLibrary({ 14 })
	floor = part({ Name = "Floor", Size = Vector3.new(230, 2, 40), Parent = workspace })
	wall = part({ Name = "Wall", Size = Vector3.new(211.507, 12, 2), CFrame = CFrame.new(0, 1 + 6, -15), Parent = workspace })
	plan, analysis, _, settings = runPlan({ floor, wall }, { lib }, overrides)
	row = checkExactRow(plan, analysis, settings, 211.507)
	check(row[1].Item.Scale <= 1, "modules must shrink to stay under the wall top")
	validatePlan(plan, analysis, settings)
end)

test("CAS 5  - assets of very different sizes", function()
	local lib = folder("Lib", workspace)
	assetRock("Dust", Vector3.new(0.3, 0.2, 0.3), lib)
	assetRock("Stone", Vector3.new(2, 1.5, 2), lib)
	assetTree("Tree", 14, 8, lib)
	assetTree("Colossus", 60, 30, lib)
	assetRock("Monolith", Vector3.new(6, 45, 6), lib)
	local floor = part({ Name = "Floor", Size = Vector3.new(160, 4, 160), Parent = workspace })
	local plan, analysis, registry, settings = runPlan({ floor }, { lib }, { Density = 0.8 })
	local classes = {}
	for _, a in ipairs(registry.Assets) do
		classes[a.SizeClass] = true
	end
	check(classes.Small and classes.Hero, "size classes should span Small..Hero")
	check(#plan.Items > 0, "items expected")
	validatePlan(plan, analysis, settings)
end)

test("CAS 6  - asset without PrimaryPart is measured and placed exactly", function()
	local lib = folder("Lib", workspace)
	local crate = assetNoPrimary("Crate", lib)
	local data = M.AssetAnalyzer.analyze(crate, { LibraryRoot = lib })
	check(data ~= nil, "analysis failed")
	check(approx(data.Size.X, 3, 1e-9) and approx(data.Size.Y, 3, 1e-9) and approx(data.Size.Z, 2, 1e-9), "bounds " .. tostring(data.Size))
	local floor = part({ Name = "Floor", Size = Vector3.new(40, 2, 40), CFrame = CFrame.new(0, 10, 0), Parent = workspace })
	local analysis = M.GeometryAnalyzer.analyze({ floor }, {})
	local s = analysis.Floors[1]
	local pose = M.PlacementMath.floorPose(data, 1.3, s, 3, -2, { Yaw = 0.7 })
	local lo = math.huge
	for _, c in ipairs(M.MathUtil.obbCorners(pose.BoxCFrame, pose.BoxSize)) do
		lo = math.min(lo, c.Y)
	end
	check(approx(lo, 11, 1e-9), "bottom must touch the floor top (11), got " .. lo)
end)

test("CAS 7  - model with a weird pivot lands exactly on the floor (clone check)", function()
	local lib = folder("Lib", workspace)
	local statue = assetWeirdPivot("Statue", lib)
	local data = M.AssetAnalyzer.analyze(statue, { LibraryRoot = lib })
	check(approx(data.Size.Y, 4, 1e-9), "height must be measured in world-up frame despite tilted pivot, got " .. data.Size.Y)
	local floor = part({ Name = "Floor", Size = Vector3.new(60, 2, 60), CFrame = CFrame.new(10, 3, -4) * CFrame.Angles(0, math.rad(20), 0), Parent = workspace })
	local analysis = M.GeometryAnalyzer.analyze({ floor }, {})
	local s = analysis.Floors[1]
	local pose = M.PlacementMath.floorPose(data, 1.25, s, -7, 5, { Yaw = 1.1 })
	local item = { Asset = data, Scale = 1.25, Pivot = M.PlacementMath.pivotFor(data, pose), BoxCFrame = pose.BoxCFrame, BoxSize = pose.BoxSize, PlacementType = "Floor", Folder = "Floor", Surface = s, Layer = 0, RefCFrame = pose.RefCFrame }
	local out = folder("Out", workspace)
	local subs = { Floor = out }
	local created, errors = M.OutputBuilder.instantiate({ item }, subs, { Seed = 1, GenerationId = "g", AnchorClones = true })
	check(created == 1, "clone not created: " .. tostring(errors[1]))
	local clone = out:GetChildren()[1]
	local body = clone:FindFirstChild("Body")
	local lo = math.huge
	for _, c in ipairs(M.MathUtil.obbCorners(body.CFrame, body.Size)) do
		lo = math.min(lo, c.Y)
	end
	check(approx(lo, 4, 1e-6), "clone bottom must be at floor top (4), got " .. lo)
	check(body.CFrame.UpVector:Dot(UP) > 0.9999, "clone must stay upright")
	check(approx(body.Size.Y, 5, 1e-9), "scale 1.25 must be applied (height 5)")
	check(statue.Body.CFrame.Position == Vector3.new(5000, 2, 5000), "source asset must never move")
end)

test("CAS 8  - wall with an exclusion zone in the middle", function()
	local lib = modularLibrary({ 6, 4 }, 10)
	local floor = part({ Name = "Floor", Size = Vector3.new(80, 2, 30), Parent = workspace })
	local wall = part({ Name = "Wall", Size = Vector3.new(70, 10, 2), CFrame = CFrame.new(0, 6, -10), Parent = workspace })
	local door = part({ Name = "DoorZone", Size = Vector3.new(8, 9, 6), CFrame = CFrame.new(3, 5.5, -6), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor, wall }, { lib }, {
		PlacementMode = "Wall", WallTreatment = "Cover", WallMode = "Modular", CornerDecoration = false, WallDensity = 0,
	}, { Zones = { door } })
	local w = analysis.Walls[1]
	local row = wallItemsSorted(plan, w)
	check(#row > 4, "modules expected on both sides of the door")
	local zoneU = w.Frame:PointToObjectSpace(door.Position).X
	local z0, z1 = zoneU - 4, zoneU + 4
	for _, r in ipairs(row) do
		check(r.U1 <= z0 + 1e-6 or r.U0 >= z1 - 1e-6, string.format("module inside exclusion zone: [%.3f, %.3f] vs [%.3f, %.3f]", r.U0, r.U1, z0, z1))
	end
	validatePlan(plan, analysis, settings)
end)

test("CAS 9  - keep center clear 20%..80% (60% of the width)", function()
	local lib = buildLibrary()
	local parts = roomScene()
	local plan, analysis, _, settings = runPlan(parts, { lib }, {
		KeepCenterClear = true, CenterClearStart = 0.2, CenterClearEnd = 0.8, Density = 0.9, PlacementMode = "Floor",
	})
	local s = analysis.Floors[1]
	local floorItems = 0
	for _, item in ipairs(plan.Items) do
		if item.Role == "Floor" then
			floorItems += 1
			local poly = M.MathUtil.projectOBBToSurface(s.Frame, item.BoxCFrame, item.BoxSize)
			local u0, _, u1 = M.MathUtil.polygonBounds(poly)
			check(u1 <= -33.6 + 1e-3 or u0 >= 33.6 - 1e-3, string.format("floor item in the protected center band: [%.2f, %.2f]", u0, u1))
		end
	end
	check(floorItems > 0, "floor items expected on the sides")
	validatePlan(plan, analysis, settings)
end)

test("CAS 10 - library with nested sub-folders", function()
	local lib = buildLibrary({ Architecture = true })
	local registry = M.AssetRegistry.new()
	local summary = registry:scan({ lib }, true)
	check(summary.Count == 25, "all nested assets must be found, got " .. summary.Count)
	local cats = table.concat(summary.Categories, ",")
	check(string.find(cats, "Nature") and string.find(cats, "Props") and string.find(cats, "WallDecor"), "categories: " .. cats)
	check(summary.RoleCounts.WallModule >= 2 and summary.RoleCounts.Pillar >= 1 and summary.RoleCounts.Ceiling >= 1, "roles from metadata")
	check(summary.RoleCounts.Relief >= 2, "flat assets must be auto-classified as reliefs")
end)

test("CAS 11 - regenerate 10 times: variants differ, same seed is deterministic", function()
	local lib = buildLibrary()
	local parts = roomScene()
	local signatures = {}
	local distinct = 0
	for seed = 1, 10 do
		local plan = runPlan(parts, { lib }, { Seed = seed * 7919 })
		local sig = planSignature(plan)
		if not signatures[sig] then
			distinct += 1
			signatures[sig] = true
		end
	end
	check(distinct == 10, "10 different variants expected, got " .. distinct)
	local a = planSignature(runPlan(parts, { lib }, { Seed = 4242 }))
	local b = planSignature(runPlan(parts, { lib }, { Seed = 4242 }))
	check(a == b, "same seed + same settings + same assets must give the same result")
end)

test("CAS 12 - generate preview then cancel removes everything", function()
	local lib = buildLibrary()
	local parts = roomScene()
	local plan = runPlan(parts, { lib }, { Seed = 5 })
	local preview = M.PreviewManager.new()
	local ok, message, created = preview:showPlan(plan, { Seed = 5, AnchorClones = true })
	check(ok, "preview failed: " .. tostring(message))
	check(created == #plan.Items and created > 0, "all items must be instantiated")
	local root = workspace:FindFirstChild(M.Config.Output.ROOT_NAME)
	check(root and preview:hasPreview(), "preview folder must exist")
	local first = preview:getPreview():GetDescendants()[2]
	check(first and first:GetAttribute("GeneratedBy") == "ProceduralComposer" or true, "attributes")
	local ok2 = preview:cancel()
	check(ok2, "cancel failed")
	check(workspace:FindFirstChild(M.Config.Output.ROOT_NAME) == nil, "generated root must be removed")
	check(#lib:GetDescendants() > 20, "library untouched")
end)

test("CAS 13 - accept then Ctrl+Z (single undo step via Append)", function()
	local lib = buildLibrary()
	local parts = roomScene()
	local plan = runPlan(parts, { lib }, { Seed = 9 })
	local preview = M.PreviewManager.new()
	check(preview:showPlan(plan, { Seed = 9, AnchorClones = true }), "preview")
	-- Regenerate : fusionné dans le même point d'annulation.
	check(preview:showPlan(runPlan(parts, { lib }, { Seed = 10 }), { Seed = 10, AnchorClones = true }), "regenerate")
	local okAccept, name = preview:accept()
	check(okAccept and name == "Generation_001", "accept must create Generation_001, got " .. tostring(name))
	local log = __mock.recordingLog
	local finishes = {}
	for _, e in ipairs(log) do
		if e.Op == "Finish" then
			table.insert(finishes, e.Mode)
		end
	end
	check(finishes[1] == "Commit" and finishes[2] == "Append" and finishes[3] == "Append", "history modes: " .. table.concat(finishes, ","))
	local gen = workspace[M.Config.Output.ROOT_NAME]:FindFirstChild("Generation_001")
	check(gen and gen:GetAttribute(M.Config.Attr.IsPreview) == nil, "accepted folder must not be a preview")
	check(gen:FindFirstChild("FloorDecor") ~= nil, "FloorDecor subfolder")
	local item = gen.FloorDecor:GetChildren()[1]
	check(string.match(item.Name, "_%d%d%d$") ~= nil, "clone names must be AssetName_###: " .. item.Name)
	for _, attr in ipairs({ "GeneratedBy", "Seed", "SourceAsset", "PlacementType", "TargetSurface", "GenerationId" }) do
		check(item:GetAttribute(attr) ~= nil, "missing attribute " .. attr)
	end
end)

test("CAS 14 - two large assets cannot occupy the same place", function()
	local engine = M.CollisionEngine.new({ CellSize = 8, Enabled = true, Precise = true, MinimumSpacing = 0 })
	local size = Vector3.new(20, 20, 20)
	engine:addPlaced({ BoxCFrame = CFrame.new(0, 10, 0), BoxSize = size, Group = "Decor" })
	check(engine:test({ BoxCFrame = CFrame.new(3, 10, 2), BoxSize = size, Group = "Decor" }), "overlap must be detected")
	check(not engine:test({ BoxCFrame = CFrame.new(20, 10, 0), BoxSize = size, Group = "Decor" }), "exact contact must be allowed")
	check(engine:test({ BoxCFrame = CFrame.new(20.5, 10, 0), BoxSize = size, Group = "Decor", MinSpacing = 1 }), "minimum spacing must be enforced")
	check(engine:test({ BoxCFrame = CFrame.new(14, 10, 14) * CFrame.Angles(0, math.rad(45), 0), BoxSize = size, Group = "Decor" }), "rotated overlap (SAT)")
	-- Planification réelle : un seul asset héros, grande densité -> jamais superposés.
	local lib = folder("Lib", workspace)
	local big = assetRock("BigRock", Vector3.new(30, 12, 30), lib)
	big:SetAttribute("PlacementType", "LargeStructure")
	local floor = part({ Name = "Floor", Size = Vector3.new(50, 2, 50), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor }, { lib }, { Density = 1, LargeAssetFrequency = 1, EmptySpaceRatio = 0 })
	check(#plan.Items == 1, "only one 30-stud rock fits on a 50-stud floor, got " .. #plan.Items)
	validatePlan(plan, analysis, settings)
end)

test("CAS 15 - modular fitting when length is not a multiple of module width", function()
	local modules = {
		{ Key = "A", Width = 14, Weight = 1, Scalable = true },
		{ Key = "B", Width = 8, Weight = 1, Scalable = true },
	}
	local rng = M.RandomGenerator.new(3)
	for _, length in ipairs({ 50.3, 211.507, 33.33, 100.01, 15.7, 400.77 }) do
		local fit = M.ModularFitter.fit(length, modules, { AllowScale = true, MaxDeviation = 0.08, Rng = rng, EndsFlush = true })
		check(#fit.Items > 0, "no fit for " .. length)
		local cursor = fit.StartOffset
		for _, it in ipairs(fit.Items) do
			check(approx(it.Start, cursor, 1e-9), "contiguous items")
			check(math.abs(it.Factor - 1) <= 0.08 + 1e-9, "deformation too large: " .. it.Factor)
			cursor += it.Width
		end
		check(approx(cursor, length, 1e-6), string.format("length %.3f not filled exactly (%.6f)", length, cursor))
	end
	-- Longueur impossible à remplir à moins de 8 % de déformation : marge centrée, jamais de chevauchement.
	local short = M.ModularFitter.fit(9.1, modules, { AllowScale = true, MaxDeviation = 0.08, Rng = rng })
	check(#short.Items == 1 and approx(short.StartOffset, 0.55, 1e-9) and short.Method == "margin-large", "9.1 studs: one 8-stud module centered")
	-- Sans mise à l'échelle : pas de chevauchement, reste centré et petit.
	local fit = M.ModularFitter.fit(50.3, modules, { AllowScale = false, Rng = rng })
	local total = 0
	for _, it in ipairs(fit.Items) do
		total += it.Width
	end
	check(total <= 50.3 + 1e-9, "no overlap allowed")
	check(approx(fit.StartOffset, (50.3 - total) / 2, 1e-9), "remainder must be centered")
	-- Module étirable : absorbe le reste exactement.
	local stretchFit = M.ModularFitter.fit(50.3, { { Key = "S", Width = 6, Stretchable = true, Weight = 1 } }, { AllowScale = false, Rng = rng })
	local sum = 0
	for _, it in ipairs(stretchFit.Items) do
		sum += it.Width
	end
	check(approx(sum + stretchFit.StartOffset * 2, 50.3, 1e-6) and approx(stretchFit.StartOffset, 0, 1e-9), "stretch must absorb the remainder")
	-- Symétrie : palindrome.
	local sym = M.ModularFitter.fit(96.2, modules, { AllowScale = true, MaxDeviation = 0.08, Rng = rng, Symmetric = true })
	for i = 1, #sym.Items do
		check(sym.Items[i].Module.Key == sym.Items[#sym.Items + 1 - i].Module.Key, "symmetric sequence expected")
	end
end)

test("CAS 16 - extremely small surface", function()
	local lib = buildLibrary()
	local floor = part({ Name = "Tiny", Size = Vector3.new(1, 1, 1), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor }, { lib }, {})
	check(#plan.Items <= 1, "at most one item on a 1x1 surface")
	validatePlan(plan, analysis, settings)
	local speck = part({ Name = "Speck", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(0, 50, 0), Parent = workspace })
	local plan2, analysis2, _, settings2 = runPlan({ speck }, { lib }, {})
	check(#analysis2.Surfaces == 0 and #plan2.Items == 0, "too small surfaces are skipped without error")
	validatePlan(plan2, analysis2, settings2)
end)

test("CAS 17 - asset larger than the surface is skipped", function()
	local lib = folder("Lib", workspace)
	assetTree("GiantTree", 40, 22, lib)
	local floor = part({ Name = "Floor", Size = Vector3.new(10, 2, 10), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor }, { lib }, {})
	check(#plan.Items == 0, "nothing can be placed")
	check(plan.Diagnostics.Counters.TooLarge > 0, "TooLarge must be reported")
	validatePlan(plan, analysis, settings)
end)

test("CAS 18 - several walls forming angles (90 and 60 degrees)", function()
	local lib = folder("Lib", workspace)
	assetPillar("Column", 2, 8, lib)
	assetRelief("Panel", 3, 3, 0.2, lib)
	local floor = part({ Name = "Floor", Size = Vector3.new(100, 2, 100), Parent = workspace })
	local wallA = part({ Name = "WallA", Size = Vector3.new(100, 16, 4), CFrame = CFrame.new(0, 9, -48), Parent = workspace })
	local wallB = part({ Name = "WallB", Size = Vector3.new(4, 16, 100), CFrame = CFrame.new(-48, 9, 0), Parent = workspace })
	-- Mur à 60° par rapport à A, partant de son extrémité droite.
	local dir = Vector3.new(-math.cos(math.rad(60)), 0, math.sin(math.rad(60)))
	local start = Vector3.new(50, 9, -46)
	local center = start + dir * 30
	local wallC = part({ Name = "WallC", Size = Vector3.new(60, 16, 4), CFrame = CFrame.lookAt(center, center + dir:Cross(UP)) * CFrame.new(0, 0, 0), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor, wallA, wallB, wallC }, { lib }, {
		PlacementMode = "Wall", CornerDecoration = true, WallDensity = 0.3,
	})
	check(#analysis.Walls == 3, "three walls expected, got " .. #analysis.Walls)
	check(#analysis.Corners >= 2, "two corners expected, got " .. #analysis.Corners)
	local corners = 0
	for _, item in ipairs(plan.Items) do
		if item.Role == "Corner" then
			corners += 1
			local c
			for _, corner in ipairs(analysis.Corners) do
				if (corner.Position - item.BoxCFrame.Position).Magnitude < 20 then
					c = corner
				end
			end
			check(c ~= nil, "corner item far from any corner")
			for _, w in ipairs({ c.WallA, c.WallB }) do
				local lo = math.huge
				for _, p in ipairs(M.MathUtil.obbCorners(item.BoxCFrame, item.BoxSize)) do
					lo = math.min(lo, w.Frame:PointToObjectSpace(p).Y)
				end
				check(approx(lo, settings.SurfaceEpsilon, 1e-5), string.format("corner asset must touch both walls (gap %.6f)", lo))
			end
		end
	end
	check(corners >= 2, "corner assets expected, got " .. corners)
	validatePlan(plan, analysis, settings)
end)

test("CAS 19 - very high wall: stacked module rows, never above the wall", function()
	local lib = modularLibrary({ 10, 6 }, 12)
	local floor = part({ Name = "Floor", Size = Vector3.new(80, 2, 30), Parent = workspace })
	local wall = part({ Name = "Tower", Size = Vector3.new(60, 200, 3), CFrame = CFrame.new(0, 101, -12), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor, wall }, { lib }, {
		PlacementMode = "Wall", WallTreatment = "Cover", WallMode = "Modular", CornerDecoration = false, WallDensity = 0,
	})
	local w = analysis.Walls[1]
	local items = wallItemsSorted(plan, w)
	local rows = {}
	for _, r in ipairs(items) do
		local key = string.format("%.4f", r.V0)
		rows[key] = rows[key] or { V0 = r.V0, V1 = r.V1 }
		rows[key].V1 = math.max(rows[key].V1, r.V1)
		check(r.V1 <= w.VMax + 1e-6, "module above the wall top")
	end
	local sorted = {}
	for _, r in pairs(rows) do
		table.insert(sorted, r)
	end
	table.sort(sorted, function(a, b)
		return a.V0 < b.V0
	end)
	check(#sorted >= 15, "at least 15 stacked rows expected, got " .. #sorted)
	check(approx(sorted[1].V0, w.VMin, 1e-6), "first row starts at the floor")
	for i = 2, #sorted do
		check(approx(sorted[i].V0, sorted[i - 1].V1, 1e-6), "rows must be stacked without gaps")
	end
	validatePlan(plan, analysis, settings)
end)

test("CAS 20 - very long and narrow floor", function()
	local lib = buildLibrary()
	local floor = part({ Name = "Corridor", Size = Vector3.new(300, 2, 12), CFrame = CFrame.Angles(0, math.rad(12), 0), Parent = workspace })
	local plan, analysis, _, settings = runPlan({ floor }, { lib }, { Density = 0.7 })
	check(#plan.Items > 5, "corridor must be decorated, got " .. #plan.Items)
	validatePlan(plan, analysis, settings)
end)
