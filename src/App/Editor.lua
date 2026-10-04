--!strict
-- Puts the editor together: the window layout, the open project, the current page and
-- screen size, and the actions the panels call (insert, duplicate, delete, generate...).

local AutoSave = require(script.Parent.Parent.Persistence.AutoSave)
local Commands = require(script.Parent.Parent.Core.Commands)
local Document = require(script.Parent.Parent.Core.Document)
local Generator = require(script.Parent.Parent.Generator.Generator)
local NodeTypes = require(script.Parent.Parent.Schema.NodeTypes)
local Store = require(script.Parent.Parent.Core.Store)
local Canvas = require(script.Parent.Canvas)
local Inspector = require(script.Parent.Inspector)
local Layers = require(script.Parent.Layers)
local Picker = require(script.Parent.Picker)
local Topbar = require(script.Parent.Topbar)
local Ui = require(script.Parent.Ui)

local Editor = {}
Editor.__index = Editor

local TOPBAR = 44
local LEFT = 230
local RIGHT = 320
local STATUS = 24

export type Services = {
	projectStore: any, -- Persistence/ProjectStore
	generateTarget: () -> Instance, -- where to generate (StarterGui)
	-- Wraps a change to the place so Studio can undo it (ChangeHistoryService).
	recordChange: (label: string, fn: () -> ()) -> (),
	-- Shows generated objects in Studio's Explorer.
	selectInStudio: ((instances: { Instance }) -> ())?,
}

-- A new project with one empty page.
function Editor.newProject(name: string?): any
	local store = Store.new(Document.newProject(name or "MonInterface"))
	store:dispatch(Commands.AddPage.new("Main"))
	return store.project
end

function Editor.new(root: Instance, services: Services, project: any?)
	local self = setmetatable({}, Editor)
	self.services = services
	self.store = Store.new(project or Editor.newProject())
	self.device = "PC"
	self.dragging = false
	self.openSections = { Fill = true, Text = true, Image = true, Layout = true } :: { [string]: boolean }
	self.pageId = nil :: string?
	self.autoSave = nil :: any

	self.root = Ui.new("Frame", {
		Name = "GuiCreator",
		BackgroundColor3 = Ui.colors.background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	local top =
		Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TOPBAR), Parent = self.root })
	local left = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TOPBAR),
		Size = UDim2.new(0, LEFT, 1, -(TOPBAR + STATUS)),
		Parent = self.root,
	})
	local center = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(LEFT, TOPBAR),
		Size = UDim2.new(1, -(LEFT + RIGHT), 1, -(TOPBAR + STATUS)),
		Parent = self.root,
	})
	local right = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, TOPBAR),
		Size = UDim2.new(0, RIGHT, 1, -(TOPBAR + STATUS)),
		Parent = self.root,
	})
	self.statusLabel = Ui.label("", {
		Position = UDim2.new(0, 10, 1, -STATUS),
		Size = UDim2.new(1, -20, 0, STATUS),
		TextColor3 = Ui.colors.muted,
		TextSize = 13,
		Parent = self.root,
	})

	self.topbar = Topbar.new(self, top)
	self.layers = Layers.new(self, left)
	self.canvas = Canvas.new(self, center)
	self.inspector = Inspector.new(self, right)
	self.picker = Picker.new(self, self.root)

	self.store.changed:Connect(function()
		self:refresh()
	end)
	self.store.selection.changed:Connect(function()
		if not self.dragging then
			self.layers:render()
			self.inspector:render()
		end
		self.canvas:renderOverlay()
	end)

	self:_startAutoSave()
	self:refresh()
	self:setStatus("Prêt. Choisis un preset ou ajoute des éléments depuis le panneau de droite.")
	return self
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function Editor:currentPage(): any
	local project = self.store.project
	if self.pageId and project.pages[self.pageId] then
		return project.pages[self.pageId]
	end
	local first = project.pageOrder[1]
	self.pageId = first
	return first and project.pages[first]
end

function Editor:refresh()
	self:currentPage()
	self.canvas:render()
	if not self.dragging then
		self.topbar:render()
		self.layers:render()
		self.inspector:render()
	end
end

function Editor:setStatus(text: string)
	self.statusLabel.Text = text
end

local function cleanError(err: any): string
	return (string.gsub(tostring(err), "^.-:%d+: ", ""))
end

function Editor:dispatch(command: any): (boolean, any)
	local ok, result = self.store:dispatch(command)
	if not ok then
		self:setStatus("Action impossible : " .. cleanError(result))
	end
	return ok, result
end

function Editor:setPage(pageId: string)
	self.pageId = pageId
	self.store.selection:clear()
	self:refresh()
end

function Editor:setDevice(deviceId: string)
	self.device = deviceId
	self:refresh()
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

function Editor:insertTemplate(template: any, parentId: string, variantId: string?)
	local copy = table.clone(template)
	copy.variant = variantId
	local ok, id = self:dispatch(Commands.InsertTree.new(copy, parentId))
	if ok then
		self.store.selection:set({ id })
		self:setStatus(self.store.project.nodes[id].name .. " ajouté. Tout est modifiable à droite.")
	end
end

function Editor:addPage()
	local ok, pageId = self:dispatch(Commands.AddPage.new("Page"))
	if ok then
		self:setPage(pageId)
	end
end

function Editor:deletePage(pageId: string)
	if #self.store.project.pageOrder <= 1 then
		self:setStatus("Un projet garde au moins une page.")
		return
	end
	if self:dispatch(Commands.RemovePage.new(pageId)) then
		self.pageId = nil
		self:refresh()
		self:setStatus("Page supprimée. Annuler la ramène.")
	end
end

function Editor:renameProject(name: string)
	if name ~= self.store.project.name then
		self:dispatch(Commands.RenameProject.new(name))
	end
end

function Editor:duplicateSelection()
	local project = self.store.project
	local created = {}
	self.store:beginGroup("Duplicate")
	for _, id in self.store.selection:get() do
		local node = project.nodes[id]
		if node and node.parent then
			local template = Document.toTemplate(project, id)
			local position = template.props.position
			if type(position) == "table" then
				template.props.position = { position[1], position[2] + 16, position[3], position[4] + 16 }
			end
			local index = table.find(project.nodes[node.parent].children, id)
			local ok, newId = self:dispatch(Commands.InsertTree.new(template, node.parent, (index or 0) + 1))
			if ok then
				table.insert(created, newId)
			end
		end
	end
	self.store:endGroup()
	if #created > 0 then
		self.store.selection:set(created)
		self:refresh()
	end
end

function Editor:deleteSelection()
	local ids = self.store.selection:get()
	if #ids > 0 and self:dispatch(Commands.DeleteNodes.new(ids)) then
		self:setStatus("Supprimé. Annuler le ramène.")
	end
end

function Editor:moveSelection(direction: number)
	local project = self.store.project
	local id = self.store.selection:primary()
	local node = id and project.nodes[id]
	if not node or not node.parent then
		return
	end
	local siblings = project.nodes[node.parent].children
	local index = table.find(siblings, id) :: number
	local target = index + direction
	if target >= 1 and target <= #siblings then
		self:dispatch(Commands.Move.new(id, node.parent, target))
	end
end

function Editor:moveSelectionOut()
	local project = self.store.project
	local id = self.store.selection:primary()
	local node = id and project.nodes[id]
	local parent = node and node.parent and project.nodes[node.parent]
	if parent and parent.parent then
		local index = table.find(project.nodes[parent.parent].children, parent.id)
		self:dispatch(Commands.Move.new(id, parent.parent, (index or 0) + 1))
	end
end

-- Where new elements go when nothing more precise is chosen.
function Editor:insertTarget(): string?
	local project = self.store.project
	local id = self.store.selection:primary()
	local node = id and project.nodes[id]
	if node and NodeTypes.get(node.type).container then
		return node.id
	elseif node and node.parent then
		return node.parent
	end
	local page = self:currentPage()
	return page and page.rootId
end

--------------------------------------------------------------------------------
-- Projects and generation
--------------------------------------------------------------------------------

function Editor:_startAutoSave()
	if self.autoSave then
		self.autoSave.stop()
	end
	self.autoSave = AutoSave.start(self.store, self.services.projectStore, function(err)
		self:setStatus("Sauvegarde impossible : " .. cleanError(err))
	end)
end

function Editor:loadProject(project: any)
	if self.autoSave then
		self.autoSave.stop()
	end
	self.pageId = nil
	self.store:load(project)
	self:_startAutoSave()
	self.services.projectStore:save(project)
end

function Editor:openProjects()
	local projectStore = self.services.projectStore
	self.picker:openProjects(projectStore:list(), function(id)
		local ok, result = pcall(projectStore.load, projectStore, id)
		if ok then
			self:loadProject(result)
			self:setStatus("Projet " .. result.name .. " ouvert.")
		else
			self:setStatus("Impossible d'ouvrir ce projet : " .. cleanError(result))
		end
	end, function()
		self:loadProject(Editor.newProject())
		self:setStatus("Nouveau projet créé.")
	end)
end

function Editor:generate()
	local project = self.store.project
	local target = self.services.generateTarget()
	local report
	local ok, err = pcall(function()
		self.services.recordChange("GuiCreator : générer " .. project.name, function()
			report = Generator.generate(project, target)
		end)
	end)
	if not ok then
		self:setStatus("Génération impossible : " .. cleanError(err))
		return
	end
	if self.services.selectInStudio then
		local screens = {}
		for _, child in target:GetChildren() do
			if child:GetAttribute("GuiCreatorProject") == project.id then
				table.insert(screens, child)
			end
		end
		self.services.selectInStudio(screens)
	end
	self:setStatus(
		string.format(
			"Généré dans %s : %d page(s), %d élément(s). Regénérer met à jour sans tout recréer.",
			target.Name,
			report.pages,
			report.elements
		)
	)
end

function Editor:destroy()
	if self.autoSave then
		self.autoSave.stop()
	end
	self.root:Destroy()
end

return Editor
