-- MainWindow : fenêtre ancrable « CREATURE FORGE » à deux onglets.
-- Toute la logique est dans Controller ; ici on ne fait qu'afficher et relayer les clics.

local Root = script.Parent.Parent
local Config = require(Root.Config)
local Components = require(script.Parent.Components)

local Theme = Components.Theme
local new = Components.new

local MainWindow = {}
MainWindow.__index = MainWindow

local VARIATIONS = { "Faible", "Moyenne", "Forte" }
local MATERIALS = { "Original", "Studs", "SmoothPlastic" }
local MATERIAL_LABELS = { "Original", "Studs", "Smooth" }

local function escape(text: string)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function createWidget(plugin)
	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 360, 720, 300, 420)
	local ok, widget = pcall(function()
		return plugin:CreateDockWidgetPluginGuiAsync("CreatureForge_Main", info)
	end)
	if not ok or not widget then
		widget = plugin:CreateDockWidgetPluginGui("CreatureForge_Main", info)
	end
	widget.Title = "Creature Forge"
	widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return widget
end

function MainWindow.new(plugin, controller)
	local self = setmetatable({}, MainWindow)
	self.controller = controller
	self.widget = createWidget(plugin)

	local rootFrame = new("Frame", {
		Parent = self.widget,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
	})

	-- En-tête
	new("TextLabel", {
		Parent = rootFrame,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1,
		Text = "CREATURE FORGE",
		TextSize = 18,
		Font = Theme.FontBold,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	new("TextLabel", {
		Parent = rootFrame,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1,
		Text = "v" .. Config.VERSION,
		TextSize = 11,
		Font = Theme.Font,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- Onglets
	local tabBar = new("Frame", {
		Parent = rootFrame,
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 3),
		}),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self.pages = {}
	self.tabs = {}
	local function tab(i, text)
		local b = new("TextButton", {
			Parent = tabBar,
			LayoutOrder = i,
			Size = UDim2.new(0.5, -2, 1, 0),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			TextSize = 12,
			Font = Theme.FontBold,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
		b.Activated:Connect(function()
			self:selectTab(i)
		end)
		self.tabs[i] = b
	end
	tab(1, "STUDY / REBUILD")
	tab(2, "CREATURE MIXER")

	self.pages[1] = Components.page(rootFrame)
	self.pages[2] = Components.page(rootFrame)
	self:buildStudy(self.pages[1])
	self:buildMixer(self.pages[2])
	self:selectTab(1)

	controller:onChanged(function(state)
		self:render(state)
	end)
	self:render(controller.state)
	return self
end

function MainWindow:selectTab(i)
	for k, page in self.pages do
		page.Visible = k == i
		local b = self.tabs[k]
		b.BackgroundColor3 = if k == i then Theme.Panel2 else Theme.Panel
		b.TextColor3 = if k == i then Theme.Accent else Theme.SubText
	end
end

function MainWindow:toggle()
	self.widget.Enabled = not self.widget.Enabled
end

----------------------------------------------------------------------
-- Onglet 1 : STUDY / REBUILD
----------------------------------------------------------------------

function MainWindow:buildStudy(page)
	local c = self.controller
	local o = Components.orderer()
	local ui = {}
	self.ui = ui

	-- Sélection + analyse
	local card = Components.card(page, o())
	local k = Components.orderer()
	Components.label(card, "Créature sélectionnée :", { order = k(), size = 12, color = Theme.SubText })
	ui.selection = Components.label(card, "", { order = k(), size = 16, bold = true, rich = true })
	ui.analyze = Components.button(card, "ANALYSER LA CRÉATURE", {
		order = k(),
		style = "primary",
		height = 42,
		onClick = function()
			c:analyze()
		end,
	})
	ui.summary = Components.label(card, "", { order = k(), size = 14, rich = true, lineHeight = 1.25 })
	ui.morph = Components.label(card, "", { order = k(), size = 12, color = Theme.SubText })

	-- Étude
	local study = Components.card(page, o())
	k = Components.orderer()
	Components.header(study, "ÉTUDE", k())
	ui.blueprint = Components.button(study, "BLUEPRINT", {
		order = k(),
		onClick = function()
			c:blueprint()
		end,
	})
	ui.ghost = Components.button(study, "FANTÔME (forme réelle)", {
		order = k(),
		onClick = function()
			c:toggleGhost()
		end,
	})
	ui.explode = Components.button(study, "VUE ÉCLATÉE", {
		order = k(),
		onClick = function()
			c:toggleExplode()
		end,
	})
	ui.slider = Components.slider(study, "Explosion", 0, function(v, phase)
		c:setExplode(v, phase)
	end, k())
	ui.rig = Components.button(study, "AFFICHER RIG", {
		order = k(),
		onClick = function()
			c:toggleRig()
		end,
	})

	-- Ma version
	local mine = Components.card(page, o())
	k = Components.orderer()
	Components.header(mine, "MA VERSION", k())
	Components.label(mine, "Variation", { order = k(), size = 12, color = Theme.SubText })
	ui.variation = Components.segmented(mine, VARIATIONS, c.state.settings.variation, function(i)
		c:setSetting("variation", i)
	end, k())

	local seedRow = Components.row(mine, k(), 34)
	ui.seed = Components.textbox(seedRow, "Seed : auto", c.state.settings.seed, function(text)
		c:setSetting("seed", text:match("%d+") or "")
	end, { order = 1, size = UDim2.new(0.62, 0, 1, 0) })
	Components.button(seedRow, "RANDOM", {
		order = 2,
		size = UDim2.new(0.38, -6, 1, 0),
		textSize = 12,
		onClick = function()
			c:setSetting("seed", tostring(Random.new():NextInteger(1, 999999)))
		end,
	})

	ui.create = Components.button(mine, "CRÉER MA CRÉATURE", {
		order = k(),
		style = "accent",
		height = 50,
		textSize = 16,
		onClick = function()
			c:createCreature()
		end,
	})
	ui.rebuild = Components.button(mine, "RECONSTRUIRE FIDÈLE", {
		order = k(),
		style = "primary",
		onClick = function()
			c:rebuildFaithful()
		end,
	})
	Components.label(mine, "Fidèle = même disposition, tailles, couleurs et rig que l'original, avec tes propres meshes.", {
		order = k(),
		size = 11,
		color = Theme.Muted,
	})

	Components.label(mine, "Couleurs  (cliquez une pastille pour la modifier)", { order = k(), size = 12, color = Theme.SubText })
	ui.swatches = Components.swatches(mine, Config.PALETTE_SLOTS, function(slot)
		c:editColor(slot)
	end, k())
	ui.colors = Components.button(mine, "NOUVELLES COULEURS", {
		order = k(),
		onClick = function()
			c:newColors()
		end,
	})

	Components.label(mine, "Material", { order = k(), size = 12, color = Theme.SubText })
	local matIndex = table.find(MATERIALS, c.state.settings.material) or 2
	ui.material = Components.segmented(mine, MATERIAL_LABELS, matIndex, function(i)
		c:setMaterial(MATERIALS[i])
	end, k())
	ui.variant = Components.textbox(mine, "Nom du MaterialVariant (ex. Studs)", c.state.settings.variant, function(text)
		c:setVariantName(text)
	end, { order = k() })

	ui.buildRig = Components.button(mine, "CRÉER RIG", {
		order = k(),
		onClick = function()
			c:buildRig()
		end,
	})
	ui.publish = Components.button(mine, "PUBLIER MES MESHES", {
		order = k(),
		style = "primary",
		height = 44,
		onClick = function()
			c:publish()
		end,
	})
	ui.retry = Components.button(mine, "RÉESSAYER", {
		order = k(),
		style = "danger",
		onClick = function()
			c:publish()
		end,
	})

	-- Statut
	local statusCard = Components.card(page, o())
	Components.header(statusCard, "STATUT", 1)
	ui.status = Components.status(statusCard, 2)

	-- Détails avancés (fermé par défaut)
	ui.details = Components.collapsible(page, "Détails avancés", o())
end

----------------------------------------------------------------------
-- Onglet 2 : CREATURE MIXER (étape suivante)
----------------------------------------------------------------------

function MainWindow:buildMixer(page)
	local o = Components.orderer()
	local card = Components.card(page, o())
	Components.header(card, "CREATURE MIXER", 1)
	Components.label(
		card,
		"Prochaine étape du développement.\n\n1. Sélectionnez un dossier de 5 à 20 créatures\n2. ANALYSER LES CRÉATURES\n3. CRÉER UNE NOUVELLE CRÉATURE\n\nLes caractéristiques générales (proportions, ailes, queue, cornes, palette…) seront mélangées pour générer une créature originale, avec des meshes 100 % neufs.",
		{ order = 2, size = 13, color = Theme.SubText, lineHeight = 1.25 }
	)
end

----------------------------------------------------------------------
-- Rendu de l'état
----------------------------------------------------------------------

function MainWindow:render(state)
	local ui = self.ui
	local c = self.controller
	local busy = state.busy
	local success = Theme.Success:ToHex()

	-- Sélection
	local sel = state.selection
	if state.selectionKind == "reference" then
		ui.selection.Text = string.format('%s <font color="#%s">✓</font>', escape(sel.Name), success)
	elseif state.selectionKind == "generated" then
		ui.selection.Text = string.format('%s <font color="#%s">✓ (ma créature)</font>', escape(sel.Name), success)
	elseif state.selectionKind == "blueprint" then
		ui.selection.Text = escape(sel.Name) .. ' <font color="#' .. Theme.SubText:ToHex() .. '">(blueprint)</font>'
	elseif state.report and state.report.model.Parent then
		ui.selection.Text = string.format('<font color="#%s">Aucune — référence : %s</font>', Theme.SubText:ToHex(), escape(state.report.name))
	else
		ui.selection.Text = string.format('<font color="#%s">Aucune — sélectionnez une créature</font>', Theme.Muted:ToHex())
	end

	-- Résumé d'analyse
	local report = state.report
	if report then
		local k = report.counts
		ui.summary.Text = string.format(
			"<b>Créature :</b> %s\n<b>Pièces :</b> %d\n<b>MeshParts :</b> %d\n<b>Couleurs :</b> %d\n<b>Motor6D :</b> %d\n<b>Bones :</b> %d",
			escape(report.name),
			k.parts,
			k.meshParts,
			k.colors,
			k.motor6D,
			k.bones
		)
		ui.morph.Text = report.morphology .. (if state.reportStale then "  (sélection différente : relancez l'analyse)" else "")
	end
	ui.summary.Visible = report ~= nil
	ui.morph.Visible = report ~= nil

	local hasRef = c:currentReference() ~= nil
	local hasGen = c:currentGenerated() ~= nil
	local hasBlueprint = state.blueprint ~= nil and state.blueprint.Parent ~= nil

	ui.analyze.setEnabled(not busy and hasRef)
	ui.blueprint.setEnabled(not busy and hasRef)
	ui.blueprint.setText(if hasBlueprint then "RECRÉER LE BLUEPRINT" else "BLUEPRINT")
	ui.explode.setEnabled(not busy and hasRef)
	ui.ghost.setEnabled(not busy and hasRef)
	ui.ghost.setText(if c:isGhostShown() then "MASQUER LE FANTÔME" else "FANTÔME (forme réelle)")
	ui.slider.setVisible(hasBlueprint)
	ui.slider.set(state.explode or 0)
	ui.rig.setEnabled(not busy and (hasRef or (state.selectionKind == "generated" and hasGen)))
	ui.rig.setText(if c:isRigShown() then "MASQUER RIG" else "AFFICHER RIG")

	ui.variation.set(state.settings.variation)
	ui.seed.set(state.settings.seed or "")
	ui.create.setEnabled(not busy and hasRef)
	ui.rebuild.setEnabled(not busy and hasRef)
	ui.create.setText(if busy and state.busyText:find("Génération") then "GÉNÉRATION…" else "CRÉER MA CRÉATURE")

	ui.swatches.setColors(c:currentPalette())
	ui.colors.setEnabled(not busy and hasGen)
	ui.material.set(table.find(MATERIALS, state.settings.material) or 2)
	ui.variant.instance.Visible = state.settings.material == "Studs"
	ui.variant.set(state.settings.variant or "")
	ui.buildRig.setEnabled(not busy and hasGen)
	ui.publish.setEnabled(not busy and hasGen)
	local failed = state.publish and state.publish.failed and #state.publish.failed > 0
	ui.retry.setVisible(failed and not busy)

	-- Statut
	local lines = c:statusLines()
	if busy then
		table.insert(lines, 1, { busy = true, text = state.busyText })
	elseif #lines == 0 then
		table.insert(lines, { text = "Sélectionnez une créature puis ANALYSER (ou directement CRÉER MA CRÉATURE)." })
	end
	ui.status.set(lines)

	-- Détails avancés
	local details = state.details or ""
	if state.lastSeed then
		details = "Dernière seed : " .. state.lastSeed .. "\n\n" .. details
	end
	ui.details.setText(if details ~= "" then details else "Aucune analyse pour l'instant.")
end

return MainWindow
