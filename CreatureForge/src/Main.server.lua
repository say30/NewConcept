-- Creature Forge — point d'entrée du plugin (plugin local Roblox Studio).
-- Bouton de barre d'outils -> fenêtre ancrable « CREATURE FORGE ».

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

-- Le plugin ne tourne qu'en mode édition (pas pendant un Play Solo côté client/serveur).
if RunService:IsRunning() then
	return
end

local root = script.Parent
local Config = require(root.Config)
local Controller = require(root.Core.Controller)
local MainWindow = require(root.UI.MainWindow)

local toolbar = plugin:CreateToolbar(Config.PLUGIN_NAME)
local button = toolbar:CreateButton("CreatureForge", "Ouvrir Creature Forge", "", "Creature Forge")
button.ClickableWhenViewportHidden = true

local controller = Controller.new(plugin)
local window = MainWindow.new(plugin, controller)

button.Click:Connect(function()
	window:toggle()
end)
window.widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(window.widget.Enabled)
end)
button:SetActive(window.widget.Enabled)

local selectionConn = Selection.SelectionChanged:Connect(function()
	controller:setSelection(Selection:Get())
end)
controller:setSelection(Selection:Get())

-- Après un Ctrl+Z / Ctrl+Y, l'état affiché est rafraîchi.
local undoConn = ChangeHistoryService.OnUndo:Connect(function()
	controller:emit()
end)
local redoConn = ChangeHistoryService.OnRedo:Connect(function()
	controller:emit()
end)

plugin.Unloading:Connect(function()
	selectionConn:Disconnect()
	undoConn:Disconnect()
	redoConn:Disconnect()
	controller:destroy()
end)
