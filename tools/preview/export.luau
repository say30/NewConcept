-- Dev tool: turns a tree of Roblox Instances (built under Lune) into JSON that render.js
-- draws in a browser, so designs can be looked at without opening Studio.

local roblox = require("@lune/roblox")

local PROPS = {
	"Position",
	"Size",
	"AnchorPoint",
	"Rotation",
	"ZIndex",
	"Visible",
	"LayoutOrder",
	"BackgroundColor3",
	"BackgroundTransparency",
	"ClipsDescendants",
	"GroupTransparency",
	"Text",
	"TextColor3",
	"TextSize",
	"TextScaled",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
	"TextTransparency",
	"TextStrokeColor3",
	"TextStrokeTransparency",
	"Font",
	"Image",
	"ImageColor3",
	"ImageTransparency",
	"ScaleType",
	"CornerRadius",
	"Color",
	"Thickness",
	"Transparency",
	"ApplyStrokeMode",
	"BorderStrokePosition",
	"LineJoinMode",
	"Type",
	"TileMode",
	"Scale",
	"Offset",
	"Enabled",
	"FillDirection",
	"Padding",
	"HorizontalAlignment",
	"VerticalAlignment",
	"CellSize",
	"CellPadding",
	"PaddingTop",
	"PaddingBottom",
	"PaddingLeft",
	"PaddingRight",
	"AspectRatio",
	"BlurRadius",
	"Spread",
	"DominantAxis",
	"AspectType",
	"SortOrder",
	"StartCorner",
	"Wraps",
	"AutomaticSize",
	"Active",
	"PlaceholderText",
	"TextTruncate",
	"PlaceholderColor3",
}

local function hex(c)
	return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

local function convert(v)
	local t = typeof(v)
	if t == "UDim2" then
		return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then
		return { v.Scale, v.Offset }
	elseif t == "Vector2" then
		return { v.X, v.Y }
	elseif t == "Color3" then
		return hex(v)
	elseif t == "EnumItem" then
		return v.Name
	elseif t == "ColorSequence" then
		local out = {}
		for _, k in v.Keypoints do
			table.insert(out, { k.Time, hex(k.Value) })
		end
		return out
	elseif t == "NumberSequence" then
		local out = {}
		for _, k in v.Keypoints do
			table.insert(out, { k.Time, k.Value })
		end
		return out
	elseif t == "number" or t == "string" or t == "boolean" then
		return v
	end
	return nil
end

local function serialize(instance)
	local node = { class = instance.ClassName, name = instance.Name, props = {}, children = {} }
	for _, prop in PROPS do
		local ok, value = pcall(function()
			return instance[prop]
		end)
		if ok then
			node.props[prop] = convert(value)
		end
	end
	for _, child in instance:GetChildren() do
		table.insert(node.children, serialize(child))
	end
	return node
end

return { serialize = serialize, roblox = roblox }
