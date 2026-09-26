--[[
	Theme
	Couleurs synchronisées avec le thème de Studio (clair / sombre) et
	ré-appliquées automatiquement quand l'utilisateur change de thème.
]]

local Theme = {}
Theme.__index = Theme

-- Correspondance nom logique -> StudioStyleGuideColor (+ modificateur optionnel).
local MAP = {
	Background = { "MainBackground" },
	Header = { "Titlebar" },
	Section = { "Titlebar" },
	SectionHover = { "Titlebar", "Hover" },
	Text = { "MainText" },
	DimText = { "DimmedText" },
	Border = { "Border" },
	Input = { "InputFieldBackground" },
	InputBorder = { "InputFieldBorder" },
	Button = { "Button" },
	ButtonHover = { "Button", "Hover" },
	ButtonPressed = { "Button", "Pressed" },
	ButtonDisabled = { "Button", "Disabled" },
	ButtonText = { "ButtonText" },
	ButtonTextDisabled = { "ButtonText", "Disabled" },
	Primary = { "DialogMainButton" },
	PrimaryHover = { "DialogMainButton", "Hover" },
	PrimaryText = { "DialogMainButtonText" },
	Accent = { "LinkText" },
	Track = { "ScrollBarBackground" },
	Error = { "ErrorText" },
	Warning = { "WarningText" },
	Item = { "Item" },
	ItemHover = { "Item", "Hover" },
	Selected = { "Item", "Selected" },
}

local FALLBACK = {
	Background = Color3.fromRGB(46, 46, 46),
	Header = Color3.fromRGB(53, 53, 53),
	Section = Color3.fromRGB(60, 60, 60),
	SectionHover = Color3.fromRGB(70, 70, 70),
	Text = Color3.fromRGB(220, 220, 220),
	DimText = Color3.fromRGB(150, 150, 150),
	Border = Color3.fromRGB(34, 34, 34),
	Input = Color3.fromRGB(37, 37, 37),
	InputBorder = Color3.fromRGB(26, 26, 26),
	Button = Color3.fromRGB(64, 64, 64),
	ButtonHover = Color3.fromRGB(76, 76, 76),
	ButtonPressed = Color3.fromRGB(50, 50, 50),
	ButtonDisabled = Color3.fromRGB(52, 52, 52),
	ButtonText = Color3.fromRGB(230, 230, 230),
	ButtonTextDisabled = Color3.fromRGB(120, 120, 120),
	Primary = Color3.fromRGB(0, 122, 204),
	PrimaryHover = Color3.fromRGB(20, 140, 222),
	PrimaryText = Color3.fromRGB(255, 255, 255),
	Accent = Color3.fromRGB(53, 181, 255),
	Track = Color3.fromRGB(41, 41, 41),
	Error = Color3.fromRGB(255, 90, 90),
	Warning = Color3.fromRGB(255, 190, 60),
	Item = Color3.fromRGB(46, 46, 46),
	ItemHover = Color3.fromRGB(66, 66, 66),
	Selected = Color3.fromRGB(11, 90, 175),
}

Theme.SuccessColor = Color3.fromRGB(80, 200, 120)

function Theme.new()
	local self = setmetatable({}, Theme)
	self._bindings = {}
	self._callbacks = {}
	self._studio = nil
	pcall(function()
		self._studio = settings().Studio
	end)
	if self._studio then
		self._connection = self._studio.ThemeChanged:Connect(function()
			self:apply()
		end)
	end
	return self
end

function Theme:color(name)
	local entry = MAP[name]
	if self._studio and entry then
		local ok, c = pcall(function()
			local theme = self._studio.Theme
			local colorEnum = Enum.StudioStyleGuideColor[entry[1]]
			if entry[2] then
				return theme:GetColor(colorEnum, Enum.StudioStyleGuideModifier[entry[2]])
			end
			return theme:GetColor(colorEnum)
		end)
		if ok and c then
			return c
		end
	end
	return FALLBACK[name] or Color3.new(1, 0, 1)
end

-- Lie une propriété à une couleur logique (ré-appliquée au changement de thème).
function Theme:bind(instance, property, name)
	instance[property] = self:color(name)
	table.insert(self._bindings, { Instance = instance, Property = property, Name = name })
end

function Theme:apply()
	local alive = {}
	for _, b in ipairs(self._bindings) do
		if b.Instance.Parent ~= nil or b.Instance:IsA("LayerCollector") then
			pcall(function()
				b.Instance[b.Property] = self:color(b.Name)
			end)
			table.insert(alive, b)
		end
	end
	self._bindings = alive
	for _, cb in ipairs(self._callbacks) do
		pcall(cb)
	end
end

-- Rappel exécuté à chaque changement de thème (contrôles à états multiples).
function Theme:onApply(callback)
	table.insert(self._callbacks, callback)
end

function Theme:destroy()
	if self._connection then
		self._connection:Disconnect()
	end
	self._bindings = {}
	self._callbacks = {}
end

return Theme
