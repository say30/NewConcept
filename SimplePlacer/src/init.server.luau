--[[
	Simple Placer — plugin Roblox Studio
	1) Sélectionne ta zone (sol + murs, ou le Model/Folder qui les contient) -> "Zone"
	2) Sélectionne ton dossier d'assets -> "Assets"
	3) Sélectionne ton dossier de structures -> "Structures" (optionnel)
	4) "Générer". Les structures vont contre l'intérieur des murs, les assets
	   sur le sol, jamais au centre ni à l'extérieur. Ctrl+Z annule.
]]

local RunService = game:GetService("RunService")
if not RunService:IsEdit() then
	return
end

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local ROOT_NAME = "SimplePlacer_Generated"
local SETTINGS_KEY = "SimplePlacer_Settings_v1"

local toolbar = plugin:CreateToolbar("Simple Placer")
local button = toolbar:CreateButton("SimplePlacerToggle", "Placement procédural simple", "rbxasset://textures/ui/GuiImagePlaceholder.png", "Placer")
button.ClickableWhenViewportHidden = true

local okLoad, Placer = pcall(require, script.Placer)
if not okLoad then
	warn("[Simple Placer] erreur de chargement : " .. tostring(Placer))
	return
end

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 300, 420, 260, 300)
local widget = plugin:CreateDockWidgetPluginGui("SimplePlacerWidget", info)
widget.Title = "Simple Placer"
button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
end)

-- État --------------------------------------------------------------------------
local state = {
	ZoneRoots = {},
	AssetRoot = nil,
	StructureRoot = nil,
}
local options = {
	AssetCount = 25,
	CenterClear = 60, -- en %
	Spacing = 2,
	StructureGap = 4,
	Seed = 1,
}
local saved = plugin:GetSetting(SETTINGS_KEY)
if type(saved) == "table" then
	for k, v in pairs(saved) do
		if options[k] ~= nil and type(v) == "number" then
			options[k] = v
		end
	end
end

-- Interface -------------------------------------------------------------------------
local theme = settings().Studio.Theme
local function color(name)
	return theme:GetColor(Enum.StudioStyleGuideColor[name])
end

local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = color("MainBackground")
root.BorderSizePixel = 0
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.CanvasSize = UDim2.new()
root.ScrollBarThickness = 6
root.Parent = widget
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
pad.Parent = root

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function label(text, bold)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 20)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = if bold then Enum.Font.SourceSansBold else Enum.Font.SourceSans
	l.TextSize = 15
	l.TextColor3 = color(if bold then "MainText" else "DimmedText")
	l.Text = text
	l.LayoutOrder = nextOrder()
	l.Parent = root
	return l
end

local function makeButton(text, callback, primary)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BackgroundColor3 = color(if primary then "DialogMainButton" else "Button")
	b.TextColor3 = color(if primary then "DialogMainButtonText" else "ButtonText")
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 15
	b.Text = text
	b.AutoButtonColor = true
	b.LayoutOrder = nextOrder()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = b
	b.Parent = root
	b.Activated:Connect(callback)
	return b
end

local function numberField(text, key)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = root
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0.62, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.SourceSans
	l.TextSize = 15
	l.TextColor3 = color("MainText")
	l.Text = text
	l.Parent = row
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.38, 0, 1, 0)
	box.Position = UDim2.fromScale(0.62, 0)
	box.BackgroundColor3 = color("InputFieldBackground")
	box.TextColor3 = color("MainText")
	box.Font = Enum.Font.SourceSans
	box.TextSize = 15
	box.ClearTextOnFocus = false
	box.Text = tostring(options[key])
	box.Parent = row
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			options[key] = n
			plugin:SetSetting(SETTINGS_KEY, options)
		end
		box.Text = tostring(options[key])
	end)
	return box
end

label("1. Sélection", true)
local zoneLabel, assetLabel, structLabel
local statusLabel

local function setStatus(text)
	statusLabel.Text = text
end

makeButton("Zone = sélection (sol + murs)", function()
	local sel = Selection:Get()
	if #sel == 0 then
		setStatus("Sélectionne d'abord le sol et les murs.")
		return
	end
	local zone, err = Placer.analyzeZone(sel)
	if not zone then
		setStatus(err)
		return
	end
	state.ZoneRoots = sel
	zoneLabel.Text = string.format("Zone : sol '%s', %d mur(s)", zone.Floor.Name, #zone.Walls)
	setStatus("Zone prête.")
end)
zoneLabel = label("Zone : -")

makeButton("Assets = dossier sélectionné", function()
	local sel = Selection:Get()
	if #sel ~= 1 then
		setStatus("Sélectionne UN dossier d'assets.")
		return
	end
	state.AssetRoot = sel[1]
	assetLabel.Text = string.format("Assets : %s (%d)", sel[1].Name, #Placer.scanLibrary(sel[1]))
end)
assetLabel = label("Assets : -")

makeButton("Structures = dossier sélectionné", function()
	local sel = Selection:Get()
	if #sel ~= 1 then
		setStatus("Sélectionne UN dossier de structures.")
		return
	end
	state.StructureRoot = sel[1]
	structLabel.Text = string.format("Structures : %s (%d)", sel[1].Name, #Placer.scanLibrary(sel[1]))
end)
structLabel = label("Structures : - (optionnel)")

label("2. Réglages", true)
numberField("Nombre d'assets", "AssetCount")
numberField("Centre vide (%)", "CenterClear")
numberField("Espacement (studs)", "Spacing")
numberField("Écart entre structures", "StructureGap")
local seedBox = numberField("Seed", "Seed")

label("3. Génération", true)

local function getRoot()
	local r = workspace:FindFirstChild(ROOT_NAME)
	if not r then
		r = Instance.new("Folder")
		r.Name = ROOT_NAME
		r.Parent = workspace
	end
	return r
end

local function lastGeneration()
	local r = workspace:FindFirstChild(ROOT_NAME)
	if not r then
		return nil
	end
	local best, bestN = nil, -1
	for _, c in ipairs(r:GetChildren()) do
		local n = tonumber(string.match(c.Name, "^Generation_(%d+)$"))
		if n and n > bestN then
			best, bestN = c, n
		end
	end
	return best, bestN
end

local function generate()
	if #state.ZoneRoots == 0 then
		setStatus("Choisis d'abord la zone.")
		return
	end
	if not state.AssetRoot and not state.StructureRoot then
		setStatus("Choisis un dossier d'assets et/ou de structures.")
		return
	end
	local zone, err = Placer.analyzeZone(state.ZoneRoots)
	if not zone then
		setStatus(err)
		return
	end
	local assets = if state.AssetRoot and state.AssetRoot.Parent then Placer.scanLibrary(state.AssetRoot) else {}
	local structures = if state.StructureRoot and state.StructureRoot.Parent then Placer.scanLibrary(state.StructureRoot) else {}
	local recording = ChangeHistoryService:TryBeginRecording("Simple Placer: Generate")
	local ok, result = pcall(function()
		local _, n = lastGeneration()
		local gen = Instance.new("Folder")
		gen.Name = "Generation_" .. tostring(math.max(n or 0, 0) + 1)
		gen:SetAttribute("Seed", options.Seed)
		local sFolder = Instance.new("Folder")
		sFolder.Name = "Structures"
		sFolder.Parent = gen
		local aFolder = Instance.new("Folder")
		aFolder.Name = "Assets"
		aFolder.Parent = gen
		local res = Placer.generate(zone, assets, structures, { Structures = sFolder, Assets = aFolder }, {
			Seed = options.Seed,
			AssetCount = math.max(0, math.floor(options.AssetCount)),
			CenterClear = math.clamp(options.CenterClear, 0, 90) / 100,
			Spacing = math.max(0, options.Spacing),
			StructureGap = math.max(0, options.StructureGap),
			Anchor = true,
		})
		gen.Parent = getRoot()
		return res
	end)
	if recording then
		ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end
	if ok then
		setStatus(string.format("OK : %d structure(s), %d asset(s). Ctrl+Z pour annuler.", result.Structures, result.Assets))
	else
		setStatus("Erreur : " .. tostring(result))
		warn("[Simple Placer] " .. tostring(result))
	end
end

local function clearLast()
	local gen = lastGeneration()
	if not gen then
		setStatus("Rien à supprimer.")
		return false
	end
	local recording = ChangeHistoryService:TryBeginRecording("Simple Placer: Clear")
	gen:Destroy()
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return true
end

makeButton("Générer", generate, true)
makeButton("Régénérer (nouvelle variante)", function()
	clearLast()
	options.Seed = Random.new():NextInteger(1, 999999)
	seedBox.Text = tostring(options.Seed)
	plugin:SetSetting(SETTINGS_KEY, options)
	generate()
end)
makeButton("Supprimer la dernière génération", function()
	if clearLast() then
		setStatus("Dernière génération supprimée.")
	end
end)

statusLabel = label("Sélectionne la zone, puis le dossier d'assets.")
