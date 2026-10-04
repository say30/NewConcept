--!strict
-- Small helpers to build the plugin's own interface with plain Instances.

local Ui = {}

-- Colours of the plugin window itself (not of the user's interface).
Ui.colors = {
	background = Color3.fromRGB(30, 31, 36),
	panel = Color3.fromRGB(39, 41, 47),
	panelLight = Color3.fromRGB(50, 52, 60),
	field = Color3.fromRGB(24, 25, 29),
	border = Color3.fromRGB(64, 66, 76),
	text = Color3.fromRGB(232, 233, 237),
	muted = Color3.fromRGB(150, 153, 165),
	accent = Color3.fromRGB(76, 141, 255),
	accentDark = Color3.fromRGB(44, 82, 160),
	danger = Color3.fromRGB(229, 72, 77),
	success = Color3.fromRGB(48, 164, 108),
	selection = Color3.fromRGB(76, 141, 255),
	stage = Color3.fromRGB(90, 120, 150),
}

Ui.font = Enum.Font.BuilderSans
Ui.fontBold = Enum.Font.BuilderSansBold

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

-- Removes everything except layout helpers (UIListLayout, UIPadding...).
function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Ui
