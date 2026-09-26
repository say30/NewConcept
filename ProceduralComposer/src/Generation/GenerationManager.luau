--[[
	GenerationManager
	Orchestration d'une génération complète, en pur calcul (aucune instance
	créée ici) :

	  1. collision : géométrie cible + géométrie protégée + scène ;
	  2. zones d'exclusion (sélection + tag ProceduralPlacementExclude) ;
	  3. passes dans l'ordre : architecture -> coins -> décor mural ->
	     sols / pentes -> plafonds (les gros éléments structurels d'abord, les
	     détails ensuite, tous dans le même monde de collision) ;
	  4. diagnostics.

	Chaque passe utilise un sous-flux aléatoire nommé : même seed + mêmes
	réglages + mêmes assets = même résultat.
]]

local Workspace = game:GetService("Workspace")

local Core = script.Parent.Parent.Core
local Placement = script.Parent.Parent.Placement

local Config = require(Core.Config)
local Utilities = require(Core.Utilities)
local RandomGenerator = require(Core.RandomGenerator)
local CollisionEngine = require(Placement.CollisionEngine)
local ExclusionZones = require(Placement.ExclusionZones)
local PlacementContext = require(Placement.PlacementContext)
local AssetSelector = require(Placement.AssetSelector)
local FloorPlacementEngine = require(Placement.FloorPlacementEngine)
local WallPlacementEngine = require(Placement.WallPlacementEngine)
local ArchitectureEngine = require(Placement.ArchitectureEngine)
local CornerEngine = require(Placement.CornerEngine)
local CeilingPlacementEngine = require(Placement.CeilingPlacementEngine)
local Diagnostics = require(script.Parent.Diagnostics)

local GenerationManager = {}

-- Quelles passes exécuter selon le mode et les réglages.
function GenerationManager.resolvePasses(settings)
	local mode = settings.PlacementMode
	local treatment = settings.WallTreatment
	local wallMode = settings.WallMode
	local passes = {
		Floors = mode == "Auto" or mode == "Floor" or mode == "Hybrid",
		WallProps = mode == "Auto" or mode == "Wall" or mode == "Hybrid",
		Architecture = false,
		Corners = settings.CornerDecoration and (mode == "Auto" or mode == "Wall" or mode == "Hybrid" or mode == "Architecture"),
		Ceilings = (mode == "Auto" or mode == "Hybrid") and settings.CeilingDecoration,
		FloorAlgorithm = if mode == "Auto" then "Hybrid" else settings.FloorAlgorithm,
		WallPropMode = "Hybrid",
		ArchitectureMode = "Modular",
		Treatment = treatment,
	}
	if mode == "Architecture" then
		passes.Architecture = true
		passes.ArchitectureMode = "Architectural"
		if treatment == "Keep" then
			passes.Treatment = "Rebuild"
		end
	elseif passes.WallProps then
		if treatment ~= "Keep" or wallMode == "Modular" or wallMode == "Architectural" then
			passes.Architecture = true
			if wallMode == "Architectural" or wallMode == "Modular" then
				passes.ArchitectureMode = wallMode
			else
				passes.ArchitectureMode = if treatment == "Rebuild" then "Architectural" else "Modular"
			end
			if treatment == "Keep" then
				passes.Treatment = "Cover"
			end
		end
		if wallMode == "Props" then
			passes.WallPropMode = "Props"
		elseif wallMode == "Relief" then
			passes.WallPropMode = "Relief"
		end
	end
	return passes
end

local function medianAssetSize(registry)
	local sizes = {}
	for _, a in ipairs(registry.Assets) do
		table.insert(sizes, a.CharacteristicSize)
	end
	table.sort(sizes)
	if #sizes == 0 then
		return 4
	end
	return sizes[math.ceil(#sizes / 2)]
end

--[[
	params = {
	  Settings, Analysis, Registry,
	  ExclusionParts, ProtectedParts,
	  SceneExclude : { Instance }  (exclus des requêtes de scène)
	  OnProgress(fraction, text)
	}
	Renvoie le plan : { Items, Diagnostics, HiddenWalls, Facades, Seed, Passes }
]]
function GenerationManager.plan(params)
	local S = params.Settings
	local analysis = params.Analysis
	local registry = params.Registry
	local startTime = os.clock()
	local diagnostics = Diagnostics.new(S.DebugEnabled)
	local progress = params.OnProgress or function() end

	local c = diagnostics.Counters
	c.Surfaces = #analysis.Surfaces
	c.Floors = #analysis.Floors + #analysis.Slopes
	c.Walls = #analysis.Walls
	c.Ceilings = #analysis.Ceilings
	c.Corners = #analysis.Corners
	c.Assets = registry:count()
	for _, w in ipairs(analysis.Warnings) do
		diagnostics:warn(w)
	end

	-- Collision.
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = params.SceneExclude or {}
	local collision = CollisionEngine.new({
		CellSize = medianAssetSize(registry) * Config.Collision.CELL_SIZE_FACTOR,
		Enabled = S.CollisionCheck,
		Precise = S.PreciseCollision,
		MinimumSpacing = S.MinimumSpacing,
		SceneQuery = S.CollideWithScene,
		OverlapParams = overlap,
		World = Workspace,
	})
	for _, part in ipairs(analysis.Parts) do
		collision:addProtectedPart(part)
	end
	for _, part in ipairs(params.ProtectedParts or {}) do
		if Utilities.isAlive(part) then
			collision:addProtectedPart(part)
		end
	end

	-- Zones d'exclusion.
	local zones = ExclusionZones.new(params.ExclusionParts or {})
	for _, s in ipairs(analysis.Surfaces) do
		for _, z in ipairs(zones:forSurface(s)) do
			diagnostics:zone(s, z.Polygon, "Exclusion")
		end
	end

	local yielder = Utilities.createYielder(Config.Performance.YIELD_BUDGET)
	local ctx = PlacementContext.new({
		Settings = S,
		Analysis = analysis,
		Registry = registry,
		Collision = collision,
		Zones = zones,
		Rng = RandomGenerator.new(S.Seed),
		Diagnostics = diagnostics,
		Yield = yielder,
		MaxAssets = math.min(S.MaxAssets, Config.Performance.HARD_MAX_ASSETS),
	})
	ctx.Selector = AssetSelector.new(ctx)
	ctx.HiddenWalls = {}

	local passes = GenerationManager.resolvePasses(S)
	local steps = 0
	local totalSteps = math.max(1, (if passes.Architecture then #analysis.Walls else 0)
		+ (if passes.Corners then 1 else 0)
		+ (if passes.WallProps then #analysis.Walls else 0)
		+ (if passes.Floors then #analysis.Floors + #analysis.Slopes else 0)
		+ (if passes.Ceilings then #analysis.Ceilings else 0))
	local function step(text)
		steps += 1
		progress(math.clamp(steps / totalSteps, 0, 1) * 0.8, text)
		yielder()
	end

	-- 1) Architecture.
	if passes.Architecture then
		for _, wall in ipairs(analysis.Walls) do
			ArchitectureEngine.run(ctx, wall, { Treatment = passes.Treatment, Mode = passes.ArchitectureMode })
			step("Architecture " .. wall.Id)
		end
	end
	-- 2) Coins.
	if passes.Corners and #analysis.Corners > 0 then
		CornerEngine.run(ctx, analysis.Corners)
		step("Corners")
	end
	-- 3) Décor mural (réduit sur les façades déjà décorées).
	if passes.WallProps then
		for _, wall in ipairs(analysis.Walls) do
			local factor = if ctx.Facades[wall] then 0.4 else 1
			local mode = if ctx.Facades[wall] then "Props" else passes.WallPropMode
			WallPlacementEngine.run(ctx, wall, mode, factor)
			step("Wall " .. wall.Id)
		end
	end
	-- 4) Sols et pentes.
	if passes.Floors then
		for _, floor in ipairs(analysis.Floors) do
			FloorPlacementEngine.run(ctx, floor, passes.FloorAlgorithm)
			step("Floor " .. floor.Id)
		end
		for _, slope in ipairs(analysis.Slopes) do
			FloorPlacementEngine.run(ctx, slope, "Scatter")
			step("Slope " .. slope.Id)
		end
	end
	-- 5) Plafonds.
	if passes.Ceilings then
		for _, ceiling in ipairs(analysis.Ceilings) do
			CeilingPlacementEngine.run(ctx, ceiling)
			step("Ceiling " .. ceiling.Id)
		end
	end

	if #ctx.Items >= ctx.MaxAssets then
		diagnostics:warn(string.format("Max assets (%d) reached: increase 'Max assets' for denser results.", ctx.MaxAssets))
	end
	if #ctx.Items == 0 then
		diagnostics:warn("Nothing could be placed. Check the Diagnostics counters (too large assets, exclusion zones, collisions) or lower the minimum spacing.")
	end
	c.PlanningTime = os.clock() - startTime
	return {
		Items = ctx.Items,
		Diagnostics = diagnostics,
		HiddenWalls = ctx.HiddenWalls,
		Facades = ctx.Facades,
		Seed = S.Seed,
		Passes = passes,
		Settings = S,
		Context = ctx,
	}
end

return GenerationManager
