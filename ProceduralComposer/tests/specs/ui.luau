-- Test de fumée de l'interface : construction complète, rafraîchissements, clics.

local function findAll(root, className)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d.ClassName == className then
			table.insert(out, d)
		end
	end
	return out
end

test("UI - builds the full widget, refreshes and every button is clickable", function()
	local AppController = require(ROOT.Generation.AppController)
	local UIController = require(ROOT.UI.UIController)
	local lib = buildLibrary({ Architecture = true })
	local _, zone = roomScene()
	local settings = M.Settings.new(nil)
	local app = AppController.new(nil, settings)
	local widget = Instance.new("Frame")
	local ui = UIController.new(nil, widget, app, settings)
	check(#widget:GetChildren() == 1, "root frame created")
	local buttons = findAll(widget, "TextButton")
	check(#buttons > 40, "controls expected, got " .. #buttons)
	-- Sélection de la zone et de la bibliothèque via les boutons.
	local sel = __mock.services.Selection
	local function click(text)
		for _, b in ipairs(findAll(widget, "TextButton")) do
			if b.Text == text then
				b.Activated:Fire()
				return true
			end
		end
		error("button not found: " .. text)
	end
	sel:Set({ zone })
	click("Use Current Selection")
	check(app.Analysis ~= nil, "analysis through UI")
	sel:Set({ lib })
	click("Use Current Selection as Library")
	check(app.Registry:count() == 25, "library through UI")
	click("Generate Preview")
	check(app:hasPreview(), "preview through UI: " .. app.Status.Text)
	click("Regenerate")
	click("Accept")
	check(app:generationCount() == 1, "accept through UI")
	-- Toutes les autres commandes : aucun plantage.
	for _, text in ipairs({ "Analyse Selection", "Rescan Library", "Random Seed", "Redraw Debug", "Clear Debug",
		"Use Selection as Zones", "Clear Zones", "Use Selection as Protected", "Clear Protected", "Analyse" }) do
		click(text)
	end
	click("Clear Generated")
	-- La boîte de confirmation apparaît : on confirme.
	click("Delete")
	check(app:generationCount() == 0, "clear through confirmation dialog")
	-- Dropdowns : ouverture + choix d'une option.
	local dropdown
	for _, b in ipairs(findAll(widget, "TextButton")) do
		if b.Name == "Dropdown" and b.Text == settings:get("RotationMode") then
			dropdown = b
		end
	end
	check(dropdown ~= nil, "rotation dropdown")
	dropdown.Activated:Fire()
	click("  FaceCenter")
	check(settings:get("RotationMode") == "FaceCenter", "dropdown changes the setting")
	-- Toggles.
	local before = settings:get("KeepCenterClear")
	for _, b in ipairs(findAll(widget, "TextButton")) do
		if b.Name == "Toggle" and b.Parent.Parent.Name == "Row_Keep center clear" then
			b.Activated:Fire()
		end
	end
	check(settings:get("KeepCenterClear") ~= before, "toggle changes the setting")
	-- Presets.
	settings:applyPreset("CleanCorridor")
	check(settings:get("KeepCenterClear") == true, "preset through settings")
	-- Changement de thème.
	ui.Theme:apply()
	ui:refreshAll()
	ui:destroy()
	app:destroy()
end)
