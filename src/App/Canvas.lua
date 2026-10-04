--!strict
-- The work area: a live preview of the current page on a simulated screen, with selection,
-- moving and resizing. The preview is built by the same Builder as the final generation.

local Builder = require(script.Parent.Parent.Generator.Builder)
local Commands = require(script.Parent.Parent.Core.Commands)
local Schema = require(script.Parent.Parent.Schema.NodeTypes)
local Ui = require(script.Parent.Ui)

local Canvas = {}
Canvas.__index = Canvas

Canvas.DEVICES = {
	{ id = "Mobile", label = "Mobile", size = Vector2.new(844, 390) },
	{ id = "PC", label = "PC", size = Vector2.new(1366, 768) },
	{ id = "Console", label = "Console", size = Vector2.new(1920, 1080) },
}

local HANDLE = 8
local MARGIN = 24

function Canvas.deviceSize(id: string): Vector2
	for _, device in Canvas.DEVICES do
		if device.id == id then
			return device.size
		end
	end
	return Canvas.DEVICES[2].size
end

function Canvas.new(editor: any, parent: Instance)
	local self = setmetatable({}, Canvas)
	self.editor = editor
	self.instances = {} :: { [string]: Instance }
	self.drag = nil :: any

	self.area = Ui.new("Frame", {
		Name = "Canvas",
		BackgroundColor3 = Color3.fromRGB(22, 23, 27),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self.stage = Ui.new(
		"Frame",
		{
			Name = "Stage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Ui.colors.stage,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = self.area,
		},
		{
			Ui.new("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(120, 160, 200), Color3.fromRGB(70, 95, 125)),
				Rotation = 90,
			}),
		}
	)
	self.scale = Ui.new("UIScale", { Parent = self.stage })
	self.deviceLabel = Ui.label("", {
		Position = UDim2.new(0, 10, 1, -24),
		Size = UDim2.new(0, 300, 0, 18),
		TextColor3 = Ui.colors.muted,
		TextSize = 12,
		Parent = self.area,
	})

	-- Selection boxes and handles are drawn outside the scaled stage so they keep their size.
	self.overlay = Ui.new("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = self.area,
	})

	-- One transparent button above everything receives all mouse input.
	self.input = Ui.new("TextButton", {
		Name = "Input",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = self.area,
	})
	Ui.connect(self.input, "InputBegan", function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_mouseDown(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	Ui.connect(self.input, "InputChanged", function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_mouseMove(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	Ui.connect(self.input, "InputEnded", function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_mouseUp()
		end
	end)
	Ui.connect(self.input, "MouseLeave", function()
		self:_mouseUp()
	end)
	Ui.onPropertyChanged(self.area, "AbsoluteSize", function()
		self:_fit()
		self:renderOverlay()
	end)
	return self
end

function Canvas:_fit()
	local size = Canvas.deviceSize(self.editor.device)
	local area = Ui.absoluteSize(self.area)
	self.stage.Size = UDim2.fromOffset(size.X, size.Y)
	local scale = math.min((area.X - MARGIN * 2) / size.X, (area.Y - MARGIN * 2) / size.Y)
	self.scale.Scale = math.max(scale, 0.05)
end

function Canvas:render()
	local editor = self.editor
	local page = editor:currentPage()
	self:_fit()
	local size = Canvas.deviceSize(editor.device)
	self.deviceLabel.Text = string.format("%s · %d × %d", editor.device, size.X, size.Y)
	if not page then
		for _, child in self.stage:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		self.instances = {}
		self:renderOverlay()
		return
	end
	-- Only the current page is shown on the stage.
	for _, child in self.stage:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("GuiCreatorId") ~= page.rootId then
			child:Destroy()
		end
	end
	local ctx = Builder.newContext(editor.store.project, "preview", size, self.instances)
	Builder.syncNode(ctx, page.rootId, self.stage)
	self.instances = ctx.instances
	self:renderOverlay()
end

--------------------------------------------------------------------------------
-- Overlay
--------------------------------------------------------------------------------

function Canvas:_rectOf(id: string): (Vector2?, Vector2?)
	local instance = self.instances[id] :: any
	if not instance or not instance:IsA("GuiObject") then
		return nil, nil
	end
	local origin = Ui.absolutePosition(self.area)
	return Ui.absolutePosition(instance) - origin, Ui.absoluteSize(instance)
end

function Canvas:_handles(position: Vector2, size: Vector2): { { name: string, at: Vector2 } }
	local x0, y0 = position.X, position.Y
	local x1, y1 = x0 + size.X, y0 + size.Y
	local xm, ym = (x0 + x1) / 2, (y0 + y1) / 2
	return {
		{ name = "TL", at = Vector2.new(x0, y0) },
		{ name = "T", at = Vector2.new(xm, y0) },
		{ name = "TR", at = Vector2.new(x1, y0) },
		{ name = "R", at = Vector2.new(x1, ym) },
		{ name = "BR", at = Vector2.new(x1, y1) },
		{ name = "B", at = Vector2.new(xm, y1) },
		{ name = "BL", at = Vector2.new(x0, y1) },
		{ name = "L", at = Vector2.new(x0, ym) },
	}
end

function Canvas:renderOverlay()
	Ui.clear(self.overlay)
	local selection = self.editor.store.selection:get()
	for index, id in selection do
		local position, size = self:_rectOf(id)
		if position and size then
			Ui.new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(position.X, position.Y),
				Size = UDim2.fromOffset(size.X, size.Y),
				Parent = self.overlay,
			}, { Ui.stroke(Ui.colors.selection, 2) })
			if index == #selection then
				for _, handle in self:_handles(position, size) do
					Ui.new("Frame", {
						BackgroundColor3 = Color3.new(1, 1, 1),
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(handle.at.X - HANDLE / 2, handle.at.Y - HANDLE / 2),
						Size = UDim2.fromOffset(HANDLE, HANDLE),
						Parent = self.overlay,
					}, { Ui.stroke(Ui.colors.selection, 1.5) })
				end
				local node = self.editor.store.project.nodes[id]
				if node then
					Ui.label(node.name, {
						Position = UDim2.fromOffset(position.X, position.Y - 20),
						Size = UDim2.fromOffset(240, 18),
						TextSize = 12,
						Font = Ui.fontBold,
						TextColor3 = Ui.colors.selection,
						TextStrokeTransparency = 0.4,
						Parent = self.overlay,
					})
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Mouse
--------------------------------------------------------------------------------

local function depthOf(project: any, id: string): number
	local depth = 0
	local node = project.nodes[id]
	while node and node.parent do
		depth += 1
		node = project.nodes[node.parent]
	end
	return depth
end

-- The deepest visible, unlocked element under the point (in widget coordinates).
function Canvas:hitTest(point: Vector2): string?
	local project = self.editor.store.project
	local best, bestDepth, bestZ = nil, -1, -math.huge
	for id, instance in self.instances do
		local node = project.nodes[id]
		local gui = instance :: any
		if node and node.parent and not node.editor.locked and gui:IsA("GuiObject") and gui.Visible then
			local p, s = Ui.absolutePosition(gui), Ui.absoluteSize(gui)
			if point.X >= p.X and point.Y >= p.Y and point.X <= p.X + s.X and point.Y <= p.Y + s.Y then
				local depth = depthOf(project, id)
				if depth > bestDepth or (depth == bestDepth and gui.ZIndex >= bestZ) then
					best, bestDepth, bestZ = id, depth, gui.ZIndex
				end
			end
		end
	end
	return best
end

function Canvas:_handleAt(point: Vector2): string?
	local id = self.editor.store.selection:primary()
	if not id then
		return nil
	end
	local position, size = self:_rectOf(id)
	if not position or not size then
		return nil
	end
	local local_ = point - Ui.absolutePosition(self.area)
	for _, handle in self:_handles(position, size) do
		if (local_ - handle.at).Magnitude <= HANDLE then
			return handle.name
		end
	end
	return nil
end

local function parentLayoutKind(editor: any, id: string): string
	local project = editor.store.project
	local node = project.nodes[id]
	local parent = node and node.parent and project.nodes[node.parent]
	if not parent or parent.type == "Page" or parent.type == "Button" then
		return "None"
	end
	local props = Schema.effectiveProps(parent)
	return props.layout and props.layout.kind or "None"
end

function Canvas:_mouseDown(point: Vector2)
	local editor = self.editor
	local store = editor.store
	local handle = self:_handleAt(point)
	local id = if handle then store.selection:primary() else self:hitTest(point)

	if not id then
		store.selection:clear()
		return
	end
	if not handle and store.selection:primary() ~= id then
		store.selection:set({ id })
	end

	local node = store.project.nodes[id]
	if node.editor.locked then
		return
	end
	local layoutKind = parentLayoutKind(editor, id)
	if not handle and layoutKind ~= "None" then
		return -- placed by its parent's layout: nothing to drag
	end
	local instance = self.instances[id] :: any
	local parentInstance = instance and instance.Parent
	if not parentInstance or not parentInstance:IsA("GuiObject") then
		return
	end
	local props = Schema.effectiveProps(node)
	self.drag = {
		id = id,
		handle = handle,
		start = point,
		moved = false,
		position = table.clone(props.position),
		size = table.clone(props.size),
		anchor = table.clone(props.anchor or { 0.5, 0.5 }),
		parentSize = Ui.absoluteSize(parentInstance) / self.scale.Scale,
	}
end

local function round(value: number): number
	return math.round(value)
end

local function roundScale(value: number): number
	return math.round(value * 1000) / 1000
end

-- Applies a change in page pixels to one axis of a {scale, offset} pair, keeping its mode.
local function shift(
	scaleValue: number,
	offset: number,
	delta: number,
	parentLength: number
): (number, number)
	if scaleValue ~= 0 and parentLength > 0 then
		return roundScale(scaleValue + delta / parentLength), offset
	end
	return scaleValue, round(offset + delta)
end

function Canvas:_mouseMove(point: Vector2)
	local drag = self.drag
	if not drag then
		return
	end
	local delta = (point - drag.start) / self.scale.Scale
	if not drag.moved then
		if delta.Magnitude < 3 then
			return
		end
		drag.moved = true
		self.editor.dragging = true
		self.editor.store:beginGroup(if drag.handle then "Resize" else "Move")
	end

	local position = table.clone(drag.position)
	local size = table.clone(drag.size)
	local parentSize = drag.parentSize
	local handle = drag.handle

	if not handle then
		position[1], position[2] = shift(position[1], position[2], delta.X, parentSize.X)
		position[3], position[4] = shift(position[3], position[4], delta.Y, parentSize.Y)
	else
		local ax, ay = drag.anchor[1], drag.anchor[2]
		local dw, dh, dx, dy = 0, 0, 0, 0
		if string.find(handle, "R") then
			dw = delta.X
			dx = delta.X * ax
		elseif string.find(handle, "L") then
			dw = -delta.X
			dx = delta.X * (1 - ax)
		end
		if string.find(handle, "B") then
			dh = delta.Y
			dy = delta.Y * ay
		elseif string.find(handle, "T") then
			dh = -delta.Y
			dy = delta.Y * (1 - ay)
		end
		size[1], size[2] = shift(size[1], size[2], dw, parentSize.X)
		size[3], size[4] = shift(size[3], size[4], dh, parentSize.Y)
		position[1], position[2] = shift(position[1], position[2], dx, parentSize.X)
		position[3], position[4] = shift(position[3], position[4], dy, parentSize.Y)
		-- Never let an element shrink to nothing.
		if size[1] <= 0 and size[2] < 4 then
			size[1], size[2] = 0, 4
		end
		if size[3] <= 0 and size[4] < 4 then
			size[3], size[4] = 0, 4
		end
	end

	self.editor:dispatch(Commands.SetProps.new(drag.id, {
		{ path = { "position" }, value = position },
		{ path = { "size" }, value = size },
	}))
end

function Canvas:_mouseUp()
	local drag = self.drag
	self.drag = nil
	if drag and drag.moved then
		self.editor.store:endGroup()
		self.editor.dragging = false
		self.editor:refresh()
	end
end

return Canvas
