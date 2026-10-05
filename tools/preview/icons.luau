-- Dev scene: every icon of src/Visual/Icons on a grid, exported for render.js.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local loader = require("../../tests/loader")
local export = require("./export")
local roblox = loader.roblox

local Icons = loader.require(loader.src.Visual.Icons)
local size = tonumber(process.args[2]) or 96
local root = roblox.Instance.new("Frame")
root.Size = roblox.UDim2.fromOffset(6 * (size + 40), 0)
root.BackgroundTransparency = 1
local grid = roblox.Instance.new("UIGridLayout")
grid.CellSize = roblox.UDim2.fromOffset(size + 24, size + 40)
grid.CellPadding = roblox.UDim2.fromOffset(16, 8)
grid.Parent = root
for i, def in Icons.list do
	local cell = roblox.Instance.new("Frame")
	cell.BackgroundTransparency = 1
	cell.LayoutOrder = i
	local box = roblox.Instance.new("Frame")
	box.Size = roblox.UDim2.fromOffset(size, size)
	box.Position = roblox.UDim2.fromOffset(12, 0)
	box.BackgroundTransparency = 1
	box.Parent = cell
	Icons.build(def.id, box)
	local label = roblox.Instance.new("TextLabel")
	label.Text = def.label
	label.Size = roblox.UDim2.new(1, 0, 0, 30)
	label.Position = roblox.UDim2.fromOffset(0, size + 4)
	label.BackgroundTransparency = 1
	label.TextColor3 = roblox.Color3.new(1, 1, 1)
	label.TextSize = 15
	label.Font = roblox.Enum.Font.FredokaOne
	label.Parent = cell
	cell.Parent = root
end
local rows = math.ceil(#Icons.list / 6)
local scene = {
	width = 6 * (size + 40),
	height = rows * (size + 48),
	background = "#3b4a6b",
	root = export.serialize(root),
	fillRoot = true,
}
fs.writeFile(process.args[1], serde.encode("json", { scenes = { scene } }))
