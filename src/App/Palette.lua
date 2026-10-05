--!strict
-- The "Ajouter" gallery on the left: pick a category, then click a picture to add it.
-- Every picture is a live miniature in the project's style pack.

local Elements = require(script.Parent.Parent.Catalog.Elements)
local Icons = require(script.Parent.Parent.Visual.Icons)
local Preview = require(script.Parent.Preview)
local Ui = require(script.Parent.Ui)

local Palette = {}
Palette.__index = Palette

local TABS_HEIGHT = 128
local TILE = Vector2.new(124, 112)

function Palette.new(editor: any, parent: Instance)
	local self = setmetatable({}, Palette)
	self.editor = editor
	self.category = "Windows"
	self.renderedFor = nil :: string?
	self.frame = Ui.new("Frame", {
		Name = "Palette",
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	Ui.title("Ajouter", 22, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 28),
		Parent = self.frame,
	})
	self.tabs = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, TABS_HEIGHT - 44),
		Parent = self.frame,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(60, 40),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.grid = Ui.scroll({
		Position = UDim2.fromOffset(0, TABS_HEIGHT),
		Size = UDim2.new(1, 0, 1, -TABS_HEIGHT),
		Parent = self.frame,
	})
	Ui.padding(6, 8).Parent = self.grid
	Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.grid,
	})
	return self
end

-- Redraws when the category or the style pack changed (miniatures are costly).
function Palette:render()
	local project = self.editor.store.project
	local key = self.category .. "|" .. project.theme.base
	if self.renderedFor == key then
		return
	end
	self.renderedFor = key

	Ui.clear(self.tabs)
	for i, category in Elements.categories() do
		local selected = category.id == self.category
		local tab = Ui.new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = if selected then Ui.colors.accentDark else Ui.colors.panelLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = self.tabs,
		}, {
			Ui.corner(8),
			Ui.stroke(if selected then Ui.colors.selection else Ui.colors.border, if selected then 2 else 1),
		})
		local holder = Ui.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(24, 24),
			Parent = tab,
		})
		Icons.build(category.icon, holder, 1)
		Ui.label(category.label, {
			TextSize = 11,
			Font = Ui.fontBold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 1, -14),
			Size = UDim2.new(1, 0, 0, 12),
			Parent = tab,
		})
		Ui.connect(tab, "MouseButton1Click", function()
			self.category = category.id
			self:render()
		end)
	end

	Ui.clear(self.grid)
	for _, category in Elements.categories() do
		if category.id == self.category then
			for i, entry in category.entries do
				local _, picture = Ui.tile({
					order = i,
					label = entry.label,
					size = UDim2.fromOffset(TILE.X, TILE.Y),
					parent = self.grid,
					onClick = function()
						self.editor:insertElement(entry.make(), category.id)
					end,
				})
				local template = entry.make()
				Preview.draw(picture, { template }, {
					project = project,
					box = Vector2.new(TILE.X - 10, TILE.Y - 30),
					backdrop = true,
					lite = true,
					screen = Preview.measure({ template }, if category.id == "Icons" then 12 else 20),
				})
			end
		end
	end
end

return Palette
