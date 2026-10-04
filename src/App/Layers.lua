--!strict
-- The left panel: the tree of the current page. Click to select, click the name of the
-- selected element to rename it, and use the two small buttons to hide or lock.

local Commands = require(script.Parent.Parent.Core.Commands)
local NodeTypes = require(script.Parent.Parent.Schema.NodeTypes)
local Ui = require(script.Parent.Ui)

local Layers = {}
Layers.__index = Layers

local ROW_HEIGHT = 26
local INDENT = 14

function Layers.new(editor: any, parent: Instance)
	local self = setmetatable({}, Layers)
	self.editor = editor
	self.renaming = nil :: string?
	self.frame = Ui.new("Frame", {
		Name = "Layers",
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	Ui.label("Calques", {
		Font = Ui.fontBold,
		TextSize = 15,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 20),
		Parent = self.frame,
	})
	self.scroll = Ui.scroll({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34) })
	self.scroll.Parent = self.frame
	Ui.list("Vertical", 1).Parent = self.scroll
	Ui.padding(4, 6).Parent = self.scroll
	return self
end

function Layers:_row(id: string, depth: number, order: number)
	local editor = self.editor
	local store = editor.store
	local node = store.project.nodes[id]
	local selected = store.selection:isSelected(id)
	local isRoot = node.parent == nil

	local rowFrame = Ui.new("Frame", {
		BackgroundColor3 = if selected then Ui.colors.accentDark else Ui.colors.panel,
		BackgroundTransparency = if selected then 0 else 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = order,
		Parent = self.scroll,
	}, { Ui.corner(4) })

	local left = 4 + depth * INDENT
	local nameWidth = UDim2.new(1, -(left + 64), 1, 0)
	if self.renaming == id then
		local box = Ui.textBox(node.name, {
			size = nameWidth,
			onCommit = function(text)
				self.renaming = nil
				if text ~= node.name then
					editor:dispatch(Commands.Rename.new(id, text))
				else
					self:render()
				end
			end,
		})
		box.Position = UDim2.fromOffset(left, 0)
		box.Parent = rowFrame
		box:CaptureFocus()
	else
		local nameButton = Ui.new("TextButton", {
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = node.name .. "  ",
			RichText = false,
			Font = if isRoot then Ui.fontBold else Ui.font,
			TextSize = 14,
			TextColor3 = if node.editor.hidden then Ui.colors.muted else Ui.colors.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(left, 0),
			Size = nameWidth,
			Parent = rowFrame,
		})
		Ui.label(NodeTypes.get(node.type).label, {
			Position = UDim2.new(1, -(64 + 70), 0, 0),
			Size = UDim2.new(0, 66, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.colors.muted,
			TextSize = 11,
			Parent = rowFrame,
		})
		Ui.connect(nameButton, "MouseButton1Click", function()
			if isRoot then
				store.selection:clear()
			elseif selected then
				self.renaming = id
				self:render()
			else
				store.selection:set({ id })
			end
		end)
	end

	if not isRoot then
		Ui.button(if node.editor.hidden then "Caché" else "Vu", {
			size = UDim2.fromOffset(30, 20),
			textSize = 11,
			bold = false,
			color = if node.editor.hidden then Ui.colors.panelLight else Ui.colors.panel,
			textColor = if node.editor.hidden then Ui.colors.text else Ui.colors.muted,
			parent = rowFrame,
			onClick = function()
				editor:dispatch(Commands.SetEditorFlag.new(id, "hidden", not node.editor.hidden))
			end,
		}).Position =
			UDim2.new(1, -62, 0.5, -10)
		Ui.button(if node.editor.locked then "Verr." else "Libre", {
			size = UDim2.fromOffset(30, 20),
			textSize = 11,
			bold = false,
			color = if node.editor.locked then Ui.colors.panelLight else Ui.colors.panel,
			textColor = if node.editor.locked then Ui.colors.text else Ui.colors.muted,
			parent = rowFrame,
			onClick = function()
				editor:dispatch(Commands.SetEditorFlag.new(id, "locked", not node.editor.locked))
			end,
		}).Position =
			UDim2.new(1, -30, 0.5, -10)
	end
end

function Layers:render()
	Ui.clear(self.scroll)
	local page = self.editor:currentPage()
	if not page then
		return
	end
	local project = self.editor.store.project
	local order = 0
	local function visit(id: string, depth: number)
		order += 1
		self:_row(id, depth, order)
		for _, childId in project.nodes[id].children do
			visit(childId, depth + 1)
		end
	end
	visit(page.rootId, 0)
end

return Layers
