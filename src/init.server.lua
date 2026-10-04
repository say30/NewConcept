-- GuiCreator plugin entry point.
--
-- Step 1 only ships the core (project model, commands, undo/redo, saving in the place).
-- The window below is a temporary test panel to check that core inside Studio; the real
-- editor (canvas, inspector, layers) replaces it in step 2.

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Core = script.Core
local Document = require(Core.Document)
local Store = require(Core.Store)
local Commands = require(Core.Commands)
local ProjectStore = require(script.Persistence.ProjectStore)
local AutoSave = require(script.Persistence.AutoSave)

local codec = {
	encode = function(value)
		return HttpService:JSONEncode(value)
	end,
	decode = function(text)
		return HttpService:JSONDecode(text)
	end,
}

local projects = ProjectStore.new(ServerStorage, codec)
local store = Store.new()
local autoSave = nil

local toolbar = plugin:CreateToolbar("GuiCreator")
local openButton =
	toolbar:CreateButton("GuiCreator", "Open GuiCreator", "rbxasset://textures/ui/GuiImagePlaceholder.png")
openButton.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui(
	"GuiCreatorMain",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 360, 420, 300, 300)
)
widget.Title = "GuiCreator (test du socle)"

openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	openButton:SetActive(widget.Enabled)
end)

--------------------------------------------------------------------------------
-- Temporary test panel
--------------------------------------------------------------------------------

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(37, 37, 41)
root.BorderSizePixel = 0
root.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = root

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root

local order = 0
local function nextOrder()
	order += 1
	return order
end

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 150)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.fromRGB(230, 230, 235)
info.Font = Enum.Font.GothamMedium
info.TextSize = 14
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.LayoutOrder = nextOrder()
info.Parent = root

local function makeButton(text: string, onClick: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 32)
	button.BackgroundColor3 = Color3.fromRGB(58, 120, 220)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = text
	button.AutoButtonColor = true
	button.LayoutOrder = nextOrder()
	button.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.MouseButton1Click:Connect(onClick)
	return button
end

local lastMessage = ""

local function describe(): string
	local project = store.project
	local nodeCount = 0
	for _ in project.nodes do
		nodeCount += 1
	end
	local pageNames = {}
	for _, page in Document.getPages(project) do
		table.insert(pageNames, page.name)
	end
	local saved = {}
	for _, summary in projects:list() do
		table.insert(saved, summary.name)
	end
	return string.format(
		"Projet : %s\nPages : %s\nÉléments : %d\nAnnuler : %s   Rétablir : %s\nProjets dans la place : %s\n\n%s",
		project.name,
		if #pageNames > 0 then table.concat(pageNames, ", ") else "aucune",
		nodeCount,
		if store.history:canUndo() then "oui" else "non",
		if store.history:canRedo() then "oui" else "non",
		if #saved > 0 then table.concat(saved, ", ") else "aucun",
		lastMessage
	)
end

local function refresh()
	info.Text = describe()
end

local function report(ok: boolean, err: any)
	lastMessage = if ok then "" else "Erreur : " .. tostring(err)
	refresh()
end

local function useProject(project)
	if autoSave then
		autoSave.stop()
	end
	store:load(project)
	autoSave = AutoSave.start(store, projects, function(err)
		report(false, err)
	end)
	refresh()
end

store.changed:Connect(refresh)

makeButton("Créer un projet de test", function()
	local fresh = Store.new(Document.newProject("TestShop"))
	local _, pageId = fresh:dispatch(Commands.AddPage.new("Shop"))
	local page = fresh.project.pages[pageId]
	fresh:dispatch(Commands.InsertTree.new({
		type = "Window",
		name = "ShopWindow",
		children = {
			{ type = "Text", name = "Title", props = { text = { value = "Shop" } } },
			{ type = "Button", name = "Close button" },
			{ type = "Button", name = "Buy button" },
		},
	}, page.rootId))
	useProject(fresh.project)
	projects:save(store.project)
	lastMessage = "Projet créé et enregistré dans ServerStorage."
	refresh()
end)

makeButton("Ajouter un bouton", function()
	local page = Document.getPages(store.project)[1]
	if not page then
		report(false, "crée d'abord un projet de test")
		return
	end
	report(store:dispatch(Commands.InsertTree.new({ type = "Button", name = "BuyButton" }, page.rootId)))
end)

makeButton("Annuler (undo)", function()
	store:undo()
end)

makeButton("Rétablir (redo)", function()
	store:redo()
end)

makeButton("Recharger le dernier projet enregistré", function()
	local latest = projects:list()[1]
	if not latest then
		report(false, "aucun projet enregistré dans cette place")
		return
	end
	local ok, result = pcall(projects.load, projects, latest.id)
	if ok then
		useProject(result)
		lastMessage = "Projet rechargé depuis la place."
		refresh()
	else
		report(false, result)
	end
end)

refresh()

plugin.Unloading:Connect(function()
	if autoSave then
		autoSave.stop()
	end
end)
