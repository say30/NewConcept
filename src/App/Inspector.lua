--!strict
-- The right panel. Select something and it shows, in this order:
--   1. Ajouter       what you can put inside it
--   2. Style rapide  the few settings people change most
--   3. Propriétés    every setting, in folding sections
-- Everything is drawn from Schema, so every kind of element works the same way.

local Commands = require(script.Parent.Parent.Core.Commands)
local Fields = require(script.Parent.Parent.Schema.Fields)
local NodeTypes = require(script.Parent.Parent.Schema.NodeTypes)
local Style = require(script.Parent.Parent.Style.Style)
local Table = require(script.Parent.Parent.Util.Table)
local FieldEditors = require(script.Parent.FieldEditors)
local Ui = require(script.Parent.Ui)

local Inspector = {}
Inspector.__index = Inspector

function Inspector.new(editor: any, parent: Instance)
	local self = setmetatable({}, Inspector)
	self.editor = editor
	self.frame = Ui.new("Frame", {
		Name = "Inspector",
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self.scroll = Ui.scroll({ Parent = self.frame })
	Ui.list("Vertical", 10).Parent = self.scroll
	Ui.padding(10).Parent = self.scroll
	return self
end

local function heading(text: string, parent: Instance, order: number)
	return Ui.label(text, {
		Font = Ui.fontBold,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function block(parent: Instance, order: number, spacing: number?): Frame
	return Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.list("Vertical", spacing or 6) })
end

local function tileGrid(parent: Instance, order: number, cellWidth: number?): Frame
	return Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellWidth or 84, 32),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- "Ajouter" tiles for the element that will receive new children.
function Inspector:_addSection(targetId: string, order: number)
	local editor = self.editor
	local node = editor.store.project.nodes[targetId]
	local nodeType = NodeTypes.get(node.type)
	if #nodeType.canAdd == 0 then
		return
	end
	heading("Ajouter dans " .. node.name, self.scroll, order)
	local grid = tileGrid(self.scroll, order + 1)
	for i, typeName in nodeType.canAdd do
		Ui.button(NodeTypes.get(typeName).label, {
			order = i,
			textSize = 13,
			color = Ui.colors.accentDark,
			parent = grid,
			onClick = function()
				editor.picker:openVariants(typeName, targetId)
			end,
		})
	end
end

function Inspector:_fieldsFor(node: any, fieldList: { any }, parent: Instance)
	local editor = self.editor
	local props = NodeTypes.effectiveProps(node)
	local tokens = Style.tokens(editor.store.project)
	for i, field in fieldList do
		if not field.showIf or field.showIf(props) then
			local value = Table.getPath(props, field.path)
			FieldEditors.render(field, value, tokens, function(newValue)
				editor:dispatch(
					Commands.SetProps.new(node.id, { { path = field.path, value = newValue } }, field.label)
				)
			end, parent, i)
		end
	end
end

local function findField(path: { string }): any
	for _, section in Fields.sections do
		for _, field in section.fields do
			if Table.deepEqual(field.path, path) then
				return field
			end
		end
	end
	return nil
end

function Inspector:_renderNode(node: any)
	local editor = self.editor
	local nodeType = NodeTypes.get(node.type)
	local order = 0
	local function nextOrder()
		order += 10
		return order
	end

	-- Header: type, name and actions.
	local header = block(self.scroll, nextOrder(), 6)
	Ui.label(
		nodeType.label,
		{
			TextColor3 = Ui.colors.muted,
			TextSize = 12,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 1,
			Parent = header,
		}
	)
	Ui.textBox(node.name, {
		order = 2,
		size = UDim2.new(1, 0, 0, 30),
		onCommit = function(text)
			if text ~= node.name then
				editor:dispatch(Commands.Rename.new(node.id, text))
			end
		end,
	}).Parent =
		header
	local actions = tileGrid(header, 3, 82)
	Ui.button("Dupliquer", {
		order = 1,
		textSize = 13,
		parent = actions,
		onClick = function()
			editor:duplicateSelection()
		end,
	})
	Ui.button("Supprimer", {
		order = 2,
		textSize = 13,
		color = Ui.colors.danger,
		parent = actions,
		onClick = function()
			editor:deleteSelection()
		end,
	})
	Ui.button("Monter", {
		order = 3,
		textSize = 13,
		parent = actions,
		onClick = function()
			editor:moveSelection(-1)
		end,
	})
	Ui.button("Descendre", {
		order = 4,
		textSize = 13,
		parent = actions,
		onClick = function()
			editor:moveSelection(1)
		end,
	})
	local parentNode = editor.store.project.nodes[node.parent]
	if parentNode and parentNode.type ~= "Page" then
		Ui.button("Sortir de " .. parentNode.name, {
			order = 5,
			textSize = 12,
			parent = actions,
			onClick = function()
				editor:moveSelectionOut()
			end,
		})
	end
	Ui.button("Centrer", {
		order = 6,
		textSize = 13,
		parent = actions,
		onClick = function()
			editor:dispatch(Commands.SetProps.new(node.id, {
				{ path = { "position" }, value = { 0.5, 0, 0.5, 0 } },
				{ path = { "anchor" }, value = { 0.5, 0.5 } },
			}, "Centrer"))
		end,
	})

	-- 1. Add inside (or next to it, for elements that cannot contain anything).
	local target = if #nodeType.canAdd > 0 then node.id else node.parent
	self:_addSection(target, nextOrder())
	order += 10

	-- 2. Quick style.
	if #nodeType.quick > 0 then
		heading("Style rapide", self.scroll, nextOrder())
		local quick = block(self.scroll, nextOrder(), 8)
		local quickFields = {}
		for _, path in nodeType.quick do
			local field = findField(path)
			if field then
				table.insert(quickFields, field)
			end
		end
		self:_fieldsFor(node, quickFields, quick)
	end

	-- 3. All properties.
	heading("Toutes les propriétés", self.scroll, nextOrder())
	for _, sectionId in nodeType.sections do
		local section = Fields.sections[sectionId]
		local open = editor.openSections[sectionId] == true
		Ui.button((if open then "-   " else "+   ") .. section.label, {
			order = nextOrder(),
			size = UDim2.new(1, 0, 0, 30),
			color = Ui.colors.panelLight,
			parent = self.scroll,
			onClick = function()
				editor.openSections[sectionId] = not open
				self:render()
			end,
		}).TextXAlignment =
			Enum.TextXAlignment.Left
		if open then
			local body = block(self.scroll, nextOrder(), 8)
			Ui.padding(4, 6).Parent = body
			self:_fieldsFor(node, section.fields, body)
		end
	end
end

function Inspector:_renderPage(page: any)
	local editor = self.editor
	local order = 0
	local function nextOrder()
		order += 10
		return order
	end
	local header = block(self.scroll, nextOrder(), 6)
	Ui.label(
		"Page",
		{
			TextColor3 = Ui.colors.muted,
			TextSize = 12,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 1,
			Parent = header,
		}
	)
	Ui.textBox(page.name, {
		order = 2,
		size = UDim2.new(1, 0, 0, 30),
		onCommit = function(text)
			if text ~= page.name then
				editor:dispatch(Commands.RenamePage.new(page.id, text))
			end
		end,
	}).Parent =
		header
	local actions = tileGrid(header, 3, 130)
	Ui.button(if page.openByDefault then "Visible au lancement" else "Cachée au lancement", {
		order = 1,
		textSize = 12,
		color = if page.openByDefault then Ui.colors.success else Ui.colors.panelLight,
		parent = actions,
		onClick = function()
			editor:dispatch(Commands.SetPageOpen.new(page.id, not page.openByDefault))
		end,
	})
	Ui.button("Supprimer la page", {
		order = 2,
		textSize = 12,
		color = Ui.colors.danger,
		parent = actions,
		onClick = function()
			editor:deletePage(page.id)
		end,
	})

	heading("Partir d'un modèle complet", self.scroll, nextOrder())
	Ui.button("Choisir un preset (Shop, Inventory…)", {
		order = nextOrder(),
		size = UDim2.new(1, 0, 0, 34),
		color = Ui.colors.accent,
		parent = self.scroll,
		onClick = function()
			editor.picker:openPresets(page.rootId)
		end,
	})

	self:_addSection(page.rootId, nextOrder())
	order += 10

	Ui.label(
		"Astuce : clique sur un élément dans l'aperçu ou dans les calques pour voir tout ce que tu peux modifier.",
		{
			TextWrapped = true,
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 52),
			TextTruncate = Enum.TextTruncate.None,
			LayoutOrder = nextOrder(),
			Parent = self.scroll,
		}
	)
end

function Inspector:render()
	Ui.clear(self.scroll)
	local editor = self.editor
	local id = editor.store.selection:primary()
	local node = id and editor.store.project.nodes[id]
	if node and node.parent then
		self:_renderNode(node)
		return
	end
	local page = editor:currentPage()
	if page then
		self:_renderPage(page)
	else
		heading("Aucune page", self.scroll, 1)
		Ui.button("Créer une page", {
			order = 2,
			size = UDim2.new(1, 0, 0, 34),
			color = Ui.colors.accent,
			parent = self.scroll,
			onClick = function()
				editor:addPage()
			end,
		})
	end
end

return Inspector
