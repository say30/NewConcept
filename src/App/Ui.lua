--!strict
-- Small helpers to build the plugin's own interface with plain Instances.

local Ui = {}

-- Colours of the plugin window itself (not of the user's interface).
Ui.colors = {
	background = Color3.fromRGB(23, 26, 38),
	panel = Color3.fromRGB(31, 35, 51),
	panelLight = Color3.fromRGB(42, 47, 69),
	field = Color3.fromRGB(18, 20, 29),
	border = Color3.fromRGB(53, 59, 87),
	text = Color3.fromRGB(242, 244, 255),
	muted = Color3.fromRGB(154, 163, 199),
	accent = Color3.fromRGB(63, 169, 245),
	accentDark = Color3.fromRGB(31, 111, 184),
	danger = Color3.fromRGB(255, 77, 94),
	success = Color3.fromRGB(69, 194, 74),
	warning = Color3.fromRGB(255, 197, 49),
	purple = Color3.fromRGB(183, 107, 255),
	selection = Color3.fromRGB(255, 197, 49),
	stage = Color3.fromRGB(90, 120, 150),
	outline = Color3.fromRGB(14, 16, 24),
}

Ui.font = Enum.Font.BuilderSans
Ui.fontBold = Enum.Font.BuilderSansBold
Ui.fontTitle = Enum.Font.FredokaOne

-- Connecting is routed through here so the test runner can build the interface without
-- Roblox events.
function Ui.connect(instance: Instance, event: string, fn: (...any) -> ()): any
	return (instance :: any)[event]:Connect(fn)
end

function Ui.onPropertyChanged(instance: Instance, property: string, fn: () -> ()): any
	return instance:GetPropertyChangedSignal(property):Connect(fn)
end

-- Absolute size and position, or zero where layout has not happened (the test runner).
function Ui.absoluteSize(instance: Instance): Vector2
	local ok, value = pcall(function()
		return (instance :: any).AbsoluteSize
	end)
	return if ok then value else Vector2.zero
end

function Ui.absolutePosition(instance: Instance): Vector2
	local ok, value = pcall(function()
		return (instance :: any).AbsolutePosition
	end)
	return if ok then value else Vector2.zero
end

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Ui.padding(all: number, horizontal: number?): UIPadding
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, horizontal or all),
		PaddingRight = UDim.new(0, horizontal or all),
	})
end

function Ui.list(
	direction: "Horizontal" | "Vertical",
	spacing: number,
	align: Enum.VerticalAlignment?
): UIListLayout
	return Ui.new("UIListLayout", {
		FillDirection = if direction == "Horizontal"
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = align or Enum.VerticalAlignment.Top,
	})
end

function Ui.stroke(color: Color3, thickness: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.label(text: string, props: { [string]: any }?): TextLabel
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Ui.colors.text,
		Font = Ui.font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 20),
	})
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

export type ButtonOptions = {
	color: Color3?,
	textColor: Color3?,
	size: UDim2?,
	order: number?,
	bold: boolean?,
	textSize: number?,
	parent: Instance?,
	onClick: (() -> ())?,
}

function Ui.button(text: string, options: ButtonOptions?): TextButton
	local o: ButtonOptions = options or {}
	local button = Ui.new("TextButton", {
		Text = text,
		Font = if o.bold == false then Ui.font else Ui.fontBold,
		TextSize = o.textSize or 14,
		TextColor3 = o.textColor or Ui.colors.text,
		BackgroundColor3 = o.color or Ui.colors.panelLight,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Size = o.size or UDim2.new(0, 90, 0, 28),
		LayoutOrder = o.order or 0,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, { Ui.corner(6) })
	if o.onClick then
		Ui.connect(button, "MouseButton1Click", o.onClick)
	end
	if o.parent then
		button.Parent = o.parent
	end
	return button
end

export type BoxOptions = {
	size: UDim2?,
	order: number?,
	placeholder: string?,
	multiline: boolean?,
	onCommit: ((text: string) -> ())?,
}

function Ui.textBox(text: string, options: BoxOptions?): TextBox
	local o: BoxOptions = options or {}
	local box = Ui.new("TextBox", {
		Text = text,
		PlaceholderText = o.placeholder or "",
		PlaceholderColor3 = Ui.colors.muted,
		ClearTextOnFocus = false,
		MultiLine = o.multiline == true,
		TextWrapped = o.multiline == true,
		Font = Ui.font,
		TextSize = 14,
		TextColor3 = Ui.colors.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if o.multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		BackgroundColor3 = Ui.colors.field,
		BorderSizePixel = 0,
		Size = o.size or UDim2.new(1, 0, 0, 26),
		LayoutOrder = o.order or 0,
		ClipsDescendants = true,
	}, { Ui.corner(5), Ui.padding(3, 6), Ui.stroke(Ui.colors.border) })
	if o.onCommit then
		local commit = o.onCommit
		Ui.connect(box, "FocusLost", function()
			commit(box.Text)
		end)
	end
	return box
end

function Ui.scroll(props: { [string]: any }?): ScrollingFrame
	local frame = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.colors.border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	})
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	return frame
end

-- A label in the plugin's rounded title font.
function Ui.title(text: string, size: number, props: { [string]: any }?): TextLabel
	local label = Ui.label(text, {
		Font = Ui.fontTitle,
		TextSize = size,
		Size = UDim2.new(1, 0, 0, size + 6),
	})
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

-- A frame whose height follows its content, laid out as a grid of fixed cells.
function Ui.grid(parent: Instance, cell: Vector2, gap: number, order: number?): Frame
	return Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- A frame whose height follows its content, stacking children vertically.
function Ui.stack(parent: Instance, gap: number, order: number?): Frame
	return Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, { Ui.list("Vertical", gap) })
end

export type TileOptions = {
	size: UDim2?,
	order: number?,
	parent: Instance?,
	selected: boolean?,
	label: string?,
	color: Color3?,
	onClick: (() -> ())?,
}

-- A clickable picture tile. Returns the tile and the frame to draw the picture in.
function Ui.tile(options: TileOptions): (TextButton, Frame)
	local o = options
	local tile = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = o.color or Ui.colors.panelLight,
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(96, 96),
		LayoutOrder = o.order or 0,
		ClipsDescendants = false,
	}, {
		Ui.corner(10),
		Ui.stroke(if o.selected then Ui.colors.selection else Ui.colors.border, if o.selected then 3 else 1),
	})
	local labelHeight = if o.label then 20 else 0
	local content = Ui.new("Frame", {
		Name = "Picture",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -(10 + labelHeight)),
		Parent = tile,
	})
	if o.label then
		Ui.label(o.label, {
			Font = Ui.fontTitle,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -3),
			Size = UDim2.new(1, -8, 0, 18),
			TextColor3 = if o.selected then Ui.colors.selection else Ui.colors.text,
			Parent = tile,
		})
	end
	if o.onClick then
		Ui.connect(tile, "MouseButton1Click", o.onClick)
	end
	if o.parent then
		tile.Parent = o.parent
	end
	return tile, content
end

-- Highlights or un-highlights a tile made by Ui.tile, without rebuilding it.
function Ui.setTileSelected(tile: Instance, selected: boolean)
	local stroke = tile:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then Ui.colors.selection else Ui.colors.border
		stroke.Thickness = if selected then 3 else 1
	end
	local label = tile:FindFirstChildOfClass("TextLabel")
	if label then
		label.TextColor3 = if selected then Ui.colors.selection else Ui.colors.text
	end
end

export type BigButtonOptions = {
	color: Color3?,
	size: UDim2?,
	order: number?,
	parent: Instance?,
	textSize: number?,
	onClick: (() -> ())?,
}

-- A chunky cartoon button (coloured, with a darker lip), for the main actions.
function Ui.bigButton(text: string, options: BigButtonOptions?): TextButton
	local o: BigButtonOptions = options or {}
	local color = o.color or Ui.colors.accent
	local button = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35),
		BorderSizePixel = 0,
		Size = o.size or UDim2.fromOffset(160, 44),
		LayoutOrder = o.order or 0,
	}, { Ui.corner(12) })
	local face = Ui.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -4),
		Parent = button,
	}, { Ui.corner(12) })
	Ui.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		Rotation = 90,
		Parent = face,
	})
	Ui.label(text, {
		Font = Ui.fontTitle,
		TextSize = o.textSize or 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		Parent = face,
	})
	Ui.new("UIStroke", {
		Color = Ui.colors.outline,
		Thickness = 1.5,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = face:FindFirstChildOfClass("TextLabel"),
	})
	if o.onClick then
		Ui.connect(button, "MouseButton1Click", o.onClick)
	end
	if o.parent then
		button.Parent = o.parent
	end
	return button
end

-- Removes everything except layout helpers (UIListLayout, UIPadding...).
function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Ui
