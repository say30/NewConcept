--[[
	UIController
	Construit l'interface du DockWidgetPluginGui :

	  [En-tête fixe]   titre, preset, reset
	  [Zone défilante] TARGET, ASSET LIBRARY, PLACEMENT MODE, COMPOSITION,
	                   TRANSFORM, WALL OPTIONS, FLOOR OPTIONS, CEILING,
	                   COLLISION (+ zones d'exclusion / géométrie protégée),
	                   RANDOM, ACTIONS, OUTPUT, DEBUG, DIAGNOSTICS
	  [Pied fixe]      statut + progression, Generate Preview / Regenerate /
	                   Accept / Cancel

	Les contrôles de réglages sont générés depuis le schéma de Settings ; les
	boutons appellent AppController ; l'état est rafraîchi sur ses événements.
]]

local Selection = game:GetService("Selection")

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local Settings = require(Core.Settings)
local Presets = require(Core.Presets)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local UIController = {}
UIController.__index = UIController

local UI = Config.UI
local HEADER_HEIGHT = 62
local FOOTER_HEIGHT = 118

local ROLE_OPTIONS = { "AUTO", "FLOOR", "WALL", "CEILING", "IGNORE" }
local ROLE_FROM_OPTION = { AUTO = "Auto", FLOOR = "Floor", WALL = "Wall", CEILING = "Ceiling", IGNORE = "Ignore" }

local SECTION_KEYS = {
	Placement = { "PlacementMode", "AutoClassify" },
	Composition = { "Density", "SpacingScale", "ClusterStrength", "EmptySpaceRatio", "LargeAssetFrequency", "MediumAssetFrequency", "SmallAssetFrequency", "Symmetry", "Randomness", "Variation", "VisualRhythm" },
	Transform = { "RotationMode", "ScaleMode", "FixedScale", "MinScale", "MaxScale", "SurfaceOffset", "SurfaceEpsilon", "AlignToSlopes" },
	Wall = { "WallTreatment", "WallMode", "WallDensity", "PillarSpacing", "TopDecoration", "BaseDecoration", "CornerDecoration", "HideOriginalWalls", "AllowModuleScaling", "MaxModuleScaleDeviation", "WallSides" },
	Floor = { "FloorAlgorithm", "KeepCenterClear", "CenterClearStart", "CenterClearEnd", "CenterClearAxis", "EdgeMargin", "EdgeDepth", "PathWidth", "AllowWallContact" },
	Ceiling = { "CeilingDecoration", "CeilingDensity" },
	Collision = { "CollisionCheck", "MinimumSpacing", "PreciseCollision", "CollideWithScene", "AvoidPreviousGenerations" },
	Output = { "MaxAssets", "CandidatesPerPlacement", "AnchorClones", "StripScripts" },
	Debug = { "DebugEnabled", "DebugBounds", "DebugNormals", "DebugZones", "DebugCandidates", "DebugRejected", "DebugSnaps", "DebugSegments" },
}

function UIController.new(plugin, widget, app, settings)
	local self = setmetatable({}, UIController)
	self.Plugin = plugin
	self.Widget = widget
	self.App = app
	self.Settings = settings
	self.Theme = Theme.new()
	self._settingWidgets = {}
	self._connections = {}
	self:_build()
	self:_bind()
	self:refreshAll()
	return self
end

function UIController:_build()
	local create = Widgets.create
	local theme = self.Theme
	local root = create("Frame", {
		Name = "ProceduralComposerRoot",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = self.Widget,
	})
	theme:bind(root, "BackgroundColor3", "Background")
	self.Root = root

	local overlay = create("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	})
	self.Overlay = overlay
	local w = Widgets.new(theme, overlay)
	self.W = w

	-- En-tête.
	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BorderSizePixel = 0,
		Parent = root,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4),
		}),
	})
	theme:bind(header, "BackgroundColor3", "Header")
	w:label(header, Config.PLUGIN_DISPLAY_NAME .. "  v" .. Config.VERSION, { Bold = true, TextSize = UI.HEADER_TEXT_SIZE + 1 })
	local presetRow = create("Frame", {
		Name = "PresetRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, UI.ROW_HEIGHT),
		LayoutOrder = w:nextOrder(),
		Parent = header,
	})
	local presetLabel = w:label(presetRow, "Preset", { Size = UDim2.new(0, 50, 1, 0) })
	presetLabel.Position = UDim2.new()
	local presetHolder = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -130, 1, 0),
		Position = UDim2.fromOffset(52, 0),
		Parent = presetRow,
	})
	self._presetDropdown = w:dropdown(presetHolder, nil, Presets.Order, self.Settings:get("Preset"), function(name)
		self.Settings:applyPreset(name)
		self.App:setStatus("Preset '" .. name .. "' applied.", "Info")
	end)
	local resetHolder = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 72, 1, 0),
		Position = UDim2.new(1, -72, 0, 0),
		Parent = presetRow,
	})
	w:button(resetHolder, "Reset", function()
		w:confirm("Reset settings", "Restore every setting to its default value (the seed is kept)?", "Reset", function()
			self.Settings:resetDefaults()
			self.App:setStatus("Settings reset to defaults.", "Info")
		end)
	end, { Size = UDim2.fromScale(1, 1), Tooltip = "Restore default settings." })

	-- Zone défilante.
	local scroll = create("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + FOOTER_HEIGHT)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Parent = root,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	})
	theme:bind(scroll, "ScrollBarImageColor3", "DimText")
	self.Scroll = scroll

	self:_buildTargetSection(scroll)
	self:_buildLibrarySection(scroll)
	self:_buildSchemaSection(scroll, "Placement Mode", "Placement", true)
	self:_buildSchemaSection(scroll, "Composition", "Composition", true)
	self:_buildSchemaSection(scroll, "Transform", "Transform", false)
	self:_buildSchemaSection(scroll, "Wall Options", "Wall", false)
	self:_buildSchemaSection(scroll, "Floor Options", "Floor", false)
	self:_buildSchemaSection(scroll, "Ceiling", "Ceiling", false)
	self:_buildCollisionSection(scroll)
	self:_buildRandomSection(scroll)
	self:_buildActionsSection(scroll)
	self:_buildSchemaSection(scroll, "Output & Performance", "Output", false)
	self:_buildDebugSection(scroll)
	self:_buildDiagnosticsSection(scroll)

	-- Pied de page.
	local footer = create("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = root,
	}, {
		create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8),
		}),
	})
	theme:bind(footer, "BackgroundColor3", "Header")
	self._status = w:progress(footer)
	local row1 = w:buttonRow(footer, {
		{ Key = "Generate", Text = "Generate Preview", Primary = true, Callback = function()
			self.App:generatePreview()
		end, Tooltip = "Generate a temporary preview with the current seed." },
		{ Key = "Regenerate", Text = "Regenerate", Callback = function()
			self.App:regenerate()
		end, Tooltip = "Generate a new variant (new seed if enabled)." },
	})
	local row2 = w:buttonRow(footer, {
		{ Key = "Accept", Text = "Accept", Callback = function()
			self.App:accept()
		end, Tooltip = "Keep the preview as Generation_NNN (Ctrl+Z undoes it)." },
		{ Key = "Cancel", Text = "Cancel", Callback = function()
			self.App:cancel()
		end, Tooltip = "Delete the preview completely." },
	})
	self._footerButtons = { Generate = row1.Generate, Regenerate = row1.Regenerate, Accept = row2.Accept, Cancel = row2.Cancel }

	root.MouseEnter:Connect(function()
		self:refreshButtons()
	end)
end

-- Sections ------------------------------------------------------------------------------

function UIController:_buildTargetSection(parent)
	local w = self.W
	local content = w:section(parent, "Target", true)
	w:buttonRow(content, {
		{ Text = "Use Current Selection", Callback = function()
			self.App:useSelectionAsTargets()
		end, Tooltip = "Use the selected Parts / Models / Folders as the zone to decorate." },
		{ Text = "Analyse Selection", Callback = function()
			self.App:analyse()
		end, Tooltip = "Re-analyse the current targets (after moving or resizing them)." },
	})
	self._targetInfo = w:info(content, "No target selected.")
	w:label(content, "Target Surfaces (role per part, forced roles override the analysis):", { Wrap = true, Color = "DimText" })
	local list = Widgets.create("Frame", {
		Name = "SurfaceList",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = w:nextOrder(),
		Parent = content,
	}, {
		Widgets.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	})
	self._surfaceList = list
end

function UIController:_buildLibrarySection(parent)
	local w = self.W
	local content = w:section(parent, "Asset Library", true)
	w:buttonRow(content, {
		{ Text = "Use Current Selection as Library", Callback = function()
			self.App:useSelectionAsLibrary()
		end, Tooltip = "Select one or more Folders / Models containing your assets." },
	})
	w:buttonRow(content, {
		{ Text = "Rescan Library", Callback = function()
			self.App:rescanLibrary()
		end, Tooltip = "Re-analyse the library (after editing assets or attributes)." },
	})
	self._libCount = w:keyValue(content, "Asset count")
	self._libRoots = w:info(content, "No library selected.")
	self._libCategories = w:info(content, "")
	self._libRoles = w:info(content, "")
	self._libSizes = w:info(content, "")
	self._libWarnings = w:info(content, "", "Warning")
end

function UIController:_buildSetting(parent, key)
	local w = self.W
	local entry = Settings.ByKey[key]
	local value = self.Settings:get(key)
	local function onChange(v)
		self.Settings:set(key, v)
	end
	local api
	if entry.Type == "number" then
		api = w:slider(parent, entry.Label, entry.Min, entry.Max, entry.Step, value, onChange, entry.Tooltip)
	elseif entry.Type == "int" then
		api = w:numberInput(parent, entry.Label, value, onChange, { Integer = true, Min = entry.Min, Max = entry.Max, Tooltip = entry.Tooltip })
	elseif entry.Type == "bool" then
		api = w:toggle(parent, entry.Label, value, onChange, entry.Tooltip)
	elseif entry.Type == "enum" then
		api = w:dropdown(parent, entry.Label, entry.Options, value, onChange, entry.Tooltip)
	end
	self._settingWidgets[key] = api
	return api
end

function UIController:_buildSchemaSection(parent, title, sectionKey, expanded)
	local content = self.W:section(parent, title, expanded)
	for _, key in ipairs(SECTION_KEYS[sectionKey]) do
		self:_buildSetting(content, key)
	end
	return content
end

function UIController:_buildCollisionSection(parent)
	local w = self.W
	local content = self:_buildSchemaSection(parent, "Collision", "Collision", false)
	w:label(content, "Exclusion zones", { Bold = true })
	w:buttonRow(content, {
		{ Text = "Use Selection as Zones", Callback = function()
			self.App:useSelectionAsExclusions()
		end, Tooltip = "Selected Parts become forbidden zones (spawn, path, door, NPC...)." },
		{ Text = "Clear Zones", Callback = function()
			self.App:clearExclusions()
		end },
	})
	w:buttonRow(content, {
		{ Text = "Create Center Exclusion Zone", Callback = function()
			self.App:createCenterExclusionZone()
		end, Tooltip = "Creates a visible, resizable zone Part in the middle of each analysed floor (Clear zone start/end, Floor Options). Tagged ProceduralPlacementExclude: nothing is ever placed inside." },
	})
	self._zonesInfo = w:info(content, "")
	w:label(content, "Protected geometry", { Bold = true })
	w:buttonRow(content, {
		{ Text = "Use Selection as Protected", Callback = function()
			self.App:useSelectionAsProtected()
		end, Tooltip = "Selected Parts can never be overlapped by generated assets." },
		{ Text = "Clear Protected", Callback = function()
			self.App:clearProtected()
		end },
	})
	self._protectedInfo = w:info(content, "")
end

function UIController:_buildRandomSection(parent)
	local w = self.W
	local content = w:section(parent, "Random", true)
	self:_buildSetting(content, "Seed")
	w:buttonRow(content, {
		{ Text = "Random Seed", Callback = function()
			self.App:randomizeSeed()
		end, Tooltip = "Pick a new random seed (same seed + same settings + same assets = same result)." },
	})
	self:_buildSetting(content, "NewSeedOnRegenerate")
end

function UIController:_buildActionsSection(parent)
	local w = self.W
	local content = w:section(parent, "Actions", true)
	local r1 = w:buttonRow(content, {
		{ Key = "Analyse", Text = "Analyse", Callback = function()
			self.App:analyse()
		end },
		{ Key = "Generate", Text = "Generate Preview", Primary = true, Callback = function()
			self.App:generatePreview()
		end },
	})
	local r2 = w:buttonRow(content, {
		{ Key = "Regenerate", Text = "Regenerate", Callback = function()
			self.App:regenerate()
		end },
		{ Key = "Accept", Text = "Accept", Callback = function()
			self.App:accept()
		end },
	})
	local r3 = w:buttonRow(content, {
		{ Key = "Cancel", Text = "Cancel", Callback = function()
			self.App:cancel()
		end },
		{ Key = "Clear", Text = "Clear Generated", Callback = function()
			self:_confirmClear()
		end, Tooltip = "Delete every generated folder (with confirmation, undoable)." },
	})
	self._actionButtons = {
		Analyse = r1.Analyse, Generate = r1.Generate, Regenerate = r2.Regenerate,
		Accept = r2.Accept, Cancel = r3.Cancel, Clear = r3.Clear,
	}
end

function UIController:_confirmClear()
	local count = self.App:generationCount() + (if self.App:hasPreview() then 1 else 0)
	self.W:confirm("Clear generated content",
		string.format("Delete %d generated folder(s) from '%s'? Hidden original walls will be restored. You can undo with Ctrl+Z.", count, Config.Output.ROOT_NAME),
		"Delete", function()
			self.App:clearGenerated()
		end)
end

function UIController:_buildDebugSection(parent)
	local w = self.W
	local content = self:_buildSchemaSection(parent, "Debug", "Debug", false)
	w:buttonRow(content, {
		{ Text = "Redraw Debug", Callback = function()
			self.App:redrawDebug()
		end },
		{ Text = "Clear Debug", Callback = function()
			self.App:clearDebug()
		end },
	})
end

function UIController:_buildDiagnosticsSection(parent)
	local w = self.W
	local content = w:section(parent, "Diagnostics", true)
	self._diag = {}
	for _, key in ipairs({
		"Surfaces", "Corners", "Assets in library", "Placed assets", "Placement attempts",
		"Rejected attempts", "Overlaps prevented", "Exclusion rejections", "Modules fitted", "Generation time",
	}) do
		self._diag[key] = w:keyValue(content, key)
	end
	self._diagWarnings = w:info(content, "", "Warning")
	self._diagPasses = w:info(content, "")
end

-- Liaisons ------------------------------------------------------------------------------------

function UIController:_bind()
	table.insert(self._connections, self.Settings:onChanged(function(key, value)
		local api = self._settingWidgets[key]
		if api and api.Set then
			api.Set(value)
		end
		if key == "Preset" then
			self._presetDropdown.Set(value)
		elseif string.sub(key, 1, 5) == "Debug" then
			self.App:redrawDebug()
		elseif key == "AutoClassify" then
			if self.App.Registry:count() > 0 then
				self.App.Registry:finalizeRoles(value)
				self.App.LibrarySummary = self.App.Registry:summary()
				self:refreshLibrary()
			end
		elseif key == "WallSides" then
			if self.App.Analysis then
				self.App:analyse()
			end
		end
	end))
	self.App:onChanged(function(kind)
		if kind == "status" then
			self:refreshStatus()
		elseif kind == "analysis" then
			self:refreshTargets()
			self:refreshStatus()
		elseif kind == "library" then
			self:refreshLibrary()
			self:refreshStatus()
		elseif kind == "zones" then
			self:refreshZones()
			self:refreshStatus()
		else
			self:refreshAll()
		end
		self:refreshButtons()
	end)
end

-- Rafraîchissements -------------------------------------------------------------------------------

function UIController:refreshStatus()
	local s = self.App.Status
	self._status.Set(s.Progress, s.Text, s.Level)
end

function UIController:refreshButtons()
	local app = self.App
	local busy = app.Busy
	local hasPreview = app:hasPreview()
	local hasAny = hasPreview or app:generationCount() > 0
	for _, set in ipairs({ self._footerButtons, self._actionButtons }) do
		if set.Generate then
			set.Generate.SetEnabled(not busy)
		end
		if set.Regenerate then
			set.Regenerate.SetEnabled(not busy and hasPreview)
		end
		if set.Accept then
			set.Accept.SetEnabled(not busy and hasPreview)
		end
		if set.Cancel then
			set.Cancel.SetEnabled(not busy and hasPreview)
		end
	end
	self._actionButtons.Analyse.SetEnabled(not busy)
	self._actionButtons.Clear.SetEnabled(not busy and hasAny)
end

function UIController:refreshTargets()
	local app = self.App
	local analysis = app.Analysis
	for _, child in ipairs(self._surfaceList:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	if not analysis then
		self._targetInfo.Set(if #app.TargetRoots > 0 then "Targets set but not analysed." else "No target selected.")
		return
	end
	local parallel = ""
	if #analysis.WallPairs > 0 then
		local d = {}
		for i, p in ipairs(analysis.WallPairs) do
			if i > 3 then
				break
			end
			table.insert(d, string.format("%.1f", p.Distance))
		end
		parallel = "\nDistance between parallel walls: " .. table.concat(d, ", ") .. " studs"
	end
	self._targetInfo.Set(string.format("%d part(s) · %d surface(s): %d floor, %d wall, %d ceiling, %d slope · %d corner(s)%s",
		#analysis.Parts, #analysis.Surfaces, #analysis.Floors, #analysis.Walls, #analysis.Ceilings, #analysis.Slopes, #analysis.Corners, parallel))

	-- Rôles détectés par Part.
	local rolesByPart = {}
	for _, s in ipairs(analysis.Surfaces) do
		local t = rolesByPart[s.Part]
		if not t then
			t = {}
			rolesByPart[s.Part] = t
		end
		table.insert(t, string.format("%s %.0f×%.0f", s.Role, s.UMax - s.UMin, s.VMax - s.VMin))
	end
	local w = self.W
	local create = Widgets.create
	for i, info in ipairs(analysis.PartInfos) do
		if i > UI.MAX_SURFACE_ROWS then
			w:info(self._surfaceList, string.format("... and %d more part(s).", #analysis.PartInfos - UI.MAX_SURFACE_ROWS))
			break
		end
		local part = info.Part
		local row = create("Frame", {
			Name = "PartRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, UI.ROW_HEIGHT),
			LayoutOrder = i,
			Parent = self._surfaceList,
		})
		local detected = rolesByPart[part]
		local text = part.Name .. "  ·  " .. (if detected then table.concat(detected, ", ") else "ignored")
		local nameButton = create("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.64, -4, 1, 0),
			Font = UI.FONT,
			TextSize = UI.TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			Parent = row,
		})
		self.Theme:bind(nameButton, "TextColor3", if detected then "Text" else "DimText")
		nameButton.Activated:Connect(function()
			if part.Parent then
				Selection:Set({ part })
			end
		end)
		w:tooltip(nameButton, part:GetFullName() .. "\nClick to select this part.")
		local holder = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.36, 0, 1, 0),
			Position = UDim2.new(0.64, 0, 0, 0),
			Parent = row,
		})
		local current = string.upper(app:getOverride(part))
		w:dropdown(holder, nil, ROLE_OPTIONS, current, function(option)
			app:setOverride(part, ROLE_FROM_OPTION[option])
		end)
	end
end

function UIController:refreshLibrary()
	local app = self.App
	local summary = app.LibrarySummary
	local roots = {}
	for _, r in ipairs(app.LibraryRoots) do
		if r.Parent then
			table.insert(roots, r.Name)
		end
	end
	if not summary then
		self._libCount.Set(0)
		self._libRoots.Set("No library selected.")
		self._libCategories.Set("")
		self._libRoles.Set("")
		self._libSizes.Set("")
		self._libWarnings.Set("")
		return
	end
	self._libCount.Set(summary.Count)
	self._libRoots.Set("Library: " .. (if #roots > 0 then table.concat(roots, ", ") else "-"))
	self._libCategories.Set("Categories detected: " .. (if #summary.Categories > 0 then table.concat(summary.Categories, ", ") else "-"))
	local roleParts = {}
	for _, role in ipairs(Config.Roles) do
		local n = summary.RoleCounts[role] or 0
		if n > 0 then
			table.insert(roleParts, role .. " " .. n)
		end
	end
	self._libRoles.Set("Roles: " .. (if #roleParts > 0 then table.concat(roleParts, " · ") else "-"))
	local s = summary.SizeCounts
	self._libSizes.Set(string.format("Sizes: Small %d · Medium %d · Large %d · Hero %d", s.Small or 0, s.Medium or 0, s.Large or 0, s.Hero or 0))
	local warnings = {}
	for i, wtext in ipairs(summary.Warnings) do
		if i > 6 then
			table.insert(warnings, string.format("... %d more (see Output).", #summary.Warnings - 6))
			break
		end
		table.insert(warnings, "• " .. wtext)
	end
	self._libWarnings.Set(table.concat(warnings, "\n"))
end

function UIController:refreshZones()
	local app = self.App
	local tagged = app:taggedExclusionCount()
	self._zonesInfo.Set(string.format("%d selected zone part(s) · %d tagged '%s'", #app.ExclusionParts, tagged, Config.Tags.EXCLUDE))
	self._protectedInfo.Set(string.format("%d protected part(s) (tag '%s' also supported)", #app.ProtectedParts, Config.Tags.PROTECTED))
end

function UIController:refreshDiagnostics()
	local plan = self.App.LastPlan
	if not plan then
		for _, api in pairs(self._diag) do
			api.Set("-")
		end
		self._diagWarnings.Set("")
		self._diagPasses.Set("")
		return
	end
	for _, line in ipairs(plan.Diagnostics:summaryLines()) do
		local api = self._diag[line[1]]
		if api then
			api.Set(line[2])
		end
	end
	local warnings = {}
	for i, wtext in ipairs(plan.Diagnostics.Warnings) do
		if i > 8 then
			table.insert(warnings, string.format("... %d more.", #plan.Diagnostics.Warnings - 8))
			break
		end
		table.insert(warnings, "• " .. wtext)
	end
	self._diagWarnings.Set(table.concat(warnings, "\n"))
	local passes = {}
	local names = {}
	for name in pairs(plan.Diagnostics.PerPass) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		table.insert(passes, name .. " " .. plan.Diagnostics.PerPass[name])
	end
	self._diagPasses.Set(if #passes > 0 then "Per pass: " .. table.concat(passes, " · ") else "")
end

function UIController:refreshAll()
	self:refreshStatus()
	self:refreshTargets()
	self:refreshLibrary()
	self:refreshZones()
	self:refreshDiagnostics()
	self:refreshButtons()
end

function UIController:destroy()
	for _, disconnect in ipairs(self._connections) do
		pcall(disconnect)
	end
	self.Theme:destroy()
	if self.Root then
		self.Root:Destroy()
	end
end

return UIController
