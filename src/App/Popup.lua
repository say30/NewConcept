--!strict
-- A window over the editor for bigger choices: the style pack (shown as previews of the
-- open page), the projects of the place, and what a new page starts with.

local Document = require(script.Parent.Parent.Core.Document)
local Icons = require(script.Parent.Parent.Visual.Icons)
local Packs = require(script.Parent.Parent.Style.Packs)
local Preview = require(script.Parent.Preview)
local Ui = require(script.Parent.Ui)

local Popup = {}
Popup.__index = Popup

function Popup.new(editor: any, parent: Instance)
	local self = setmetatable({}, Popup)
	self.editor = editor
	self.backdrop = Ui.new("TextButton", {
		Name = "Popup",
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
		Size = UDim2.new(1, -80, 1, -80),
		Parent = self.backdrop,
	}, { Ui.corner(16), Ui.stroke(Ui.colors.border, 2) })
	self.title = Ui.title("", 26, {
		Position = UDim2.fromOffset(22, 16),
		Size = UDim2.new(1, -200, 0, 32),
		Parent = self.panel,
	})
	local close = Ui.bigButton("Fermer", {
		color = Ui.colors.danger,
		size = UDim2.fromOffset(110, 40),
		onClick = function()
			self:close()
		end,
	})
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -18, 0, 14)
	close.Parent = self.panel
	self.body = Ui.scroll({
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 1, -80),
		Parent = self.panel,
	})
	return self
end

function Popup:close()
	self.backdrop.Visible = false
	for _, child in self.body:GetChildren() do
		child:Destroy()
	end
end

function Popup:_open(title: string, cell: Vector2): Frame
	self:close()
	self.title.Text = title
	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(16, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.padding(6),
	})
	self.backdrop.Visible = true
	return grid
end

-- The open page drawn in every style pack; clicking one switches the whole project.
function Popup:openPacks()
	local editor = self.editor
	local project = editor.store.project
	local grid = self:_open("Choisis un style", Vector2.new(290, 210))
	local page = editor:currentPage()
	local templates = {}
	if page then
		for _, childId in project.nodes[page.rootId].children do
			table.insert(templates, Document.toTemplate(project, childId))
		end
	end
	if #templates == 0 then
		local Recipes = require(script.Parent.Parent.Catalog.Recipes)
		templates = Recipes.build(Recipes.get("Shop") :: any, {})
	end
	local screen = if #templates == 1 then Preview.measure(templates, 30) else nil
	for i, pack in Packs.list() do
		local _, picture = Ui.tile({
			order = i,
			label = pack.label,
			selected = project.theme.base == pack.name,
			parent = grid,
			onClick = function()
				self:close()
				editor:setPack(pack.name)
			end,
		})
		Preview.draw(picture, templates, {
			pack = pack.name,
			box = Vector2.new(280, 176),
			backdrop = true,
			lite = true,
			screen = screen,
		})
	end
end

local function iconTile(
	grid: Instance,
	order: number,
	iconId: string,
	label: string,
	detail: string,
	onClick: () -> ()
)
	local _, picture = Ui.tile({ order = order, label = label, parent = grid, onClick = onClick })
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(64, 64),
		Parent = picture,
	})
	Icons.build(iconId, holder, 1)
	Ui.label(detail, {
		TextColor3 = Ui.colors.muted,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = picture,
	})
end

function Popup:openProjects(projects: { any }, onOpen: (id: string) -> (), onNew: () -> ())
	local grid = self:_open("Projets de cette place", Vector2.new(210, 140))
	iconTile(grid, 0, "Plus", "Nouveau projet", "Repartir de zéro", function()
		self:close()
		onNew()
	end)
	for i, summary in projects do
		iconTile(
			grid,
			i,
			"Chest",
			summary.name,
			os.date("Enregistré le %d/%m à %H:%M", summary.savedAt) :: string,
			function()
				self:close()
				onOpen(summary.id)
			end
		)
	end
end

-- What a new page starts with: the assistant or an empty page.
function Popup:openNewPage()
	local editor = self.editor
	local grid = self:_open("Nouvelle page", Vector2.new(240, 150))
	iconTile(grid, 1, "LuckyBlock", "Avec l'assistant", "Questions en images", function()
		self:close()
		editor:showWizard(nil)
	end)
	iconTile(grid, 2, "Plus", "Page vide", "Tu ajoutes ce que tu veux", function()
		self:close()
		editor:addPage()
	end)
end

return Popup
