-- Helpers de test : registre, assertions, construction de scènes et de
-- bibliothèques d'assets, exécution d'une génération, validation des invariants.

local TESTS = {}
local function test(name, fn)
	table.insert(TESTS, { Name = name, Fn = fn })
end

local function check(cond, message)
	if not cond then
		error(message or "check failed", 2)
	end
end

local function approx(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

local M = {
	Config = require(ROOT.Core.Config),
	Settings = require(ROOT.Core.Settings),
	MathUtil = require(ROOT.Core.MathUtil),
	RandomGenerator = require(ROOT.Core.RandomGenerator),
	GeometryAnalyzer = require(ROOT.Analysis.GeometryAnalyzer),
	AssetRegistry = require(ROOT.Analysis.AssetRegistry),
	AssetAnalyzer = require(ROOT.Analysis.AssetAnalyzer),
	GenerationManager = require(ROOT.Generation.GenerationManager),
	ModularFitter = require(ROOT.Placement.ModularFitter),
	CollisionEngine = require(ROOT.Placement.CollisionEngine),
	PlacementMath = require(ROOT.Placement.PlacementMath),
	PreviewManager = require(ROOT.Generation.PreviewManager),
	OutputBuilder = require(ROOT.Generation.OutputBuilder),
	HistoryManager = require(ROOT.Generation.HistoryManager),
}

local TOL = M.Config.Precision.CONTACT_TOLERANCE

local function resetScene()
	for _, child in ipairs(workspace:GetChildren()) do
		if child.ClassName ~= "Terrain" then
			child:Destroy()
		end
	end
	__mock.resetHistory()
end

local function part(props)
	local p = Instance.new(props.Class or "Part")
	p.Name = props.Name or "Part"
	p.Size = props.Size or Vector3.new(4, 1, 2)
	p.CFrame = props.CFrame or CFrame.new()
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	p.Parent = props.Parent
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(name, parent, parts, primaryIndex)
	local m = Instance.new("Model")
	m.Name = name
	for i, p in ipairs(parts) do
		p.Parent = m
		if primaryIndex == i then
			m.PrimaryPart = p
		end
	end
	m.Parent = parent
	return m
end

-- Assets génériques (placés loin de la zone, dans une bibliothèque) ----------------------

local LIB_ORIGIN = Vector3.new(5000, 0, 5000)

local function assetRock(name, size, parent)
	return part({ Name = name, Size = size, CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, size.Y / 2, 0)), Parent = parent })
end

local function assetTree(name, height, canopy, parent)
	local trunk = part({ Name = "Trunk", Size = Vector3.new(canopy * 0.2, height * 0.6, canopy * 0.2), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, height * 0.3, 0)) })
	local leaves = part({ Name = "Leaves", Size = Vector3.new(canopy, height * 0.45, canopy), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, height * 0.775, 0)) })
	return model(name, parent, { trunk, leaves }, 1)
end

local function assetNoPrimary(name, parent)
	local a = part({ Name = "A", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, 1, 0)) })
	local b = part({ Name = "B", Size = Vector3.new(1, 3, 1), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(1.5, 1.5, 0)) })
	return model(name, parent, { a, b }, nil)
end

local function assetWeirdPivot(name, parent)
	local a = part({ Name = "Body", Size = Vector3.new(3, 4, 3), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, 2, 0)) })
	local m = model(name, parent, { a }, nil)
	-- Pivot décalé de 50 studs et basculé de 90° autour de X.
	m.WorldPivot = CFrame.new(LIB_ORIGIN + Vector3.new(50, 30, -20)) * CFrame.Angles(math.rad(90), 0, math.rad(33))
	return m
end

local function assetRelief(name, w, h, d, parent)
	local p = part({ Name = name, Size = Vector3.new(w, h, d), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, h / 2, 0)), Parent = parent })
	return p
end

local function assetModule(name, w, h, d, parent)
	local p = part({ Name = name, Size = Vector3.new(w, h, d), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, h / 2, 0)), Parent = parent })
	p:SetAttribute("PlacementType", "WallModule")
	return p
end

local function assetPillar(name, w, h, parent)
	local p = part({ Name = name, Size = Vector3.new(w, h, w), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, h / 2, 0)), Parent = parent })
	p:SetAttribute("PlacementType", "Pillar, Corner")
	return p
end

local function assetTrim(name, length, parent, placement)
	local p = part({ Name = name, Size = Vector3.new(length, 0.8, 0.8), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, 0.4, 0)), Parent = parent })
	p:SetAttribute("PlacementType", placement or "WallTop, WallBase")
	p:SetAttribute("Stretchable", true)
	return p
end

local function assetLamp(name, parent)
	local cable = part({ Name = "Cable", Size = Vector3.new(0.2, 3, 0.2), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, 1.5 + 1, 0)) })
	local bulb = part({ Name = "Bulb", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(LIB_ORIGIN + Vector3.new(0, 0.5, 0)) })
	local m = model(name, parent, { cable, bulb }, 2)
	m:SetAttribute("PlacementType", "Ceiling")
	return m
end

-- Bibliothèque générique avec sous-dossiers (> 20 assets de tailles variées).
local function buildLibrary(opts)
	opts = opts or {}
	local lib = folder("AssetLibrary", workspace)
	local nature = folder("Nature", lib)
	local rocks = folder("Rocks", nature)
	local props = folder("Props", lib)
	local wall = folder("WallDecor", lib)
	for i = 1, 4 do
		assetTree("Tree" .. i, 10 + i * 3, 6 + i, nature)
	end
	assetTree("GiantTree", 40, 22, nature)
	for i = 1, 6 do
		assetRock("Rock" .. i, Vector3.new(0.6 + i * 0.5, 0.4 + i * 0.3, 0.7 + i * 0.4), rocks)
	end
	assetRock("Pebble", Vector3.new(0.5, 0.3, 0.5), rocks)
	assetNoPrimary("Crate", props)
	assetWeirdPivot("WeirdStatue", props)
	assetRock("Barrel", Vector3.new(2, 3, 2), props)
	assetRock("Bench", Vector3.new(5, 1.5, 1.6), props)
	assetRock("Mushroom", Vector3.new(0.8, 1, 0.8), props)
	assetRelief("Vine", 2, 8, 0.2, wall)
	assetRelief("Sign", 4, 2.5, 0.3, wall)
	assetRelief("Frame", 3, 3, 0.25, wall)
	assetLamp("HangingLamp", props)
	if opts.Architecture then
		local arch = folder("Architecture", lib)
		assetModule("WallSection", 14, 12, 1.5, arch)
		assetModule("WallSectionB", 8, 12, 1.5, arch)
		assetPillar("Pillar", 2, 12, arch)
		assetTrim("Cornice", 6, arch)
	end
	return lib
end

-- Exécution d'une génération ---------------------------------------------------------------

local function makeSettings(overrides)
	local s = M.Settings.defaults()
	for k, v in pairs(overrides or {}) do
		s[k] = v
	end
	if s.MinScale > s.MaxScale then
		s.MinScale, s.MaxScale = s.MaxScale, s.MinScale
	end
	return s
end

local function runPlan(targets, libraryRoots, overrides, extra)
	extra = extra or {}
	local settings = makeSettings(overrides)
	local registry = M.AssetRegistry.new()
	registry:scan(libraryRoots, settings.AutoClassify)
	local analysis = M.GeometryAnalyzer.analyze(targets, {
		Overrides = extra.Overrides or {},
		WallSides = settings.WallSides,
		ObstacleParts = extra.Protected or {},
		Camera = extra.Camera,
	})
	local exclude = table.clone(libraryRoots)
	for _, t in ipairs(targets) do
		table.insert(exclude, t)
	end
	for _, z in ipairs(extra.Zones or {}) do
		table.insert(exclude, z)
	end
	local plan = M.GenerationManager.plan({
		Settings = settings,
		Analysis = analysis,
		Registry = registry,
		ExclusionParts = extra.Zones or {},
		ProtectedParts = extra.Protected or {},
		SceneExclude = exclude,
	})
	return plan, analysis, registry, settings
end

-- Validation des invariants --------------------------------------------------------------------

local function isFinite(x)
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function heightRange(frame, cf, size)
	local lo, hi = math.huge, -math.huge
	for _, c in ipairs(M.MathUtil.obbCorners(cf, size)) do
		local l = frame:PointToObjectSpace(c)
		lo = math.min(lo, l.Y)
		hi = math.max(hi, l.Y)
	end
	return lo, hi
end

local function boxesOf(item)
	return M.PlacementMath.worldSubBoxes(item.Pose)
end

local function itemsIntersect(a, b)
	local la, ha = M.MathUtil.obbAABB(a.BoxCFrame, a.BoxSize)
	local lb, hb = M.MathUtil.obbAABB(b.BoxCFrame, b.BoxSize)
	if la.X > hb.X or lb.X > ha.X or la.Y > hb.Y or lb.Y > ha.Y or la.Z > hb.Z or lb.Z > ha.Z then
		return false
	end
	if not M.MathUtil.obbIntersects(a.BoxCFrame, a.BoxSize, b.BoxCFrame, b.BoxSize, TOL, 0) then
		return false
	end
	for _, x in ipairs(boxesOf(a)) do
		for _, y in ipairs(boxesOf(b)) do
			if M.MathUtil.obbIntersects(x.CFrame, x.Size, y.CFrame, y.Size, TOL, 0) then
				return true
			end
		end
	end
	return false
end

--[[
	Vérifie : valeurs finies, contact exact au sol, pas de pénétration dans les
	murs, objets dans les limites des surfaces, aucune interpénétration entre
	décorations, aucune interpénétration avec la géométrie cible, pas de doublon.
]]
local function validatePlan(plan, analysis, settings, opts)
	opts = opts or {}
	local eps = settings.SurfaceEpsilon
	local stats = { Floor = 0, Wall = 0, Architecture = 0, Corner = 0, Ceiling = 0 }
	for _, item in ipairs(plan.Items) do
		local p = item.BoxCFrame.Position
		check(isFinite(p.X) and isFinite(p.Y) and isFinite(p.Z), "non-finite position for " .. item.Asset.Name)
		check(isFinite(item.BoxSize.X) and item.BoxSize.X > 0, "invalid size for " .. item.Asset.Name)
		stats[item.Role] = (stats[item.Role] or 0) + 1
		local s = item.Surface
		if item.Role == "Floor" and s and s.Role == "Floor" and s.Tilt < 0.5 then
			local lo = heightRange(s.Frame, item.BoxCFrame, item.BoxSize)
			local expected = item.Asset.Meta.FloorOffset + settings.SurfaceOffset + (if item.Asset.IsFlat then eps else 0)
			check(approx(lo, expected, 1e-4), string.format("floor item %s not on surface: bottom=%.6f expected=%.6f", item.Asset.Name, lo, expected))
			local poly = M.MathUtil.projectOBBToSurface(s.Frame, item.BoxCFrame, item.BoxSize)
			check(M.MathUtil.polygonInsideRect(poly, s.UMin, s.VMin, s.UMax, s.VMax, 1e-3), "floor item outside its surface: " .. item.Asset.Name)
		elseif item.Role == "Wall" and s then
			local lo = heightRange(s.Frame, item.BoxCFrame, item.BoxSize)
			check(lo >= -1e-6, string.format("wall item %s penetrates wall (%.5f)", item.Asset.Name, lo))
			if not plan.Facades[s] then
				local expected = item.Layer * eps + item.Asset.Meta.WallOffset + settings.SurfaceOffset
				check(approx(lo, expected, 1e-4), string.format("wall item %s back not at epsilon: %.6f vs %.6f", item.Asset.Name, lo, expected))
			end
			local poly = M.MathUtil.projectOBBToSurface(s.Frame, item.BoxCFrame, item.BoxSize)
			check(M.MathUtil.polygonInsideRect(poly, s.UMin, s.VMin, s.UMax, s.VMax, 1e-3), "wall item outside wall: " .. item.Asset.Name)
		elseif item.Role == "Architecture" and s then
			local lo = heightRange(s.Frame, item.BoxCFrame, item.BoxSize)
			check(lo >= eps * 0.999, string.format("architecture %s too close to wall (%.5f)", item.Asset.Name, lo))
			local poly = M.MathUtil.projectOBBToSurface(s.Frame, item.BoxCFrame, item.BoxSize)
			check(M.MathUtil.polygonInsideRect(poly, s.UMin, s.VMin, s.UMax, s.VMax, 1e-3), string.format("architecture %s outside wall", item.Asset.Name))
		elseif item.Role == "Ceiling" and s then
			local lo = heightRange(s.Frame, item.BoxCFrame, item.BoxSize)
			check(lo >= -1e-6 and approx(lo, eps + settings.SurfaceOffset, 1e-4), string.format("ceiling item %s not at ceiling (%.5f)", item.Asset.Name, lo))
		end
	end
	-- Interpénétrations entre décorations (et décor/architecture).
	local items = plan.Items
	for i = 1, #items do
		local a = items[i]
		for j = i + 1, #items do
			local b = items[j]
			local bothArch = a.Group == "Architecture" and b.Group == "Architecture"
			local overlapAllowed = bothArch or (a.Group == "Decor" and b.Group == "Decor" and (a.Asset.Meta.CanOverlapDecoration or b.Asset.Meta.CanOverlapDecoration))
			if not overlapAllowed then
				check(not itemsIntersect(a, b), string.format("items overlap: %s #%d and %s #%d", a.Asset.Name, a.Id, b.Asset.Name, b.Id))
			end
			if a.Asset == b.Asset then
				check((a.BoxCFrame.Position - b.BoxCFrame.Position).Magnitude > 1e-3, "duplicate item at the same position: " .. a.Asset.Name)
			end
		end
	end
	-- Géométrie cible : aucune pénétration (hors surfaces hôtes explicitement ignorées).
	for _, item in ipairs(items) do
		for _, target in ipairs(analysis.Parts) do
			if not (item.IgnoreParts and item.IgnoreParts[target]) then
				local fake = { BoxCFrame = target.CFrame, BoxSize = target.Size, Pose = { SubBoxes = { { CFrame = target.CFrame, Size = target.Size } } } }
				check(not itemsIntersect(item, fake), string.format("%s penetrates target part %s", item.Asset.Name, target.Name))
			end
		end
	end
	return stats
end

-- Scène : sol + deux murs parallèles (comme la capture d'écran), repère optionnel.
local function roomScene(rootCf, opts)
	opts = opts or {}
	rootCf = rootCf or CFrame.new()
	local scene = folder("Zone", workspace)
	local floorSize = opts.FloorSize or Vector3.new(120, 4, 80)
	local floor = part({ Name = "Ground", Size = floorSize, CFrame = rootCf * CFrame.new(0, 0, 0), Parent = scene })
	local parts = { floor }
	if opts.Walls ~= false then
		local h = opts.WallHeight or 20
		local x = floorSize.X / 2 - 2
		local left = part({ Name = "WallL", Size = Vector3.new(4, h, floorSize.Z), CFrame = rootCf * CFrame.new(-x, floorSize.Y / 2 + h / 2, 0), Parent = scene })
		local right = part({ Name = "WallR", Size = Vector3.new(4, h, floorSize.Z), CFrame = rootCf * CFrame.new(x, floorSize.Y / 2 + h / 2, 0), Parent = scene })
		table.insert(parts, left)
		table.insert(parts, right)
	end
	return parts, scene
end

-- Signature d'un plan (déterminisme).
local function planSignature(plan)
	local parts = {}
	for _, item in ipairs(plan.Items) do
		local p = item.BoxCFrame.Position
		table.insert(parts, string.format("%s|%.5f|%.5f|%.5f|%.5f", item.Asset.Key, p.X, p.Y, p.Z, item.Scale))
	end
	return table.concat(parts, ";")
end

function runAllTests()
	local passed, failed = 0, 0
	local failures = {}
	for _, t in ipairs(TESTS) do
		resetScene()
		local start = os.clock()
		local ok, err = pcall(t.Fn)
		local dt = os.clock() - start
		if ok then
			passed += 1
			print(string.format("  PASS  %-58s %6.2fs", t.Name, dt))
		else
			failed += 1
			print(string.format("  FAIL  %-58s %6.2fs\n        %s", t.Name, dt, tostring(err)))
			table.insert(failures, t.Name)
		end
	end
	print(string.format("\n%d passed, %d failed", passed, failed))
	if failed > 0 then
		error("Test failures: " .. table.concat(failures, ", "))
	end
end
