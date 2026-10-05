-- Dev scene: the plugin's own screens (home, assistant, workspace) exported for render.js.
--   lune run tools/preview/plugin.luau <out.json>
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local loader = require("../../tests/loader")
local export = require("./export")
local roblox = loader.roblox
local R = loader.require
local src = loader.src

local Ui = R(src.App.Ui)
local noop = { Disconnect = function() end }
Ui.connect = function()
	return noop
end
Ui.onPropertyChanged = function()
	return noop
end
local Editor = R(src.App.Editor)
local ProjectStore = R(src.Persistence.ProjectStore)
local Recipes = R(src.Catalog.Recipes)

local codec = {
	encode = function(v)
		return serde.encode("json", v)
	end,
	decode = function(s)
		return serde.decode("json", s)
	end,
}
local W, H = 1280, 760
local function newEditor()
	local root = roblox.Instance.new("Frame")
	root.Size = roblox.UDim2.fromOffset(W, H)
	local services = {
		projectStore = ProjectStore.new(roblox.Instance.new("Folder"), codec),
		generateTarget = function()
			return roblox.Instance.new("Folder")
		end,
		recordChange = function(_, fn)
			fn()
		end,
	}
	return Editor.new(root, services), root
end

local scenes = {}
local function snap(title, root)
	table.insert(
		scenes,
		{ title = title, width = W, height = H, root = export.serialize(root), background = "#000000" }
	)
end

local which = process.args[2] or "all"

if which == "all" or which == "home" then
	local editor, root = newEditor()
	snap("Accueil", root)
	editor:showWizard(nil)
	snap("Assistant : choix du type", root)
end
if which == "all" or which == "wizard" then
	local editor, root = newEditor()
	editor:showWizard("Shop")
	snap("Assistant : style", root)
	editor.wizard.step = 5
	editor.wizard:render()
	snap("Assistant : présentation", root)
	editor.wizard.step = 11
	editor.wizard:render()
	snap("Assistant : monnaie", root)
end
if which == "all" or which == "workspace" then
	local editor, root = newEditor()
	editor:applyRecipe(Recipes.get("Shop"), { pack = "Studs" })
	-- No layout engine here: fit the canvas by hand.
	editor.canvas.scale.Scale = (W - 290 - 330 - 48) / 1366
	editor.canvas:render()
	editor.canvas.scale.Scale = (W - 290 - 330 - 48) / 1366
	snap("Éditeur : fenêtre sélectionnée", root)
	local window = editor.store.selection:primary()
	local body = editor.store.project.nodes[window].children[1]
	local items = editor.store.project.nodes[body].children[1]
	local card = editor.store.project.nodes[items].children[1]
	editor.store.selection:set({ card })
	editor.palette.category = "Buttons"
	editor.palette:render()
	snap("Éditeur : carte sélectionnée", root)
end
fs.writeFile(process.args[1], serde.encode("json", { columns = 1, scenes = scenes }))
