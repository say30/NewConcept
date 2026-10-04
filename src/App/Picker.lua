--!strict
-- The big visual list that opens on "Ajouter un bouton", "Ajouter une carte"... and the
-- preset library. Every tile is a real preview drawn with the project's current theme.

local Builder = require(script.Parent.Parent.Generator.Builder)
local Commands = require(script.Parent.Parent.Core.Commands)
local Document = require(script.Parent.Parent.Core.Document)
local NodeTypes = require(script.Parent.Parent.Schema.NodeTypes)
local Presets = require(script.Parent.Parent.Catalog.Presets)
local Store = require(script.Parent.Parent.Core.Store)
local Table = require(script.Parent.Parent.Util.Table)
local Variants = require(script.Parent.Parent.Catalog.Variants)
local Ui = require(script.Parent.Ui)

local Picker = {}
Picker.__index = Picker

local TILE = Vector2.new(196, 150)
local PREVIEW = Vector2.new(184, 104)

local SMALL = { Button = true, Text = true, Icon = true, Image = true }
local MEDIUM = { Card = true, Panel = true, List = true }

local function pageSizeFor(typeName: string): Vector2
	if SMALL[typeName] then
		return Vector2.new(300, 170)
	elseif MEDIUM[typeName] then
		return Vector2.new(460, 300)
	end
	return Vector2.new(1000, 600)
end

function Picker.new(editor: any, parent: Instance)
	local self = setmetatable({}, Picker)
	self.editor = editor
	self.backdrop = Ui.new("TextButton", {
		Name = "Picker",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 200,
		Visible = false,
		Parent = parent,
	})
	self.panel = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -60, 1, -60),
		Parent = self.backdrop,
	}, { Ui.corner(10), Ui.stroke(Ui.colors.border) })
	self.title = Ui.label("", {
		Font = Ui.fontBold,
		TextSize = 18,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -140, 0, 26),
		Parent = self.panel,
	})
	self.subtitle = Ui.label("", {
		TextColor3 = Ui.colors.muted,
		TextSize = 13,
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -140, 0, 18),
		Parent = self.panel,
	})
	Ui.button("Fermer", {
		size = UDim2.fromOffset(90, 30),
		parent = self.panel,
		onClick = function()
			self:close()
		end,
	}).Position =
		UDim2.new(1, -106, 0, 14)
	self.grid = Ui.scroll({ Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 1, -78) })
	self.grid.Parent = self.panel
	Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.grid,
	})
	return self
end

function Picker:close()
	self.backdrop.Visible = false
	Ui.clear(self.grid)
end

-- Draws a template in a small frame, using the current project's theme.
function Picker:_preview(template: any, typeName: string, parent: Instance)
	local mini = Store.new(Document.newProject("Preview"))
	mini.project.theme = Table.deepCopy(self.editor.store.project.theme)
	local _, pageId = mini:dispatch(Commands.AddPage.new("Preview"))
	local page = mini.project.pages[pageId]
	local ok = mini:dispatch(Commands.InsertTree.new(template, page.rootId))
	if not ok then
		return
	end

	local pageSize = pageSizeFor(typeName)
	local holder = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.stage,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(PREVIEW.X, PREVIEW.Y),
		Parent = parent,
	}, { Ui.corner(6) })
	local stage = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(pageSize.X, pageSize.Y),
		Parent = holder,
	})
	Ui.new("UIScale", {
		Scale = math.min(PREVIEW.X / pageSize.X, PREVIEW.Y / pageSize.Y),
		Parent = stage,
	})
	local ctx = Builder.newContext(mini.project, "preview", pageSize)
	Builder.syncNode(ctx, page.rootId, stage)
end

function Picker:_tile(
	order: number,
	label: string,
	detail: string?,
	template: any,
	typeName: string,
	onPick: () -> ()
)
	local tile = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.panelLight,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = self.grid,
	}, { Ui.corner(8) })
	self:_preview(template, typeName, tile)
	Ui.label(label, {
		Font = Ui.fontBold,
		Position = UDim2.fromOffset(8, PREVIEW.Y + 10),
		Size = UDim2.new(1, -16, 0, 18),
		Parent = tile,
	})
	if detail then
		Ui.label(detail, {
			TextColor3 = Ui.colors.muted,
			TextSize = 12,
			Position = UDim2.fromOffset(8, PREVIEW.Y + 28),
			Size = UDim2.new(1, -16, 0, 14),
			Parent = tile,
		})
	end
	-- A transparent button on top, so buttons inside the preview cannot take the click.
	local catcher = Ui.new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = tile,
	})
	Ui.connect(catcher, "MouseButton1Click", onPick)
end

function Picker:openVariants(typeName: string, parentId: string)
	Ui.clear(self.grid)
	local label = NodeTypes.get(typeName).label
	self.title.Text = "Ajouter : " .. label
	self.subtitle.Text = "Choisis un point de départ. Tout restera modifiable ensuite."
	for i, variant in Variants.list(typeName) do
		self:_tile(i, variant.label, nil, variant.template, typeName, function()
			self:close()
			self.editor:insertTemplate(variant.template, parentId, variant.id)
		end)
	end
	self.backdrop.Visible = true
end

function Picker:openPresets(pageRootId: string)
	Ui.clear(self.grid)
	self.title.Text = "Presets"
	self.subtitle.Text = "Une interface complète à modifier librement : rien n'est figé."
	for i, preset in Presets.list() do
		self:_tile(i, preset.label, preset.description, preset.template, "Preset", function()
			self:close()
			self.editor:insertTemplate(preset.template, pageRootId, "Preset." .. preset.id)
		end)
	end
	self.backdrop.Visible = true
end

-- Saved projects of this place, plus a tile to start a new one.
function Picker:openProjects(projects: { any }, onOpen: (id: string) -> (), onNew: () -> ())
	Ui.clear(self.grid)
	self.title.Text = "Projets de cette place"
	self.subtitle.Text = "Les projets sont enregistrés dans ServerStorage, avec la place."
	local function textTile(order: number, label: string, detail: string, color: Color3, onPick: () -> ())
		local tile = Ui.button(
			label,
			{ order = order, color = color, textSize = 16, parent = self.grid, onClick = onPick }
		)
		Ui.label(detail, {
			TextColor3 = Ui.colors.muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 8, 1, -28),
			Size = UDim2.new(1, -16, 0, 16),
			Parent = tile,
		})
	end
	textTile(0, "+ Nouveau projet", "Commence avec une page vide", Ui.colors.accentDark, function()
		self:close()
		onNew()
	end)
	for i, summary in projects do
		textTile(
			i,
			summary.name,
			os.date("Enregistré le %d/%m à %H:%M", summary.savedAt) :: string,
			Ui.colors.panelLight,
			function()
				self:close()
				onOpen(summary.id)
			end
		)
	end
	self.backdrop.Visible = true
end

return Picker
