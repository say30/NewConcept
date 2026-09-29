-- Construit la vraie fenêtre (instances simulées), clique sur les boutons, vérifie le rendu.
local Controller = REQUIRE(ROOT_SCRIPT.Core.Controller)
local MainWindow = REQUIRE(ROOT_SCRIPT.UI.MainWindow)

local plugin = {
	settings = {},
	GetSetting = function(self, k)
		return self.settings[k]
	end,
	SetSetting = function(self, k, v)
		self.settings[k] = v
	end,
	CreateDockWidgetPluginGuiAsync = function(self, id, info)
		return MockInstance("DockWidgetPluginGui", { Enabled = false })
	end,
}

local pivot = CFrame.new(0, 0, 0)
local creature = MockInstance("Model", { Name = "Sunshine Dragon", WorldPivot = pivot }, workspace)
for i, def in {
	{ "Body", Vector3.new(0, 3, 0), Vector3.new(2.6, 2.2, 4.2) },
	{ "Head", Vector3.new(0, 5, -3), Vector3.new(1.6, 1.4, 1.8) },
	{ "LegFL", Vector3.new(1, 1, -1.3), Vector3.new(0.6, 2, 0.6) },
	{ "LegFR", Vector3.new(-1, 1, -1.3), Vector3.new(0.6, 2, 0.6) },
	{ "LegBL", Vector3.new(1, 1, 1.3), Vector3.new(0.6, 2, 0.6) },
	{ "LegBR", Vector3.new(-1, 1, 1.3), Vector3.new(0.6, 2, 0.6) },
	{ "Tail", Vector3.new(0, 2.5, 3.2), Vector3.new(0.6, 0.6, 2.4) },
} do
	MockInstance("MeshPart", { Name = def[1], CFrame = pivot * CFrame.new(def[2]), Size = def[3], Color = Color3.fromRGB(200, 100, 50), Material = Enum.Material.Plastic }, creature)
end

local c = Controller.new(plugin)
local w = MainWindow.new(plugin, c)

local function findButton(text)
	for _, d in w.widget:GetDescendants() do
		if d.ClassName == "TextButton" and d.Text == text then
			return d
		end
	end
	error("bouton introuvable : " .. text)
end
local function click(text)
	findButton(text).Activated:Fire()
	local err = c.state.status.error
	assert(err == nil, "erreur après " .. text .. " : " .. (err and err.text or ""))
	print("  clic  " .. text)
end

c:setSelection({ creature })
assert(w.ui.selection.Text:find("Sunshine Dragon"), "nom de la sélection affiché")
click("ANALYSER LA CRÉATURE")
assert(w.ui.summary.Text:find("Pièces :</b> 7"), "résumé : " .. w.ui.summary.Text)
click("BLUEPRINT")
click("VUE ÉCLATÉE")
click("AFFICHER RIG")
assert(findButton("MASQUER RIG"), "libellé bascule")
click("MASQUER RIG")
click("Forte")
assert(c.state.settings.variation == 3, "variation Forte")
click("RANDOM")
assert(tonumber(c.state.settings.seed), "seed aléatoire")
click("CRÉER MA CRÉATURE")
assert(c.state.generated, "créature générée via l'UI")
click("NOUVELLES COULEURS")
click("Smooth")
click("CRÉER RIG")
click("PUBLIER MES MESHES")
for _, d in w.widget:GetDescendants() do
	if d.ClassName == "TextButton" and d.Text == "" then
		local l = d:FindFirstChildWhichIsA("TextLabel")
		if l and l.Text == "Primary" then
			d.Activated:Fire()
			print("  clic  pastille Primary")
		end
	end
end
local sel = game:GetService("Selection"):Get()[1]
assert(sel and sel.ClassName == "Color3Value", "clic pastille -> Color3Value sélectionnée")
c:setSelection({ sel })
assert(c.state.selectionKind == "generated", "reste sur la créature générée")
local lines = {}
for _, d in w.widget:GetDescendants() do
	if d.ClassName == "TextLabel" and d.RichText and d.Visible ~= false and tostring(d.Text):find("font") then
		table.insert(lines, (d.Text:gsub("<[^>]+>", "")))
	end
end
print("Rendu (extraits) :")
for _, l in lines do
	print("   " .. l:gsub("\n", " | "))
end
print("UI OK")
