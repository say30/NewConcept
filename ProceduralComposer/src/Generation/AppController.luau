--[[
	AppController
	État de session du plugin et actions déclenchées par l'interface :
	cibles, surcharges de rôle, bibliothèque, zones d'exclusion, géométrie
	protégée, génération, preview, validation, annulation.

	L'interface n'a aucune logique métier : elle appelle ces méthodes et se
	met à jour sur l'événement onChanged.
]]

local HttpService = game:GetService("HttpService")

local Core = script.Parent.Parent.Core
local Analysis = script.Parent.Parent.Analysis

local Config = require(Core.Config)
local Logger = require(Core.Logger)
local Utilities = require(Core.Utilities)
local RandomGenerator = require(Core.RandomGenerator)
local SelectionAnalyzer = require(Analysis.SelectionAnalyzer)
local GeometryAnalyzer = require(Analysis.GeometryAnalyzer)
local AssetRegistry = require(Analysis.AssetRegistry)
local GenerationManager = require(script.Parent.GenerationManager)
local PreviewManager = require(script.Parent.PreviewManager)
local DebugVisualizer = require(script.Parent.DebugVisualizer)
local HistoryManager = require(script.Parent.HistoryManager)
local OutputBuilder = require(script.Parent.OutputBuilder)
local FloorPlacementEngine = require(script.Parent.Parent.Placement.FloorPlacementEngine)
local CollectionService = game:GetService("CollectionService")

local AppController = {}
AppController.__index = AppController

local function userError(message)
	error({ User = message }, 0)
end

local function describeError(err)
	if type(err) == "table" and err.User then
		return err.User, true
	end
	return "Unexpected error: " .. tostring(err), false
end

function AppController.new(plugin, settings)
	local self = setmetatable({}, AppController)
	self.Plugin = plugin
	self.Settings = settings
	self.TargetRoots = {}
	self.Overrides = setmetatable({}, { __mode = "k" })
	self.Analysis = nil
	self.Registry = AssetRegistry.new()
	self.LibraryRoots = {}
	self.LibrarySummary = nil
	self.ExclusionParts = {}
	self.ProtectedParts = {}
	self.Preview = PreviewManager.new()
	self.Debug = DebugVisualizer.new()
	self.LastPlan = nil
	self.Busy = false
	self.Status = { Text = "Select a zone and an asset library to begin.", Level = "Info", Progress = nil }
	self._listeners = {}
	self._connections = {}
	self._unsubscribeHistory = HistoryManager.onUndoRedo(function()
		self:_emit("history")
	end)
	self._unsubscribeLogger = Logger.addSink(function(level, message)
		if level == Logger.Level.Warning or level == Logger.Level.Error then
			self.Status = { Text = message, Level = level, Progress = nil }
			self:_emit("status")
		end
	end)
	return self
end

function AppController:onChanged(callback)
	table.insert(self._listeners, callback)
end

function AppController:_emit(kind)
	for _, cb in ipairs(self._listeners) do
		task.spawn(cb, kind, self)
	end
end

function AppController:setStatus(text, level, progress)
	self.Status = { Text = text, Level = level or "Info", Progress = progress }
	self:_emit("status")
end

-- Cibles ----------------------------------------------------------------------------

function AppController:_aliveList(list)
	local out = {}
	for _, inst in ipairs(list) do
		if Utilities.isAlive(inst) then
			table.insert(out, inst)
		end
	end
	return out
end

function AppController:targetParts()
	self.TargetRoots = self:_aliveList(self.TargetRoots)
	local parts = SelectionAnalyzer.resolveTargets(self.TargetRoots, self.LibraryRoots)
	return parts
end

function AppController:useSelectionAsTargets()
	local selection = SelectionAnalyzer.getSelection()
	local parts, warnings = SelectionAnalyzer.resolveTargets(selection, self.LibraryRoots)
	if #parts == 0 then
		self:setStatus(warnings[1] or "The selection contains no usable part.", "Warning")
		return false
	end
	self.TargetRoots = selection
	self:analyse()
	return true
end

function AppController:_analysisOptions()
	local S = self.Settings.Values
	local protected = table.clone(self:_aliveList(self.ProtectedParts))
	Utilities.appendAll(protected, SelectionAnalyzer.getTaggedParts(Config.Tags.PROTECTED))
	return {
		Overrides = self.Overrides,
		WallSides = S.WallSides,
		ObstacleParts = protected,
		Camera = workspace.CurrentCamera,
	}
end

function AppController:analyse()
	local parts = self:targetParts()
	if #parts == 0 then
		self.Analysis = nil
		self:setStatus("No target: select the geometry to decorate and press 'Use Current Selection'.", "Warning")
		self:_emit("analysis")
		return nil
	end
	local ok, result = pcall(GeometryAnalyzer.analyze, parts, self:_analysisOptions())
	if not ok then
		self:setStatus("Analysis failed: " .. tostring(result), "Error")
		return nil
	end
	self.Analysis = result
	self.Debug:drawAnalysis(result, self.Settings.Values)
	self:setStatus(string.format("Analysis: %d surfaces (%d floor, %d wall, %d ceiling, %d slope), %d corners.",
		#result.Surfaces, #result.Floors, #result.Walls, #result.Ceilings, #result.Slopes, #result.Corners),
		if #result.Surfaces > 0 then "Success" else "Warning")
	self:_emit("analysis")
	return result
end

function AppController:setOverride(part, role)
	role = GeometryAnalyzer.normalizeRole(role)
	if role == "Auto" then
		self.Overrides[part] = nil
	else
		self.Overrides[part] = role
	end
	self:analyse()
end

function AppController:getOverride(part)
	return self.Overrides[part] or "Auto"
end

-- Bibliothèque -------------------------------------------------------------------------

function AppController:useSelectionAsLibrary()
	local selection = SelectionAnalyzer.getSelection()
	local roots, warnings = SelectionAnalyzer.resolveLibraryRoots(selection)
	if #roots == 0 then
		self:setStatus(warnings[1] or "Select a Folder or Model containing assets.", "Warning")
		return false
	end
	self.LibraryRoots = roots
	return self:rescanLibrary()
end

function AppController:rescanLibrary()
	self.LibraryRoots = self:_aliveList(self.LibraryRoots)
	if #self.LibraryRoots == 0 then
		self:setStatus("No asset library selected.", "Warning")
		return false
	end
	if self.Busy then
		return false
	end
	self.Busy = true
	self:_emit("busy")
	local ok, summary = pcall(function()
		return self.Registry:scan(self.LibraryRoots, self.Settings.Values.AutoClassify, function(f, text)
			self:setStatus(text, "Info", f)
		end)
	end)
	self.Busy = false
	if not ok then
		self:setStatus("Library scan failed: " .. tostring(summary), "Error")
		self:_emit("library")
		return false
	end
	self.LibrarySummary = summary
	if summary.Count == 0 then
		self:setStatus(summary.Warnings[1] or "The library is empty.", "Warning")
	else
		self:setStatus(string.format("Library: %d assets in %d categories.", summary.Count, #summary.Categories), "Success")
	end
	self:_emit("library")
	return summary.Count > 0
end

-- Zones -----------------------------------------------------------------------------------

function AppController:useSelectionAsExclusions()
	local parts = SelectionAnalyzer.resolveZoneParts(SelectionAnalyzer.getSelection())
	if #parts == 0 then
		self:setStatus("Select one or more Parts to use as exclusion zones.", "Warning")
		return
	end
	self.ExclusionParts = parts
	self:setStatus(string.format("%d exclusion zone part(s) set.", #parts), "Success")
	self:_emit("zones")
end

function AppController:clearExclusions()
	self.ExclusionParts = {}
	self:_emit("zones")
end

function AppController:useSelectionAsProtected()
	local parts = SelectionAnalyzer.resolveZoneParts(SelectionAnalyzer.getSelection())
	if #parts == 0 then
		self:setStatus("Select one or more Parts to protect.", "Warning")
		return
	end
	self.ProtectedParts = parts
	self:setStatus(string.format("%d protected part(s) set.", #parts), "Success")
	self:_emit("zones")
end

function AppController:clearProtected()
	self.ProtectedParts = {}
	self:_emit("zones")
end

--[[
	Crée une vraie Part de zone d'exclusion au centre de chaque sol analysé
	(bande CenterClearStart..CenterClearEnd sur l'axe transversal). La Part est
	visible, redimensionnable, taguée ProceduralPlacementExclude, rangée dans un
	dossier séparé, et la création est annulable (Ctrl+Z).
]]
function AppController:createCenterExclusionZone()
	local analysis = self.Analysis or self:analyse()
	if not analysis or #analysis.Floors == 0 then
		self:setStatus("Analyse a zone with at least one floor first (Target > Use Current Selection).", "Warning")
		return {}
	end
	local S = self.Settings:snapshot()
	local Z = Config.ExclusionZone
	local created = {}
	local ok, err = HistoryManager.run("ProceduralComposer: Create Exclusion Zone", "Commit", function()
		local folder = workspace:FindFirstChild(Z.FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = Z.FOLDER_NAME
			folder.Parent = workspace
		end
		for _, floor in ipairs(analysis.Floors) do
			for _, r in ipairs(FloorPlacementEngine.centerZoneRects(floor, S)) do
				local zone = Instance.new("Part")
				zone.Name = Z.PART_NAME
				zone.Anchored = true
				zone.CanCollide = false
				zone.CanQuery = false
				zone.CanTouch = false
				zone.CastShadow = false
				zone.Transparency = Z.TRANSPARENCY
				zone.Color = Z.COLOR
				zone.Material = Enum.Material.ForceField
				zone.Size = Vector3.new(r.U1 - r.U0, Z.HEIGHT, r.V1 - r.V0)
				zone.CFrame = floor.Frame * CFrame.new((r.U0 + r.U1) * 0.5, Z.HEIGHT * 0.5, (r.V0 + r.V1) * 0.5)
				zone:SetAttribute("ProceduralExclusionZone", true)
				CollectionService:AddTag(zone, Config.Tags.EXCLUDE)
				zone.Parent = folder
				table.insert(created, zone)
			end
		end
	end)
	if not ok then
		self:setStatus("Could not create the zone: " .. tostring(err), "Error")
		return {}
	end
	if #created > 0 then
		pcall(function()
			game:GetService("Selection"):Set(created)
		end)
		self:setStatus(string.format("%d center exclusion zone(s) created (tag '%s'). Resize them freely; nothing will ever be placed inside.", #created, Config.Tags.EXCLUDE), "Success")
	else
		self:setStatus("The floor is too small for a center zone.", "Warning")
	end
	self:_emit("zones")
	return created
end

function AppController:taggedExclusionCount()
	return #SelectionAnalyzer.getTaggedParts(Config.Tags.EXCLUDE)
end

-- Seed ----------------------------------------------------------------------------------------

function AppController:randomizeSeed()
	self.Settings:set("Seed", RandomGenerator.randomSeed())
end

-- Génération ------------------------------------------------------------------------------------

function AppController:_sceneExclude()
	local list = {}
	local preview = self.Preview:getPreview()
	if preview then
		table.insert(list, preview)
	end
	if not self.Settings.Values.AvoidPreviousGenerations then
		local root = OutputBuilder.getRoot(false)
		if root then
			table.insert(list, root)
		end
	end
	Utilities.appendAll(list, self:_aliveList(self.LibraryRoots))
	Utilities.appendAll(list, self:_aliveList(self.ExclusionParts))
	Utilities.appendAll(list, self:_aliveList(self.ProtectedParts))
	if self.Analysis then
		Utilities.appendAll(list, self.Analysis.Parts)
	end
	return list
end

function AppController:generatePreview()
	if self.Busy then
		return
	end
	self.Busy = true
	self:_emit("busy")
	local startTime = os.clock()
	local ok, err = pcall(function()
		local parts = self:targetParts()
		if #parts == 0 then
			userError("No target geometry. Select the zone (Parts, Models, Folders) and press 'Use Current Selection'.")
		end
		self.Registry:validate()
		if self.Registry:count() == 0 then
			if #self:_aliveList(self.LibraryRoots) > 0 then
				self.Busy = false
				self:rescanLibrary()
				self.Busy = true
			end
			if self.Registry:count() == 0 then
				userError("No asset library. Select a Folder of assets and press 'Use Current Selection as Library'.")
			end
		end
		self.Registry:finalizeRoles(self.Settings.Values.AutoClassify)
		local S = self.Settings:snapshot()
		self:setStatus("Analysing geometry...", "Info", 0.02)
		local analysis = GeometryAnalyzer.analyze(parts, self:_analysisOptions())
		self.Analysis = analysis
		self:_emit("analysis")
		if #analysis.Surfaces == 0 then
			userError("No usable surface was found in the target. Force a role in the Target Surfaces list.")
		end
		local exclusions = self:_aliveList(self.ExclusionParts)
		Utilities.appendAll(exclusions, SelectionAnalyzer.getTaggedParts(Config.Tags.EXCLUDE))
		local protected = self:_aliveList(self.ProtectedParts)
		Utilities.appendAll(protected, SelectionAnalyzer.getTaggedParts(Config.Tags.PROTECTED))

		local plan = GenerationManager.plan({
			Settings = S,
			Analysis = analysis,
			Registry = self.Registry,
			ExclusionParts = exclusions,
			ProtectedParts = protected,
			SceneExclude = self:_sceneExclude(),
			OnProgress = function(f, text)
				self:setStatus(text, "Info", f)
			end,
		})
		self:setStatus(string.format("Building %d objects...", #plan.Items), "Info", 0.82)
		local buildStart = os.clock()
		local settingsJson = nil
		pcall(function()
			settingsJson = HttpService:JSONEncode(S)
		end)
		local shown, message, created, errors = self.Preview:showPlan(plan, {
			Seed = S.Seed,
			SettingsJson = settingsJson,
			AnchorClones = S.AnchorClones,
			StripScripts = S.StripScripts,
			OnProgress = function(f, text)
				self:setStatus(text, "Info", 0.82 + 0.18 * f)
			end,
		})
		if not shown then
			userError("Could not create the preview: " .. tostring(message))
		end
		local counters = plan.Diagnostics.Counters
		counters.InstantiationTime = os.clock() - buildStart
		counters.GenerationTime = os.clock() - startTime
		for _, e in ipairs(errors) do
			plan.Diagnostics:warn(e)
		end
		self.LastPlan = plan
		self.Debug:drawPlan(plan, analysis, S)
		self:setStatus(string.format("Preview ready: %d assets placed (seed %d). Accept, Regenerate or Cancel.", created, S.Seed), "Success")
		Logger.verbose(string.format("Generation done in %.2fs: %d items, %d rejected attempts.", counters.GenerationTime, created, counters.Rejected))
	end)
	self.Busy = false
	if not ok then
		local message, isUser = describeError(err)
		self:setStatus(message, if isUser then "Warning" else "Error")
		if not isUser then
			Logger.error(message)
		end
	end
	self:_emit("generated")
end

function AppController:regenerate()
	if self.Busy then
		return
	end
	if self.Settings.Values.NewSeedOnRegenerate then
		self:randomizeSeed()
	end
	self:generatePreview()
end

function AppController:accept()
	if self.Busy then
		return
	end
	local ok, result = self.Preview:accept()
	if ok then
		self.Debug:clear()
		self:setStatus("Generation accepted as " .. tostring(result) .. ". Ctrl+Z undoes it in one step.", "Success")
	else
		self:setStatus(tostring(result), "Warning")
	end
	self:_emit("accepted")
end

function AppController:cancel()
	if self.Busy then
		return
	end
	local ok, err = self.Preview:cancel()
	self.Debug:clear()
	if ok then
		self.LastPlan = nil
		self:setStatus("Preview cancelled and removed.", "Info")
	else
		self:setStatus(tostring(err), "Warning")
	end
	self:_emit("cancelled")
end

function AppController:clearGenerated()
	if self.Busy then
		return
	end
	local ok, result = self.Preview:clearGenerated()
	self.Debug:clear()
	if ok then
		self.LastPlan = nil
		self:setStatus(string.format("Cleared %d generated folder(s). Original walls restored. Ctrl+Z to undo.", result), "Success")
	else
		self:setStatus(tostring(result), "Warning")
	end
	self:_emit("cleared")
end

function AppController:redrawDebug()
	if self.LastPlan and self.Analysis then
		self.Debug:drawPlan(self.LastPlan, self.Analysis, self.Settings.Values)
	elseif self.Analysis then
		self.Debug:drawAnalysis(self.Analysis, self.Settings.Values)
	else
		self.Debug:clear()
	end
end

function AppController:clearDebug()
	self.Debug:clear()
end

function AppController:hasPreview()
	return self.Preview:hasPreview()
end

function AppController:generationCount()
	return #self.Preview:getGenerations()
end

function AppController:destroy()
	if self._unsubscribeHistory then
		self._unsubscribeHistory()
	end
	if self._unsubscribeLogger then
		self._unsubscribeLogger()
	end
	self.Debug:clear()
	self._listeners = {}
end

return AppController
