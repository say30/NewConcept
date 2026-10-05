--!strict
-- The bar at the top of the editor: home, project name, pages, screen size, style pack,
-- undo/redo and Générer.

local Canvas = require(script.Parent.Canvas)
local Document = require(script.Parent.Parent.Core.Document)
local Packs = require(script.Parent.Parent.Style.Packs)
local Style = require(script.Parent.Parent.Style.Style)
local Ui = require(script.Parent.Ui)

local Topbar = {}
Topbar.__index = Topbar

function Topbar.new(editor: any, parent: Instance)
	local self = setmetatable({}, Topbar)
	self.editor = editor
	self.frame = Ui.new("Frame", {
		Name = "Topbar",
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self.left = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -600, 1, 0),
		ClipsDescendants = true,
		Parent = self.frame,
	}, { Ui.list("Horizontal", 8, Enum.VerticalAlignment.Center), Ui.padding(0, 10) })
	self.right = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 600, 1, 0),
		Parent = self.frame,
	}, { Ui.list("Horizontal", 8, Enum.VerticalAlignment.Center), Ui.padding(0, 10) });
	(self.right:FindFirstChildOfClass("UIListLayout") :: UIListLayout).HorizontalAlignment =
		Enum.HorizontalAlignment.Right
	return self
end

local function pill(
	text: string,
	selected: boolean,
	order: number,
	parent: Instance,
	onClick: () -> ()
): TextButton
	return Ui.button(text, {
		order = order,
		size = UDim2.fromOffset(math.clamp(#text * 8 + 26, 60, 150), 34),
		color = if selected then Ui.colors.accent else Ui.colors.panelLight,
		textSize = 15,
		parent = parent,
		onClick = onClick,
	})
end

function Topbar:render()
	local editor = self.editor
	local project = editor.store.project
	Ui.clear(self.left)
	Ui.clear(self.right)

	-- Left: home, project and pages.
	Ui.bigButton("Accueil", {
		order = 1,
		color = Ui.colors.panelLight,
		size = UDim2.fromOffset(96, 38),
		textSize = 15,
		parent = self.left,
		onClick = function()
			editor:showHome()
		end,
	})
	Ui.textBox(project.name, {
		order = 2,
		size = UDim2.fromOffset(140, 34),
		onCommit = function(text)
			editor:renameProject(text)
		end,
	}).Parent =
		self.left
	for i, page in Document.getPages(project) do
		pill(page.name, page.id == editor.pageId, 2 + i, self.left, function()
			editor:setPage(page.id)
		end)
	end
	pill("+ Page", false, 100, self.left, function()
		editor.popup:openNewPage()
	end)

	-- Right: screen, style, history, generate.
	for i, device in Canvas.DEVICES do
		pill(device.label, device.id == editor.device, i, self.right, function()
			editor:setDevice(device.id)
		end)
	end
	local pack = Packs.get(project.theme.base)
	local styleButton = Ui.button("Style : " .. pack.label, {
		order = 10,
		size = UDim2.fromOffset(136, 34),
		textSize = 15,
		parent = self.right,
		onClick = function()
			editor.popup:openPacks()
		end,
	})
	styleButton.TextXAlignment = Enum.TextXAlignment.Right
	Ui.padding(0, 10).Parent = styleButton
	Ui.new("Frame", {
		BackgroundColor3 = Style.color(pack.tokens.frame),
		Position = UDim2.new(0, -2, 0.5, -8),
		Size = UDim2.fromOffset(16, 16),
		Parent = styleButton,
	}, { Ui.corner(8), Ui.stroke(Color3.new(1, 1, 1), 1) })
	local history = editor.store.history
	Ui.button("↶", {
		order = 11,
		size = UDim2.fromOffset(38, 34),
		textSize = 20,
		textColor = if history:canUndo() then Ui.colors.text else Ui.colors.muted,
		parent = self.right,
		onClick = function()
			editor.store:undo()
		end,
	})
	Ui.button("↷", {
		order = 12,
		size = UDim2.fromOffset(38, 34),
		textSize = 20,
		textColor = if history:canRedo() then Ui.colors.text else Ui.colors.muted,
		parent = self.right,
		onClick = function()
			editor.store:redo()
		end,
	})
	Ui.bigButton("Générer", {
		order = 20,
		color = Ui.colors.success,
		size = UDim2.fromOffset(110, 40),
		textSize = 18,
		parent = self.right,
		onClick = function()
			editor:generate()
		end,
	})
end

return Topbar
