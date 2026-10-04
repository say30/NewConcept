--!strict
-- The bar at the top: project, pages, screen size, theme, undo/redo and Générer.

local Canvas = require(script.Parent.Canvas)
local Commands = require(script.Parent.Parent.Core.Commands)
local Document = require(script.Parent.Parent.Core.Document)
local Themes = require(script.Parent.Parent.Style.Themes)
local Ui = require(script.Parent.Ui)

local Topbar = {}
Topbar.__index = Topbar

function Topbar.new(editor: any, parent: Instance)
	local self = setmetatable({}, Topbar)
	self.editor = editor
	self.frame = Ui.new("Frame", {
		Name = "Topbar",
		BackgroundColor3 = Ui.colors.background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self.left = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -580, 1, 0),
		Parent = self.frame,
	}, { Ui.list("Horizontal", 6, Enum.VerticalAlignment.Center), Ui.padding(0, 8) })
	self.right = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 580, 1, 0),
		Parent = self.frame,
	}, { Ui.list("Horizontal", 6, Enum.VerticalAlignment.Center), Ui.padding(0, 8) });
	(self.right:FindFirstChildOfClass("UIListLayout") :: UIListLayout).HorizontalAlignment =
		Enum.HorizontalAlignment.Right
	return self
end

function Topbar:render()
	local editor = self.editor
	local project = editor.store.project
	Ui.clear(self.left)
	Ui.clear(self.right)

	-- Left: project and pages.
	Ui.button("Projets", {
		order = 1,
		size = UDim2.fromOffset(70, 28),
		parent = self.left,
		onClick = function()
			editor:openProjects()
		end,
	})
	Ui.textBox(project.name, {
		order = 2,
		size = UDim2.fromOffset(130, 28),
		onCommit = function(text)
			editor:renameProject(text)
		end,
	}).Parent =
		self.left
	Ui.label(
		"Pages :",
		{ LayoutOrder = 3, Size = UDim2.fromOffset(46, 28), TextColor3 = Ui.colors.muted, Parent = self.left }
	)
	for i, page in Document.getPages(project) do
		local current = page.id == editor.pageId
		Ui.button(page.name, {
			order = 3 + i,
			size = UDim2.fromOffset(math.clamp(#page.name * 8 + 20, 60, 140), 28),
			color = if current then Ui.colors.accent else Ui.colors.panelLight,
			bold = current,
			parent = self.left,
			onClick = function()
				editor:setPage(page.id)
			end,
		})
	end
	Ui.button("+ Page", {
		order = 100,
		size = UDim2.fromOffset(64, 28),
		parent = self.left,
		onClick = function()
			editor:addPage()
		end,
	})

	-- Right: screen, theme, history, generate.
	for i, device in Canvas.DEVICES do
		local current = device.id == editor.device
		Ui.button(device.label, {
			order = i,
			size = UDim2.fromOffset(64, 28),
			textSize = 13,
			color = if current then Ui.colors.accentDark else Ui.colors.panelLight,
			parent = self.right,
			onClick = function()
				editor:setDevice(device.id)
			end,
		})
	end
	local themeName = project.theme.base
	Ui.button("Thème : " .. themeName, {
		order = 10,
		size = UDim2.fromOffset(120, 28),
		textSize = 13,
		parent = self.right,
		onClick = function()
			local order = Themes.ORDER
			local index = (table.find(order, themeName) or 0) % #order + 1
			editor:dispatch(Commands.SetTheme.new(order[index]))
		end,
	})
	local history = editor.store.history
	Ui.button("Annuler", {
		order = 11,
		size = UDim2.fromOffset(62, 28),
		textSize = 13,
		textColor = if history:canUndo() then Ui.colors.text else Ui.colors.muted,
		parent = self.right,
		onClick = function()
			editor.store:undo()
		end,
	})
	Ui.button("Rétablir", {
		order = 12,
		size = UDim2.fromOffset(62, 28),
		textSize = 13,
		textColor = if history:canRedo() then Ui.colors.text else Ui.colors.muted,
		parent = self.right,
		onClick = function()
			editor.store:redo()
		end,
	})
	Ui.button("Générer", {
		order = 20,
		size = UDim2.fromOffset(84, 30),
		color = Ui.colors.success,
		parent = self.right,
		onClick = function()
			editor:generate()
		end,
	})
end

return Topbar
