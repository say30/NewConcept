--!strict
-- Background patterns (studs, dots, diamonds...) drawn with plain Frames. They are placed
-- inside a CanvasGroup that has the same rounded corners as the surface, so the pattern
-- follows the corners instead of sticking out of them.

local Patterns = {}

export type PatternDef = { id: string, label: string }

Patterns.list = {
	{ id = "None", label = "Aucun" },
	{ id = "Studs", label = "Studs" },
	{ id = "Dots", label = "Pois" },
	{ id = "Diamonds", label = "Losanges" },
	{ id = "Checker", label = "Damier" },
	{ id = "Stripes", label = "Rayures" },
	{ id = "Grid", label = "Quadrillage" },
} :: { PatternDef }

-- Upper bound on the number of shapes one pattern may create.
local MAX_CELLS = 450

local function frame(parent: Instance, color: Color3): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Parent = parent
	return f
end

local function round(f: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
end

local function grid(parent: Instance, cell: number, gap: number)
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(cell, cell)
	g.CellPadding = UDim2.fromOffset(gap, gap)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Left
	g.VerticalAlignment = Enum.VerticalAlignment.Top
	g.Parent = parent
end

-- Number of grid cells needed to cover w x h with a step of `step` pixels.
local function cells(w: number, h: number, step: number): number
	local count = (math.ceil(w / step) + 1) * (math.ceil(h / step) + 1)
	return math.min(count, MAX_CELLS)
end

-- Fills `holder` (a CanvasGroup the size of the surface) with pattern `id`.
-- `w` and `h` are the expected pixel size of the surface; `size` is the pattern step.
function Patterns.build(holder: Instance, id: string, w: number, h: number, color: Color3, size: number)
	local step = math.max(8, size)
	-- Wide surfaces would need too many shapes: grow the step instead.
	while (math.ceil(w / step) + 1) * (math.ceil(h / step) + 1) > MAX_CELLS do
		step += 2
	end

	if id == "Studs" or id == "Dots" then
		local d = math.floor(step * (if id == "Studs" then 0.62 else 0.34))
		local gap = step - d
		local area = Instance.new("Frame")
		area.Name = "Area"
		area.BackgroundTransparency = 1
		area.Position = UDim2.fromOffset(math.floor(gap / 2), math.floor(gap / 2))
		area.Size = UDim2.new(1, step, 1, step)
		area.Parent = holder
		grid(area, d, gap)
		for i = 1, cells(w, h, step) do
			local dot = frame(area, color)
			dot.Name = "Dot"
			dot.LayoutOrder = i
			round(dot)
			if id == "Studs" then
				local rim = Instance.new("UIStroke")
				rim.Color = Color3.new(0, 0, 0)
				rim.Transparency = 0.55
				rim.Thickness = math.max(1, math.floor(step / 12))
				rim.Parent = dot
			end
		end
	elseif id == "Diamonds" then
		local d = math.floor(step * 0.5)
		local gap = step - d
		local area = Instance.new("Frame")
		area.Name = "Area"
		area.BackgroundTransparency = 1
		area.Position = UDim2.fromOffset(math.floor(gap / 2), math.floor(gap / 2))
		area.Size = UDim2.new(1, step, 1, step)
		area.Parent = holder
		grid(area, d, gap)
		for i = 1, cells(w, h, step) do
			local diamond = frame(area, color)
			diamond.Name = "Diamond"
			diamond.Rotation = 45
			diamond.LayoutOrder = i
		end
	elseif id == "Checker" then
		local block = step * 2
		local area = Instance.new("Frame")
		area.Name = "Area"
		area.BackgroundTransparency = 1
		area.Size = UDim2.new(1, block, 1, block)
		area.Parent = holder
		grid(area, block, 0)
		for i = 1, cells(w, h, block) do
			local cell = Instance.new("Frame")
			cell.Name = "Block"
			cell.BackgroundTransparency = 1
			cell.LayoutOrder = i
			cell.Parent = area
			local a = frame(cell, color)
			a.Size = UDim2.fromScale(0.5, 0.5)
			local b = frame(cell, color)
			b.Size = UDim2.fromScale(0.5, 0.5)
			b.Position = UDim2.fromScale(0.5, 0.5)
		end
	elseif id == "Stripes" then
		local count = math.min(MAX_CELLS, math.ceil((w + h) / step) + 2)
		local length = (w + h) * 1.5
		for i = 0, count do
			local bar = frame(holder, color)
			bar.Name = "Stripe"
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Size = UDim2.fromOffset(math.floor(step * 0.45), length)
			bar.Rotation = 45
			bar.Position = UDim2.fromOffset(i * step * 1.414 - h, h / 2)
		end
	elseif id == "Grid" then
		local thickness = math.max(1, math.floor(step / 14))
		for x = 0, math.ceil(w / step) do
			local line = frame(holder, color)
			line.Name = "Column"
			line.Size = UDim2.new(0, thickness, 1, 0)
			line.Position = UDim2.fromOffset(x * step, 0)
		end
		for y = 0, math.ceil(h / step) do
			local line = frame(holder, color)
			line.Name = "Row"
			line.Size = UDim2.new(1, 0, 0, thickness)
			line.Position = UDim2.fromOffset(0, y * step)
		end
	end
end

return Patterns
