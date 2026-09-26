--[[
	Settings
	Schéma unique de tous les paramètres réglables : type, bornes, valeur par
	défaut, libellé et section d'interface. L'UI est générée à partir de ce
	schéma, la validation aussi, et la persistance passe par
	plugin:SetSetting / plugin:GetSetting.
]]

local Config = require(script.Parent.Config)
local Utilities = require(script.Parent.Utilities)
local Presets = require(script.Parent.Presets)

local Settings = {}
Settings.__index = Settings

local ROTATION_MODES = {
	"Fixed", "Random90", "Random180", "Random360",
	"AlignToSurface", "AlignToWall", "FaceCenter", "FaceAway", "FollowPath",
}

-- Schéma ordonné. Type : "number" | "int" | "bool" | "enum".
Settings.Schema = {
	-- PLACEMENT MODE
	{ Key = "PlacementMode", Type = "enum", Default = "Auto", Options = { "Auto", "Floor", "Wall", "Architecture", "Hybrid" }, Section = "Placement", Label = "Placement mode",
		Tooltip = "Auto: le moteur décide tout. Floor/Wall: uniquement ces surfaces. Architecture: façades murales + coins. Hybrid: tout, avec vos algorithmes choisis." },
	{ Key = "AutoClassify", Type = "bool", Default = true, Section = "Placement", Label = "Auto-classify assets",
		Tooltip = "Déduit le rôle des assets sans métadonnées à partir de leur forme." },

	-- COMPOSITION
	{ Key = "Density", Type = "number", Default = 0.5, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Density" },
	{ Key = "SpacingScale", Type = "number", Default = 1, Min = 0.25, Max = 3, Step = 0.05, Section = "Composition", Label = "Spacing" },
	{ Key = "ClusterStrength", Type = "number", Default = 0.6, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Cluster strength" },
	{ Key = "EmptySpaceRatio", Type = "number", Default = 0.35, Min = 0, Max = 0.9, Step = 0.01, Section = "Composition", Label = "Empty space" },
	{ Key = "LargeAssetFrequency", Type = "number", Default = 0.5, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Large asset frequency" },
	{ Key = "MediumAssetFrequency", Type = "number", Default = 0.6, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Medium asset frequency" },
	{ Key = "SmallAssetFrequency", Type = "number", Default = 0.7, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Small asset frequency" },
	{ Key = "Symmetry", Type = "number", Default = 0, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Symmetry" },
	{ Key = "Randomness", Type = "number", Default = 0.45, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Randomness" },
	{ Key = "Variation", Type = "number", Default = 0.6, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Variation" },
	{ Key = "VisualRhythm", Type = "number", Default = 0.5, Min = 0, Max = 1, Step = 0.01, Section = "Composition", Label = "Visual rhythm" },

	-- TRANSFORM
	{ Key = "RotationMode", Type = "enum", Default = "Random360", Options = ROTATION_MODES, Section = "Transform", Label = "Rotation" },
	{ Key = "ScaleMode", Type = "enum", Default = "Preserve", Options = { "Preserve", "Fixed", "RandomRange" }, Section = "Transform", Label = "Scale" },
	{ Key = "FixedScale", Type = "number", Default = 1, Min = 0.1, Max = 10, Step = 0.05, Section = "Transform", Label = "Fixed scale" },
	{ Key = "MinScale", Type = "number", Default = 0.85, Min = 0.1, Max = 10, Step = 0.05, Section = "Transform", Label = "Min scale" },
	{ Key = "MaxScale", Type = "number", Default = 1.15, Min = 0.1, Max = 10, Step = 0.05, Section = "Transform", Label = "Max scale" },
	{ Key = "SurfaceOffset", Type = "number", Default = 0, Min = -5, Max = 5, Step = 0.01, Section = "Transform", Label = "Surface offset" },
	{ Key = "SurfaceEpsilon", Type = "number", Default = Config.Precision.DEFAULT_SURFACE_EPSILON, Min = Config.Precision.MIN_SURFACE_EPSILON, Max = Config.Precision.MAX_SURFACE_EPSILON, Step = 0.001, Section = "Transform", Label = "Surface epsilon",
		Tooltip = "SURFACE_EPSILON : décalage anti z-fighting appliqué aux décorations murales et aux superpositions." },
	{ Key = "AlignToSlopes", Type = "bool", Default = false, Section = "Transform", Label = "Align to slopes",
		Tooltip = "Incliner les assets selon la pente (sinon ils restent verticaux et sont légèrement enfoncés)." },

	-- WALL OPTIONS
	{ Key = "WallTreatment", Type = "enum", Default = "Keep", Options = { "Keep", "Cover", "Rebuild" }, Section = "Wall", Label = "Wall treatment",
		Tooltip = "Keep: décorations seulement. Cover: façade décorative devant le mur. Rebuild: structure architecturale complète." },
	{ Key = "WallMode", Type = "enum", Default = "Hybrid", Options = { "Hybrid", "Props", "Relief", "Modular", "Architectural" }, Section = "Wall", Label = "Wall mode" },
	{ Key = "WallDensity", Type = "number", Default = 0.5, Min = 0, Max = 1, Step = 0.01, Section = "Wall", Label = "Wall density" },
	{ Key = "PillarSpacing", Type = "number", Default = 16, Min = 2, Max = 200, Step = 0.5, Section = "Wall", Label = "Pillar spacing" },
	{ Key = "TopDecoration", Type = "bool", Default = true, Section = "Wall", Label = "Top decoration" },
	{ Key = "BaseDecoration", Type = "bool", Default = true, Section = "Wall", Label = "Base decoration" },
	{ Key = "CornerDecoration", Type = "bool", Default = true, Section = "Wall", Label = "Corner decoration" },
	{ Key = "HideOriginalWalls", Type = "bool", Default = false, Section = "Wall", Label = "Hide original walls (Rebuild)",
		Tooltip = "En mode Rebuild, rend les murs d'origine invisibles (Transparency). Réversible : Cancel, Clear Generated et Ctrl+Z restaurent." },
	{ Key = "AllowModuleScaling", Type = "bool", Default = true, Section = "Wall", Label = "Allow module scaling" },
	{ Key = "MaxModuleScaleDeviation", Type = "number", Default = Config.Fitting.DEFAULT_MAX_SCALE_DEVIATION, Min = 0, Max = 0.3, Step = 0.005, Section = "Wall", Label = "Max module deformation" },
	{ Key = "WallSides", Type = "enum", Default = "Auto", Options = { "Auto", "Both" }, Section = "Wall", Label = "Wall sides",
		Tooltip = "Auto: face tournée vers le sol (ou la caméra). Both: les deux faces." },

	-- FLOOR OPTIONS
	{ Key = "FloorAlgorithm", Type = "enum", Default = "Hybrid", Options = { "Hybrid", "EdgeDecoration", "Scatter", "Cluster", "Grid", "Border", "HeroComposition" }, Section = "Floor", Label = "Floor algorithm" },
	{ Key = "KeepCenterClear", Type = "bool", Default = false, Section = "Floor", Label = "Keep center clear" },
	{ Key = "CenterClearStart", Type = "number", Default = 0.2, Min = 0, Max = 1, Step = 0.01, Section = "Floor", Label = "Clear zone start" },
	{ Key = "CenterClearEnd", Type = "number", Default = 0.8, Min = 0, Max = 1, Step = 0.01, Section = "Floor", Label = "Clear zone end" },
	{ Key = "CenterClearAxis", Type = "enum", Default = "Auto", Options = { "Auto", "Width", "Length", "Both" }, Section = "Floor", Label = "Clear zone axis" },
	{ Key = "EdgeMargin", Type = "number", Default = 0.25, Min = 0, Max = 50, Step = 0.05, Section = "Floor", Label = "Left/Right margin" },
	{ Key = "EdgeDepth", Type = "number", Default = 8, Min = 0, Max = 200, Step = 0.5, Section = "Floor", Label = "Edge depth" },
	{ Key = "PathWidth", Type = "number", Default = 0, Min = 0, Max = 200, Step = 0.5, Section = "Floor", Label = "Path width" },
	{ Key = "AllowWallContact", Type = "bool", Default = true, Section = "Floor", Label = "Allow wall contact" },

	-- CEILING
	{ Key = "CeilingDecoration", Type = "bool", Default = true, Section = "Ceiling", Label = "Ceiling decoration" },
	{ Key = "CeilingDensity", Type = "number", Default = 0.4, Min = 0, Max = 1, Step = 0.01, Section = "Ceiling", Label = "Ceiling density" },

	-- COLLISION
	{ Key = "CollisionCheck", Type = "bool", Default = true, Section = "Collision", Label = "Collision check" },
	{ Key = "MinimumSpacing", Type = "number", Default = 0.5, Min = 0, Max = 20, Step = 0.05, Section = "Collision", Label = "Minimum spacing" },
	{ Key = "PreciseCollision", Type = "bool", Default = true, Section = "Collision", Label = "Precise (per-part) collision" },
	{ Key = "CollideWithScene", Type = "bool", Default = true, Section = "Collision", Label = "Collide with scene geometry" },
	{ Key = "AvoidPreviousGenerations", Type = "bool", Default = true, Section = "Collision", Label = "Avoid previous generations" },

	-- RANDOM
	{ Key = "Seed", Type = "int", Default = 12345, Min = 0, Max = 2147483646, Section = "Random", Label = "Seed" },
	{ Key = "NewSeedOnRegenerate", Type = "bool", Default = true, Section = "Random", Label = "New seed on Regenerate" },

	-- PERFORMANCE / OUTPUT
	{ Key = "MaxAssets", Type = "int", Default = 600, Min = 1, Max = Config.Performance.HARD_MAX_ASSETS, Section = "Output", Label = "Max assets" },
	{ Key = "CandidatesPerPlacement", Type = "int", Default = Config.Composition.DEFAULT_CANDIDATES, Min = 4, Max = 64, Section = "Output", Label = "Candidates per placement" },
	{ Key = "AnchorClones", Type = "bool", Default = true, Section = "Output", Label = "Anchor generated parts" },
	{ Key = "StripScripts", Type = "bool", Default = false, Section = "Output", Label = "Strip scripts from clones" },

	-- DEBUG
	{ Key = "DebugEnabled", Type = "bool", Default = false, Section = "Debug", Label = "Debug visualization" },
	{ Key = "DebugBounds", Type = "bool", Default = true, Section = "Debug", Label = "Bounding boxes" },
	{ Key = "DebugNormals", Type = "bool", Default = true, Section = "Debug", Label = "Surface normals" },
	{ Key = "DebugZones", Type = "bool", Default = true, Section = "Debug", Label = "Forbidden / clear zones" },
	{ Key = "DebugCandidates", Type = "bool", Default = false, Section = "Debug", Label = "Candidate points" },
	{ Key = "DebugRejected", Type = "bool", Default = false, Section = "Debug", Label = "Rejected points" },
	{ Key = "DebugSnaps", Type = "bool", Default = true, Section = "Debug", Label = "Snap points" },
	{ Key = "DebugSegments", Type = "bool", Default = true, Section = "Debug", Label = "Wall segmentation" },

	-- Dernier preset appliqué (affichage).
	{ Key = "Preset", Type = "enum", Default = "Balanced", Options = Presets.Order, Section = "Hidden", Label = "Preset" },
}

Settings.ByKey = {}
for _, entry in ipairs(Settings.Schema) do
	Settings.ByKey[entry.Key] = entry
end

-- Valide et normalise une valeur ; renvoie (valeur, ok).
function Settings.validate(key, value)
	local entry = Settings.ByKey[key]
	if not entry then
		return nil, false
	end
	if entry.Type == "bool" then
		if type(value) ~= "boolean" then
			return entry.Default, false
		end
		return value, true
	elseif entry.Type == "number" or entry.Type == "int" then
		local n = tonumber(value)
		if not n or not Utilities.isFiniteNumber(n) then
			return entry.Default, false
		end
		if entry.Type == "int" then
			n = math.floor(n + 0.5)
		end
		if entry.Min then
			n = math.max(entry.Min, n)
		end
		if entry.Max then
			n = math.min(entry.Max, n)
		end
		return n, true
	elseif entry.Type == "enum" then
		if type(value) == "string" and table.find(entry.Options, value) then
			return value, true
		end
		return entry.Default, false
	end
	return entry.Default, false
end

function Settings.defaults()
	local values = {}
	for _, entry in ipairs(Settings.Schema) do
		values[entry.Key] = entry.Default
	end
	return values
end

function Settings.new(plugin)
	local self = setmetatable({}, Settings)
	self._plugin = plugin
	self.Values = Settings.defaults()
	self._listeners = {}
	self._saveScheduled = false
	return self
end

function Settings:get(key)
	return self.Values[key]
end

function Settings:onChanged(callback)
	table.insert(self._listeners, callback)
	return function()
		local i = table.find(self._listeners, callback)
		if i then
			table.remove(self._listeners, i)
		end
	end
end

function Settings:_notify(key, value)
	for _, cb in ipairs(self._listeners) do
		task.spawn(cb, key, value)
	end
end

function Settings:set(key, value, silent)
	local normalized, _ = Settings.validate(key, value)
	if normalized == nil then
		return
	end
	if self.Values[key] == normalized then
		return
	end
	self.Values[key] = normalized
	if not silent then
		self:_notify(key, normalized)
	end
	self:scheduleSave()
end

function Settings:applyPreset(name)
	local preset = Presets.Values[name]
	if not preset then
		return false
	end
	-- Un preset part toujours des valeurs par défaut de la composition pour être reproductible.
	for _, key in ipairs(Presets.ResetKeys) do
		self:set(key, Settings.ByKey[key].Default)
	end
	for key, value in pairs(preset) do
		self:set(key, value)
	end
	self:set("Preset", name)
	return true
end

function Settings:resetDefaults()
	for _, entry in ipairs(Settings.Schema) do
		if entry.Key ~= "Seed" then
			self:set(entry.Key, entry.Default)
		end
	end
end

-- Copie figée utilisée par une génération (les changements pendant la génération n'ont pas d'effet).
function Settings:snapshot()
	local snap = table.clone(self.Values)
	-- Cohérence des bornes couplées.
	if snap.MinScale > snap.MaxScale then
		snap.MinScale, snap.MaxScale = snap.MaxScale, snap.MinScale
	end
	if snap.CenterClearStart > snap.CenterClearEnd then
		snap.CenterClearStart, snap.CenterClearEnd = snap.CenterClearEnd, snap.CenterClearStart
	end
	return snap
end

function Settings:load()
	if not self._plugin then
		return
	end
	local ok, stored = pcall(function()
		return self._plugin:GetSetting(Config.SETTINGS_KEY)
	end)
	if ok and type(stored) == "table" then
		for key, value in pairs(stored) do
			if Settings.ByKey[key] then
				local normalized = Settings.validate(key, value)
				if normalized ~= nil then
					self.Values[key] = normalized
				end
			end
		end
	end
end

function Settings:save()
	if not self._plugin then
		return
	end
	local ok, err = pcall(function()
		self._plugin:SetSetting(Config.SETTINGS_KEY, self.Values)
	end)
	if not ok then
		warn("[" .. Config.PLUGIN_DISPLAY_NAME .. "] Unable to save settings: " .. tostring(err))
	end
end

function Settings:scheduleSave()
	if self._saveScheduled then
		return
	end
	self._saveScheduled = true
	task.delay(Config.UI.SETTINGS_SAVE_DELAY, function()
		self._saveScheduled = false
		self:save()
	end)
end

return Settings
