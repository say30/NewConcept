--[[
	Procedural Composer — plugin Roblox Studio
	Point d'entrée (MainPlugin) : barre d'outils, DockWidgetPluginGui,
	chargement des réglages, contrôleurs.

	Architecture :
	  Core/        Config, Settings, Presets, Logger, Utilities, MathUtil, RandomGenerator
	  Analysis/    SelectionAnalyzer, GeometryAnalyzer, AssetAnalyzer, AssetRegistry
	  Placement/   PlacementMath, CollisionEngine, ExclusionZones, SnapEngine,
	               ModularFitter, CandidateScoring, CompositionPlanner, AssetSelector,
	               PlacementContext, FloorPlacementEngine, WallPlacementEngine,
	               ArchitectureEngine, CornerEngine, CeilingPlacementEngine
	  Generation/  AppController, GenerationManager, OutputBuilder, PreviewManager,
	               HistoryManager, DebugVisualizer, Diagnostics
	  UI/          Theme, Widgets, UIController
]]

local RunService = game:GetService("RunService")

-- Le plugin ne fait rien en mode Play / serveur de test.
if not RunService:IsEdit() then
	return
end

local Core = script.Core
local Config = require(Core.Config)
local Settings = require(Core.Settings)
local Logger = require(Core.Logger)
local AppController = require(script.Generation.AppController)
local UIController = require(script.UI.UIController)

local toolbar = plugin:CreateToolbar(Config.PLUGIN_DISPLAY_NAME)
local toggleButton = toolbar:CreateButton(
	"ProceduralComposerToggle",
	"Open the Procedural Composer panel (procedural level design from your asset library)",
	"",
	"Composer"
)
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	Config.UI.DEFAULT_WIDTH,
	Config.UI.DEFAULT_HEIGHT,
	Config.UI.MIN_WIDTH,
	Config.UI.MIN_HEIGHT
)
local widget
do
	-- API récente (asynchrone) avec repli sur l'ancienne.
	local ok, result = pcall(function()
		return (plugin :: any):CreateDockWidgetPluginGuiAsync(Config.UI.WIDGET_ID, widgetInfo)
	end)
	if ok and result then
		widget = result
	else
		widget = (plugin :: any):CreateDockWidgetPluginGui(Config.UI.WIDGET_ID, widgetInfo)
	end
end
widget.Title = Config.PLUGIN_DISPLAY_NAME
widget.Name = Config.UI.WIDGET_ID
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local settings = Settings.new(plugin)
settings:load()

local app = AppController.new(plugin, settings)
local ui = UIController.new(plugin, widget, app, settings)

toggleButton:SetActive(widget.Enabled)
toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
	if not widget.Enabled then
		app:clearDebug()
	end
end)

plugin.Unloading:Connect(function()
	settings:save()
	ui:destroy()
	app:destroy()
end)

Logger.verbose("v" .. Config.VERSION .. " loaded.")
