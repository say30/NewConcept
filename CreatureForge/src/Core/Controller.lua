-- Controller : orchestre toutes les actions du plugin et tient l'état affiché par l'UI.
-- Chaque action lourde = un enregistrement ChangeHistoryService (Ctrl+Z annule tout).

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Root = script.Parent.Parent
local Config = require(Root.Config)
local Util = require(Root.Core.Util)
local CreatureAnalyzer = require(Root.Analysis.CreatureAnalyzer)
local RigAnalyzer = require(Root.Analysis.RigAnalyzer)
local CreatureGenerator = require(Root.Generation.CreatureGenerator)
local Rebuilder = require(Root.Generation.Rebuilder)
local PaletteGenerator = require(Root.Generation.PaletteGenerator)
local RigBuilder = require(Root.Rigging.RigBuilder)
local MaterialManager = require(Root.Materials.MaterialManager)
local AssetPublisher = require(Root.Publishing.AssetPublisher)
local EditableMeshFactory = require(Root.Geometry.EditableMeshFactory)
local BlueprintBuilder = require(Root.Study.BlueprintBuilder)
local ExplodedView = require(Root.Study.ExplodedView)
local RigVisualizer = require(Root.Study.RigVisualizer)

local Controller = {}
Controller.__index = Controller

local A = Config.ATTR
local SETTINGS_KEY = "CreatureForge_Settings"
local STATUS_ORDER = { "analysis", "blueprint", "create", "meshes", "rig", "colors", "material", "publish", "error" }

local function alive(inst: Instance?)
	return inst ~= nil and inst.Parent ~= nil
end

function Controller.new(plugin)
	local self = setmetatable({}, Controller)
	self.plugin = plugin
	self.listeners = {}
	self.paletteBindings = {}
	self.state = {
		selection = nil,
		selectionKind = "none",
		report = nil,
		reportStale = false,
		details = "",
		blueprint = nil,
		blueprintMap = nil,
		explode = 0,
		generated = nil,
		busy = false,
		busyText = "",
		status = {},
		publish = nil,
		lastSeed = nil,
		settings = { variation = 2, material = "Studs", variant = Config.DEFAULT_VARIANT, seed = "" },
	}
	local ok, saved = pcall(function()
		return plugin:GetSetting(SETTINGS_KEY)
	end)
	if ok and type(saved) == "table" then
		for k, v in saved do
			if self.state.settings[k] ~= nil then
				self.state.settings[k] = v
			end
		end
	end
	AssetPublisher.init(plugin)
	return self
end

----------------------------------------------------------------------
-- État / événements
----------------------------------------------------------------------

function Controller:onChanged(fn)
	table.insert(self.listeners, fn)
end

function Controller:emit()
	for _, fn in self.listeners do
		local ok, err = pcall(fn, self.state)
		if not ok then
			warn("[Creature Forge] UI : " .. tostring(err))
		end
	end
end

function Controller:setStatus(key: string, ok: boolean?, text: string?)
	self.state.status[key] = if text then { ok = ok, text = text } else nil
end

function Controller:statusLines()
	local lines = {}
	for _, key in STATUS_ORDER do
		local s = self.state.status[key]
		if s then
			table.insert(lines, s)
		end
	end
	return lines
end

function Controller:saveSettings()
	pcall(function()
		self.plugin:SetSetting(SETTINGS_KEY, self.state.settings)
	end)
end

function Controller:setSetting(key: string, value)
	self.state.settings[key] = value
	self:saveSettings()
	self:emit()
end

-- Exécute une action en tâche de fond (UI réactive, erreurs affichées proprement).
function Controller:run(label: string, fn)
	local st = self.state
	if st.busy then
		return
	end
	st.busy = true
	st.busyText = label
	self:setStatus("error", nil, nil)
	self:emit()
	task.spawn(function()
		local ok, err = xpcall(fn, debug.traceback)
		st.busy = false
		st.busyText = ""
		if not ok then
			self:setStatus("error", false, Util.shortError(err))
			warn("[Creature Forge] " .. tostring(err))
		end
		self:emit()
	end)
end

function Controller:progress(text: string)
	self.state.busyText = text
	self:emit()
end

----------------------------------------------------------------------
-- Sélection
----------------------------------------------------------------------

function Controller:setSelection(list)
	local st = self.state
	local inst = list[1]
	local model = Util.resolveCreature(inst)
	st.selection = model
	if model == nil then
		st.selectionKind = "none"
	elseif Util.isGenerated(model) then
		st.selectionKind = "generated"
		st.generated = model
		self:bindPalette(model)
		self:restoreIfNeeded(model)
	elseif Util.isBlueprint(model) then
		st.selectionKind = "blueprint"
		st.blueprint = model
	elseif Util.isInOutput(model) then
		st.selectionKind = "none"
	else
		st.selectionKind = "reference"
		st.reportStale = st.report ~= nil and st.report.model ~= model
	end
	self:emit()
end

-- Référence courante : la sélection, sinon la dernière créature analysée.
function Controller:currentReference()
	local st = self.state
	if st.selectionKind == "reference" and alive(st.selection) then
		return st.selection
	end
	if st.report and alive(st.report.model) then
		return st.report.model
	end
	return nil
end

function Controller:currentGenerated()
	local g = self.state.generated
	if alive(g) and Util.isGenerated(g) then
		return g
	end
	return nil
end

----------------------------------------------------------------------
-- Analyse / étude
----------------------------------------------------------------------

local function findBlueprint(name: string)
	local folder = Util.getOutputFolder(false)
	if not folder then
		return nil
	end
	for _, d in folder:GetChildren() do
		if Util.isBlueprint(d) and d:GetAttribute(A .. "Source") == name then
			return d
		end
	end
	return nil
end

function Controller:ensureReport()
	local st = self.state
	local ref = self:currentReference()
	if not ref then
		error("Sélectionnez d'abord une créature dans Workspace", 0)
	end
	if not st.report or st.report.model ~= ref or st.reportStale then
		st.report = CreatureAnalyzer.analyze(ref)
		st.details = CreatureAnalyzer.details(st.report)
		st.reportStale = false
		st.blueprint = findBlueprint(ref.Name)
		st.blueprintMap = nil
		st.explode = if st.blueprint then (st.blueprint:GetAttribute(A .. "Explode") or 0) else 0
		self:setStatus("analysis", true, "Analyse : " .. st.report.morphology)
	end
	return st.report
end

function Controller:analyze()
	self:run("Analyse…", function()
		self.state.reportStale = true
		self:ensureReport()
	end)
end

function Controller:ensureBlueprint()
	local st = self.state
	local report = self:ensureReport()
	if alive(st.blueprint) then
		if not st.blueprintMap then
			st.blueprintMap = BlueprintBuilder.rebuildMap(report, st.blueprint)
		end
		return st.blueprint
	end
	Util.record("Blueprint", function()
		st.blueprint, st.blueprintMap = BlueprintBuilder.build(report, Util.getOutputFolder(true))
	end)
	st.explode = 0
	self:setStatus("blueprint", true, "Blueprint créé (" .. #report.parts .. " pièces)")
	return st.blueprint
end

function Controller:blueprint()
	self:run("Blueprint…", function()
		local st = self.state
		if alive(st.blueprint) then
			Util.record("Recréer blueprint", function()
				st.blueprint:Destroy()
			end)
			st.blueprint = nil
		end
		self:ensureBlueprint()
	end)
end

-- Vue éclatée : bouton = bascule 0 % <-> 60 %.
function Controller:toggleExplode()
	self:run("Vue éclatée…", function()
		local st = self.state
		local bp = self:ensureBlueprint()
		local target = if st.explode > 0.01 then 0 else 0.6
		Util.record("Vue éclatée", function()
			ExplodedView.apply(bp, target)
		end)
		st.explode = target
	end)
end

-- Slider : phase "begin" | "move" | "end".
function Controller:setExplode(t: number, phase: string)
	local st = self.state
	local bp = st.blueprint
	if st.busy or not alive(bp) then
		return
	end
	if phase == "begin" then
		local ok, id = pcall(function()
			return ChangeHistoryService:TryBeginRecording("CreatureForge_Explode", "Vue éclatée")
		end)
		self.explodeRecording = if ok then id else nil
	end
	ExplodedView.apply(bp, t)
	st.explode = t
	if phase == "end" then
		if self.explodeRecording then
			pcall(function()
				ChangeHistoryService:FinishRecording(self.explodeRecording, Enum.FinishRecordingOperation.Commit)
			end)
			self.explodeRecording = nil
		end
		self:emit()
	end
end

-- Données de rig d'une créature générée (ses propres joints).
local function rigDataOfModel(model: Model)
	local rig = RigAnalyzer.analyze(model)
	local data = { joints = {}, bones = {}, attachments = {} }
	for _, j in rig.joints do
		if j.part0 and j.part1 then
			table.insert(data.joints, j)
		end
	end
	return data
end

-- Données de rig de la source, transposées sur le blueprint.
function Controller:rigDataOfBlueprint()
	local st = self.state
	local report, map = st.report, st.blueprintMap
	local data = { joints = {}, bones = {}, attachments = {} }
	for _, j in report.rig.joints do
		local p0, p1 = map[j.part0], map[j.part1]
		if p0 and p1 then
			local c0, c1 = j.c0, j.c1
			if not c0 then
				c0 = j.part0.CFrame:ToObjectSpace(CFrame.new(j.part1.Position))
				c1 = CFrame.new()
			end
			table.insert(data.joints, { part0 = p0, part1 = p1, c0 = c0, c1 = c1, kind = j.kind, name = j.name })
		end
	end
	local index = {}
	for i, b in report.rig.bones do
		index[b.inst] = i
	end
	for i, b in report.rig.bones do
		local part = b.part and map[b.part]
		if part and b.worldCFrame then
			data.bones[i] = {
				part = part,
				cframe = b.part.CFrame:ToObjectSpace(b.worldCFrame),
				parent = b.parentBone and index[b.parentBone],
				name = b.name,
			}
		end
	end
	for _, a in report.rig.attachments do
		local part = map[a.part]
		if part then
			table.insert(data.attachments, { part = part, cframe = a.cframe })
		end
	end
	return data
end

function Controller:toggleRig()
	self:run("Rig…", function()
		local st = self.state
		local target, data
		if st.selectionKind == "generated" and self:currentGenerated() then
			target = self:currentGenerated()
		else
			target = self:ensureBlueprint()
		end
		if RigVisualizer.isShown(target) then
			Util.record("Masquer rig", function()
				RigVisualizer.clear(target)
			end)
			self:setStatus("blueprint", nil, "Rig masqué")
			return
		end
		data = if Util.isGenerated(target) then rigDataOfModel(target) else self:rigDataOfBlueprint()
		local counts
		Util.record("Afficher rig", function()
			counts = RigVisualizer.show(target, data)
		end)
		self:setStatus(
			"blueprint",
			true,
			string.format("Rig affiché : %d joints · %d bones · %d attachments", counts.joints, counts.bones, counts.attachments)
		)
	end)
end

function Controller:isRigShown()
	local st = self.state
	local target = if st.selectionKind == "generated" then self:currentGenerated() else st.blueprint
	return alive(target) and RigVisualizer.isShown(target)
end

----------------------------------------------------------------------
-- Ma version
----------------------------------------------------------------------

local function countGeneratedFrom(refName: string)
	local folder = Util.getOutputFolder(false)
	local n = 0
	if folder then
		for _, d in folder:GetChildren() do
			if Util.isGenerated(d) and d:GetAttribute(A .. "Reference") == refName then
				n += 1
			end
		end
	end
	return n
end

function Controller:createCreature()
	self:run("Génération…", function()
		local st = self.state
		local report = self:ensureReport()
		local seed = tonumber(st.settings.seed)
		if not seed then
			seed = Random.new():NextInteger(1, 999999)
		end
		seed = math.floor(seed)
		st.lastSeed = seed

		for _, key in { "create", "meshes", "rig", "colors", "material", "publish" } do
			self:setStatus(key, nil, nil)
		end
		st.publish = nil

		local ext = math.max(report.boundingSize.X, report.boundingSize.Z)
		local index = countGeneratedFrom(report.name) + 1
		local place = report.frame + Vector3.new(-(ext + Config.LAYOUT_GAP) * index, 0, 0)

		local model, info, rig, mat
		Util.record("Créer ma créature", function()
			model, info = CreatureGenerator.build({
				traits = report.traits,
				level = st.settings.variation,
				seed = seed,
				parent = Util.getOutputFolder(true),
				placeCFrame = place,
				referenceName = report.name,
				onProgress = function(i, n)
					self:progress(string.format("Génération des meshes… %d / %d", i, n))
				end,
			})
			rig = RigBuilder.build(model)
			mat = MaterialManager.apply(model, st.settings.material, st.settings.variant)
		end)

		st.generated = model
		self:bindPalette(model)
		self:setStatus("create", true, string.format("Créature créée : %s (seed %d)", info.name, seed))
		self:setStatus("meshes", true, string.format("%d meshes · %d pièces · %d triangles", info.meshes, info.parts, info.triangles))
		self:setStatus("rig", true, string.format("Rig créé : %d Motor6D · %d welds", rig.motors, rig.welds))
		self:reportMaterial(mat)
		self:setStatus("publish", nil, "Meshes non publiés (temporaires) → PUBLIER")
		Selection:Set({ model })
	end)
end

-- Reconstruction fidèle : mêmes pièces, positions, tailles, couleurs et rig que la référence,
-- avec des meshes 100 % générés (publiables sur votre compte).
function Controller:rebuildFaithful()
	self:run("Reconstruction…", function()
		local st = self.state
		local report = self:ensureReport()
		for _, key in { "create", "meshes", "rig", "colors", "material", "publish" } do
			self:setStatus(key, nil, nil)
		end
		st.publish = nil

		local ext = math.max(report.boundingSize.X, report.boundingSize.Z)
		local index = countGeneratedFrom(report.name) + 1
		local place = report.frame + Vector3.new(-(ext + Config.LAYOUT_GAP) * index, 0, 0)

		local model, info, rig, mat
		Util.record("Reconstruire fidèle", function()
			local plan = Rebuilder.plan(report)
			model, info = CreatureGenerator.build({
				plan = plan,
				traits = report.traits,
				level = 0,
				seed = 0,
				parent = Util.getOutputFolder(true),
				placeCFrame = place,
				referenceName = report.name,
				onProgress = function(i, n)
					self:progress(string.format("Reconstruction des meshes… %d / %d", i, n))
				end,
			})
			rig = RigBuilder.build(model)
			mat = MaterialManager.apply(model, st.settings.material, st.settings.variant)
		end)

		st.generated = model
		self:bindPalette(model)
		self:setStatus("create", true, "Reconstruction fidèle : " .. info.name)
		self:setStatus("meshes", true, string.format("%d meshes · %d pièces · %d triangles", info.meshes, info.parts, info.triangles))
		self:setStatus("rig", true, string.format("Rig d'origine repris : %d Motor6D · %d welds", rig.motors, rig.welds))
		self:reportMaterial(mat)
		self:setStatus("publish", nil, "Meshes non publiés (temporaires) → PUBLIER")
		Selection:Set({ model })
	end)
end

-- Fantôme : superpose l'original (vraie forme) au blueprint, en transparence.
function Controller:toggleGhost()
	self:run("Fantôme…", function()
		local st = self.state
		local bp = self:ensureBlueprint()
		local shown
		Util.record("Fantôme", function()
			shown = BlueprintBuilder.toggleGhost(st.report, bp)
		end)
		self:setStatus("blueprint", nil, if shown then "Fantôme affiché (forme réelle, étude uniquement)" else "Fantôme masqué")
	end)
end

function Controller:isGhostShown()
	local bp = self.state.blueprint
	return alive(bp) and BlueprintBuilder.hasGhost(bp)
end

function Controller:reportMaterial(mat)
	local st = self.state
	if mat.missingVariant then
		self:setStatus(
			"material",
			false,
			"MaterialVariant « " .. mat.missingVariant .. " » introuvable dans MaterialService (SmoothPlastic appliqué)"
		)
	else
		local label = if st.settings.material == "Studs" then "Studs (" .. st.settings.variant .. ")" else st.settings.material
		self:setStatus("material", true, "Matériau : " .. label)
	end
end

function Controller:requireGenerated()
	local g = self:currentGenerated()
	if not g then
		error("Créez d'abord votre créature (ou sélectionnez-en une générée)", 0)
	end
	return g
end

function Controller:newColors()
	self:run("Couleurs…", function()
		local model = self:requireGenerated()
		local palette = PaletteGenerator.generate({
			seed = Random.new():NextInteger(1, 999999),
			level = 3,
			biome = model:GetAttribute(A .. "Biome"),
		})
		Util.record("Nouvelles couleurs", function()
			PaletteGenerator.apply(model, palette)
		end)
		self:setStatus("colors", true, "Nouvelle palette appliquée (modifiable : cliquez une pastille)")
	end)
end

function Controller:setMaterial(mode: string)
	self.state.settings.material = mode
	self:saveSettings()
	local model = self:currentGenerated()
	if not model then
		self:emit()
		return
	end
	self:run("Matériau…", function()
		local mat
		Util.record("Matériau " .. mode, function()
			mat = MaterialManager.apply(model, mode, self.state.settings.variant)
		end)
		self:reportMaterial(mat)
	end)
end

function Controller:setVariantName(name: string)
	self.state.settings.variant = if name ~= "" then name else Config.DEFAULT_VARIANT
	self:saveSettings()
	if self.state.settings.material == "Studs" then
		self:setMaterial("Studs")
	else
		self:emit()
	end
end

function Controller:buildRig()
	self:run("Rig…", function()
		local model = self:requireGenerated()
		local rig
		Util.record("Créer rig", function()
			rig = RigBuilder.build(model)
		end)
		self:setStatus("rig", true, string.format("Rig créé : %d Motor6D · %d welds", rig.motors, rig.welds))
		self.state.details = "Hiérarchie du rig :\n" .. RigBuilder.describe(model)
	end)
end

function Controller:publish()
	self:run("Publication…", function()
		local st = self.state
		local model = self:requireGenerated()
		local results
		Util.record("Publier meshes", function()
			results = AssetPublisher.publish(model, function(done, total, msg)
				st.publish = { done = done, total = total, failed = {} }
				self:progress(string.format("Publication… %d / %d  (%s)", done, total, msg or ""))
			end)
		end)
		st.publish = results
		if #results.failed == 0 then
			self:setStatus("publish", true, string.format("%d / %d meshes publiés", results.done, results.total))
		else
			self:setStatus(
				"publish",
				false,
				string.format("Échec : %d meshes — %s", results.total - results.done, AssetPublisher.describeFailure(results))
			)
		end
	end)
end

----------------------------------------------------------------------
-- Palette éditable (Color3Value) + restauration des meshes
----------------------------------------------------------------------

function Controller:bindPalette(model: Model)
	if self.paletteBindings[model] then
		return
	end
	local folder = model:FindFirstChild("Palette")
	if not folder then
		return
	end
	local conns = {}
	for _, value in folder:GetChildren() do
		if value:IsA("Color3Value") then
			table.insert(
				conns,
				value.Changed:Connect(function()
					local palette = PaletteGenerator.read(model)
					if not palette then
						return
					end
					local ok, id = pcall(function()
						return ChangeHistoryService:TryBeginRecording("CreatureForge_Recolor", "Couleur")
					end)
					pcall(PaletteGenerator.apply, model, palette)
					if ok and id then
						pcall(function()
							ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Append)
						end)
					end
					self:emit()
				end)
			)
		end
	end
	table.insert(
		conns,
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:unbindPalette(model)
			end
		end)
	)
	self.paletteBindings[model] = conns
end

function Controller:unbindPalette(model)
	local conns = self.paletteBindings[model]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
		self.paletteBindings[model] = nil
	end
end

-- Clic sur une pastille : sélectionne la Color3Value -> éditable dans Propriétés.
function Controller:editColor(slot: string)
	local model = self:currentGenerated()
	local folder = model and model:FindFirstChild("Palette")
	local value = folder and folder:FindFirstChild(slot)
	if value then
		Selection:Set({ value })
	end
end

function Controller:currentPalette()
	local model = self:currentGenerated()
	return model and PaletteGenerator.read(model)
end

-- Après redémarrage de Studio, les meshes non publiés doivent être reconstruits.
function Controller:restoreIfNeeded(model: Model)
	if self.state.busy or model:GetAttribute(A .. "Published") == true then
		return
	end
	local missing = false
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and d:GetAttribute(A .. "ShapeSpec") then
			local ok, isMissing = pcall(EditableMeshFactory.isMeshMissing, d)
			if ok and isMissing then
				missing = true
				break
			end
		end
	end
	if not missing then
		return
	end
	self:run("Restauration des meshes…", function()
		local n = 0
		Util.record("Restaurer meshes", function()
			n = AssetPublisher.restoreMissing(model)
		end)
		self:setStatus("meshes", true, n .. " meshes restaurés (temporaires) → pensez à PUBLIER")
	end)
end

function Controller:destroy()
	for model in self.paletteBindings do
		self:unbindPalette(model)
	end
end

return Controller
