-- GuiCreator plugin entry point: toolbar button, editor window, and the Studio services
-- the editor needs (saving in ServerStorage, generating into StarterGui, undo in Studio).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local Editor = require(script.App.Editor)
local ProjectStore = require(script.Persistence.ProjectStore)

local codec = {
	encode = function(value)
		return HttpService:JSONEncode(value)
	end,
	decode = function(text)
		return HttpService:JSONDecode(text)
	end,
}

local projects = ProjectStore.new(ServerStorage, codec)

local services = {
	projectStore = projects,
	generateTarget = function()
		return StarterGui
	end,
	recordChange = function(label, fn)
		local recording = ChangeHistoryService:TryBeginRecording(label)
		local ok, err = pcall(fn)
		if recording then
			ChangeHistoryService:FinishRecording(
				recording,
				if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end
		if not ok then
			error(err, 0)
		end
	end,
	selectInStudio = function(instances)
		Selection:Set(instances)
	end,
}

local toolbar = plugin:CreateToolbar("GuiCreator")
local openButton = toolbar:CreateButton(
	"GuiCreator",
	"Ouvrir l'éditeur d'interface GuiCreator",
	"rbxasset://textures/ui/GuiImagePlaceholder.png",
	"GuiCreator"
)
openButton.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui(
	"GuiCreatorEditor",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 1280, 760, 1000, 560)
)
widget.Title = "GuiCreator"
widget.Name = "GuiCreator"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local editor = nil

-- Opens the most recent project of this place, or starts a new one.
local function startEditor()
	if editor then
		return
	end
	local project = nil
	local latest = projects:list()[1]
	if latest then
		local ok, result = pcall(projects.load, projects, latest.id)
		if ok then
			project = result
		else
			warn("[GuiCreator] Impossible de relire le projet enregistré : " .. tostring(result))
		end
	end
	editor = Editor.new(widget, services, project)
end

openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	openButton:SetActive(widget.Enabled)
	if widget.Enabled then
		startEditor()
	end
end)

if widget.Enabled then
	startEditor()
end

plugin.Unloading:Connect(function()
	if editor then
		editor:destroy()
		editor = nil
	end
end)
